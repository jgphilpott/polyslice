/**
 * Ultra-fast debug script: Slice ONLY FIRST 10 LAYERS with outer walls only
 * This allows rapid iteration for debugging wall path issues.
 */

const { Polyslice, Printer, Filament } = require("../../src/index");
const fs = require("fs");
const path = require("path");
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

  // Place bottom at Z=0 (build plate)
  geometry.computeBoundingBox();
  const bb = geometry.boundingBox;
  const zShift = -bb.min.z;
  mesh.position.set(0, 0, zShift);
  mesh.updateMatrixWorld();
  return mesh;
}

async function main() {
  console.log("Benchy Quick Debug - First 10 Layers, Walls Only");
  console.log("=================================================\n");

  const stlPath = path.join(__dirname, "../../resources/testing/benchy.test.stl");
  console.log("Loading STL...");

  let mesh;
  try {
    mesh = await loadSTLMesh(stlPath);
  } catch (err) {
    console.error("Failed to load STL:", err.message);
    process.exit(1);
  }

  const pos = mesh.geometry.attributes.position;
  console.log("✅ Mesh loaded");
  console.log(`- Vertices: ${pos ? pos.count.toLocaleString() : "unknown"}`);
  console.log(`- Triangles: ~${pos ? (pos.count / 3).toLocaleString() : "unknown"}\n`);

  // Slice only first 10 layers directly using Polytree
  const boundingBox = new THREE.Box3().setFromObject(mesh);
  const minZ = boundingBox.min.z;
  const layerHeight = 0.2;
  const numLayers = 10;
  const maxZ = minZ + (numLayers * layerHeight);
  const SLICE_EPSILON = 0.01;

  console.log("Slicing first 10 layers only...");
  console.log(`- Layer height: ${layerHeight}mm`);
  console.log(`- Z range: ${minZ.toFixed(2)} to ${maxZ.toFixed(2)}mm`);
  console.log(`- Layers: ${numLayers}\n`);

  const t0 = Date.now();
  const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ + SLICE_EPSILON, maxZ);
  const dt = Date.now() - t0;
  
  console.log(`✅ Sliced in ${(dt / 1000).toFixed(1)}s`);
  console.log(`- Layers generated: ${allLayers.length}\n`);

  // Analyze segments per layer
  console.log("Layer analysis:");
  for (let i = 0; i < Math.min(allLayers.length, 10); i++) {
    const segments = allLayers[i];
    const z = (minZ + SLICE_EPSILON + i * layerHeight).toFixed(2);
    console.log(`  Layer ${i} (Z=${z}mm): ${segments.length} segments`);
  }

  // Now use the helpers to connect segments to paths for layer 5
  console.log("\n=== Detailed Analysis: Layer 5 ===");
  if (allLayers.length > 5) {
    const helpers = require("../../src/slicer/geometry/helpers");
    const layer5Segments = allLayers[5];
    
    console.log(`Raw segments from Polytree: ${layer5Segments.length}`);
    
    // Convert to simple format
    const edges = layer5Segments.map(seg => ({
      start: { x: seg.start.x, y: seg.start.y },
      end: { x: seg.end.x, y: seg.end.y }
    }));
    
    const paths = helpers.connectSegmentsToPaths(layer5Segments);
    console.log(`Paths after connection: ${paths.length}`);
    
    paths.forEach((path, idx) => {
      if (idx < 5) {
        const firstPt = path[0];
        const lastPt = path[path.length - 1];
        const dist = Math.sqrt(
          Math.pow(lastPt.x - firstPt.x, 2) + 
          Math.pow(lastPt.y - firstPt.y, 2)
        );
        const isClosed = dist < 0.01;
        console.log(`  Path ${idx}: ${path.length} points, ${isClosed ? "CLOSED" : "OPEN (" + dist.toFixed(2) + "mm gap)"}`);
        console.log(`    First: (${firstPt.x.toFixed(2)}, ${firstPt.y.toFixed(2)})`);
        console.log(`    Last:  (${lastPt.x.toFixed(2)}, ${lastPt.y.toFixed(2)})`);
      }
    });

    // Check for large gaps in layer 5
    console.log("\nChecking for large gaps in layer 5 paths:");
    paths.forEach((path, pathIdx) => {
      for (let i = 0; i < path.length - 1; i++) {
        const p1 = path[i];
        const p2 = path[i + 1];
        const dist = Math.sqrt(
          Math.pow(p2.x - p1.x, 2) + 
          Math.pow(p2.y - p1.y, 2)
        );
        if (dist > 5) {  // Gap larger than 5mm
          console.log(`  ⚠️  Path ${pathIdx}, segment ${i}-${i+1}: ${dist.toFixed(2)}mm gap`);
          console.log(`      From (${p1.x.toFixed(2)}, ${p1.y.toFixed(2)}) to (${p2.x.toFixed(2)}, ${p2.y.toFixed(2)})`);
        }
      }
    });
  }

  console.log("\n✅ Quick analysis complete!");
  console.log("This script analyzes segment connectivity without full G-code generation.");
}

main().catch(err => {
  console.error("Error:", err);
  process.exit(1);
});
