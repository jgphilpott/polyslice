const { Polyslice } = require('./src/index');
const THREE = require('three');
const { Polytree } = require('@jgphilpott/polytree');

async function main() {
  // Create base mesh (5mm tall box).
  const baseMat = new THREE.MeshStandardMaterial({ color: 0x888888 });
  const baseGeo = new THREE.BoxGeometry(10, 10, 5);
  const baseMesh = new THREE.Mesh(baseGeo, baseMat);
  baseMesh.position.set(0, 0, 2.5);
  baseMesh.updateMatrixWorld();
  
  // Create hole (2mm diameter, vertical through the base).
  const holeGeo = new THREE.CylinderGeometry(1, 1, 5, 16);
  const holeMesh = new THREE.Mesh(holeGeo, baseMat);
  holeMesh.position.set(0, 0, 2.5);
  holeMesh.updateMatrixWorld();
  
  // Subtract hole from base.
  const resultMesh = await Polytree.subtract(baseMesh, holeMesh);
  const finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material);
  finalMesh.position.set(0, 0, 2.5);
  finalMesh.updateMatrixWorld();
  
  const slicer = new Polyslice({
    layerHeight: 0.2,
    shellSkinThickness: 0.8,
    shellWallThickness: 0.8,
    verbose: false,
    autohome: false,
    exposureDetection: true,
    exposureDetectionResolution: 900
  });
  
  const gcode = slicer.slice(finalMesh);
  
  // Count skin layers.
  const lines = gcode.split('\n');
  const skinLayers = new Set();
  let currentLayer = null;
  
  for (const line of lines) {
    if (line.includes('LAYER:')) {
      const match = line.match(/LAYER:\s*(\d+)/);
      if (match) currentLayer = parseInt(match[1]);
    } else if (currentLayer !== null && line.includes('TYPE: SKIN')) {
      skinLayers.add(currentLayer);
    }
  }
  
  console.log('Through-hole test:');
  console.log(`Layers with skin: ${Array.from(skinLayers).sort((a,b) => a-b).join(', ')}`);
  console.log(`Total: ${skinLayers.size}`);
  console.log('\nExpected: Layers 0-3 (bottom) and 21-24 (top), total 8');
  console.log(skinLayers.size === 8 ? '✅ PASS' : '❌ FAIL');
}

main().catch(console.error);
