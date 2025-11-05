// Example demonstrating the exposure detection feature
// This script compares slicing with and without exposure detection enabled

const Polyslice = require('../../src/index');
const THREE = require('three');

// Create a tall cylinder (10mm diameter, 10mm height)
const geometry = new THREE.CylinderGeometry(5, 5, 10, 32);
const material = new THREE.MeshBasicMaterial();
const mesh = new THREE.Mesh(geometry, material);

// Position cylinder so bottom is at Z=0
mesh.position.set(0, 0, 5);
mesh.updateMatrixWorld();

console.log('\n=== Exposure Detection Comparison ===\n');

// Test 1: Exposure detection DISABLED (default)
console.log('1. Slicing with exposure detection DISABLED (default)...');
const slicerDisabled = new Polyslice({
    layerHeight: 0.2,
    shellSkinThickness: 0.8,  // 4 layers
    nozzleTemperature: 200,
    bedTemperature: 60,
    verbose: true,
    exposureDetection: false  // Explicitly disabled
});

const gcodeDisabled = slicerDisabled.slice(mesh);
const skinCountDisabled = (gcodeDisabled.match(/TYPE: SKIN/g) || []).length;
const infillCountDisabled = (gcodeDisabled.match(/TYPE: INFILL/g) || []).length;
const totalLinesDisabled = gcodeDisabled.split('\n').length;

console.log(`   - Total G-code lines: ${totalLinesDisabled}`);
console.log(`   - Skin operations: ${skinCountDisabled}`);
console.log(`   - Infill operations: ${infillCountDisabled}`);
console.log('   - Strategy: Skin only on top 4 and bottom 4 layers\n');

// Test 2: Exposure detection ENABLED
console.log('2. Slicing with exposure detection ENABLED...');
const slicerEnabled = new Polyslice({
    layerHeight: 0.2,
    shellSkinThickness: 0.8,  // 4 layers
    nozzleTemperature: 200,
    bedTemperature: 60,
    verbose: true,
    exposureDetection: true  // Enabled
});

const gcodeEnabled = slicerEnabled.slice(mesh);
const skinCountEnabled = (gcodeEnabled.match(/TYPE: SKIN/g) || []).length;
const infillCountEnabled = (gcodeEnabled.match(/TYPE: INFILL/g) || []).length;
const totalLinesEnabled = gcodeEnabled.split('\n').length;

console.log(`   - Total G-code lines: ${totalLinesEnabled}`);
console.log(`   - Skin operations: ${skinCountEnabled}`);
console.log(`   - Infill operations: ${infillCountEnabled}`);
console.log('   - Strategy: Adaptive skin generation on exposed surfaces\n');

// Compare results
console.log('=== Comparison ===');
console.log(`Line difference: ${totalLinesEnabled - totalLinesDisabled} lines (${((totalLinesEnabled - totalLinesDisabled) / totalLinesDisabled * 100).toFixed(1)}%)`);
console.log(`Skin operation difference: ${skinCountEnabled - skinCountDisabled} operations`);
console.log(`Infill operation difference: ${infillCountEnabled - infillCountDisabled} operations\n`);

console.log('Note: For a simple cylinder, exposure detection may not show significant differences');
console.log('      since all layers have similar coverage. The feature is most useful for');
console.log('      complex geometries with varying cross-sections and overhangs.\n');
