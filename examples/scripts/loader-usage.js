/**
 * Polyslice Loader Usage Example
 * Demonstrates loading 3D models from various file formats
 * 
 * The Polyslice Loader works in both Node.js and browser environments.
 * In Node.js, it reads local files using fs and parses them with three.js loaders.
 * In browsers, it uses the three.js loaders' fetch-based loading.
 */

const path = require('path');
const Loader = require('../../src/loaders/loader');

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

// Test loading real files using the Polyslice Loader
async function runExamples() {
  console.log('Loading real model files using Polyslice Loader...\n');

  // Example 1: Load STL files
  console.log('Example 1: Loading STL files');
  console.log('----------------------------');
  
  try {
    const cubeStl = path.join(stlDir, 'cube/cube-1cm.stl');
    console.log(`Loading: cube-1cm.stl`);
    const cubeMesh = await Loader.loadSTL(cubeStl);
    console.log(`  ✓ Loaded cube STL successfully`);
    console.log(`    - Type: ${cubeMesh.type}`);
    console.log(`    - Geometry vertices: ${cubeMesh.geometry.attributes.position.count}`);
  } catch (error) {
    console.log(`  ✗ Failed to load cube STL: ${error.message}`);
  }

  try {
    const sphereStl = path.join(stlDir, 'sphere/sphere-3cm.stl');
    console.log(`Loading: sphere-3cm.stl`);
    const sphereMesh = await Loader.loadSTL(sphereStl);
    console.log(`  ✓ Loaded sphere STL successfully`);
    console.log(`    - Type: ${sphereMesh.type}`);
    console.log(`    - Geometry vertices: ${sphereMesh.geometry.attributes.position.count}`);
  } catch (error) {
    console.log(`  ✗ Failed to load sphere STL: ${error.message}`);
  }

  try {
    const torusStl = path.join(stlDir, 'torus/torus-5cm.stl');
    console.log(`Loading: torus-5cm.stl`);
    const torusMesh = await Loader.loadSTL(torusStl);
    console.log(`  ✓ Loaded torus STL successfully`);
    console.log(`    - Type: ${torusMesh.type}`);
    console.log(`    - Geometry vertices: ${torusMesh.geometry.attributes.position.count}`);
  } catch (error) {
    console.log(`  ✗ Failed to load torus STL: ${error.message}`);
  }
  console.log('');

  // Example 2: Load OBJ files
  console.log('Example 2: Loading OBJ files');
  console.log('----------------------------');
  
  try {
    const cylinderObj = path.join(objDir, 'cylinder/cylinder-1cm.obj');
    console.log(`Loading: cylinder-1cm.obj`);
    const cylinderMesh = await Loader.loadOBJ(cylinderObj);
    const meshCount = Array.isArray(cylinderMesh) ? cylinderMesh.length : 1;
    console.log(`  ✓ Loaded cylinder OBJ successfully`);
    console.log(`    - Meshes found: ${meshCount}`);
  } catch (error) {
    console.log(`  ✗ Failed to load cylinder OBJ: ${error.message}`);
  }

  try {
    const coneObj = path.join(objDir, 'cone/cone-3cm.obj');
    console.log(`Loading: cone-3cm.obj`);
    const coneMesh = await Loader.loadOBJ(coneObj);
    const meshCount = Array.isArray(coneMesh) ? coneMesh.length : 1;
    console.log(`  ✓ Loaded cone OBJ successfully`);
    console.log(`    - Meshes found: ${meshCount}`);
  } catch (error) {
    console.log(`  ✗ Failed to load cone OBJ: ${error.message}`);
  }
  console.log('');

  // Example 3: Load PLY files
  console.log('Example 3: Loading PLY files');
  console.log('----------------------------');
  
  try {
    const cubePly = path.join(plyDir, 'cube/cube-1cm.ply');
    console.log(`Loading: cube-1cm.ply`);
    const cubePlyMesh = await Loader.loadPLY(cubePly);
    console.log(`  ✓ Loaded cube PLY successfully`);
    console.log(`    - Type: ${cubePlyMesh.type}`);
    console.log(`    - Geometry vertices: ${cubePlyMesh.geometry.attributes.position.count}`);
  } catch (error) {
    console.log(`  ✗ Failed to load cube PLY: ${error.message}`);
  }

  try {
    const spherePly = path.join(plyDir, 'sphere/sphere-5cm.ply');
    console.log(`Loading: sphere-5cm.ply`);
    const spherePlyMesh = await Loader.loadPLY(spherePly);
    console.log(`  ✓ Loaded sphere PLY successfully`);
    console.log(`    - Type: ${spherePlyMesh.type}`);
    console.log(`    - Geometry vertices: ${spherePlyMesh.geometry.attributes.position.count}`);
  } catch (error) {
    console.log(`  ✗ Failed to load sphere PLY: ${error.message}`);
  }
  console.log('');

  // Example 4: Using the generic load() method with auto-detection
  console.log('Example 4: Generic loading (auto-detect format)');
  console.log('----------------------------------------------');
  
  try {
    const torusStl = path.join(stlDir, 'torus/torus-1cm.stl');
    console.log(`Loading via generic load(): torus-1cm.stl`);
    const mesh = await Loader.load(torusStl);
    console.log(`  ✓ Auto-detected and loaded STL successfully`);
    console.log(`    - Type: ${mesh.type}`);
  } catch (error) {
    console.log(`  ✗ Failed: ${error.message}`);
  }

  try {
    const cubeObj = path.join(objDir, 'cube/cube-5cm.obj');
    console.log(`Loading via generic load(): cube-5cm.obj`);
    const mesh = await Loader.load(cubeObj);
    console.log(`  ✓ Auto-detected and loaded OBJ successfully`);
  } catch (error) {
    console.log(`  ✗ Failed: ${error.message}`);
  }

  try {
    const conePly = path.join(plyDir, 'cone/cone-3cm.ply');
    console.log(`Loading via generic load(): cone-3cm.ply`);
    const mesh = await Loader.load(conePly);
    console.log(`  ✓ Auto-detected and loaded PLY successfully`);
    console.log(`    - Type: ${mesh.type}`);
  } catch (error) {
    console.log(`  ✗ Failed: ${error.message}`);
  }
  console.log('');

  console.log('All examples completed!');
  console.log('');

  // Code examples for documentation
  console.log('=== Code Examples ===\n');

  console.log('Node.js - Using Polyslice Loader:');
  console.log('```javascript');
  console.log('const { Loader } = require("@jgphilpott/polyslice");');
  console.log('');
  console.log('// Load STL file');
  console.log('const mesh = await Loader.loadSTL("path/to/model.stl");');
  console.log('');
  console.log('// Generic load (auto-detects format)');
  console.log('const mesh = await Loader.load("path/to/model.stl");');
  console.log('const mesh = await Loader.load("path/to/model.obj");');
  console.log('const mesh = await Loader.load("path/to/model.ply");');
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
  console.log('- The Polyslice Loader handles both Node.js and browser environments');
  console.log('- In Node.js, it reads local files using fs and parses them');
  console.log('- In browsers, it uses fetch-based loading via three.js loaders');
  console.log('- The generic load() method auto-detects format from file extension');
  console.log('- Loaded meshes are three.js Mesh objects compatible with Polyslice');
}

// Run the examples
runExamples().catch(console.error);
