/**
 * Example showing how to slice a 1cm cube
 * This demonstrates the main slicing functionality of Polyslice
 */

const Polyslice = require('../../src/index');
const THREE = require('three');
const fs = require('fs');
const path = require('path');

console.log('Polyslice Cube Slicing Example');
console.log('===============================\n');

// Create a 1cm cube (10mm x 10mm x 10mm).
const geometry = new THREE.BoxGeometry(10, 10, 10);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const cube = new THREE.Mesh(geometry, material);

// Position cube so the bottom is at Z=0.
cube.position.set(0, 0, 5);
cube.updateMatrixWorld();

console.log('Created 1cm cube:');
console.log(`- Dimensions: 10mm x 10mm x 10mm`);
console.log(`- Position: (${cube.position.x}, ${cube.position.y}, ${cube.position.z})`);
console.log(`- Vertices: ${geometry.attributes.position.count}`);

// Create slicer instance with optimized settings.
const slicer = new Polyslice({
  autohome: true,
  workspacePlane: 'XY',
  lengthUnit: 'millimeters',
  timeUnit: 'seconds',
  nozzleTemperature: 200,
  bedTemperature: 60,
  fanSpeed: 100,
  layerHeight: 0.2,
  nozzleDiameter: 0.4,
  filamentDiameter: 1.75,
  perimeterSpeed: 1200,
  travelSpeed: 3000
});

console.log('\nSlicer Configuration:');
console.log(`- Layer Height: ${slicer.getLayerHeight()}mm`);
console.log(`- Nozzle Temperature: ${slicer.getNozzleTemperature()}°C`);
console.log(`- Bed Temperature: ${slicer.getBedTemperature()}°C`);
console.log(`- Fan Speed: ${slicer.getFanSpeed()}%`);
console.log(`- Nozzle Diameter: ${slicer.getNozzleDiameter()}mm`);
console.log(`- Filament Diameter: ${slicer.getFilamentDiameter()}mm`);

// Slice the cube.
console.log('\nSlicing cube...');
const startTime = Date.now();
const gcode = slicer.slice(cube);
const endTime = Date.now();

console.log(`Slicing completed in ${endTime - startTime}ms`);

// Analyze the G-code.
const lines = gcode.split('\n').filter(line => line.trim() !== '');
const layerLines = lines.filter(line => line.includes('Layer'));
const moveLines = lines.filter(line => line.startsWith('G0') || line.startsWith('G1'));

console.log('\nG-code Statistics:');
console.log(`- Total lines: ${lines.length}`);
console.log(`- Layer count: ${layerLines.length}`);
console.log(`- Movement commands: ${moveLines.length}`);

// Display first 30 lines.
console.log('\nG-code Preview (first 30 lines):');
console.log('================================');
lines.slice(0, 30).forEach((line, index) => {
  console.log(`${(index + 1).toString().padStart(3, ' ')}: ${line}`);
});

if (lines.length > 30) {
  console.log(`... (${lines.length - 30} more lines)`);
}

// Save G-code to file.
const outputDir = path.join(__dirname, '../output');
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

const outputPath = path.join(outputDir, '1cm-cube.gcode');
fs.writeFileSync(outputPath, gcode);

console.log(`\n✅ G-code saved to: ${outputPath}`);

// Display some layer information.
console.log('\nLayer Information:');
const sampleLayers = layerLines.slice(0, 5);
sampleLayers.forEach(line => {
  console.log(`- ${line.trim()}`);
});
if (layerLines.length > 5) {
  console.log(`... (${layerLines.length - 5} more layers)`);
}

console.log('\n✅ Cube slicing example completed successfully!');
console.log('\nNext steps:');
console.log('- Try loading an STL/OBJ file from resources/ folder');
console.log('- Experiment with different layer heights and speeds');
console.log('- Use the generated G-code with a 3D printer or simulator');
