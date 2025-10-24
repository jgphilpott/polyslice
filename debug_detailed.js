const { Polyslice, Printer, Filament } = require('./src/index');
const THREE = require('three');
const helpers = require('./src/slicer/geometry/helpers');

const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

const geometry = new THREE.ConeGeometry(5, 10, 32);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const mesh = new THREE.Mesh(geometry, material);
mesh.rotation.x = Math.PI / 2;
mesh.position.set(0, 0, 5);
mesh.updateMatrixWorld();

// Monkey-patch createInsetPath to add logging.
const originalCreateInsetPath = helpers.createInsetPath;
let callCount = 0;

helpers.createInsetPath = function(path, insetDistance, isHole = false) {
  callCount++;
  
  // Calculate bounding box of input path.
  let minX = Infinity, maxX = -Infinity;
  let minY = Infinity, maxY = -Infinity;
  
  for (const point of path) {
    minX = Math.min(minX, point.x);
    maxX = Math.max(maxX, point.x);
    minY = Math.min(minY, point.y);
    maxY = Math.max(maxY, point.y);
  }
  
  const width = maxX - minX;
  const height = maxY - minY;
  const z = path[0] ? path[0].z : 'unknown';
  
  const result = originalCreateInsetPath.call(this, path, insetDistance, isHole);
  
  console.log(`createInsetPath call #${callCount}:`);
  console.log(`  Z=${z}, insetDistance=${insetDistance.toFixed(3)}, isHole=${isHole}`);
  console.log(`  Input: ${path.length} points, width=${width.toFixed(3)}, height=${height.toFixed(3)}`);
  console.log(`  Output: ${result.length} points`);
  
  if (result.length >= 3) {
    let minX2 = Infinity, maxX2 = -Infinity;
    let minY2 = Infinity, maxY2 = -Infinity;
    
    for (const point of result) {
      minX2 = Math.min(minX2, point.x);
      maxX2 = Math.max(maxX2, point.x);
      minY2 = Math.min(minY2, point.y);
      maxY2 = Math.max(maxY2, point.y);
    }
    
    const width2 = maxX2 - minX2;
    const height2 = maxY2 - minY2;
    console.log(`  Output width=${width2.toFixed(3)}, height=${height2.toFixed(3)}`);
    console.log(`  Reduction: width=${(width - width2).toFixed(3)}, height=${(height - height2).toFixed(3)}`);
  } else {
    console.log(`  ❌ FAILED: returned empty array`);
  }
  
  // Only log for layer 17 (Z around 3.4).
  if (z >= 3.35 && z <= 3.45) {
    console.log(`  >>> This is layer 17! <<<`);
  }
  
  return result;
};

const slicer = new Polyslice({
  printer: printer,
  filament: filament,
  shellSkinThickness: 0.8,
  shellWallThickness: 0.8,
  infillPattern: 'grid',
  infillDensity: 10,
  layerHeight: 0.2,
  verbose: false  // Disable verbose to reduce output
});

console.log('Starting slice...\n');
const gcode = slicer.slice(mesh);

console.log('\n--- Checking layer 17 in output ---');
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
    }
    if (line.startsWith('G1') && line.includes(' E')) {
      if (hasFillMarker) {
        fillLineCount++;
      }
    }
  }
}

if (hasFillMarker) {
  console.log('❌ Layer 17 has ; TYPE: FILL marker');
} else {
  console.log('✅ Layer 17 does NOT have ; TYPE: FILL marker');
}

console.log(`Infill lines in layer 17: ${fillLineCount}`);
