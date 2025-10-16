/**
 * Example showing how to slice multiple shapes with different infill patterns and densities
 * This demonstrates batch generation of G-code with various infill configurations
 */

const { Polyslice, Printer, Filament } = require('../../src/index');
const THREE = require('three');
const path = require('path');
const fs = require('fs');

console.log('Polyslice Shape Slicing Example');
console.log('================================\n');

// Create printer and filament configuration objects.
const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

console.log('Printer & Filament Configuration:');
console.log(`- Printer: ${printer.model}`);
console.log(`- Build Volume: ${printer.getSizeX()}x${printer.getSizeY()}x${printer.getSizeZ()}mm`);
console.log(`- Filament: ${filament.name} (${filament.type.toUpperCase()})`);
console.log(`- Brand: ${filament.brand}\n`);

// Configuration for batch slicing.
const infillPatterns = ['grid', 'triangles', 'hexagons'];
const densities = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

// Output directory.
const outputDir = path.join(__dirname, '../../resources/gcode/infill');
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

console.log('Batch Slicing Configuration:');
console.log(`- Infill Patterns: ${infillPatterns.join(', ')}`);
console.log(`- Density Range: ${densities[0]}% to ${densities[densities.length - 1]}%`);
console.log(`- Density Steps: ${densities.length} configurations`);
console.log(`- Total Files: ${infillPatterns.length * densities.length}`);
console.log(`- Output Directory: ${outputDir}\n`);

/**
 * Create a cube mesh for slicing.
 * @param {number} size - Size of the cube in millimeters.
 * @returns {THREE.Mesh} The cube mesh positioned at the build plate.
 */
function createCube(size = 10) {
  const geometry = new THREE.BoxGeometry(size, size, size);
  const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
  const cube = new THREE.Mesh(geometry, material);

  // Position cube so the bottom is at Z=0.
  cube.position.set(0, 0, size / 2);
  cube.updateMatrixWorld();

  return cube;
}

/**
 * Slice a shape with specified infill pattern and density.
 * @param {THREE.Mesh} mesh - The mesh to slice.
 * @param {string} pattern - Infill pattern name.
 * @param {number} density - Infill density percentage.
 * @returns {string} The generated G-code.
 */
function sliceShape(mesh, pattern, density) {
  const slicer = new Polyslice({
    printer: printer,
    filament: filament,
    shellSkinThickness: 0.8,
    shellWallThickness: 0.8,
    lengthUnit: 'millimeters',
    timeUnit: 'seconds',
    infillPattern: pattern,
    infillDensity: density,
    bedTemperature: 0,
    layerHeight: 0.2,
    testStrip: true,
    verbose: true
  });

  return slicer.slice(mesh);
}

// Batch slice all configurations.
console.log('Starting batch slicing...\n');
let totalStartTime = Date.now();
let successCount = 0;
let failCount = 0;

for (const pattern of infillPatterns) {
  console.log(`\nProcessing pattern: ${pattern}`);
  console.log('─'.repeat(50));

  for (const density of densities) {
    try {
      // Create a fresh cube for each slice.
      const cube = createCube(10);

      // Slice the cube.
      const startTime = Date.now();
      const gcode = sliceShape(cube, pattern, density);
      const endTime = Date.now();

      // Generate output filename.
      const filename = `1cm-cube_${pattern}-${density}%.gcode`;
      const outputPath = path.join(outputDir, filename);

      // Save G-code to file.
      fs.writeFileSync(outputPath, gcode);

      // Analyze the G-code.
      const lines = gcode.split('\n').filter(line => line.trim() !== '');
      const layerLines = lines.filter(line => line.includes('LAYER:'));

      console.log(`✅ ${filename.padEnd(35)} | ${(endTime - startTime).toString().padStart(4)}ms | ${lines.length.toString().padStart(5)} lines | ${layerLines.length.toString().padStart(2)} layers`);

      successCount++;
    } catch (error) {
      console.error(`❌ Failed ${pattern}-${density}%: ${error.message}`);
      failCount++;
    }
  }
}

const totalEndTime = Date.now();
const totalTime = totalEndTime - totalStartTime;

console.log('\n' + '='.repeat(50));
console.log('Batch Slicing Complete');
console.log('='.repeat(50));
console.log(`✅ Successful: ${successCount}/${infillPatterns.length * densities.length}`);
if (failCount > 0) {
  console.log(`❌ Failed: ${failCount}/${infillPatterns.length * densities.length}`);
}
console.log(`⏱️  Total Time: ${totalTime}ms (${(totalTime / 1000).toFixed(2)}s)`);
console.log(`📁 Output Directory: ${outputDir}`);

if (successCount > 0) {
  console.log('\n✅ Batch slicing completed successfully!');
  console.log('\nGenerated files can be used with:');
  console.log('- 3D printer or simulator');
  console.log('- G-code visualizer (examples/visualizer/)');
  console.log('- Analysis and testing');
}
