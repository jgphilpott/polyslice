const fs = require('fs');
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
    shellWallThickness: 0.8,
    verbose: true,
    exposureDetection: true,
    exposureDetectionResolution: 961,
    infillDensity: 0,
    testStrip: false,
    autohome: false
  });
  
  const gcode = slicer.slice(mesh);
  fs.writeFileSync('/tmp/test-pyramid.gcode', gcode);
  console.log('Saved to /tmp/test-pyramid.gcode');
  
  // Check for DEBUG lines
  const debugLines = gcode.split('\n').filter(l => l.includes('DEBUG'));
  console.log(`\nFound ${debugLines.length} DEBUG lines:`);
  debugLines.slice(0, 10).forEach(l => console.log(l));
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
