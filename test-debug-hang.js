const THREE = require('three');
const { Polyslice, Printer, Filament } = require('./src/index');

const geometry = new THREE.SphereGeometry(50, 128, 128);  
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const mesh = new THREE.Mesh(geometry, material);

console.log(`Mesh triangles: ${geometry.attributes.position.count / 3}`);

const slicer = new Polyslice({
  printer: new Printer('Ender3'),
  filament: new Filament('PrusamentPLA'),
  verbose: false,
  layerHeight: 0.2,
  infillDensity: 0,
  exposureDetection: false
});

console.log('Slicing...');
const gcode = slicer.slice(mesh);
console.log('Done!', gcode.length);
