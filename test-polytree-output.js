const THREE = require('three');
const Polytree = require('@jgphilpott/polytree');

const geometry = new THREE.SphereGeometry(50, 128, 128);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const mesh = new THREE.Mesh(geometry, material);

// Update matrices
mesh.updateMatrixWorld();

// Get bounding box
const bbox = new THREE.Box3().setFromObject(mesh);
console.log('Bounding box:', {
  min: bbox.min,
  max: bbox.max,
  size: bbox.max.z - bbox.min.z
});

const layerHeight = 0.2;
const minZ = bbox.min.z + 0.001;
const maxZ = bbox.max.z;

console.log(`Slicing from Z=${minZ} to Z=${maxZ} with layer height ${layerHeight}`);

const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ, maxZ);

console.log(`Total layers: ${allLayers.length}`);

// Check first few layers
for (let i = 0; i < Math.min(5, allLayers.length); i++) {
  const segments = allLayers[i];
  console.log(`Layer ${i}: ${segments ? segments.length : 0} segments`);
}

// Check a middle layer
if (allLayers.length > 10) {
  const midIdx = Math.floor(allLayers.length / 2);
  const segments = allLayers[midIdx];
  console.log(`Layer ${midIdx} (middle): ${segments ? segments.length : 0} segments`);
}

// Check last few layers
for (let i = Math.max(0, allLayers.length - 3); i < allLayers.length; i++) {
  const segments = allLayers[i];
  console.log(`Layer ${i}: ${segments ? segments.length : 0} segments`);
}
