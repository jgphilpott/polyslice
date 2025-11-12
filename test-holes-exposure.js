// Test to verify exposure detection for cylindrical holes

const { Polyslice } = require('./src/index');
const THREE = require('three');
const { Polytree } = require('@jgphilpott/polytree');

async function testHoleExposure() {
  console.log('Testing hole exposure detection...\n');
  
  // Create a simple sheet with one hole
  const sheetGeometry = new THREE.BoxGeometry(20, 20, 2);
  const sheetMesh = new THREE.Mesh(sheetGeometry, new THREE.MeshBasicMaterial());
  
  // Create a cylindrical hole
  const holeGeometry = new THREE.CylinderGeometry(2, 2, 4, 32);
  const holeMesh = new THREE.Mesh(holeGeometry, new THREE.MeshBasicMaterial());
  holeMesh.rotation.x = Math.PI / 2;
  holeMesh.position.set(0, 0, 0);
  holeMesh.updateMatrixWorld();
  
  // Subtract hole from sheet
  const resultMesh = await Polytree.subtract(sheetMesh, holeMesh);
  const finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material);
  finalMesh.position.set(0, 0, 1); // Position on build plate
  finalMesh.updateMatrixWorld();
  
  // Slice with exposure detection enabled
  const slicer = new Polyslice({
    layerHeight: 0.2,
    shellSkinThickness: 0.4, // 2 layers
    shellWallThickness: 0.4,
    verbose: true,
    exposureDetection: true
  });
  
  const gcode = slicer.slice(finalMesh);
  
  // Count skin occurrences per layer
  const lines = gcode.split('\n');
  const skinCountByLayer = {};
  let currentLayer = null;
  
  for (const line of lines) {
    if (line.includes('LAYER:')) {
      const layerMatch = line.match(/LAYER:\s*(\d+)/);
      if (layerMatch) {
        currentLayer = parseInt(layerMatch[1]);
        skinCountByLayer[currentLayer] = 0;
      }
    } else if (currentLayer !== null && line.includes('TYPE: SKIN')) {
      skinCountByLayer[currentLayer]++;
    }
  }
  
  console.log('Skin occurrences by layer:');
  for (const [layer, count] of Object.entries(skinCountByLayer)) {
    console.log(`  Layer ${layer}: ${count} skin sections`);
  }
  
  // With a 2mm thick sheet and 0.2mm layer height, we have 10 layers
  // Only layers 0, 1 (bottom) and 8, 9 (top) should have skin
  // Middle layers (2-7) should NOT have skin for vertical holes
  const middleLayers = Object.keys(skinCountByLayer).filter(l => parseInt(l) >= 2 && parseInt(l) <= 7);
  const hasSkinInMiddle = middleLayers.some(l => skinCountByLayer[l] > 0);
  
  console.log(`\nMiddle layers (2-7) have skin: ${hasSkinInMiddle ? 'YES (BUG!)' : 'NO (correct)'}`);
  
  return hasSkinInMiddle;
}

testHoleExposure().then(hasBug => {
  if (hasBug) {
    console.log('\n❌ BUG CONFIRMED: Middle layers incorrectly have skin generation for vertical holes');
    process.exit(1);
  } else {
    console.log('\n✅ PASS: No skin in middle layers (expected behavior)');
    process.exit(0);
  }
}).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
