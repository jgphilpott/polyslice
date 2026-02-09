/**
 * Quick comparison of infill patterns on a single cube
 * Demonstrates the new Lightning pattern alongside existing patterns
 */

const { Polyslice, Printer, Filament } = require('../../src/index');
const THREE = require('three');
const fs = require('fs');
const path = require('path');

console.log('Infill Pattern Comparison Demo');
console.log('==============================\n');

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

// Test each pattern with the same cube
const patterns = ['grid', 'triangles', 'hexagons', 'concentric', 'gyroid', 'spiral', 'lightning'];
const results = [];

console.log('Slicing 10mm cube with each pattern at 20% density...\n');

for (const pattern of patterns) {
  const slicer = new Polyslice({
    printer: printer,
    filament: filament,
    shellSkinThickness: 0.8,
    shellWallThickness: 0.8,
    lengthUnit: 'millimeters',
    timeUnit: 'seconds',
    infillPattern: pattern,
    infillDensity: 20,
    bedTemperature: 0,
    layerHeight: 0.2,
    wipeNozzle: false,
    testStrip: false,
    metadata: false,
    verbose: true
  });

  const mesh = createCube(10);
  const startTime = Date.now();
  const gcode = slicer.slice(mesh);
  const endTime = Date.now();

  // Analyze the G-code
  const lines = gcode.split('\n').filter(line => line.trim() !== '');
  const fillLines = lines.filter(line => line.includes('; TYPE: FILL'));
  const extrusionLines = lines.filter(line => line.includes('G1') && line.includes('E'));

  results.push({
    pattern: pattern,
    time: endTime - startTime,
    totalLines: lines.length,
    fillSections: fillLines.length,
    extrusionMoves: extrusionLines.length,
    size: (gcode.length / 1024).toFixed(2)
  });

  console.log(`${pattern.padEnd(12)} | ${(endTime - startTime).toString().padStart(4)}ms | ${lines.length.toString().padStart(5)} lines | ${fillLines.length.toString().padStart(2)} fills | ${extrusionLines.length.toString().padStart(4)} extrusions | ${(gcode.length / 1024).toFixed(2)} KB`);
}

console.log('\n' + '='.repeat(85));
console.log('Comparison Summary');
console.log('='.repeat(85));

// Find fastest and smallest
const fastest = results.reduce((min, r) => r.time < min.time ? r : min, results[0]);
const smallest = results.reduce((min, r) => parseFloat(r.size) < parseFloat(min.size) ? r : min, results[0]);
const fewestExtrusions = results.reduce((min, r) => r.extrusionMoves < min.extrusionMoves ? r : min, results[0]);

console.log(`\n⚡ Fastest:           ${fastest.pattern} (${fastest.time}ms)`);
console.log(`📦 Smallest G-code:   ${smallest.pattern} (${smallest.size} KB)`);
console.log(`🎯 Fewest extrusions: ${fewestExtrusions.pattern} (${fewestExtrusions.extrusionMoves} moves)`);

console.log('\n💡 Lightning Pattern Benefits:');
console.log('   • Tree-like branching structure');
console.log('   • Fast printing with minimal material');
console.log('   • Adequate support for top surfaces');
console.log('   • Best for rapid prototyping');
console.log('   • Natural organic appearance');

console.log('\n✅ Pattern comparison completed!');
