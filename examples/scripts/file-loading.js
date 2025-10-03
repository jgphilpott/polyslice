/**
 * Example showing how to use Polyslice file loaders
 * Demonstrates loading 3D models from various file formats
 */

const { Loader } = require('../src/index');

console.log('Polyslice File Loader Example');
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

// Example 1: Load STL file
console.log('Example 1: Loading an STL file');
console.log('------------------------------');
console.log('```javascript');
console.log('const mesh = await Loader.loadSTL("model.stl");');
console.log('// mesh is a THREE.Mesh ready to use with Polyslice');
console.log('```\n');

// Example 2: Load with custom material
console.log('Example 2: Loading with custom material');
console.log('---------------------------------------');
console.log('```javascript');
console.log('const THREE = require("three");');
console.log('const customMaterial = new THREE.MeshPhongMaterial({');
console.log('  color: 0xff0000,');
console.log('  specular: 0x111111,');
console.log('  shininess: 200');
console.log('});');
console.log('const mesh = await Loader.loadSTL("model.stl", customMaterial);');
console.log('```\n');

// Example 3: Load OBJ file (may return multiple meshes)
console.log('Example 3: Loading an OBJ file');
console.log('-----------------------------');
console.log('```javascript');
console.log('const meshes = await Loader.loadOBJ("model.obj");');
console.log('// meshes can be a single Mesh or array of Meshes');
console.log('if (Array.isArray(meshes)) {');
console.log('  console.log(`Loaded ${meshes.length} meshes`);');
console.log('  // Process each mesh separately');
console.log('} else {');
console.log('  console.log("Loaded single mesh");');
console.log('}');
console.log('```\n');

// Example 4: Load 3MF file
console.log('Example 4: Loading a 3MF file');
console.log('----------------------------');
console.log('```javascript');
console.log('const meshes = await Loader.load3MF("model.3mf");');
console.log('// 3MF supports colors and materials natively');
console.log('```\n');

// Example 5: Load PLY file
console.log('Example 5: Loading a PLY file');
console.log('----------------------------');
console.log('```javascript');
console.log('const mesh = await Loader.loadPLY("scan.ply");');
console.log('// PLY files often come from 3D scans');
console.log('// and may include vertex colors');
console.log('```\n');

// Example 6: Load GLTF/GLB file
console.log('Example 6: Loading a GLTF or GLB file');
console.log('------------------------------------');
console.log('```javascript');
console.log('const meshes = await Loader.loadGLTF("model.gltf");');
console.log('// or');
console.log('const meshes = await Loader.loadGLTF("model.glb");');
console.log('// GLTF includes materials, animations, and more');
console.log('```\n');

// Example 7: Generic load method (auto-detects format)
console.log('Example 7: Generic loading (auto-detect format)');
console.log('----------------------------------------------');
console.log('```javascript');
console.log('// Automatically detects format from file extension');
console.log('const mesh = await Loader.load("model.stl");');
console.log('const obj = await Loader.load("model.obj");');
console.log('const gltf = await Loader.load("model.gltf");');
console.log('```\n');

// Example 8: Complete workflow with Polyslice
console.log('Example 8: Complete workflow with Polyslice');
console.log('------------------------------------------');
console.log('```javascript');
console.log('const Polyslice = require("@jgphilpott/polyslice");');
console.log('const { Loader } = require("@jgphilpott/polyslice");');
console.log('');
console.log('// Load a 3D model from file');
console.log('const mesh = await Loader.loadSTL("model.stl");');
console.log('');
console.log('// Create a slicer instance');
console.log('const slicer = new Polyslice({');
console.log('  nozzleTemperature: 210,');
console.log('  bedTemperature: 60,');
console.log('  fanSpeed: 80');
console.log('});');
console.log('');
console.log('// Generate G-code from the loaded mesh');
console.log('// (Note: Full slicing implementation coming soon)');
console.log('const gcode = slicer.slice(mesh);');
console.log('```\n');

// Browser usage
console.log('Browser Usage');
console.log('------------');
console.log('```html');
console.log('<!-- Include three.js -->');
console.log('<script src="https://unpkg.com/three@0.180.0/build/three.min.js"></script>');
console.log('');
console.log('<!-- Include three.js loaders you need -->');
console.log('<script src="https://unpkg.com/three@0.180.0/examples/jsm/loaders/STLLoader.js"></script>');
console.log('<script src="https://unpkg.com/three@0.180.0/examples/jsm/loaders/OBJLoader.js"></script>');
console.log('');
console.log('<!-- Include Polyslice -->');
console.log('<script src="https://unpkg.com/@jgphilpott/polyslice/dist/index.browser.min.js"></script>');
console.log('');
console.log('<script>');
console.log('  // Loaders are available as PolysliceLoader in browser');
console.log('  const mesh = await PolysliceLoader.loadSTL("model.stl");');
console.log('</script>');
console.log('```\n');

console.log('Notes:');
console.log('------');
console.log('- All load methods are asynchronous and return Promises');
console.log('- In Node.js, loaders use dynamic import() for ES modules');
console.log('- In browsers, three.js loaders must be included separately');
console.log('- The generic load() method auto-detects format from file extension');
console.log('- Loaded meshes are three.js Mesh objects compatible with Polyslice');
console.log('- Some formats (OBJ, 3MF, GLTF, etc.) may return multiple meshes');
console.log('');
console.log('For more information, see:');
console.log('- https://threejs.org/docs/#examples/en/loaders/STLLoader');
console.log('- https://threejs.org/docs/#examples/en/loaders/OBJLoader');
console.log('- https://threejs.org/docs/#examples/en/loaders/GLTFLoader');

