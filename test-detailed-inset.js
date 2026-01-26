const { Loader } = require('./src/index');
const Polytree = require('@jgphilpott/polytree');
const pathsUtils = require('./src/slicer/utils/paths');

async function testDetailedInset() {
  const mesh = await Loader.loadSTL('resources/testing/obj_2_Assembly_B.stl');
  
  const geo = mesh.geometry;
  geo.computeBoundingBox();
  const bbox = geo.boundingBox;
  
  const layerHeight = 0.2;
  const minZ = bbox.min.z + 0.001;
  const maxZ = bbox.max.z;
  
  const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ, maxZ);
  const layer0 = allLayers[0];
  const paths = pathsUtils.connectSegmentsToPaths(layer0);
  
  // Test the first path that had the issue
  const path = paths[0];
  console.log('Testing path 0:');
  console.log(`  Input path length: ${path.length}`);
  console.log(`  Input path points:`);
  for (let i = 0; i < path.length; i++) {
    console.log(`    ${i}: (${path[i].x.toFixed(4)}, ${path[i].y.toFixed(4)})`);
  }
  
  const nozzleDiameter = 0.4;
  const insetDistance = nozzleDiameter / 2;
  
  // Try to inset
  const insetPath = pathsUtils.createInsetPath(path, insetDistance, true);  // isHole=true
  
  console.log(`\n  Output inset length: ${insetPath.length}`);
  console.log(`  Output inset points:`);
  for (let i = 0; i < insetPath.length; i++) {
    console.log(`    ${i}: (${insetPath[i].x.toFixed(4)}, ${insetPath[i].y.toFixed(4)})`);
  }
}

testDetailedInset().catch(console.error);
