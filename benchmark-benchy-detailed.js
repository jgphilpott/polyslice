/**
 * Comprehensive Benchy slicing benchmark and gap analysis
 * Analyzes layers 0-10 for segment quality, gaps, and timing
 */

const path = require("path");
const fs = require("fs");
const THREE = require("three");
const Polytree = require("@jgphilpott/polytree");
const helpers = require("./src/slicer/geometry/helpers");

async function loadSTLMesh(stlPath) {
  const { STLLoader } = await import("three/examples/jsm/loaders/STLLoader.js");
  const buffer = fs.readFileSync(stlPath);
  const loader = new STLLoader();
  const geometry = loader.parse(buffer.buffer);
  geometry.computeVertexNormals?.();
  const material = new THREE.MeshPhongMaterial({ color: 0x808080 });
  const mesh = new THREE.Mesh(geometry, material);

  geometry.computeBoundingBox();
  const bb = geometry.boundingBox;
  const zShift = -bb.min.z;
  mesh.position.set(0, 0, zShift);
  mesh.updateMatrixWorld();
  return mesh;
}

function analyzeSegmentQuality(segments, layerIdx, z) {
  const epsilon = 0.001;
  
  // Build connectivity map
  const pointMap = new Map();
  
  for (let i = 0; i < segments.length; i++) {
    const seg = segments[i];
    const startKey = `${seg.start.x.toFixed(6)},${seg.start.y.toFixed(6)}`;
    const endKey = `${seg.end.x.toFixed(6)},${seg.end.y.toFixed(6)}`;

    if (!pointMap.has(startKey)) pointMap.set(startKey, []);
    if (!pointMap.has(endKey)) pointMap.set(endKey, []);

    pointMap.get(startKey).push({ segIdx: i, type: 'start' });
    pointMap.get(endKey).push({ segIdx: i, type: 'end' });
  }

  // Count branching points
  let branchPoints = 0;
  let isolatedSegments = 0;
  
  for (const [pointKey, connections] of pointMap.entries()) {
    if (connections.length > 2) {
      branchPoints++;
    }
  }
  
  // Count isolated segments (dead ends)
  for (let i = 0; i < segments.length; i++) {
    const seg = segments[i];
    const startKey = `${seg.start.x.toFixed(6)},${seg.start.y.toFixed(6)}`;
    const endKey = `${seg.end.x.toFixed(6)},${seg.end.y.toFixed(6)}`;

    if (pointMap.get(startKey).length === 1 || pointMap.get(endKey).length === 1) {
      isolatedSegments++;
    }
  }

  // Connect segments to paths
  const paths = helpers.connectSegmentsToPaths(segments);
  
  // Analyze each path
  const pathStats = [];
  let totalGaps = 0;
  let maxGapInLayer = 0;
  let maxGapLocation = null;
  
  for (let pathIdx = 0; pathIdx < paths.length; pathIdx++) {
    const path = paths[pathIdx];
    const firstPt = path[0];
    const lastPt = path[path.length - 1];
    const closureGap = Math.sqrt(
      Math.pow(lastPt.x - firstPt.x, 2) + 
      Math.pow(lastPt.y - firstPt.y, 2)
    );
    const isClosed = closureGap < epsilon;
    
    // Find largest internal gap
    let maxInternalGap = 0;
    let maxInternalGapIdx = -1;
    
    for (let i = 0; i < path.length - 1; i++) {
      const p1 = path[i];
      const p2 = path[i + 1];
      const gap = Math.sqrt(
        Math.pow(p2.x - p1.x, 2) + 
        Math.pow(p2.y - p1.y, 2)
      );
      
      if (gap > maxInternalGap) {
        maxInternalGap = gap;
        maxInternalGapIdx = i;
      }
      
      if (gap > 1.0) {  // Count gaps > 1mm
        totalGaps++;
      }
    }
    
    if (maxInternalGap > maxGapInLayer) {
      maxGapInLayer = maxInternalGap;
      maxGapLocation = {
        pathIdx,
        segmentIdx: maxInternalGapIdx,
        from: path[maxInternalGapIdx],
        to: path[maxInternalGapIdx + 1]
      };
    }
    
    pathStats.push({
      points: path.length,
      isClosed,
      closureGap,
      maxInternalGap,
      maxInternalGapIdx
    });
  }
  
  return {
    layerIdx,
    z,
    segmentCount: segments.length,
    branchPoints,
    isolatedSegments,
    pathCount: paths.length,
    pathStats,
    totalGapsOver1mm: totalGaps,
    maxGapInLayer,
    maxGapLocation
  };
}

