// Test to understand the cavity test geometry

const { Polyslice } = require('./src/index');
const THREE = require('three');
const { Polytree } = require('@jgphilpott/polytree');

async function testCavityGeometry() {
  console.log('Testing cavity test geometry...\n');
  
  // Create geometry exactly as in the test
  const sheetGeometry = new THREE.BoxGeometry(50, 50, 5);
  const sheetMesh = new THREE.Mesh(sheetGeometry, new THREE.MeshBasicMaterial());
  
  const holeRadius = 3;
  const holeGeometry = new THREE.CylinderGeometry(holeRadius, holeRadius, 10, 32);
  const holeMesh = new THREE.Mesh(holeGeometry, new THREE.MeshBasicMaterial());
  holeMesh.rotation.x = Math.PI / 2;
  holeMesh.position.set(0, 0, 0);
  holeMesh.updateMatrixWorld();
  
  const resultMesh = await Polytree.subtract(sheetMesh, holeMesh);
  const finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material);
  finalMesh.position.set(0, 0, 2.5); // Position on build plate
  finalMesh.updateMatrixWorld();
  
  // Get bounding box
  const bbox = new THREE.Box3().setFromObject(finalMesh);
  console.log('Bounding box:');
  console.log(`  Min: (${bbox.min.x.toFixed(2)}, ${bbox.min.y.toFixed(2)}, ${bbox.min.z.toFixed(2)})`);
  console.log(`  Max: (${bbox.max.x.toFixed(2)}, ${bbox.max.y.toFixed(2)}, ${bbox.max.z.toFixed(2)})`);
  console.log(`  Height: ${(bbox.max.z - bbox.min.z).toFixed(2)}mm`);
  
  // Slice it
  const slicer = new Polyslice({
    shellSkinThickness: 0.8, // 4 skin layers
    shellWallThickness: 0.8,
    layerHeight: 0.2,
    verbose: true,
    autohome: false,
    exposureDetection: true
  });
  
  const gcode = slicer.slice(finalMesh);
  
  // Count skin and wall occurrences per layer
  const lines = gcode.split('\n');
  const layerStats = {};
  let currentLayer = null;
  
  for (const line of lines) {
    if (line.includes('LAYER:')) {
      const layerMatch = line.match(/LAYER:\s*(\d+)/);
      if (layerMatch) {
        currentLayer = parseInt(layerMatch[1]);
        layerStats[currentLayer] = { skin: 0, wall: 0 };
      }
    } else if (currentLayer !== null) {
      if (line.includes('TYPE: SKIN')) {
        layerStats[currentLayer].skin++;
      }
      if (line.includes('TYPE: WALL')) {
        layerStats[currentLayer].wall++;
      }
    }
  }
  
  console.log('\nLayer statistics:');
  for (const [layer, stats] of Object.entries(layerStats)) {
    const layerNum = parseInt(layer);
    const z = layerNum * 0.2;
    const isTopOrBottom = layerNum < 4 || layerNum >= Object.keys(layerStats).length - 4;
    console.log(`  Layer ${layer.padStart(2)} (z=${z.toFixed(2)}mm): ${stats.skin} skin, ${stats.wall} wall ${isTopOrBottom ? '(top/bottom)' : ''}`);
  }
  
  // Check layer 10 specifically
  console.log('\nLayer 10 stats:');
  if (layerStats[10]) {
    console.log(`  Skin sections: ${layerStats[10].skin}`);
    console.log(`  Wall sections: ${layerStats[10].wall}`);
  }
}

testCavityGeometry().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
