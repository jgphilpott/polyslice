/**
 * Quick test script to verify Lightning infill pattern generation
 */

const { Polyslice, Printer, Filament } = require('../../src/index');
const THREE = require('three');
const fs = require('fs');
const path = require('path');

console.log('Testing Lightning Infill Pattern...\n');

// Create a simple cube
function createCube(size = 10) {
  const geometry = new THREE.BoxGeometry(size, size, size);
  const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
  const mesh = new THREE.Mesh(geometry, material);
  mesh.position.set(0, 0, size / 2);
  mesh.updateMatrixWorld();
  return mesh;
}

// Create printer and filament
const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

console.log(`Printer: ${printer.model}`);
console.log(`Filament: ${filament.name}\n`);

// Test lightning pattern at 20% density
const slicer = new Polyslice({
  printer: printer,
  filament: filament,
  shellSkinThickness: 0.8,
  shellWallThickness: 0.8,
  lengthUnit: 'millimeters',
  timeUnit: 'seconds',
  infillPattern: 'lightning',
  infillDensity: 20,
  bedTemperature: 0,
  layerHeight: 0.2,
  wipeNozzle: false,
  testStrip: false,
  metadata: false,
  verbose: true
});

console.log('Slicing 10mm cube with Lightning infill (20% density)...');
const mesh = createCube(10);
const startTime = Date.now();
const gcode = slicer.slice(mesh);
const endTime = Date.now();

// Analyze the G-code
const lines = gcode.split('\n').filter(line => line.trim() !== '');
const fillLines = lines.filter(line => line.includes('; TYPE: FILL'));
const extrusionLines = lines.filter(line => line.includes('G1') && line.includes('E'));

console.log(`\nSlicing completed in ${endTime - startTime}ms`);
console.log(`Total lines: ${lines.length}`);
console.log(`FILL sections: ${fillLines.length}`);
console.log(`Extrusion moves: ${extrusionLines.length}`);

// Save to file
const outputDir = path.join(__dirname, '../../resources/gcode/test');
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}
const outputPath = path.join(outputDir, 'lightning-test-cube.gcode');
fs.writeFileSync(outputPath, gcode);

console.log(`\nG-code saved to: ${outputPath}`);
console.log('File size:', (gcode.length / 1024).toFixed(2), 'KB');

// Show a sample of the lightning infill section
const fillStartIdx = lines.findIndex(line => line.includes('; TYPE: FILL'));
if (fillStartIdx !== -1) {
  console.log('\nSample of Lightning infill G-code:');
  console.log('-----------------------------------');
  for (let i = fillStartIdx; i < Math.min(fillStartIdx + 10, lines.length); i++) {
    console.log(lines[i]);
  }
  console.log('...');
}

console.log('\n✅ Lightning infill pattern test completed successfully!');