async function main() {
  console.log("╔═══════════════════════════════════════════════════════════════╗");
  console.log("║  BENCHY SLICING BENCHMARK - Polytree Performance Analysis    ║");
  console.log("╚═══════════════════════════════════════════════════════════════╝\n");

  const stlPath = path.join(__dirname, "resources/testing/benchy.test.stl");
  
  console.log("Phase 1: Loading STL mesh");
  console.log("─────────────────────────────────────────────────────────────────");
  
  const loadStart = Date.now();
  let mesh;
  try {
    mesh = await loadSTLMesh(stlPath);
  } catch (err) {
    console.error("❌ Failed to load STL:", err.message);
    process.exit(1);
  }
  const loadTime = Date.now() - loadStart;
  
  const pos = mesh.geometry.attributes.position;
  const triangleCount = pos ? Math.floor(pos.count / 3) : 0;
  
  console.log(`✅ Mesh loaded in ${(loadTime / 1000).toFixed(2)}s`);
  console.log(`   Vertices: ${pos ? pos.count.toLocaleString() : "unknown"}`);
  console.log(`   Triangles: ${triangleCount.toLocaleString()}\n`);

  const boundingBox = new THREE.Box3().setFromObject(mesh);
  const minZ = boundingBox.min.z;
  const maxZ = boundingBox.max.z;
  const layerHeight = 0.2;
  const SLICE_EPSILON = 0.01;
  const numLayers = 11;  // Layers 0-10
  const sliceMaxZ = minZ + (numLayers * layerHeight);

  console.log("Phase 2: Slicing with Polytree");
  console.log("─────────────────────────────────────────────────────────────────");
  console.log(`   Layer height: ${layerHeight}mm`);
  console.log(`   Z range: ${minZ.toFixed(2)} to ${sliceMaxZ.toFixed(2)}mm`);
  console.log(`   Target layers: ${numLayers}\n`);

  const sliceStart = Date.now();
  const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ + SLICE_EPSILON, sliceMaxZ);
  const sliceTime = Date.now() - sliceStart;
  
  console.log(`✅ Sliced in ${(sliceTime / 1000).toFixed(2)}s`);
  console.log(`   Average: ${(sliceTime / allLayers.length).toFixed(0)}ms per layer`);
  console.log(`   Layers generated: ${allLayers.length}\n`);

  console.log("Phase 3: Segment Quality Analysis");
  console.log("─────────────────────────────────────────────────────────────────\n");

  const analysisResults = [];
  const analysisStart = Date.now();
  
  for (let i = 0; i < Math.min(allLayers.length, numLayers); i++) {
    const segments = allLayers[i];
    const z = (minZ + SLICE_EPSILON + i * layerHeight);
    const result = analyzeSegmentQuality(segments, i, z);
    analysisResults.push(result);
  }
  
  const analysisTime = Date.now() - analysisStart;
  console.log(`✅ Analysis completed in ${(analysisTime / 1000).toFixed(2)}s\n`);

  // Print summary table
  console.log("╔══════════════════════════════════════════════════════════════════════════════════╗");
  console.log("║                           LAYER SUMMARY TABLE                                    ║");
  console.log("╠═══════╦═══════════╦══════════╦═════════╦══════════╦══════════╦═══════════════════╣");
  console.log("║ Layer ║   Z (mm)  ║ Segments ║  Paths  ║ Branch   ║ Isolated ║  Max Gap (mm)     ║");
  console.log("╠═══════╬═══════════╬══════════╬═════════╬══════════╬══════════╬═══════════════════╣");
  
  for (const result of analysisResults) {
    const layer = result.layerIdx.toString().padStart(5);
    const z = result.z.toFixed(2).padStart(9);
    const segs = result.segmentCount.toString().padStart(8);
    const paths = result.pathCount.toString().padStart(7);
    const branch = result.branchPoints.toString().padStart(8);
    const isolated = result.isolatedSegments.toString().padStart(8);
    const maxGap = result.maxGapInLayer.toFixed(2).padStart(17);
    
    // Highlight problematic layers
    const marker = result.maxGapInLayer > 1.0 ? "⚠️ " : "   ";
    
    console.log(`║ ${marker}${layer} ║ ${z} ║ ${segs} ║ ${paths} ║ ${branch} ║ ${isolated} ║ ${maxGap} ║`);
  }
  
  console.log("╚═══════╩═══════════╩══════════╩═════════╩══════════╩══════════╩═══════════════════╝\n");

  // Detailed reports for problematic layers
  console.log("Phase 4: Detailed Gap Reports");
  console.log("─────────────────────────────────────────────────────────────────\n");
  
  const problematicLayers = analysisResults.filter(r => r.maxGapInLayer > 1.0);
  
  if (problematicLayers.length === 0) {
    console.log("✅ No layers with gaps > 1.0mm detected!\n");
  } else {
    console.log(`⚠️  Found ${problematicLayers.length} layers with gaps > 1.0mm:\n`);
    
    for (const result of problematicLayers) {
      console.log(`Layer ${result.layerIdx} (Z=${result.z.toFixed(2)}mm):`);
      console.log(`  • Segments: ${result.segmentCount}`);
      console.log(`  • Paths: ${result.pathCount}`);
      console.log(`  • Max gap: ${result.maxGapInLayer.toFixed(4)}mm`);
      
      if (result.maxGapLocation) {
        const loc = result.maxGapLocation;
        console.log(`  • Gap location: Path ${loc.pathIdx}, segment ${loc.segmentIdx}`);
        console.log(`    From: (${loc.from.x.toFixed(2)}, ${loc.from.y.toFixed(2)})`);
        console.log(`    To:   (${loc.to.x.toFixed(2)}, ${loc.to.y.toFixed(2)})`);
      }
      
      // Path statistics
      result.pathStats.forEach((stat, idx) => {
        if (idx < 3) {  // Show first 3 paths
          const status = stat.isClosed ? "CLOSED" : `OPEN (${stat.closureGap.toFixed(4)}mm)`;
          console.log(`  • Path ${idx}: ${stat.points} points, ${status}`);
          if (stat.maxInternalGap > 1.0) {
            console.log(`    ⚠️  Max internal gap: ${stat.maxInternalGap.toFixed(4)}mm at segment ${stat.maxInternalGapIdx}`);
          }
        }
      });
      
      console.log();
    }
  }

  // Performance summary
  console.log("╔═══════════════════════════════════════════════════════════════╗");
  console.log("║                      PERFORMANCE SUMMARY                      ║");
  console.log("╚═══════════════════════════════════════════════════════════════╝\n");
  console.log(`Total time:          ${((loadTime + sliceTime + analysisTime) / 1000).toFixed(2)}s`);
  console.log(`  • Load mesh:       ${(loadTime / 1000).toFixed(2)}s`);
  console.log(`  • Slice layers:    ${(sliceTime / 1000).toFixed(2)}s (${(sliceTime / allLayers.length).toFixed(0)}ms/layer)`);
  console.log(`  • Analyze quality: ${(analysisTime / 1000).toFixed(2)}s\n`);

  // Key findings
  console.log("╔═══════════════════════════════════════════════════════════════╗");
  console.log("║                         KEY FINDINGS                          ║");
  console.log("╚═══════════════════════════════════════════════════════════════╝\n");
  
  const layersWithIssues = analysisResults.filter(r => 
    r.maxGapInLayer > 0.1 || r.branchPoints > 0 || r.isolatedSegments > 0
  );
  
  console.log(`1. Layers analyzed: ${analysisResults.length}`);
  console.log(`2. Layers with gaps > 1mm: ${problematicLayers.length}`);
  console.log(`3. Layers with any issues: ${layersWithIssues.length}`);
  
  const criticalLayers = problematicLayers.filter(r => r.maxGapInLayer > 4.0);
  if (criticalLayers.length > 0) {
    console.log(`\n⚠️  CRITICAL: ${criticalLayers.length} layers have gaps > 4mm!`);
    criticalLayers.forEach(r => {
      console.log(`   • Layer ${r.layerIdx}: ${r.maxGapInLayer.toFixed(2)}mm gap`);
    });
  }
  
  // Pattern analysis
  const firstProblemLayer = problematicLayers.length > 0 ? problematicLayers[0].layerIdx : -1;
  if (firstProblemLayer >= 0) {
    console.log(`\n4. First problematic layer: ${firstProblemLayer} (Z=${problematicLayers[0].z.toFixed(2)}mm)`);
    console.log(`5. Pattern: Issues appear starting at layer ${firstProblemLayer}`);
    
    // Check if earlier layers are clean
    const cleanLayers = analysisResults.slice(0, firstProblemLayer).filter(r => r.maxGapInLayer < 0.1);
    console.log(`6. Clean layers (0-${firstProblemLayer-1}): ${cleanLayers.length}/${firstProblemLayer}`);
  }
  
  console.log("\n╔═══════════════════════════════════════════════════════════════╗");
  console.log("║                    POLYTREE DIAGNOSTIC COMPLETE                ║");
  console.log("╚═══════════════════════════════════════════════════════════════╝\n");
}

main().catch(err => {
  console.error("❌ Error:", err);
  console.error(err.stack);
  process.exit(1);
});
