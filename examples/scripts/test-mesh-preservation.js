/**
 * Test script to verify that Polyslice does not modify the original mesh
 * This demonstrates the fix for the issue where meshes were being moved during slicing
 */

const { Polyslice } = require('../../src/index');
const THREE = require('three');

console.log('Testing Mesh Preservation During Slicing');
console.log('=========================================\n');

// Create a cube at a specific position
const geometry = new THREE.BoxGeometry(10, 10, 10);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const mesh = new THREE.Mesh(geometry, material);

// Position the mesh at specific coordinates
mesh.position.set(5, 10, 15);
mesh.rotation.set(Math.PI / 4, Math.PI / 6, 0);
mesh.scale.set(1.5, 1.0, 2.0);
mesh.updateMatrixWorld();

console.log('Original mesh state:');
console.log(`  Position: (${mesh.position.x}, ${mesh.position.y}, ${mesh.position.z})`);
console.log(`  Rotation: (${mesh.rotation.x.toFixed(4)}, ${mesh.rotation.y.toFixed(4)}, ${mesh.rotation.z.toFixed(4)})`);
console.log(`  Scale: (${mesh.scale.x}, ${mesh.scale.y}, ${mesh.scale.z})`);
console.log('');

// Create slicer instance
const slicer = new Polyslice({
  layerHeight: 0.2,
  nozzleTemperature: 200,
  bedTemperature: 60,
  fanSpeed: 100,
  infillDensity: 20,
  verbose: false
});

// Slice the mesh
console.log('Slicing mesh...');
const startTime = Date.now();
const gcode = slicer.slice(mesh);
const endTime = Date.now();

console.log(`Slicing completed in ${endTime - startTime}ms\n`);

// Check if mesh was modified
console.log('Mesh state after slicing:');
console.log(`  Position: (${mesh.position.x}, ${mesh.position.y}, ${mesh.position.z})`);
console.log(`  Rotation: (${mesh.rotation.x.toFixed(4)}, ${mesh.rotation.y.toFixed(4)}, ${mesh.rotation.z.toFixed(4)})`);
console.log(`  Scale: (${mesh.scale.x}, ${mesh.scale.y}, ${mesh.scale.z})`);
console.log('');

// Verify preservation
const positionPreserved = mesh.position.x === 5 && mesh.position.y === 10 && mesh.position.z === 15;
const rotationPreserved = Math.abs(mesh.rotation.x - Math.PI / 4) < 1e-10 && 
                          Math.abs(mesh.rotation.y - Math.PI / 6) < 1e-10 &&
                          Math.abs(mesh.rotation.z - 0) < 1e-10;
const scalePreserved = mesh.scale.x === 1.5 && mesh.scale.y === 1.0 && mesh.scale.z === 2.0;

console.log('Verification:');
console.log(`  ✓ Position preserved: ${positionPreserved ? 'YES ✅' : 'NO ❌'}`);
console.log(`  ✓ Rotation preserved: ${rotationPreserved ? 'YES ✅' : 'NO ❌'}`);
console.log(`  ✓ Scale preserved: ${scalePreserved ? 'YES ✅' : 'NO ❌'}`);
console.log('');

// Verify slicing worked
const layerCount = (gcode.match(/LAYER:/g) || []).length;
console.log('Slicing results:');
console.log(`  ✓ G-code generated: ${gcode.length} bytes`);
console.log(`  ✓ Layers produced: ${layerCount > 0 ? layerCount + ' layers' : 'N/A (verbose disabled)'}`);
console.log('');

if (positionPreserved && rotationPreserved && scalePreserved && gcode.length > 1000) {
  console.log('✅ SUCCESS: Mesh was not modified during slicing!');
  console.log('The original mesh remains untouched in the scene while slicing works correctly.');
  process.exit(0);
} else {
  console.log('❌ FAILURE: Mesh state was modified or slicing failed!');
  process.exit(1);
}
