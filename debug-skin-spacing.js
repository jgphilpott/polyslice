/**
 * Debug script to check skin wall spacing flags
 */

const { Polyslice, Printer, Filament } = require('./src/index');
const THREE = require('three');

console.log('Debugging Torus Skin Wall Spacing\n');

// Monkey-patch the slice function to add debug output
const originalSlice = require('./src/slicer/slice');
const originalSliceFunction = originalSlice.slice;

originalSlice.slice = function(slicer, scene) {
  // Store original function reference
  const slice = originalSliceFunction;
  
  // Call original slice and capture output
  return slice.call(this, slicer, scene);
};

const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

function createTorus(radius = 5, tube = 2) {
  const geometry = new THREE.TorusGeometry(radius, tube, 16, 32);
  const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
  const mesh = new THREE.Mesh(geometry, material);
  mesh.position.set(0, 0, tube);
  mesh.updateMatrixWorld();
  return mesh;
}

const slicer = new Polyslice({
  printer: printer,
  filament: filament,
  shellSkinThickness: 0.8,  // 4 layers
  shellWallThickness: 0.8,  // 2 walls
  lengthUnit: 'millimeters',
  timeUnit: 'seconds',
  infillPatternCentering: 'global',
  infillPattern: 'grid',
  infillDensity: 20,
  bedTemperature: 0,
  layerHeight: 0.2,
  wipeNozzle: false,
  testStrip: false,
  metadata: false,
  verbose: false  // Turn off verbose for cleaner output
});

const mesh = createTorus(5, 2);
const gcode = slicer.slice(mesh);

console.log('Slicing complete.');
