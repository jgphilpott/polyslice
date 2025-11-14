const { Polyslice } = require('/home/runner/work/polyslice/polyslice/src/index');
const THREE = require('three');
const { Polytree } = require('@jgphilpott/polytree');

async function buildSimplePyramid() {
  const mat = new THREE.MeshStandardMaterial({ color: 0x888888 });
  
  const baseSlab = new THREE.BoxGeometry(50, 50, 10);
  const baseSlabMesh = new THREE.Mesh(baseSlab, mat);
  baseSlabMesh.position.set(0, 0, 0);
  baseSlabMesh.updateMatrixWorld();
  
  const topSlab = new THREE.BoxGeometry(30, 30, 10);
  const topSlabMesh = new THREE.Mesh(topSlab, mat);
  topSlabMesh.position.set(0, 0, 10);
  topSlabMesh.updateMatrixWorld();
  
  const pyramidMesh = await Polytree.unite(baseSlabMesh, topSlabMesh);
  const finalMesh = new THREE.Mesh(pyramidMesh.geometry, mat);
  finalMesh.position.set(0, 0, 0);
  finalMesh.updateMatrixWorld();
  
  return finalMesh;
}

async function main() {
  console.log('Debug Pyramid Exposure Detection');
  console.log('==================================\n');
  
  const mesh = await buildSimplePyramid();
  
  const slicer = new Polyslice({
    layerHeight: 0.2,
    shellSkinThickness: 0.8,
    shellWallThickness: 0.8,
    verbose: false, // Disable verbose to reduce output
    exposureDetection: true,
    exposureDetectionResolution: 961,
    infillDensity: 0,
    testStrip: false,
    autohome: false
  });
  
  console.log('Slicing...');
  const gcode = slicer.slice(mesh);
  console.log('Done.\n');
  
  // The issue is that coveringRegions are collected but may not be properly formatted
  // or passed to the skin generation. Let me check the actual G-code.
  
  const lines = gcode.split('\n');
  let inLayer49 = false;
  let skinLineCount = 0;
  
  for (const line of lines) {
    if (line.includes('LAYER: 49')) {
      inLayer49 = true;
    } else if (line.includes('LAYER: 50')) {
      break;
    } else if (inLayer49 && line.match(/G1.*E/)) { // G1 with extrusion
      skinLineCount++;
    }
  }
  
  console.log(`Layer 49 has ${skinLineCount} extrusion moves`);
  console.log('\nThe covering regions should be excluding the center 30x30 area.');
  console.log('If the fix is working, we should see skin ONLY in the ring area.');
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
