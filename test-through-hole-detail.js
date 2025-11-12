// Detailed analysis of through-hole test

const { Polyslice } = require('./src/index');
const THREE = require('three');
const { Polytree } = require('@jgphilpott/polytree');

async function testThroughHoleDetail() {
  console.log('Analyzing through-hole test in detail...\n');
  
  // Create geometry exactly as in the test
  const sheetGeometry = new THREE.BoxGeometry(50, 50, 5);
  const sheetMesh = new THREE.Mesh(sheetGeometry, new THREE.MeshBasicMaterial());
  
  const holeRadius = 5;
  const holeGeometry = new THREE.CylinderGeometry(holeRadius, holeRadius, 10, 32);
  const holeMesh = new THREE.Mesh(holeGeometry, new THREE.MeshBasicMaterial());
  
  holeMesh.rotation.x = Math.PI / 2;
  holeMesh.position.set(0, 0, 0);
  holeMesh.updateMatrixWorld();
  
  const resultMesh = await Polytree.subtract(sheetMesh, holeMesh);
  const finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material);
  finalMesh.position.set(0, 0, 2.5);
  finalMesh.updateMatrixWorld();
  
  const slicer = new Polyslice({
    layerHeight: 0.2,
    shellSkinThickness: 0.8, // 4 skin layers
    shellWallThickness: 0.8,
    verbose: true,
    autohome: false,
    exposureDetection: true,
    exposureDetectionResolution: 900
  });
  
  const gcode = slicer.slice(finalMesh);
  
  // Analyze each layer
  const lines = gcode.split('\n');
  const layerData = {};
  let currentLayer = null;
  let inWallSection = false;
  let inSkinSection = false;
  
  for (const line of lines) {
    if (line.includes('LAYER:')) {
      const layerMatch = line.match(/LAYER:\s*(\d+)/);
      if (layerMatch) {
        currentLayer = parseInt(layerMatch[1]);
        layerData[currentLayer] = {
          wallCount: 0,
          skinCount: 0,
          wallLines: [],
          skinLines: []
        };
        inWallSection = false;
        inSkinSection = false;
      }
    } else if (currentLayer !== null) {
      if (line.includes('TYPE: WALL')) {
        inWallSection = true;
        inSkinSection = false;
        layerData[currentLayer].wallCount++;
      } else if (line.includes('TYPE: SKIN')) {
        inSkinSection = true;
        inWallSection = false;
        layerData[currentLayer].skinCount++;
      } else if (line.includes('TYPE:')) {
        inWallSection = false;
        inSkinSection = false;
      }
      
      // Track actual movement lines
      if (inWallSection && line.match(/^G[01]\s+.*X.*Y/)) {
        layerData[currentLayer].wallLines.push(line);
      } else if (inSkinSection && line.match(/^G[01]\s+.*X.*Y/)) {
        layerData[currentLayer].skinLines.push(line);
      }
    }
  }
  
  console.log('Layer Analysis:');
  console.log('Layer | Walls | Skin Sections | Wall Moves | Skin Moves');
  console.log('------|-------|---------------|------------|------------');
  
  const skinLayers = [];
  for (const [layer, data] of Object.entries(layerData)) {
    const layerNum = parseInt(layer);
    const z = layerNum * 0.2;
    const isTopOrBottom = layerNum < 4 || layerNum >= 21;
    
    console.log(
      `${layer.padStart(5)} | ${data.wallCount.toString().padStart(5)} | ` +
      `${data.skinCount.toString().padStart(13)} | ` +
      `${data.wallLines.length.toString().padStart(10)} | ` +
      `${data.skinLines.length.toString().padStart(10)} ${isTopOrBottom ? '(top/bot)' : ''}`
    );
    
    if (data.skinCount > 0) {
      skinLayers.push(layerNum);
    }
  }
  
  console.log(`\nTotal layers with skin: ${skinLayers.length}`);
  console.log(`Skin layers: ${skinLayers.join(', ')}`);
  
  // Expected: 8 layers (4 bottom + 4 top)
  // Test expects: > 15 layers
  console.log(`\nTest expects > 15 skin layers, we have ${skinLayers.length}`);
}

testThroughHoleDetail().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
