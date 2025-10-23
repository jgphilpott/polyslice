const { Polyslice, Printer, Filament } = require('./src/index');
const THREE = require('three');

// Create the exact same torus as in slice-shapes.js
function createTorus(radius = 5, tube = 2) {
  const geometry = new THREE.TorusGeometry(radius, tube, 16, 32);
  const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
  const mesh = new THREE.Mesh(geometry, material);

  // Position torus so the bottom is at Z=0.
  mesh.position.set(0, 0, tube);
  mesh.updateMatrixWorld();

  return mesh;
}

const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

const mesh = createTorus(5, 2);

const slicer = new Polyslice({
  printer: printer,
  filament: filament,
  shellSkinThickness: 0.8,
  shellWallThickness: 0.8,
  lengthUnit: 'millimeters',
  timeUnit: 'seconds',
  infillPattern: 'grid',
  infillDensity: 50,
  bedTemperature: 0,
  layerHeight: 0.2,
  wipeNozzle: false,
  testStrip: true,
  metadata: false,
  verbose: true
});

const gcode = slicer.slice(mesh);

// Find Layer 10
const lines = gcode.split('\n');
let layer10Start = -1;
let layer11Start = -1;

for (let i = 0; i < lines.length; i++) {
    if (lines[i].includes('LAYER: 10')) {
        layer10Start = i;
    }
    if (lines[i].includes('LAYER: 11')) {
        layer11Start = i;
        break;
    }
}

if (layer10Start >= 0 && layer11Start >= 0) {
    const layer10Content = lines.slice(layer10Start, layer11Start).join('\n');
    
    const xCoords = [];
    const yCoords = [];
    const g1Regex = /G1 X([\d.]+) Y([\d.]+)/g;
    let match;
    while ((match = g1Regex.exec(layer10Content)) !== null) {
        xCoords.push(parseFloat(match[1]));
        yCoords.push(parseFloat(match[2]));
    }
    
    if (xCoords.length > 0) {
        const minX = Math.min(...xCoords);
        const maxX = Math.max(...xCoords);
        const minY = Math.min(...yCoords);
        const maxY = Math.max(...yCoords);
        const width = maxX - minX;
        const height = maxY - minY;
        
        const zMatch = layer10Content.match(/Z([\d.]+)/);
        const z = zMatch ? parseFloat(zMatch[1]) : 'N/A';
        
        const wallOuterCount = (layer10Content.match(/; TYPE: WALL-OUTER/g) || []).length;
        
        console.log(`Layer 10 at Z=${z}:`);
        console.log(`  X range: ${minX.toFixed(2)} to ${maxX.toFixed(2)} (width: ${width.toFixed(2)}mm)`);
        console.log(`  Y range: ${minY.toFixed(2)} to ${maxY.toFixed(2)} (height: ${height.toFixed(2)}mm)`);
        console.log(`  Wall outer count: ${wallOuterCount}`);
        
        if (width < 10 && wallOuterCount < 2) {
            console.log(`\n❌ BUG CONFIRMED: Layer 10 only prints the hole!`);
        } else {
            console.log(`\n✓ Layer 10 appears correct`);
        }
    }
}
