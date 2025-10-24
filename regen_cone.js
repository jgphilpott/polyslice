// Force require to bypass cache
delete require.cache[require.resolve('./src/index')];
delete require.cache[require.resolve('./src/polyslice')];
delete require.cache[require.resolve('./src/slicer/slice')];
delete require.cache[require.resolve('./src/slicer/infill/infill')];

const { Polyslice, Printer, Filament } = require('./src/index');
const THREE = require('three');

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

console.log('Slicing...');
const gcode = slicer.slice(mesh);

const lines = gcode.split('\n');
let inLayer17 = false;
let hasFillMarker = false;
let fillLineCount = 0;

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  
  if (line.includes('M117 LAYER: 17')) {
    inLayer17 = true;
  } else if (line.includes('M117 LAYER: 18')) {
    inLayer17 = false;
    break;
  }
  
  if (inLayer17) {
    if (line.includes('; TYPE: FILL')) {
      hasFillMarker = true;
      console.log(`Found ; TYPE: FILL at line ${i+1}`);
    }
    if (line.startsWith('G1') && line.includes(' E')) {
      if (hasFillMarker) {
        fillLineCount++;
      }
    }
  }
}

if (hasFillMarker) {
  console.log('❌ Layer 17 has ; TYPE: FILL marker (BUG STILL EXISTS)');
} else {
  console.log('✅ Layer 17 does NOT have ; TYPE: FILL marker (BUG FIXED)');
}

console.log(`Infill lines in layer 17: ${fillLineCount}`);
