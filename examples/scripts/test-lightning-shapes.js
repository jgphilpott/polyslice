/**
 * Test Lightning infill on various shapes
 */

const { Polyslice } = require('../../src/index');
const THREE = require('three');

console.log('Testing Lightning Infill Pattern on Various Shapes\n');

// Test with different shapes
const shapes = [
  { name: 'Cube', geometry: new THREE.BoxGeometry(10, 10, 10), position: [0, 0, 5] },
  { name: 'Cylinder', geometry: new THREE.CylinderGeometry(5, 5, 10, 32), position: [0, 0, 5], rotation: [Math.PI/2, 0, 0] },
  { name: 'Sphere', geometry: new THREE.SphereGeometry(5, 32, 32), position: [0, 0, 5] }
];

shapes.forEach(shape => {
  const mesh = new THREE.Mesh(shape.geometry, new THREE.MeshBasicMaterial());
  mesh.position.set(...shape.position);
  if (shape.rotation) mesh.rotation.set(...shape.rotation);
  mesh.updateMatrixWorld();

  const slicer = new Polyslice({
    infillPattern: 'lightning',
    infillDensity: 20,
    layerHeight: 0.2,
    verbose: false,
    testStrip: false,
    metadata: false,
    bedTemperature: 0
  });

  const gcode = slicer.slice(mesh);
  const lines = gcode.split('\n').filter(l => l.trim());
  const fillSections = lines.filter(l => l.includes('; TYPE: FILL')).length;
  
  console.log(`${shape.name.padEnd(10)} | ${fillSections} fill sections | ${lines.length} total lines`);
});

console.log('\n✅ Lightning pattern successfully tested on multiple shapes!');
