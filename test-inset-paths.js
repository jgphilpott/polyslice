const { Loader } = require('./src/index');
const Polytree = require('@jgphilpott/polytree');
const pathsUtils = require('./src/slicer/utils/paths');

async function testInsetPaths() {
  const mesh = await Loader.loadSTL('resources/testing/obj_2_Assembly_B.stl');
  
  const geo = mesh.geometry;
  geo.computeBoundingBox();
  const bbox = geo.boundingBox;
  
  // Slice and connect paths
  const layerHeight = 0.2;
  const minZ = bbox.min.z + 0.001;
  const maxZ = bbox.max.z;
  
  const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ, maxZ);
  const layer0 = allLayers[0];
  const paths = pathsUtils.connectSegmentsToPaths(layer0);
  
  console.log(`Layer 0: ${paths.length} paths`);
  
  // Test inset on a few paths
  const nozzleDiameter = 0.4;
  const insetDistance = nozzleDiameter / 2;
  
  let validPaths = 0;
  let invalidPaths = 0;
  let emptyInsets = 0;
  
  for (let i = 0; i < paths.length; i++) {
    const path = paths[i];
    const insetPath = pathsUtils.createInsetPath(path, insetDistance, false);
    
    if (insetPath.length === 0) {
      emptyInsets++;
    } else {
      // Check for invalid coordinates
      let hasInvalid = false;
      for (const point of insetPath) {
        if (Math.abs(point.x) > 1000 || Math.abs(point.y) > 1000) {
          hasInvalid = true;
          if (invalidPaths < 3) {
            console.log(`\nInvalid inset path ${i}:`);
            console.log(`  Original path size: ${path.length} points`);
            console.log(`  Inset path size: ${insetPath.length} points`);
            console.log(`  Invalid point: (${point.x.toFixed(2)}, ${point.y.toFixed(2)})`);
            console.log(`  Original path sample:`);
            for (let j = 0; j < Math.min(3, path.length); j++) {
              console.log(`    (${path[j].x.toFixed(2)}, ${path[j].y.toFixed(2)})`);
            }
          }
          break;
        }
      }
      
      if (hasInvalid) {
        invalidPaths++;
      } else {
        validPaths++;
      }
    }
  }
  
  console.log(`\n\nSummary:`);
  console.log(`  Total paths: ${paths.length}`);
  console.log(`  Valid insets: ${validPaths}`);
  console.log(`  Invalid insets (extreme coordinates): ${invalidPaths}`);
  console.log(`  Empty insets (too small): ${emptyInsets}`);
}

testInsetPaths().catch(console.error);
