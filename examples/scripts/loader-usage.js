/**
 * Polyslice Loader Usage Example
 * Demonstrates loading 3D models from various file formats
 * 
 * Note: In Node.js, the three.js loaders use fetch() which doesn't support file:// URLs.
 * This example uses direct file reading with Node's fs module and the loader's parse() method.
 * In browsers, you can use the PolysliceLoader.load() method directly with HTTP URLs.
 */

const fs = require('fs');
const path = require('path');
const THREE = require('three');

console.log('Polyslice Loader Usage Example');
console.log('==============================\n');

// Display supported formats
console.log('Supported 3D Printing File Formats:');
console.log('  - STL  (Stereolithography)');
console.log('  - OBJ  (Wavefront Object)');
console.log('  - 3MF  (3D Manufacturing Format)');
console.log('  - AMF  (Additive Manufacturing File)');
console.log('  - PLY  (Polygon File Format)');
console.log('  - GLTF/GLB (GL Transmission Format)');
console.log('  - DAE  (Collada)');
console.log('');

// Define resource paths
const resourcesDir = path.join(__dirname, '../../resources');
const stlDir = path.join(resourcesDir, 'stl');
const objDir = path.join(resourcesDir, 'obj');
const plyDir = path.join(resourcesDir, 'ply');

// Helper to convert Node Buffer to ArrayBuffer
function toArrayBuffer(buffer) {
  return buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength);
}

