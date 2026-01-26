const { Loader } = require('./src/index');
const Polytree = require('@jgphilpott/polytree');
const pathsUtils = require('./src/slicer/utils/paths');

async function testPathConnection() {
  const mesh = await Loader.loadSTL('resources/testing/obj_2_Assembly_B.stl');
  
  const geo = mesh.geometry;
  geo.computeBoundingBox();
  const bbox = geo.boundingBox;
  
  // Slice the mesh
  const layerHeight = 0.2;
  const minZ = bbox.min.z + 0.001;
  const maxZ = bbox.max.z;
  
  console.log('Slicing mesh...');
  const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ, maxZ);
  
  // Test path connection on first layer
  const layer0 = allLayers[0];
  console.log(`\nLayer 0 has ${layer0.length} segments`);
  console.log('Attempting to connect segments into paths...');
  
  const startTime = Date.now();
  const timeout = setTimeout(() => {
    console.log(`\nSTILL RUNNING after ${Math.floor((Date.now() - startTime) / 1000)}s - this is the problem!`);
    process.exit(1);
  }, 30000);
  
  const paths = pathsUtils.connectSegmentsToPaths(layer0);
  clearTimeout(timeout);
  
  const elapsed = Date.now() - startTime;
  console.log(`\n✓ Connected in ${(elapsed / 1000).toFixed(1)}s`);
  console.log(`Resulting paths: ${paths.length}`);
  
  // Analyze path sizes
  const pathSizes = paths.map(p => p.length).sort((a, b) => b - a);
  console.log(`\nPath size distribution:`);
  console.log(`  Largest: ${pathSizes[0]} points`);
  console.log(`  Median: ${pathSizes[Math.floor(pathSizes.length / 2)]} points`);
  console.log(`  Smallest: ${pathSizes[pathSizes.length - 1]} points`);
  console.log(`  Total paths: ${paths.length}`);
}

testPathConnection().catch(console.error);
