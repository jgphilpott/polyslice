const THREE = require('three');
const { Polyslice, Printer, Filament } = require('./src/index');

// Create a more complex mesh with many faces
function createComplexMesh() {
  const geometry = new THREE.SphereGeometry(25, 64, 64);  // Large sphere with many faces
  const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
  return new THREE.Mesh(geometry, material);
}

const mesh = createComplexMesh();
console.log(`Created mesh with ${mesh.geometry.attributes.position.count / 3} triangles`);

const printer = new Printer('Ender3');
const filament = new Filament('PrusamentPLA');

const slicer = new Polyslice({
  printer,
  filament,
  verbose: false,
  layerHeight: 0.2,
  infillDensity: 20
});

console.log('Starting slice...');
const startTime = Date.now();

// Monitor progress every second
const progressInterval = setInterval(() => {
  const elapsed = Math.floor((Date.now() - startTime) / 1000);
  console.log(`Still slicing... ${elapsed}s elapsed`);
}, 1000);

// Add a timeout to detect hangs
const timeout = setTimeout(() => {
  console.log('TIMEOUT: Slicing took more than 60 seconds - likely hanging');
  clearInterval(progressInterval);
  process.exit(1);
}, 60000);

try {
  const gcode = slicer.slice(mesh);
  clearTimeout(timeout);
  clearInterval(progressInterval);
  const endTime = Date.now();
  console.log(`\n✓ Slice completed in ${Math.floor((endTime - startTime) / 1000)}s (${endTime - startTime}ms)`);
  console.log(`G-code length: ${gcode.length} bytes`);
  console.log(`Layers: ${gcode.split('\n').filter(l => l.includes('LAYER:')).length}`);
} catch (error) {
  clearTimeout(timeout);
  clearInterval(progressInterval);
  console.error('✗ Error during slicing:', error);
  process.exit(1);
}
