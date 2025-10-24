delete require.cache[require.resolve('./src/index')];

const { Polyslice, Printer, Filament } = require('./src/index');
const THREE = require('three');
const gridPattern = require('./src/slicer/infill/patterns/grid');

// Monkey-patch the grid generation to add logging
const originalGenerateGridInfill = gridPattern.generateGridInfill;

gridPattern.generateGridInfill = function(slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint, holeInnerWalls) {
  console.log(`\n[GRID] generateGridInfill called at Z=${z}`);
  console.log(`[GRID] infillBoundary.length=${infillBoundary.length}`);
  console.log(`[GRID] lineSpacing=${lineSpacing}`);
  
  // Call original function
  const originalGcodeLength = slicer.gcode.length;
  const result = originalGenerateGridInfill.call(this, slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint, holeInnerWalls);
  const gcodeAdded = slicer.gcode.length - originalGcodeLength;
  
  console.log(`[GRID] G-code added: ${gcodeAdded} characters`);
  
  if (z >= 3.35 && z <= 3.45) {
    console.log(`\n>>> This is layer 17! <<<`);
    console.log(`>>> G-code added for infill: ${gcodeAdded} characters`);
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
  verbose: false  // Disable to reduce output
});

console.log('Starting slice...\n');
const gcode = slicer.slice(mesh);
