const THREE = require('three');
const { Polyslice, Printer, Filament } = require('./src/index');

// Create a simple cube
const geometry = new THREE.BoxGeometry(10, 10, 10);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const cube = new THREE.Mesh(geometry, material);

const printer = new Printer('Ender3');
const filament = new Filament('PrusamentPLA');

const slicer = new Polyslice({
  printer,
  filament,
  verbose: true
});

console.log('Starting slice...');
const startTime = Date.now();

// Add a timeout to detect hangs
const timeout = setTimeout(() => {
  console.log('TIMEOUT: Slicing took more than 10 seconds');
  process.exit(1);
}, 10000);

try {
  const gcode = slicer.slice(cube);
  clearTimeout(timeout);
  const endTime = Date.now();
  console.log(`Slice completed in ${endTime - startTime}ms`);
  console.log(`G-code length: ${gcode.length} bytes`);
} catch (error) {
  clearTimeout(timeout);
  console.error('Error during slicing:', error);
  process.exit(1);
}
