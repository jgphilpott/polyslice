// Example demonstrating exposure detection with a complex geometry
// This creates a shape with varying cross-sections to show adaptive skin generation

const Polyslice = require('../../src/index');
const THREE = require('three');

// Create a shape with varying width (like a vase or hourglass shape)
// We'll use a sphere which has varying cross-sections at different heights
const geometry = new THREE.SphereGeometry(5, 32, 32);
const material = new THREE.MeshBasicMaterial();
const mesh = new THREE.Mesh(geometry, material);

// Position sphere so bottom is at Z=0
mesh.position.set(0, 0, 5);
mesh.updateMatrixWorld();

console.log('\n=== Exposure Detection with Complex Geometry (Sphere) ===\n');

// Test 1: Exposure detection DISABLED
console.log('1. Slicing sphere with exposure detection DISABLED...');
const slicerDisabled = new Polyslice({
    layerHeight: 0.2,
    shellSkinThickness: 0.8,  // 4 layers
    infillDensity: 20,  // 20% infill
    nozzleTemperature: 200,
    bedTemperature: 60,
    verbose: true,
    exposureDetection: false  // Disabled for comparison
});

const gcodeDisabled = slicerDisabled.slice(mesh);
const skinCountDisabled = (gcodeDisabled.match(/TYPE: SKIN/g) || []).length;
const infillCountDisabled = (gcodeDisabled.match(/TYPE: INFILL/g) || []).length;
const layerCountDisabled = (gcodeDisabled.match(/LAYER:/g) || []).length;
const totalLinesDisabled = gcodeDisabled.split('\n').length;

console.log(`   - Total layers: ${layerCountDisabled}`);
console.log(`   - Total G-code lines: ${totalLinesDisabled}`);
console.log(`   - Skin operations: ${skinCountDisabled}`);
console.log(`   - Infill operations: ${infillCountDisabled}`);
console.log('   - Strategy: Skin only on top 4 and bottom 4 layers\n');

// Test 2: Exposure detection ENABLED (default)
console.log('2. Slicing sphere with exposure detection ENABLED (default)...');
const slicerEnabled = new Polyslice({
    layerHeight: 0.2,
    shellSkinThickness: 0.8,  // 4 layers
    infillDensity: 20,  // 20% infill
    nozzleTemperature: 200,
    bedTemperature: 60,
    verbose: true,
    exposureDetection: true  // Enabled by default (shown explicitly here)
});

const gcodeEnabled = slicerEnabled.slice(mesh);
const skinCountEnabled = (gcodeEnabled.match(/TYPE: SKIN/g) || []).length;
const infillCountEnabled = (gcodeEnabled.match(/TYPE: INFILL/g) || []).length;
const layerCountEnabled = (gcodeEnabled.match(/LAYER:/g) || []).length;
const totalLinesEnabled = gcodeEnabled.split('\n').length;

console.log(`   - Total layers: ${layerCountEnabled}`);
console.log(`   - Total G-code lines: ${totalLinesEnabled}`);
console.log(`   - Skin operations: ${skinCountEnabled}`);
console.log(`   - Infill operations: ${infillCountEnabled}`);
console.log('   - Strategy: Adaptive skin on exposed surfaces\n');

// Compare results
console.log('=== Comparison ===');
const lineDiff = totalLinesEnabled - totalLinesDisabled;
const skinDiff = skinCountEnabled - skinCountDisabled;
const infillDiff = infillCountEnabled - infillCountDisabled;

console.log(`Line difference: ${lineDiff} lines (${(lineDiff / totalLinesDisabled * 100).toFixed(1)}%)`);
console.log(`Skin operation difference: ${skinDiff} operations`);
console.log(`Infill operation difference: ${infillDiff} operations\n`);

if (skinDiff !== 0 || infillDiff !== 0) {
    console.log('✓ Exposure detection is working! Different skin/infill patterns detected.');
} else {
    console.log('ℹ For this geometry, exposure detection may not significantly alter the output');
    console.log('  since sphere layers transition gradually. The algorithm is more effective');
    console.log('  with geometries that have sudden changes in cross-section.\n');
}

console.log('Tip: The exposure detection algorithm is designed to be conservative to avoid');
console.log('     false positives on curved surfaces. You can adjust coverage thresholds in');
console.log('     src/slicer/slice.coffee for more aggressive detection if needed.\n');
