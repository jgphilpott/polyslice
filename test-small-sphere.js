const THREE = require('three');
const { Polyslice, Printer, Filament } = require('./src/index');

// Test with progressively larger spheres
const sizes = [
  { r: 10, w: 32, h: 32, name: 'Small (32x32)' },
  { r: 20, w: 64, h: 64, name: 'Medium (64x64)' },
  { r: 30, w: 96, h: 96, name: 'Large (96x96)' }
];

async function testSphere(config) {
  const geometry = new THREE.SphereGeometry(config.r, config.w, config.h);
  const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({ color: 0x00ff00 }));
  
  const triangles = geometry.attributes.position.count / 3;
  console.log(`\n${config.name}: ${triangles} triangles, radius ${config.r}mm`);
  
  const slicer = new Polyslice({
    printer: new Printer('Ender3'),
    filament: new Filament('PrusamentPLA'),
    verbose: false,
    layerHeight: 0.2,
    infillDensity: 0
  });
  
  const startTime = Date.now();
  const timeout = setTimeout(() => {
    console.log(`  ✗ TIMEOUT after 20s`);
    process.exit(1);
  }, 20000);
  
  try {
    const gcode = slicer.slice(mesh);
    clearTimeout(timeout);
    const elapsed = Date.now() - startTime;
    console.log(`  ✓ Sliced in ${elapsed}ms (${(gcode.length / 1024).toFixed(0)} KB)`);
  } catch (error) {
    clearTimeout(timeout);
    console.log(`  ✗ Error: ${error.message}`);
  }
}

(async () => {
  for (const config of sizes) {
    await testSphere(config);
  }
  console.log('\nAll tests completed!');
})();
