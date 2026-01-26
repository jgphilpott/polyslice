const { Loader } = require('./src/index');
const Polytree = require('@jgphilpott/polytree');
const pathsUtils = require('./src/slicer/utils/paths');

async function testDuplicateIssue() {
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
  
  console.log('Checking for paths with duplicate consecutive points:\n');
  
  let pathsWithDuplicates = 0;
  
  for (let i = 0; i < Math.min(10, paths.length); i++) {
    const path = paths[i];
    
    let hasDuplicates = false;
    for (let j = 0; j < path.length; j++) {
      const nextIdx = (j + 1) % path.length;
      const p1 = path[j];
      const p2 = path[nextIdx];
      
      const dx = p2.x - p1.x;
      const dy = p2.y - p1.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      
      if (dist < 0.0001) {
        hasDuplicates = true;
        console.log(`Path ${i}: Duplicate at index ${j}-${nextIdx}`);
        console.log(`  Point ${j}: (${p1.x.toFixed(2)}, ${p1.y.toFixed(2)})`);
        console.log(`  Point ${nextIdx}: (${p2.x.toFixed(2)}, ${p2.y.toFixed(2)})`);
      }
    }
    
    if (hasDuplicates) {
      pathsWithDuplicates++;
      console.log(`  Path ${i} length: ${path.length}`);
      console.log();
    }
  }
  
  console.log(`\nTotal paths checked: ${Math.min(10, paths.length)}`);
  console.log(`Paths with duplicates: ${pathsWithDuplicates}`);
}

testDuplicateIssue().catch(console.error);
