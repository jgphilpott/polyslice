const { Loader } = require('./src/index');
const Polytree = require('@jgphilpott/polytree');
const pathsUtils = require('./src/slicer/utils/paths');
const primitives = require('./src/slicer/utils/primitives');

async function findProblematicPath() {
  const mesh = await Loader.loadSTL('resources/testing/obj_2_Assembly_B.stl');
  
  const geo = mesh.geometry;
  geo.computeBoundingBox();
  const bbox = geo.boundingBox;
  
  // Slice and connect paths for first layer
  const layerHeight = 0.2;
  const minZ = bbox.min.z + 0.001;
  const maxZ = bbox.max.z;
  
  const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ, maxZ);
  const layer0 = allLayers[0];
  const paths = pathsUtils.connectSegmentsToPaths(layer0);
  
  console.log(`Checking ${paths.length} paths for issues...\n`);
  
  const nozzleDiameter = 0.4;
  
  // Check each path
  for (let i = 0; i < paths.length; i++) {
    const path = paths[i];
    
    // Test if it's a hole (using point-in-polygon for all other paths)
    let isHole = false;
    for (let j = 0; j < paths.length; j++) {
      if (i !== j && primitives.pointInPolygon(path[0], paths[j])) {
        isHole = true;
        break;
      }
    }
    
    // Create outer wall inset
    const outerWallOffset = nozzleDiameter / 2;
    const outerWall = pathsUtils.createInsetPath(path, outerWallOffset, isHole);
    
    if (outerWall.length > 0) {
      // Check for extreme coordinates
      for (const point of outerWall) {
        if (Math.abs(point.x) > 500 || Math.abs(point.y) > 500) {
          console.log(`\n⚠️  Found problematic path ${i}:`);
          console.log(`  IsHole: ${isHole}`);
          console.log(`  Original path: ${path.length} points`);
          console.log(`  Outer wall: ${outerWall.length} points`);
          console.log(`  Extreme coordinate: (${point.x.toFixed(2)}, ${point.y.toFixed(2)})`);
          
          console.log(`\n  Original path (first 5 points):`);
          for (let k = 0; k < Math.min(5, path.length); k++) {
            console.log(`    ${k}: (${path[k].x.toFixed(2)}, ${path[k].y.toFixed(2)})`);
          }
          
          console.log(`\n  Outer wall (first 5 points):`);
          for (let k = 0; k < Math.min(5, outerWall.length); k++) {
            console.log(`    ${k}: (${outerWall[k].x.toFixed(2)}, ${outerWall[k].y.toFixed(2)})`);
          }
          
          // Check for inner wall
          const innerWall = pathsUtils.createInsetPath(outerWall, nozzleDiameter, isHole);
          if (innerWall.length > 0) {
            console.log(`\n  Inner wall exists with ${innerWall.length} points`);
            const hasExtreme = innerWall.some(p => Math.abs(p.x) > 500 || Math.abs(p.y) > 500);
            console.log(`  Inner wall has extreme coords: ${hasExtreme}`);
          }
          
          return; // Stop after first problematic path
        }
      }
    }
  }
  
  console.log('No problematic paths found');
}

findProblematicPath().catch(console.error);
