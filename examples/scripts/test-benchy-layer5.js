const THREE = require("three");
const Polytree = require("@jgphilpott/polytree");
const fs = require("fs");
const helpers = require("../../src/slicer/geometry/helpers");

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

async function main() {
  const stlPath = "./resources/testing/benchy.test.stl";
  const mesh = await loadSTLMesh(stlPath);
  
  const boundingBox = new THREE.Box3().setFromObject(mesh);
  const minZ = boundingBox.min.z;
  const maxZ = boundingBox.max.z;
  const layerHeight = 0.2;
  const SLICE_EPSILON = 0.01;
  const adjustedMinZ = minZ + SLICE_EPSILON;
  
  const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, adjustedMinZ, maxZ);
  
  // Check layers 4 and 5
  for (let layerIdx of [4, 5]) {
    const segments = allLayers[layerIdx];
    console.log(`\n=== Layer ${layerIdx} (Z=${(adjustedMinZ + layerIdx * layerHeight).toFixed(2)}) ===`);
    console.log(`Raw segments from Polytree: ${segments.length}`);
    
    const paths = helpers.connectSegmentsToPaths(segments);
    console.log(`Paths created: ${paths.length}`);
    
    paths.forEach((path, idx) => {
      console.log(`  Path ${idx}: ${path.length} points`);
      if (path.length > 0) {
        console.log(`    First: (${path[0].x.toFixed(2)}, ${path[0].y.toFixed(2)})`);
        console.log(`    Last: (${path[path.length-1].x.toFixed(2)}, ${path[path.length-1].y.toFixed(2)})`);
      }
    });
  }
}

main().catch(err => {
  console.error("Error:", err);
  process.exit(1);
});
