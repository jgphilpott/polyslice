const { Polyslice, Printer, Filament } = require('./src/index');
const THREE = require('three');

// Calculate which layer is at Z=3.4
console.log('Layer 17 is at Z =', 0.2 * 17, 'mm');

// At Z=3.4mm, the cone radius should be:
const height = 10;
const baseRadius = 5;
const z = 3.4;
const radiusAtZ = baseRadius * (height - z) / height;
console.log('Cone radius at Z=3.4mm:', radiusAtZ, 'mm');

// Nozzle diameter and wall count.
const nozzleDiameter = 0.4;
const wallCount = 2; // shellWallThickness / nozzleDiameter = 0.8 / 0.4
console.log('Nozzle diameter:', nozzleDiameter, 'mm');
console.log('Wall count:', wallCount);

// Wall thickness: wallCount * nozzleDiameter
const wallThickness = wallCount * nozzleDiameter;
console.log('Total wall thickness:', wallThickness, 'mm');

// Infill boundary inset: wallThickness + (nozzleDiameter / 2)
const infillInset = wallThickness + (nozzleDiameter / 2);
console.log('Infill inset from outer boundary:', infillInset, 'mm');

// Effective infill radius.
const infillRadius = radiusAtZ - infillInset;
console.log('Infill radius at Z=3.4mm:', infillRadius, 'mm');

if (infillRadius <= 0) {
  console.log('\n⚠️  WARNING: Infill radius is <= 0, so no infill can be generated!');
} else if (infillRadius < nozzleDiameter) {
  console.log('\n⚠️  WARNING: Infill radius is less than nozzle diameter, might be too small for infill!');
} else {
  console.log('\n✅ Infill radius is sufficient for infill generation.');
}

console.log('\n--- Running actual slice ---');

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
  verbose: true
});

const gcode = slicer.slice(mesh);

const lines = gcode.split('\n');
let inLayer17 = false;
let inFill = false;
let fillLineCount = 0;

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  
  if (line.includes('M117 LAYER: 17')) {
    inLayer17 = true;
    console.log('Found layer 17 at line', i);
  } else if (line.includes('M117 LAYER: 18')) {
    inLayer17 = false;
    console.log('Found layer 18 at line', i);
    break;
  }
  
  if (inLayer17) {
    if (line.includes('; TYPE: FILL')) {
      inFill = true;
      console.log('Found FILL type at line', i);
    }
    if (inFill && line.startsWith('G1') && line.includes(' E')) {
      fillLineCount++;
    }
  }
}

console.log('Infill lines in layer 17:', fillLineCount);
if (fillLineCount === 0) {
  console.log('❌ No infill lines generated for layer 17!');
} else {
  console.log('✅ Infill lines were generated for layer 17.');
}
