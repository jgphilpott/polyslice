const { Polyslice, Printer, Filament } = require('../../src/index');
const THREE = require('three');
const helpers = require('../../src/slicer/geometry/helpers');

// Create a torus mesh
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

console.log('Analyzing torus wall spacing...');
console.log(`Nozzle diameter: ${slicer.getNozzleDiameter()}mm`);

// Hook into the slicer to extract innermost wall data
const originalSlice = slicer.slice.bind(slicer);
let layerData = {};

slicer.slice = function(mesh) {
  // We need to intercept during slicing - but this is complex
  // For now, just slice normally
  return originalSlice(mesh);
};

const gcode = slicer.slice(mesh);

// Parse gcode to understand what's happening on layer 1
const lines = gcode.split('\n');
let inLayer1 = false;
let inLayer2 = false;
let layer1Info = { outerCount: 0, innerCount: 0, skinCount: 0 };

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  
  if (line.includes('LAYER: 1')) {
    inLayer1 = true;
  } else if (line.includes('LAYER: 2')) {
    inLayer1 = false;
    inLayer2 = true;
    break;
  }
  
  if (inLayer1) {
    if (line.includes('TYPE: WALL-OUTER')) layer1Info.outerCount++;
    if (line.includes('TYPE: WALL-INNER')) layer1Info.innerCount++;
    if (line.includes('TYPE: SKIN')) layer1Info.skinCount++;
  }
}

console.log('\nLayer 1 Analysis:');
console.log(`  Outer walls: ${layer1Info.outerCount}`);
console.log(`  Inner walls: ${layer1Info.innerCount}`);
console.log(`  Skin walls: ${layer1Info.skinCount}`);

if (layer1Info.skinCount > 0) {
  console.log('\n⚠️  Skin walls are being generated on layer 1');
  console.log('This suggests the innermost wall spacing check may not be working correctly.');
}
