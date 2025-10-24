const helpers = require('./src/slicer/geometry/helpers');

// Simulate a circular path (approximating a cone slice at Z=3.4).
const radiusAtZ = 3.3; // mm
const segments = 32;
const boundaryPath = [];

for (let i = 0; i < segments; i++) {
  const angle = (i / segments) * 2 * Math.PI;
  boundaryPath.push({
    x: radiusAtZ * Math.cos(angle),
    y: radiusAtZ * Math.sin(angle),
    z: 3.4
  });
}

console.log('Original boundary path:');
console.log('- Radius:', radiusAtZ, 'mm');
console.log('- Points:', boundaryPath.length);

// Calculate bounding box.
let minX = Infinity, maxX = -Infinity;
let minY = Infinity, maxY = -Infinity;

for (const point of boundaryPath) {
  minX = Math.min(minX, point.x);
  maxX = Math.max(maxX, point.x);
  minY = Math.min(minY, point.y);
  maxY = Math.max(maxY, point.y);
}

console.log('- Width:', maxX - minX, 'mm');
console.log('- Height:', maxY - minY, 'mm');

// Test wall inset.
const nozzleDiameter = 0.4;
const wallCount = 2;
const wallInset = wallCount * nozzleDiameter;
console.log('\n--- Testing wall inset (', wallInset, 'mm) ---');

const wallInsetPath = helpers.createInsetPath(boundaryPath, wallInset);
console.log('Wall inset result:');
console.log('- Points:', wallInsetPath.length);

if (wallInsetPath.length >= 3) {
  let minX2 = Infinity, maxX2 = -Infinity;
  let minY2 = Infinity, maxY2 = -Infinity;
  
  for (const point of wallInsetPath) {
    minX2 = Math.min(minX2, point.x);
    maxX2 = Math.max(maxX2, point.x);
    minY2 = Math.min(minY2, point.y);
    maxY2 = Math.max(maxY2, point.y);
  }
  
  console.log('- Width:', maxX2 - minX2, 'mm');
  console.log('- Height:', maxY2 - minY2, 'mm');
  console.log('- Width reduction:', (maxX - minX) - (maxX2 - minX2), 'mm');
  console.log('- Height reduction:', (maxY - minY) - (maxY2 - minY2), 'mm');
}

// Test infill inset.
const infillInset = wallInset + nozzleDiameter / 2;
console.log('\n--- Testing infill inset (', infillInset, 'mm) ---');

const infillInsetPath = helpers.createInsetPath(boundaryPath, infillInset);
console.log('Infill inset result:');
console.log('- Points:', infillInsetPath.length);

if (infillInsetPath.length >= 3) {
  let minX3 = Infinity, maxX3 = -Infinity;
  let minY3 = Infinity, maxY3 = -Infinity;
  
  for (const point of infillInsetPath) {
    minX3 = Math.min(minX3, point.x);
    maxX3 = Math.max(maxX3, point.x);
    minY3 = Math.min(minY3, point.y);
    maxY3 = Math.max(maxY3, point.y);
  }
  
  console.log('- Width:', maxX3 - minX3, 'mm');
  console.log('- Height:', maxY3 - minY3, 'mm');
  console.log('- Width reduction:', (maxX - minX) - (maxX3 - minX3), 'mm');
  console.log('- Height reduction:', (maxY - minY) - (maxY3 - minY3), 'mm');
  
  // Check validation thresholds.
  const expectedSizeChange = infillInset * 2 * 0.1;
  console.log('\n- Expected size change threshold:', expectedSizeChange, 'mm');
  
  const widthReduction = (maxX - minX) - (maxX3 - minX3);
  const heightReduction = (maxY - minY) - (maxY3 - minY3);
  
  if (widthReduction < expectedSizeChange) {
    console.log('❌ Width reduction FAILED threshold check');
  } else {
    console.log('✅ Width reduction passed threshold check');
  }
  
  if (heightReduction < expectedSizeChange) {
    console.log('❌ Height reduction FAILED threshold check');
  } else {
    console.log('✅ Height reduction passed threshold check');
  }
} else {
  console.log('❌ Infill inset path is empty or invalid!');
}
