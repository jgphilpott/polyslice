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
  const mesh = await buildSimplePyramid();
  
  const slicer = new Polyslice({
    layerHeight: 0.2,
    shellSkinThickness: 0.8,
    verbose: false,
    exposureDetection: true,
  });
  
  console.log('Slicing...');
  const gcode = slicer.slice(mesh);
  console.log('Done.');
  
  // Count skin sections
  const lines = gcode.split('\n');
  let skinCounts = {};
  let currentLayer = null;
  
  for (const line of lines) {
    if (line.includes('LAYER:')) {
      const match = line.match(/LAYER:\s*(\d+)/);
      if (match) {
        currentLayer = parseInt(match[1]);
        skinCounts[currentLayer] = 0;
      }
    } else if (currentLayer !== null && line.includes('TYPE: SKIN')) {
      skinCounts[currentLayer]++;
    }
  }
  
  console.log('\nSkin counts for layers 45-55:');
  for (let i = 45; i <= 55; i++) {
    console.log(`  Layer ${i}: ${skinCounts[i] || 0} skin sections`);
  }
}

main().catch(err => {
  console.error('Error:', err);
  console.error(err.stack);
  process.exit(1);
});
