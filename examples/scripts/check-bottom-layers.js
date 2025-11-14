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
  
  const gcode = slicer.slice(mesh);
  
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
  
  console.log('Skin counts for bottom layers 0-5:');
  for (let i = 0; i <= 5; i++) {
    console.log(`  Layer ${i}: ${skinCounts[i] || 0} skin sections`);
  }
  
  const maxLayer = Math.max(...Object.keys(skinCounts).map(Number));
  console.log(`\nSkin counts for top layers ${maxLayer-5}-${maxLayer}:`);
  for (let i = maxLayer - 5; i <= maxLayer; i++) {
    console.log(`  Layer ${i}: ${skinCounts[i] || 0} skin sections`);
  }
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
