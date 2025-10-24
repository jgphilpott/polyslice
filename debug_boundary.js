delete require.cache[require.resolve('./src/index')];

const { Polyslice, Printer, Filament } = require('./src/index');
const THREE = require('three');
const helpers = require('./src/slicer/geometry/helpers');

// Monkey-patch clipLineWithHoles to log for layer 17
const originalClipLineWithHoles = helpers.clipLineWithHoles;
let clipCallCount = 0;

helpers.clipLineWithHoles = function(lineStart, lineEnd, inclusionPolygon, exclusionPolygons) {
  clipCallCount++;
  
  const result = originalClipLineWithHoles.call(this, lineStart, lineEnd, inclusionPolygon, exclusionPolygons);
  
  // Only log for small polygons (likely layer 17)
  if (inclusionPolygon.length > 0 && inclusionPolygon[0].z >= 3.35 && inclusionPolygon[0].z <= 3.45) {
    console.log(`[CLIP #${clipCallCount}] Layer 17 clip:`);
    console.log(`  Line: (${lineStart.x.toFixed(2)}, ${lineStart.y.toFixed(2)}) to (${lineEnd.x.toFixed(2)}, ${lineEnd.y.toFixed(2)})`);
    console.log(`  Result: ${result.length} segments`);
  }
  
  return result;
};

const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

const geometry = new THREE.ConeGeometry(5, 10, 32);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const mesh = new THREE.Mesh(geometry, material);
mesh.rotation.x = Math.PI / 2;
mesh.position.set(0, 0, 5);
mesh.updateMatrixWorld();

const slicer = new Polyslice({
  printer: printer,
  filament: filament,
  shellSkinThickness: 0.8,
  shellWallThickness: 0.8,
  infillPattern: 'grid',
  infillDensity: 10,
  layerHeight: 0.2,
  verbose: false
});

console.log('Starting slice...\n');
const gcode = slicer.slice(mesh);
console.log('\nTotal clip calls for layer 17:', clipCallCount);
