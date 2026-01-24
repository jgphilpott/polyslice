const THREE = require('three');
const { Polyslice, Printer, Filament } = require('./src/index');

// Create a mesh with many small details
function createDetailedMesh() {
  // Create a large sphere with very fine detail
  const geometry = new THREE.SphereGeometry(50, 128, 128);  // Very detailed sphere
  const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
  return new THREE.Mesh(geometry, material);
}

const mesh = createDetailedMesh();
const triangleCount = mesh.geometry.attributes.position.count / 3;
console.log(`Created mesh with ${triangleCount} triangles`);

const printer = new Printer('Ender3');
const filament = new Filament('PrusamentPLA');

const slicer = new Polyslice({
  printer,
  filament,
  verbose: false,
  layerHeight: 0.1,  // Fine layer height
  infillDensity: 20
});

console.log('Starting slice...');
const startTime = Date.now();

let lastUpdate = startTime;
const progressInterval = setInterval(() => {
  const now = Date.now();
  const elapsed = Math.floor((now - startTime) / 1000);
  const delta = now - lastUpdate;
  
  // If no progress for more than 5 seconds, something might be wrong
  if (delta > 5000) {
    console.log(`⚠ Still slicing... ${elapsed}s elapsed (possible hang detected)`);
  } else {
    console.log(`Still slicing... ${elapsed}s elapsed`);
  }
  lastUpdate = now;
}, 2000);

const timeout = setTimeout(() => {
  console.log('\nTIMEOUT: Slicing took more than 120 seconds - definitely hanging');
  clearInterval(progressInterval);
  process.exit(1);
}, 120000);

try {
  const gcode = slicer.slice(mesh);
  clearTimeout(timeout);
  clearInterval(progressInterval);
  const endTime = Date.now();
  console.log(`\n✓ Slice completed in ${Math.floor((endTime - startTime) / 1000)}s (${endTime - startTime}ms)`);
  console.log(`G-code length: ${(gcode.length / 1024 / 1024).toFixed(2)} MB`);
  const layers = gcode.split('\n').filter(l => l.includes('LAYER:')).length;
  console.log(`Layers: ${layers}`);
} catch (error) {
  clearTimeout(timeout);
  clearInterval(progressInterval);
  console.error('✗ Error during slicing:', error);
  console.error(error.stack);
  process.exit(1);
}
