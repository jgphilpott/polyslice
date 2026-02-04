const { Polyslice, Printer, Filament } = require('./src/index');
const { Polytree } = require('@jgphilpott/polytree');
const THREE = require('three');

// Create a simple 3-nested matryoshka
async function createMatryoshka() {
  const createHollowCylinder = async (outerRadius, innerRadius, height, segments = 32) => {
    const outerGeometry = new THREE.CylinderGeometry(outerRadius, outerRadius, height, segments);
    const outerMesh = new THREE.Mesh(outerGeometry, new THREE.MeshBasicMaterial());
    outerMesh.rotation.x = Math.PI / 2;
    outerMesh.updateMatrixWorld();

    const innerGeometry = new THREE.CylinderGeometry(innerRadius, innerRadius, height * 1.2, segments);
    const innerMesh = new THREE.Mesh(innerGeometry, new THREE.MeshBasicMaterial());
    innerMesh.rotation.x = Math.PI / 2;
    innerMesh.updateMatrixWorld();

    const hollowMesh = await Polytree.subtract(outerMesh, innerMesh);
    const finalMesh = new THREE.Mesh(hollowMesh.geometry, hollowMesh.material);
    finalMesh.position.set(0, 0, height / 2);
    finalMesh.updateMatrixWorld();
    return finalMesh;
  };

  const radii = [
    { inner: 5, outer: 10 },    // innermost
    { inner: 13, outer: 18 },   // middle
    { inner: 21, outer: 26 }    // outermost
  ];

  const cylinders = [];
  for (const { inner, outer } of radii) {
    const cylinder = await createHollowCylinder(outer, inner, 1.2);
    cylinders.push(cylinder);
  }

  let combined = cylinders[0];
  for (let i = 1; i < cylinders.length; i++) {
    combined = await Polytree.unite(combined, cylinders[i]);
  }

  return new THREE.Mesh(combined.geometry, combined.material);
}

(async () => {
  console.log('Analyzing matryoshka nesting structure...\n');
  
  const mesh = await createMatryoshka();
  const layerHeight = 0.2;
  const minZ = 0;
  const maxZ = 1.2;
  
  const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ + 0.001, maxZ);
  
  console.log(`Total layers: ${allLayers.length}\n`);
  
  // Analyze first layer structure
  const pathsUtils = require('./src/slicer/utils/paths');
  const primitives = require('./src/slicer/utils/primitives');
  
  const layerSegments = allLayers[0];
  const paths = pathsUtils.connectSegmentsToPaths(layerSegments);
  
  console.log(`Layer 0 has ${paths.length} paths:\n`);
  
  // Calculate nesting levels
  for (let i = 0; i < paths.length; i++) {
    let nestingLevel = 0;
    for (let j = 0; j < paths.length; j++) {
      if (i === j) continue;
      if (paths[i].length > 0 && primitives.pointInPolygon(paths[i][0], paths[j])) {
        nestingLevel++;
      }
    }
    
    const isHole = nestingLevel % 2 === 1;
    const type = isHole ? 'HOLE' : 'STRUCTURE';
    console.log(`Path ${i}: Nesting level ${nestingLevel} -> ${type}`);
  }
})();
