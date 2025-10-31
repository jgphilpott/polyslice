/**
 * Debug script to understand torus wall generation
 */

const { Polyslice, Printer, Filament } = require('../../src/index');
const THREE = require('three');

console.log('Creating torus mesh...');

const geometry = new THREE.TorusGeometry(5, 2, 16, 32);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const mesh = new THREE.Mesh(geometry, material);
mesh.position.set(0, 0, 2);
mesh.updateMatrixWorld();

const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

const slicer = new Polyslice({
  printer: printer,
  filament: filament,
  shellSkinThickness: 0.8,
  shellWallThickness: 0.8,
  lengthUnit: 'millimeters',
  timeUnit: 'seconds',
  infillPattern: 'grid',
  infillDensity: 0,  // No infill to focus on walls
  bedTemperature: 0,
  layerHeight: 0.2,
  wipeNozzle: false,
  testStrip: false,  // No test strip
  metadata: false,
  verbose: true
});

console.log('Slicing torus...');
console.log(`Nozzle diameter: ${slicer.getNozzleDiameter()}mm`);
console.log(`Wall count: ${Math.floor(slicer.getShellWallThickness() / slicer.getNozzleDiameter())}`);

const gcode = slicer.slice(mesh);

// Extract first layer
const lines = gcode.split('\n');
let layer0 = [];
let capturing = false;

for (const line of lines) {
  if (line.includes('LAYER: 0')) {
    capturing = true;
  } else if (line.includes('LAYER: 1')) {
    break;
  }
  
  if (capturing) {
    layer0.push(line);
  }
}

console.log('\n============ LAYER 0 ============');
console.log(layer0.join('\n'));

// Count wall types
const outerWalls = layer0.filter(l => l.includes('TYPE: WALL-OUTER')).length;
const innerWalls = layer0.filter(l => l.includes('TYPE: WALL-INNER')).length;
const skinWalls = layer0.filter(l => l.includes('TYPE: SKIN')).length;

console.log('\n============ WALL COUNTS ============');
console.log(`Outer walls: ${outerWalls}`);
console.log(`Inner walls: ${innerWalls}`);
console.log(`Skin walls: ${skinWalls}`);
console.log('\nExpected: Only outer walls (inner/skin should be skipped due to insufficient space)');
