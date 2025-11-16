/**
 * Deep dive analysis: Examine specific gap locations to understand
 * why Polytree is not generating connecting segments
 */

const path = require("path");
const fs = require("fs");
const THREE = require("three");
const Polytree = require("@jgphilpott/polytree");

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

function findTrianglesNearGap(mesh, z, gapStart, gapEnd, searchRadius = 6.0) {
  const geometry = mesh.geometry;
  const positionAttribute = geometry.attributes.position;
  const worldMatrix = mesh.matrixWorld;
  
  const trianglesNearGap = [];
  
  // Mid point of gap
  const gapMidX = (gapStart.x + gapEnd.x) / 2;
  const gapMidY = (gapStart.y + gapEnd.y) / 2;
  
  for (let i = 0; i < positionAttribute.count; i += 3) {
    const v1 = new THREE.Vector3().fromBufferAttribute(positionAttribute, i).applyMatrix4(worldMatrix);
    const v2 = new THREE.Vector3().fromBufferAttribute(positionAttribute, i + 1).applyMatrix4(worldMatrix);
    const v3 = new THREE.Vector3().fromBufferAttribute(positionAttribute, i + 2).applyMatrix4(worldMatrix);
    
    // Check if triangle intersects the slice plane
    const minZ = Math.min(v1.z, v2.z, v3.z);
    const maxZ = Math.max(v1.z, v2.z, v3.z);
    
    if (minZ <= z && maxZ >= z) {
      // Triangle crosses the plane, check if it's near the gap
      const avgX = (v1.x + v2.x + v3.x) / 3;
      const avgY = (v1.y + v2.y + v3.y) / 3;
      
      const distToGap = Math.sqrt(
        Math.pow(avgX - gapMidX, 2) + 
        Math.pow(avgY - gapMidY, 2)
      );
      
      if (distToGap <= searchRadius) {
        trianglesNearGap.push({
          index: Math.floor(i / 3),
          v1: { x: v1.x, y: v1.y, z: v1.z },
          v2: { x: v2.x, y: v2.y, z: v2.z },
          v3: { x: v3.x, y: v3.y, z: v3.z },
          distToGap,
          centroid: { x: avgX, y: avgY, z: (v1.z + v2.z + v3.z) / 3 }
        });
      }
    }
  }
  
  return trianglesNearGap.sort((a, b) => a.distToGap - b.distToGap);
}

function classifyTriangleIntersection(v1, v2, v3, z, epsilon = 1e-6) {
  const d1 = v1.z - z;
  const d2 = v2.z - z;
  const d3 = v3.z - z;
  
  const above1 = d1 > epsilon;
  const below1 = d1 < -epsilon;
  const on1 = Math.abs(d1) <= epsilon;
  
  const above2 = d2 > epsilon;
  const below2 = d2 < -epsilon;
  const on2 = Math.abs(d2) <= epsilon;
  
  const above3 = d3 > epsilon;
  const below3 = d3 < -epsilon;
  const on3 = Math.abs(d3) <= epsilon;
  
  const numOn = (on1 ? 1 : 0) + (on2 ? 1 : 0) + (on3 ? 1 : 0);
  const numAbove = (above1 ? 1 : 0) + (above2 ? 1 : 0) + (above3 ? 1 : 0);
  const numBelow = (below1 ? 1 : 0) + (below2 ? 1 : 0) + (below3 ? 1 : 0);
  
  if (numOn === 3) return "COPLANAR";
  if (numOn === 2) return "EDGE_ON_PLANE";
  if (numOn === 1) return "VERTEX_ON_PLANE";
  if (numAbove > 0 && numBelow > 0) return "CROSSES_PLANE";
  if (numAbove === 3 || numBelow === 3) return "NO_INTERSECTION";
  
  return "UNKNOWN";
}

