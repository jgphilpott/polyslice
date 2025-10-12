const Polyslice = require('../../src/index');
const THREE = require('three');

console.log('Pattern Comparison: Grid vs Gyroid');
console.log('===================================\n');

// Create a small test cube
const geometry = new THREE.BoxGeometry(10, 10, 2);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const cube = new THREE.Mesh(geometry, material);
cube.position.set(0, 0, 1);

// Test Grid Pattern
console.log('1. GRID PATTERN (traditional crosshatch):');
const gridSlicer = new Polyslice({
  nozzleDiameter: 0.4,
  layerHeight: 0.2,
  shellWallThickness: 0.8,
  shellSkinThickness: 0.4,
  infillDensity: 20,
  infillPattern: 'grid',
  verbose: false
});

const gridGcode = gridSlicer.slice(cube);
const gridExtrusions = gridGcode.match(/G1.*E[\d.]+/g) || [];
console.log(`   - Extrusion moves: ${gridExtrusions.length}`);
console.log('   - Pattern: +45° and -45° diagonal lines');
console.log('   - Same pattern on every layer\n');

// Test Gyroid Pattern
console.log('2. GYROID PATTERN (3D mathematical surface):');
const gyroidSlicer = new Polyslice({
  nozzleDiameter: 0.4,
  layerHeight: 0.2,
  shellWallThickness: 0.8,
  shellSkinThickness: 0.4,
  infillDensity: 20,
  infillPattern: 'gyroid',
  verbose: false
});

const gyroidGcode = gyroidSlicer.slice(cube);
const gyroidExtrusions = gyroidGcode.match(/G1.*E[\d.]+/g) || [];
console.log(`   - Extrusion moves: ${gyroidExtrusions.length}`);
console.log('   - Pattern: Curved contours from triply periodic surface');
console.log('   - Unique pattern on each layer\n');

console.log('Key Differences:');
console.log('- Grid: Simple, fast, predictable');
console.log('- Gyroid: Strong, isotropic, complex 3D structure');
console.log('- Gyroid provides better strength distribution');
console.log('- Gyroid natural layer bonding due to varying pattern\n');
