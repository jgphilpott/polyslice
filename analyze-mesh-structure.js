const { Loader } = require('./src/index');
const Polytree = require('@jgphilpott/polytree');

async function analyzeMeshStructure() {
  const mesh = await Loader.loadSTL('resources/testing/obj_2_Assembly_B.stl');
  
  const geo = mesh.geometry;
  geo.computeBoundingBox();
  const bbox = geo.boundingBox;
  
  console.log('Mesh structure analysis:');
  console.log(`Height: ${(bbox.max.z - bbox.min.z).toFixed(2)}mm`);
  console.log(`Layer height: 0.2mm`);
  console.log(`Expected layers: ${Math.ceil((bbox.max.z - bbox.min.z) / 0.2)}`);
  
  // Slice the mesh
  const layerHeight = 0.2;
  const minZ = bbox.min.z + 0.001;
  const maxZ = bbox.max.z;
  
  console.log('\nSlicing mesh...');
  const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ, maxZ);
  
  console.log(`\nSliced into ${allLayers.length} layers`);
  
  // Analyze first few layers
  for (let i = 0; i < Math.min(5, allLayers.length); i++) {
    const segments = allLayers[i];
    if (segments && segments.length > 0) {
      console.log(`\nLayer ${i}: ${segments.length} segments`);
      
      // Count segment endpoints
      let pointCount = 0;
      const points = new Set();
      segments.forEach(seg => {
        points.add(`${seg.start.x.toFixed(2)},${seg.start.y.toFixed(2)}`);
        points.add(`${seg.end.x.toFixed(2)},${seg.end.y.toFixed(2)}`);
      });
      
      console.log(`  Unique points: ${points.size}`);
      console.log(`  First 5 segments:`);
      for (let j = 0; j < Math.min(5, segments.length); j++) {
        const s = segments[j];
        console.log(`    (${s.start.x.toFixed(1)}, ${s.start.y.toFixed(1)}) -> (${s.end.x.toFixed(1)}, ${s.end.y.toFixed(1)})`);
      }
    } else {
      console.log(`\nLayer ${i}: empty`);
    }
  }
}

analyzeMeshStructure().catch(console.error);
