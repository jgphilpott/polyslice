const { Loader } = require('./src/index');
const Polytree = require('@jgphilpott/polytree');
const pathsUtils = require('./src/slicer/utils/paths');
const primitives = require('./src/slicer/utils/primitives');

async function findAllProblematic() {
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
  
  console.log(`Checking ${paths.length} paths...\n`);
  
  const nozzleDiameter = 0.4;
  let problematicCount = 0;
  
  for (let i = 0; i < paths.length; i++) {
    const path = paths[i];
    
    let isHole = false;
    for (let j = 0; j < paths.length; j++) {
      if (i !== j && primitives.pointInPolygon(path[0], paths[j])) {
        isHole = true;
        break;
      }
    }
    
    const outerWallOffset = nozzleDiameter / 2;
    const outerWall = pathsUtils.createInsetPath(path, outerWallOffset, isHole);
    
    if (outerWall.length > 0) {
      for (const point of outerWall) {
        if (Math.abs(point.x) > 300 || Math.abs(point.y) > 300) {
          problematicCount++;
          console.log(`Path ${i}: Extreme coord (${point.x.toFixed(1)}, ${point.y.toFixed(1)}), isHole=${isHole}, origSize=${path.length}, insetSize=${outerWall.length}`);
          break;
        }
      }
    }
  }
  
  console.log(`\nTotal problematic paths: ${problematicCount}/${paths.length}`);
}

findAllProblematic().catch(console.error);