async function main() {
  console.log("╔═══════════════════════════════════════════════════════════════╗");
  console.log("║     POLYTREE GAP ANALYSIS - Triangle Intersection Study      ║");
  console.log("╚═══════════════════════════════════════════════════════════════╝\n");

  const stlPath = path.join(__dirname, "resources/testing/benchy.test.stl");
  const mesh = await loadSTLMesh(stlPath);
  
  const boundingBox = new THREE.Box3().setFromObject(mesh);
  const minZ = boundingBox.min.z;
  const layerHeight = 0.2;
  const SLICE_EPSILON = 0.01;

  // Focus on Layer 5 - the reported problematic layer
  const layer5Z = minZ + SLICE_EPSILON + 5 * layerHeight;
  
  console.log("Analyzing Layer 5 Gap");
  console.log("─────────────────────────────────────────────────────────────────");
  console.log(`Z height: ${layer5Z.toFixed(4)}mm\n`);

  // Known gap location from previous analysis
  const gapStart = { x: -20.00, y: -0.81 };
  const gapEnd = { x: -24.88, y: -0.81 };
  
  console.log("Gap location:");
  console.log(`  From: (${gapStart.x.toFixed(2)}, ${gapStart.y.toFixed(2)})`);
  console.log(`  To:   (${gapEnd.x.toFixed(2)}, ${gapEnd.y.toFixed(2)})`);
  console.log(`  Distance: 4.88mm\n`);

  console.log("Searching for triangles near gap (within 6mm radius)...\n");
  
  const nearbyTriangles = findTrianglesNearGap(mesh, layer5Z, gapStart, gapEnd, 6.0);
  
  console.log(`Found ${nearbyTriangles.length} triangles near gap\n`);
  
  if (nearbyTriangles.length > 0) {
    console.log("Top 10 closest triangles to gap:\n");
    
    for (let i = 0; i < Math.min(10, nearbyTriangles.length); i++) {
      const tri = nearbyTriangles[i];
      const classification = classifyTriangleIntersection(
        tri.v1, tri.v2, tri.v3, layer5Z
      );
      
      console.log(`Triangle ${tri.index} (${i + 1}/${nearbyTriangles.length}):`);
      console.log(`  Distance to gap: ${tri.distToGap.toFixed(4)}mm`);
      console.log(`  Classification: ${classification}`);
      console.log(`  Centroid: (${tri.centroid.x.toFixed(2)}, ${tri.centroid.y.toFixed(2)}, ${tri.centroid.z.toFixed(4)})`);
      console.log(`  Vertices:`);
      console.log(`    V1: (${tri.v1.x.toFixed(2)}, ${tri.v1.y.toFixed(2)}, ${tri.v1.z.toFixed(4)})`);
      console.log(`    V2: (${tri.v2.x.toFixed(2)}, ${tri.v2.y.toFixed(2)}, ${tri.v2.z.toFixed(4)})`);
      console.log(`    V3: (${tri.v3.x.toFixed(2)}, ${tri.v3.y.toFixed(2)}, ${tri.v3.z.toFixed(4)})`);
      
      // Calculate expected intersection segment if it crosses
      if (classification === "CROSSES_PLANE") {
        const intersections = [];
        
        // Check each edge
        const edges = [
          { v1: tri.v1, v2: tri.v2, name: "V1-V2" },
          { v1: tri.v2, v2: tri.v3, name: "V2-V3" },
          { v1: tri.v3, v2: tri.v1, name: "V3-V1" }
        ];
        
        for (const edge of edges) {
          const d1 = edge.v1.z - layer5Z;
          const d2 = edge.v2.z - layer5Z;
          
          if ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) {
            const t = d1 / (d1 - d2);
            const ix = edge.v1.x + t * (edge.v2.x - edge.v1.x);
            const iy = edge.v1.y + t * (edge.v2.y - edge.v1.y);
            intersections.push({ x: ix, y: iy, edge: edge.name });
          }
        }
        
        if (intersections.length === 2) {
          console.log(`  Expected segment:`);
          console.log(`    From: (${intersections[0].x.toFixed(2)}, ${intersections[0].y.toFixed(2)}) [${intersections[0].edge}]`);
          console.log(`    To:   (${intersections[1].x.toFixed(2)}, ${intersections[1].y.toFixed(2)}) [${intersections[1].edge}]`);
          
          // Check if this segment would fill the gap
          const dist1 = Math.sqrt(
            Math.pow(intersections[0].x - gapStart.x, 2) + 
            Math.pow(intersections[0].y - gapStart.y, 2)
          );
          const dist2 = Math.sqrt(
            Math.pow(intersections[1].x - gapEnd.x, 2) + 
            Math.pow(intersections[1].y - gapEnd.y, 2)
          );
          
          if (dist1 < 0.5 || dist2 < 0.5) {
            console.log(`  ⚠️  THIS SEGMENT COULD FILL THE GAP!`);
          }
        }
      }
      
      console.log();
    }
    
    // Classify all triangles
    const classifications = {};
    nearbyTriangles.forEach(tri => {
      const c = classifyTriangleIntersection(tri.v1, tri.v2, tri.v3, layer5Z);
      classifications[c] = (classifications[c] || 0) + 1;
    });
    
    console.log("\nTriangle intersection classification summary:");
    for (const [type, count] of Object.entries(classifications)) {
      console.log(`  ${type}: ${count} triangles`);
    }
  }
  
  // Check multiple layers
  console.log("\n\n╔═══════════════════════════════════════════════════════════════╗");
  console.log("║              MULTI-LAYER GAP PATTERN ANALYSIS                 ║");
  console.log("╚═══════════════════════════════════════════════════════════════╝\n");
  
  const layersToCheck = [
    { idx: 3, gap: { x1: -20.00, y1: -0.14, x2: -24.94, y2: -0.14 } },
    { idx: 4, gap: { x1: -20.54, y1: 0.61, x2: -25.39, y2: 0.61 } },
    { idx: 5, gap: { x1: -20.00, y1: -0.81, x2: -24.88, y2: -0.81 } },
    { idx: 7, gap: { x1: -25.27, y1: 0.98, x2: -20.00, y2: 0.98 } }
  ];
  
  for (const layer of layersToCheck) {
    const z = minZ + SLICE_EPSILON + layer.idx * layerHeight;
    const gapDist = Math.sqrt(
      Math.pow(layer.gap.x2 - layer.gap.x1, 2) + 
      Math.pow(layer.gap.y2 - layer.gap.y1, 2)
    );
    
    console.log(`Layer ${layer.idx} (Z=${z.toFixed(2)}mm):`);
    console.log(`  Gap: (${layer.gap.x1.toFixed(2)}, ${layer.gap.y1.toFixed(2)}) → (${layer.gap.x2.toFixed(2)}, ${layer.gap.y2.toFixed(2)})`);
    console.log(`  Gap distance: ${gapDist.toFixed(2)}mm`);
    
    // Check if gap is horizontal (Y values similar)
    const isHorizontal = Math.abs(layer.gap.y2 - layer.gap.y1) < 0.1;
    console.log(`  Orientation: ${isHorizontal ? "HORIZONTAL" : "ANGLED"}`);
    
    const nearTriangles = findTrianglesNearGap(
      mesh, z,
      { x: layer.gap.x1, y: layer.gap.y1 },
      { x: layer.gap.x2, y: layer.gap.y2 },
      6.0
    );
    
    const crossingTriangles = nearTriangles.filter(tri => 
      classifyTriangleIntersection(tri.v1, tri.v2, tri.v3, z) === "CROSSES_PLANE"
    );
    
    console.log(`  Nearby triangles: ${nearTriangles.length}`);
    console.log(`  Crossing plane: ${crossingTriangles.length}`);
    console.log();
  }
  
  console.log("\n╔═══════════════════════════════════════════════════════════════╗");
  console.log("║                      DIAGNOSTIC SUMMARY                       ║");
  console.log("╚═══════════════════════════════════════════════════════════════╝\n");
  
  console.log("KEY OBSERVATIONS:");
  console.log("1. All major gaps occur in similar X-coordinate ranges (-20 to -25mm)");
  console.log("2. Most gaps are HORIZONTAL (same Y coordinate at both ends)");
  console.log("3. Gap magnitudes range from 4.3mm to 5.8mm");
  console.log("4. This suggests a specific geometric feature in this region");
  console.log("\nPOSSIBLE ROOT CAUSES:");
  console.log("• Triangles with edges nearly parallel to slice plane");
  console.log("• Floating-point precision issues in edge-plane intersection");
  console.log("• Missing or degenerate triangles in the mesh");
  console.log("• Polytree's epsilon threshold incorrectly filtering valid segments");
  console.log("\nRECOMMENDED FIXES FOR POLYTREE:");
  console.log("1. Review edge-plane intersection epsilon tolerance");
  console.log("2. Handle near-parallel edges with adaptive precision");
  console.log("3. Add validation for segment connectivity before returning");
  console.log("4. Implement segment gap-filling for small discontinuities (<= 0.1mm)");
  
  console.log("\n");
}

main().catch(err => {
  console.error("❌ Error:", err);
  console.error(err.stack);
  process.exit(1);
});
