const { Polyslice, Printer, Filament } = require('../../src/index');
const THREE = require('three');

const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

const geometry = new THREE.BoxGeometry(10, 10, 10);
const cube = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial());
cube.position.set(0, 0, 5);
cube.updateMatrixWorld();

const slicer = new Polyslice({
  printer: printer,
  filament: filament,
  layerHeight: 0.2,
  shellWallThickness: 1.2,
  testStrip: false
});

const gcode = slicer.slice(cube);

// Find one layer and show its walls
const lines = gcode.split('\n');
let layerStart = -1;
let layerEnd = -1;

for (let i = 0; i < lines.length; i++) {
  if (lines[i].includes('M117 LAYER:50')) {
    layerStart = i;
  }
  if (layerStart >= 0 && lines[i].includes('M117') && i > layerStart) {
    layerEnd = i;
    break;
  }
}

console.log('Layer 50 G-code (3 walls expected):');
console.log('====================================');
for (let i = layerStart; i < (layerEnd > 0 ? layerEnd : layerStart + 30); i++) {
  console.log(lines[i]);
}
