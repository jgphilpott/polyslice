const fs = require('fs');
const path = require('path');
const THREE = require('three');
const { Polyslice, Printer, Filament } = require('./src/index');

async function loadSTL(filePath) {
  const { STLLoader } = await import('three/examples/jsm/loaders/STLLoader.js');
  const buffer = fs.readFileSync(filePath);
  const loader = new STLLoader();
  const geometry = loader.parse(buffer.buffer);
  const material = new THREE.MeshPhongMaterial({ color: 0x808080 });
  return new THREE.Mesh(geometry, material);
}

async function testFile(filePath) {
  console.log(`\nTesting: ${filePath}`);
  
  const mesh = await loadSTL(filePath);
  console.log(`Loaded mesh with ${mesh.geometry.attributes.position.count / 3} triangles`);
  
  const printer = new Printer('Ender3');
  const filament = new Filament('PrusamentPLA');
  
  const slicer = new Polyslice({
    printer,
    filament,
    verbose: false
  });
  
  const startTime = Date.now();
  const timeout = setTimeout(() => {
    console.log('TIMEOUT: Slicing took more than 30 seconds');
    process.exit(1);
  }, 30000);
  
  try {
    const gcode = slicer.slice(mesh);
    clearTimeout(timeout);
    const endTime = Date.now();
    console.log(`✓ Slice completed in ${endTime - startTime}ms`);
    console.log(`  G-code length: ${gcode.length} bytes`);
  } catch (error) {
    clearTimeout(timeout);
    console.error('✗ Error during slicing:', error.message);
  }
}

async function main() {
  const testFiles = [
    'resources/stl/cube/cube-1cm.stl',
    'resources/stl/torus/torus-1cm.stl',
    'resources/testing/benchy/very-low-poly.test.stl'
  ];
  
  for (const file of testFiles) {
    const filePath = path.join(__dirname, file);
    if (fs.existsSync(filePath)) {
      await testFile(filePath);
    } else {
      console.log(`File not found: ${filePath}`);
    }
  }
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
