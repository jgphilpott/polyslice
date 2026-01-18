const { Polyslice } = require('../../dist/index.js');
const THREE = require('three');

console.log('Testing Shape Skirt Implementation\n');

// Test 1: Circular skirt
console.log('Test 1: Circular Skirt');
const slicer1 = new Polyslice({
  adhesionEnabled: true,
  adhesionType: 'skirt',
  adhesionSkirtType: 'circular',
  adhesionDistance: 5,
  adhesionLineCount: 2,
  verbose: true
});

const geometry1 = new THREE.BoxGeometry(10, 10, 10);
const mesh1 = new THREE.Mesh(geometry1);

const gcode1 = slicer1.slice(mesh1);
const g1Count1 = (gcode1.match(/G1.*E/g) || []).length;
console.log(`  - G1 moves with extrusion: ${g1Count1}`);
console.log(`  - Cumulative E: ${slicer1.cumulativeE.toFixed(4)}`);

// Test 2: Shape skirt  
console.log('\nTest 2: Shape Skirt');
const slicer2 = new Polyslice({
  adhesionEnabled: true,
  adhesionType: 'skirt',
  adhesionSkirtType: 'shape',
  adhesionDistance: 5,
  adhesionLineCount: 2,
  verbose: true
});

const geometry2 = new THREE.BoxGeometry(10, 10, 10);
const mesh2 = new THREE.Mesh(geometry2);

const gcode2 = slicer2.slice(mesh2);
const g1Count2 = (gcode2.match(/G1.*E/g) || []).length;
console.log(`  - G1 moves with extrusion: ${g1Count2}`);
console.log(`  - Cumulative E: ${slicer2.cumulativeE.toFixed(4)}`);

// Check for fallback messages
if (gcode2.includes('circular skirt')) {
  console.log('  - WARNING: Fell back to circular skirt');
} else {
  console.log('  - Shape skirt generated successfully');
}

// Test 3: Shape skirt with cylinder
console.log('\nTest 3: Shape Skirt with Cylinder');
const slicer3 = new Polyslice({
  adhesionEnabled: true,
  adhesionType: 'skirt',
  adhesionSkirtType: 'shape',
  adhesionDistance: 5,
  adhesionLineCount: 3,
  verbose: false
});

const geometry3 = new THREE.CylinderGeometry(5, 5, 10, 32);
const mesh3 = new THREE.Mesh(geometry3);

const gcode3 = slicer3.slice(mesh3);
const g1Count3 = (gcode3.match(/G1.*E/g) || []).length;
console.log(`  - G1 moves with extrusion: ${g1Count3}`);
console.log(`  - Cumulative E: ${slicer3.cumulativeE.toFixed(4)}`);

console.log('\nAll tests completed successfully!');