// Test loading real files
async function runExamples() {
  console.log('Loading real model files from resources...\n');

  // Load the three.js loaders dynamically
  const { STLLoader } = await import('three/addons/loaders/STLLoader.js');
  const { OBJLoader } = await import('three/addons/loaders/OBJLoader.js');
  const { PLYLoader } = await import('three/addons/loaders/PLYLoader.js');

  // Example 1: Load STL files
  console.log('Example 1: Loading STL files');
  console.log('----------------------------');
  const stlLoader = new STLLoader();
  
  try {
    const cubeStl = path.join(stlDir, 'cube/cube-1cm.stl');
    console.log(`Loading: cube-1cm.stl`);
    const buffer = fs.readFileSync(cubeStl);
    const geometry = stlLoader.parse(toArrayBuffer(buffer));
    const mesh = new THREE.Mesh(geometry, new THREE.MeshPhongMaterial());
    console.log(`  ✓ Loaded cube STL successfully`);
    console.log(`    - Type: ${mesh.type}`);
    console.log(`    - Geometry vertices: ${geometry.attributes.position.count}`);
  } catch (error) {
    console.log(`  ✗ Failed to load cube STL: ${error.message}`);
  }

  try {
    const sphereStl = path.join(stlDir, 'sphere/sphere-3cm.stl');
    console.log(`Loading: sphere-3cm.stl`);
    const buffer = fs.readFileSync(sphereStl);
    const geometry = stlLoader.parse(toArrayBuffer(buffer));
    const mesh = new THREE.Mesh(geometry, new THREE.MeshPhongMaterial());
    console.log(`  ✓ Loaded sphere STL successfully`);
    console.log(`    - Type: ${mesh.type}`);
    console.log(`    - Geometry vertices: ${geometry.attributes.position.count}`);
  } catch (error) {
    console.log(`  ✗ Failed to load sphere STL: ${error.message}`);
  }

  try {
    const torusStl = path.join(stlDir, 'torus/torus-5cm.stl');
    console.log(`Loading: torus-5cm.stl`);
    const buffer = fs.readFileSync(torusStl);
    const geometry = stlLoader.parse(toArrayBuffer(buffer));
    const mesh = new THREE.Mesh(geometry, new THREE.MeshPhongMaterial());
    console.log(`  ✓ Loaded torus STL successfully`);
    console.log(`    - Type: ${mesh.type}`);
    console.log(`    - Geometry vertices: ${geometry.attributes.position.count}`);
  } catch (error) {
    console.log(`  ✗ Failed to load torus STL: ${error.message}`);
  }
  console.log('');

  // Example 2: Load OBJ files
  console.log('Example 2: Loading OBJ files');
  console.log('----------------------------');
  const objLoader = new OBJLoader();
  
  try {
    const cylinderObj = path.join(objDir, 'cylinder/cylinder-1cm.obj');
    console.log(`Loading: cylinder-1cm.obj`);
    const content = fs.readFileSync(cylinderObj, 'utf8');
    const object = objLoader.parse(content);
    let meshCount = 0;
    object.traverse((child) => { if (child.isMesh) meshCount++; });
    console.log(`  ✓ Loaded cylinder OBJ successfully`);
    console.log(`    - Meshes found: ${meshCount}`);
  } catch (error) {
    console.log(`  ✗ Failed to load cylinder OBJ: ${error.message}`);
  }

  try {
    const coneObj = path.join(objDir, 'cone/cone-3cm.obj');
    console.log(`Loading: cone-3cm.obj`);
    const content = fs.readFileSync(coneObj, 'utf8');
    const object = objLoader.parse(content);
    let meshCount = 0;
    object.traverse((child) => { if (child.isMesh) meshCount++; });
    console.log(`  ✓ Loaded cone OBJ successfully`);
    console.log(`    - Meshes found: ${meshCount}`);
  } catch (error) {
    console.log(`  ✗ Failed to load cone OBJ: ${error.message}`);
  }
  console.log('');

  // Example 3: Load PLY files
  console.log('Example 3: Loading PLY files');
  console.log('----------------------------');
  const plyLoader = new PLYLoader();
  
  try {
    const cubePly = path.join(plyDir, 'cube/cube-1cm.ply');
    console.log(`Loading: cube-1cm.ply`);
    const buffer = fs.readFileSync(cubePly);
    const geometry = plyLoader.parse(toArrayBuffer(buffer));
    const mesh = new THREE.Mesh(geometry, new THREE.MeshPhongMaterial());
    console.log(`  ✓ Loaded cube PLY successfully`);
    console.log(`    - Type: ${mesh.type}`);
    console.log(`    - Geometry vertices: ${geometry.attributes.position.count}`);
  } catch (error) {
    console.log(`  ✗ Failed to load cube PLY: ${error.message}`);
  }

  try {
    const spherePly = path.join(plyDir, 'sphere/sphere-5cm.ply');
    console.log(`Loading: sphere-5cm.ply`);
    const buffer = fs.readFileSync(spherePly);
    const geometry = plyLoader.parse(toArrayBuffer(buffer));
    const mesh = new THREE.Mesh(geometry, new THREE.MeshPhongMaterial());
    console.log(`  ✓ Loaded sphere PLY successfully`);
    console.log(`    - Type: ${mesh.type}`);
    console.log(`    - Geometry vertices: ${geometry.attributes.position.count}`);
  } catch (error) {
    console.log(`  ✗ Failed to load sphere PLY: ${error.message}`);
  }
  console.log('');

  console.log('All examples completed!');
  console.log('');

  // Code examples for documentation
  console.log('=== Code Examples ===\n');

  console.log('Node.js - Loading with fs and parse():');
  console.log('```javascript');
  console.log('const fs = require("fs");');
  console.log('const THREE = require("three");');
  console.log('const { STLLoader } = await import("three/addons/loaders/STLLoader.js");');
  console.log('');
  console.log('const loader = new STLLoader();');
  console.log('const buffer = fs.readFileSync("model.stl");');
  console.log('const arrayBuffer = buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength);');
  console.log('const geometry = loader.parse(arrayBuffer);');
  console.log('const mesh = new THREE.Mesh(geometry, new THREE.MeshPhongMaterial());');
  console.log('```\n');

  console.log('Browser - Using PolysliceLoader:');
  console.log('```html');
  console.log('<script src="https://unpkg.com/three@0.180.0/build/three.min.js"></script>');
  console.log('<script src="https://unpkg.com/@jgphilpott/polyslice/dist/index.browser.min.js"></script>');
  console.log('<script>');
  console.log('  // Load from URL (HTTP/HTTPS)');
  console.log('  const mesh = await PolysliceLoader.loadSTL("https://example.com/model.stl");');
  console.log('</script>');
  console.log('```\n');

  console.log('Notes:');
  console.log('------');
  console.log('- In Node.js, use fs.readFileSync() and the loader\'s parse() method for local files');
  console.log('- In browsers, use PolysliceLoader with HTTP/HTTPS URLs');
  console.log('- The three.js loaders use fetch() which requires HTTP/HTTPS URLs');
  console.log('- STL and PLY use binary ArrayBuffer, OBJ uses text content');
  console.log('- Loaded meshes are three.js Mesh objects compatible with Polyslice');
}

// Run the examples
runExamples().catch(console.error);
