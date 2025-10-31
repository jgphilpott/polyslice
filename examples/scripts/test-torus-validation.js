const { Polyslice, Printer, Filament } = require('../../src/index');
const THREE = require('three');

// Create a torus mesh matching the sample parameters
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
  infillDensity: 10,
  bedTemperature: 0,
  layerHeight: 0.2,
  wipeNozzle: false,
  testStrip: false,
  metadata: false,
  verbose: true
});

console.log('Slicing torus with wall spacing validation...');
console.log(`Nozzle diameter: ${slicer.getNozzleDiameter()}mm`);
console.log(`Required clearance for inner walls: ${slicer.getNozzleDiameter() * 0.5}mm`);

const gcode = slicer.slice(mesh);

// Count wall types on layer 0
const parts = gcode.split('LAYER: 0');
if (parts.length < 2) {
  console.log('ERROR: Could not find LAYER: 0 in gcode');
  process.exit(1);
}
const layer0 = parts[1].split('LAYER: 1')[0];
const outerCount = (layer0.match(/TYPE: WALL-OUTER/g) || []).length;
const innerCount = (layer0.match(/TYPE: WALL-INNER/g) || []).length;
const skinCount = (layer0.match(/TYPE: SKIN/g) || []).length;

console.log('\nLayer 0 Results:');
console.log(`  Outer walls: ${outerCount}`);
console.log(`  Inner walls: ${innerCount}`);
console.log(`  Skin walls: ${skinCount}`);

if (innerCount === 0 && skinCount === 0) {
  console.log('\n✅ SUCCESS: Inner and skin walls correctly suppressed due to insufficient spacing!');
} else {
  console.log('\n⚠️  Inner and/or skin walls were generated (may indicate insufficient spacing detection)');
}

// Also check layer 1 and layer 2
const layer1 = gcode.split('LAYER: 1')[1].split('LAYER: 2')[0];
const layer1Inner = (layer1.match(/TYPE: WALL-INNER/g) || []).length;
const layer1Skin = (layer1.match(/TYPE: SKIN/g) || []).length;

console.log('\nLayer 1 Results:');
console.log(`  Inner walls: ${layer1Inner}`);
console.log(`  Skin walls: ${layer1Skin}`);
