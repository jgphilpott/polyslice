const helpers = require('./src/slicer/geometry/helpers');

// Use the actual infill boundary from layer 17
const infillBoundaryWidth = 4.992;
const infillBoundaryHeight = 4.992;
const diagonalSpan = Math.sqrt(infillBoundaryWidth * infillBoundaryWidth + infillBoundaryHeight * infillBoundaryHeight);

console.log('Actual infill boundary from layer 17:');
console.log('- Width:', infillBoundaryWidth, 'mm');
console.log('- Height:', infillBoundaryHeight, 'mm');
console.log('- Diagonal span:', diagonalSpan.toFixed(3), 'mm');

// Grid pattern with 10% density
const nozzleDiameter = 0.4;
const infillDensity = 10;
const baseSpacing = nozzleDiameter / (infillDensity / 100);
const lineSpacing = baseSpacing * 2;

console.log('\nInfill parameters:');
console.log('- Line spacing:', lineSpacing, 'mm');
console.log('- Line spacing * sqrt(2):', (lineSpacing * Math.sqrt(2)).toFixed(3), 'mm');

// Calculate line offsets
const centerOffset = 0;
const numLinesUp = Math.ceil(diagonalSpan / (lineSpacing * Math.sqrt(2)));

console.log('- Number of lines in each direction:', numLinesUp);

let offset = centerOffset - numLinesUp * lineSpacing * Math.sqrt(2);
const maxOffset = centerOffset + numLinesUp * lineSpacing * Math.sqrt(2);

console.log('- Offset range:', offset.toFixed(3), 'to', maxOffset.toFixed(3), 'mm');
console.log('- Step size:', (lineSpacing * Math.sqrt(2)).toFixed(3), 'mm');

console.log('\n+45° line offsets:');
let lineCount = 0;
while (offset < maxOffset) {
  lineCount++;
  console.log(`  Line ${lineCount}: offset = ${offset.toFixed(3)} mm`);
  offset += lineSpacing * Math.sqrt(2);
}

console.log('\nExpected infill lines:', lineCount * 2, '(+45° and -45° combined)');
