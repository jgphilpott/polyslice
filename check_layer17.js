delete require.cache[require.resolve('./src/index')];

const { Polyslice, Printer, Filament } = require('./src/index');
const THREE = require('three');
const fs = require('fs');

const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

const geometry = new THREE.ConeGeometry(5, 10, 32);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const mesh = new THREE.Mesh(geometry, material);
mesh.rotation.x = Math.PI / 2;
mesh.position.set(0, 0, 5);
mesh.updateMatrixWorld();

const slicer = new Polyslice({
  printer: printer,
  filament: filament,
  shellSkinThickness: 0.8,
  shellWallThickness: 0.8,
  infillPattern: 'grid',
  infillDensity: 10,
  layerHeight: 0.2,
  verbose: true
});

const gcode = slicer.slice(mesh);
fs.writeFileSync('test_layer17.gcode', gcode);

const lines = gcode.split('\n');
let layer17Start = -1;
let layer18Start = -1;

for (let i = 0; i < lines.length; i++) {
  if (lines[i].includes('M117 LAYER: 17')) {
    layer17Start = i;
  } else if (lines[i].includes('M117 LAYER: 18')) {
    layer18Start = i;
    break;
  }
}

console.log(`Layer 17: lines ${layer17Start} to ${layer18Start}`);
console.log('\n=== Layer 17 content ===');
for (let i = layer17Start; i < layer18Start; i++) {
  console.log(`${i}: ${lines[i]}`);
}
