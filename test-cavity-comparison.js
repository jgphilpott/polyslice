// Analyze cavity vs solid comparison

const { Polyslice } = require('./src/index');
const THREE = require('three');
const { Polytree } = require('@jgphilpott/polytree');

async function testCavityComparison() {
  console.log('Testing cavity vs solid comparison...\n');
  
  const width = 25;
  const depth = 25;
  const thickness = 12;
  const radius = 10;
  
  const slicer = new Polyslice({
    layerHeight: 0.2,
    shellSkinThickness: 0.8, // 4 skin layers
    shellWallThickness: 0.8,
    autohome: false,
    exposureDetection: true
  });
  
  // Solid box
  const solidGeometry = new THREE.BoxGeometry(width, depth, thickness);
  const solidMesh = new THREE.Mesh(solidGeometry, new THREE.MeshBasicMaterial());
  solidMesh.position.set(0, 0, thickness / 2);
  solidMesh.updateMatrixWorld();
  
  const solidResult = slicer.slice(solidMesh);
  const solidSkinCount = (solidResult.match(/TYPE: SKIN/g) || []).length;
  
  console.log(`Solid box skin count: ${solidSkinCount}`);
  
  // Box with cavity
  const boxGeometry = new THREE.BoxGeometry(width, depth, thickness);
  const boxMesh = new THREE.Mesh(boxGeometry, new THREE.MeshBasicMaterial());
  
  const sphereGeometry = new THREE.SphereGeometry(radius, 32, 24);
  const sphereMesh = new THREE.Mesh(sphereGeometry, new THREE.MeshBasicMaterial());
  sphereMesh.position.set(0, 0, -(thickness / 2));
  sphereMesh.updateMatrixWorld();
  
  const cavityMesh = await Polytree.subtract(boxMesh, sphereMesh);
  const finalCavityMesh = new THREE.Mesh(cavityMesh.geometry, cavityMesh.material);
  finalCavityMesh.position.set(0, 0, thickness / 2);
  finalCavityMesh.updateMatrixWorld();
  
  const cavityResult = slicer.slice(finalCavityMesh);
  const cavitySkinCount = (cavityResult.match(/TYPE: SKIN/g) || []).length;
  
  console.log(`Cavity box skin count: ${cavitySkinCount}`);
  
  // Analyze cavity layers
  const lines = cavityResult.split('\n');
  const skinByLayer = {};
  let currentLayer = null;
  
  for (const line of lines) {
    if (line.includes('LAYER:')) {
      const match = line.match(/LAYER:\s*(\d+)/);
      if (match) {
        currentLayer = parseInt(match[1]);
        skinByLayer[currentLayer] = 0;
      }
    } else if (currentLayer !== null && line.includes('TYPE: SKIN')) {
      skinByLayer[currentLayer]++;
    }
  }
  
  console.log('\nCavity box skin by layer:');
  for (const [layer, count] of Object.entries(skinByLayer)) {
    const layerNum = parseInt(layer);
    const z = layerNum * 0.2;
    console.log(`  Layer ${layer.padStart(2)} (z=${z.toFixed(2)}mm): ${count} skin sections`);
  }
  
  console.log(`\nRatio: ${(cavitySkinCount / solidSkinCount).toFixed(2)}x`);
  console.log(`Test expects: solid < 15, cavity > 50, ratio > 5x`);
  console.log(`Current: solid = ${solidSkinCount}, cavity = ${cavitySkinCount}, ratio = ${(cavitySkinCount / solidSkinCount).toFixed(2)}x`);
}

testCavityComparison().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
