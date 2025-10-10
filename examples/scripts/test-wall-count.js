const { Polyslice, Printer, Filament } = require('/home/runner/work/polyslice/polyslice/src/index');
const THREE = require('three');

console.log('Testing Multiple Wall Generation');
console.log('=================================\n');

// Create printer and filament configuration
const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

// Create a 1cm cube
const geometry = new THREE.BoxGeometry(10, 10, 10);
const cube = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial());
cube.position.set(0, 0, 5);
cube.updateMatrixWorld();

// Test 1: Single wall (0.4mm thickness)
console.log('Test 1: Shell Wall Thickness = 0.4mm (1 wall expected)');
const slicer1 = new Polyslice({
  printer: printer,
  filament: filament,
  layerHeight: 0.2,
  shellWallThickness: 0.4,
  testStrip: false
});
const gcode1 = slicer1.slice(cube);
const outer1 = (gcode1.match(/WALL-OUTER/g) || []).length;
const inner1 = (gcode1.match(/WALL-INNER/g) || []).length;
console.log(`  - WALL-OUTER count: ${outer1}`);
console.log(`  - WALL-INNER count: ${inner1}`);
console.log(`  - Total lines: ${gcode1.split('\n').length}\n`);

// Test 2: Two walls (0.8mm thickness)
console.log('Test 2: Shell Wall Thickness = 0.8mm (2 walls expected)');
const slicer2 = new Polyslice({
  printer: printer,
  filament: filament,
  layerHeight: 0.2,
  shellWallThickness: 0.8,
  testStrip: false
});
const gcode2 = slicer2.slice(cube);
const outer2 = (gcode2.match(/WALL-OUTER/g) || []).length;
const inner2 = (gcode2.match(/WALL-INNER/g) || []).length;
console.log(`  - WALL-OUTER count: ${outer2}`);
console.log(`  - WALL-INNER count: ${inner2}`);
console.log(`  - Total lines: ${gcode2.split('\n').length}\n`);

// Test 3: Three walls (1.2mm thickness)
console.log('Test 3: Shell Wall Thickness = 1.2mm (3 walls expected)');
const slicer3 = new Polyslice({
  printer: printer,
  filament: filament,
  layerHeight: 0.2,
  shellWallThickness: 1.2,
  testStrip: false
});
const gcode3 = slicer3.slice(cube);
const outer3 = (gcode3.match(/WALL-OUTER/g) || []).length;
const inner3 = (gcode3.match(/WALL-INNER/g) || []).length;
console.log(`  - WALL-OUTER count: ${outer3}`);
console.log(`  - WALL-INNER count: ${inner3}`);
console.log(`  - Total lines: ${gcode3.split('\n').length}\n`);

// Test 4: Round down (1.0mm thickness with 0.4mm nozzle = 2 walls)
console.log('Test 4: Shell Wall Thickness = 1.0mm (2 walls expected, rounds down)');
const slicer4 = new Polyslice({
  printer: printer,
  filament: filament,
  layerHeight: 0.2,
  shellWallThickness: 1.0,
  testStrip: false
});
const gcode4 = slicer4.slice(cube);
const outer4 = (gcode4.match(/WALL-OUTER/g) || []).length;
const inner4 = (gcode4.match(/WALL-INNER/g) || []).length;
console.log(`  - WALL-OUTER count: ${outer4}`);
console.log(`  - WALL-INNER count: ${inner4}`);
console.log(`  - Total lines: ${gcode4.split('\n').length}\n`);

console.log('All tests completed successfully!');
