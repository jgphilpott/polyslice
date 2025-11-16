const THREE = require("three");
const Polytree = require("@jgphilpott/polytree");
const fs = require("fs");

async function loadSTLMesh(stlPath) {
  const { STLLoader } = await import("three/examples/jsm/loaders/STLLoader.js");
  const buffer = fs.readFileSync(stlPath);
  const loader = new STLLoader();
  const geometry = loader.parse(buffer.buffer);
  geometry.computeVertexNormals?.();
  const material = new THREE.MeshPhongMaterial({ color: 0x808080 });
  const mesh = new THREE.Mesh(geometry, material);

  // Place bottom at Z=0
  geometry.computeBoundingBox();
  const bb = geometry.boundingBox;
  const zShift = -bb.min.z;
  mesh.position.set(0, 0, zShift);
  mesh.updateMatrixWorld();
  return mesh;
}

async function main() {
  const stlPath = "../../resources/testing/benchy.test.stl";
  console.log("Loading STL:", stlPath);
  const mesh = await loadSTLMesh(stlPath);
  
  const boundingBox = new THREE.Box3().setFromObject(mesh);
  const minZ = boundingBox.min.z;
  const maxZ = boundingBox.max.z;
  const layerHeight = 0.2;
  const SLICE_EPSILON = 0.01;
  const adjustedMinZ = minZ + SLICE_EPSILON;
  
  console.log(`Bounding box: minZ=${minZ.toFixed(2)}, maxZ=${maxZ.toFixed(2)}`);
  console.log(`Slicing with layer height ${layerHeight}mm from ${adjustedMinZ.toFixed(2)} to ${maxZ.toFixed(2)}`);
  
  const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, adjustedMinZ, maxZ);
  console.log(`Total layers: ${allLayers.length}`);
  
  // Examine layers 4 and 5
  for (let layerIdx of [4, 5]) {
    const segments = allLayers[layerIdx];
    console.log(`\n=== Layer ${layerIdx}: ${segments.length} segments ===`);
    
    // Check connectivity - each segment should connect at both ends
    const connectionCounts = segments.map((seg, idx) => {
      let count = 0;
      const epsilon = 0.001;
      
      // Check start point connections
      segments.forEach((other, otherIdx) => {
        if (idx === otherIdx) return;
        const distStart1 = Math.sqrt(
          Math.pow(seg.start.x - other.start.x, 2) + Math.pow(seg.start.y - other.start.y, 2)
        );
        const distStart2 = Math.sqrt(
          Math.pow(seg.start.x - other.end.x, 2) + Math.pow(seg.start.y - other.end.y, 2)
        );
        if (distStart1 < epsilon || distStart2 < epsilon) count++;
      });
      
      // Check end point connections
      segments.forEach((other, otherIdx) => {
        if (idx === otherIdx) return;
        const distEnd1 = Math.sqrt(
          Math.pow(seg.end.x - other.start.x, 2) + Math.pow(seg.end.y - other.start.y, 2)
        );
        const distEnd2 = Math.sqrt(
          Math.pow(seg.end.x - other.end.x, 2) + Math.pow(seg.end.y - other.end.y, 2)
        );
        if (distEnd1 < epsilon || distEnd2 < epsilon) count++;
      });
      
      return count;
    });
    
    const noConnections = connectionCounts.filter(c => c === 0).length;
    const oneConnection = connectionCounts.filter(c => c === 1).length;
    const twoConnections = connectionCounts.filter(c => c === 2).length;
    const manyConnections = connectionCounts.filter(c => c > 2).length;
    
    console.log(`  Connectivity distribution:`);
    console.log(`    No connections (isolated): ${noConnections}`);
    console.log(`    One connection (dangling): ${oneConnection}`);
    console.log(`    Two connections (normal): ${twoConnections}`);
    console.log(`    >2 connections (branch): ${manyConnections}`);
  }
}

main().catch(err => {
  console.error("Error:", err);
  process.exit(1);
});
