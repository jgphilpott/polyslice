const helpers = require('./src/slicer/geometry/helpers');

// Create a circular boundary at layer 17 (Z=3.4, radius after walls and infill gap = 2.3mm)
const radius = 2.3;
const segments = 32;
const infillBoundary = [];

for (let i = 0; i < segments; i++) {
  const angle = (i / segments) * 2 * Math.PI;
  infillBoundary.push({
    x: radius * Math.cos(angle),
    y: radius * Math.sin(angle),
    z: 3.4
  });
}

console.log('Infill boundary:');
console.log('- Radius:', radius, 'mm');
console.log('- Diameter:', radius * 2, 'mm');

// Calculate bounding box
let minX = Infinity, maxX = -Infinity;
let minY = Infinity, maxY = -Infinity;

for (const point of infillBoundary) {
  minX = Math.min(minX, point.x);
  maxX = Math.max(maxX, point.x);
  minY = Math.min(minY, point.y);
  maxY = Math.max(maxY, point.y);
}

const width = maxX - minX;
const height = maxY - minY;
const diagonalSpan = Math.sqrt(width * width + height * height);

console.log('- Width:', width.toFixed(3), 'mm');
console.log('- Height:', height.toFixed(3), 'mm');
console.log('- Diagonal span:', diagonalSpan.toFixed(3), 'mm');

// Grid pattern with 10% density
const nozzleDiameter = 0.4;
const infillDensity = 10;
const baseSpacing = nozzleDiameter / (infillDensity / 100);
const lineSpacing = baseSpacing * 2; // Grid pattern multiplier

console.log('\nInfill parameters:');
console.log('- Density:', infillDensity, '%');
console.log('- Base spacing:', baseSpacing, 'mm');
console.log('- Line spacing:', lineSpacing, 'mm');
console.log('- Line spacing * sqrt(2):', (lineSpacing * Math.sqrt(2)).toFixed(3), 'mm');

// Calculate how many lines should fit
const numLinesUp = Math.ceil(diagonalSpan / (lineSpacing * Math.sqrt(2)));
console.log('- Expected number of lines:', numLinesUp);

// Test line clipping with a +45° line through center (offset = 0)
const centerLine = {
  start: { x: -diagonalSpan / 2, y: -diagonalSpan / 2 },
  end: { x: diagonalSpan / 2, y: diagonalSpan / 2 }
};

console.log('\nTesting center line (+45° through origin):');
console.log('- Line: (', centerLine.start.x.toFixed(2), ',', centerLine.start.y.toFixed(2), ') to (', centerLine.end.x.toFixed(2), ',', centerLine.end.y.toFixed(2), ')');

const clippedSegments = helpers.clipLineWithHoles(centerLine.start, centerLine.end, infillBoundary, []);
console.log('- Clipped segments:', clippedSegments.length);

if (clippedSegments.length > 0) {
  for (let i = 0; i < clippedSegments.length; i++) {
    const seg = clippedSegments[i];
    console.log(`  Segment ${i+1}: (${seg.start.x.toFixed(2)}, ${seg.start.y.toFixed(2)}) to (${seg.end.x.toFixed(2)}, ${seg.end.y.toFixed(2)})`);
    const dx = seg.end.x - seg.start.x;
    const dy = seg.end.y - seg.start.y;
    const length = Math.sqrt(dx * dx + dy * dy);
    console.log(`    Length: ${length.toFixed(3)} mm`);
  }
} else {
  console.log('  ❌ NO segments returned - line was completely clipped away!');
}
