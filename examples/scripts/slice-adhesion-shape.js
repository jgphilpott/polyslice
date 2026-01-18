/**
 * Slice script for shape skirt adhesion examples
 *
 * This script slices cube and cylinder geometries with shape skirt enabled
 * and saves the G-code to resources/gcode/adhesion for comparison.
 */

const { Polyslice, Loader } = require('../../src/index');
const path = require('path');
const fs = require('fs');

console.log('Slicing Shape Skirt Adhesion Examples');
console.log('======================================\n');

// Configuration for all slicing operations
const slicerConfig = {
  // Adhesion settings - shape skirt
  adhesionEnabled: true,
  adhesionType: 'skirt',
  adhesionSkirtType: 'shape',
  adhesionDistance: 5,
  adhesionLineCount: 3,

  // Basic slicing settings
  layerHeight: 0.2,
  nozzleDiameter: 0.4,
  shellWallThickness: 0.8,
  shellSkinThickness: 0.8,
  infillDensity: 20,
  infillPattern: 'grid',

  // Print settings
  nozzleTemperature: 200,
  bedTemperature: 60,
  fanSpeed: 100,

  // G-code settings
  verbose: true,
  metadata: false
};

// Define the geometries to slice
const geometries = [
  { name: 'Cube (Shape Skirt)', file: 'cube/cube-1cm.stl', output: 'cube-shape-skirt.gcode' },
  { name: 'Cylinder (Shape Skirt)', file: 'cylinder/cylinder-1cm.stl', output: 'cylinder-shape-skirt.gcode' }
];

// Create output directory
const outputDir = path.join(__dirname, '../../resources/gcode/adhesion');
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

console.log(`Output directory: ${outputDir}\n`);

// Process geometries with async/await
async function processGeometries() {
  for (let index = 0; index < geometries.length; index++) {
    const geometry = geometries[index];
    console.log(`[${index + 1}/${geometries.length}] Slicing ${geometry.name}...`);

    try {
      // Build the full path to the STL file
      const stlPath = path.join(__dirname, '../../resources/stl', geometry.file);

      if (!fs.existsSync(stlPath)) {
        console.error(`  ✗ Error: File not found: ${stlPath}\n`);
        continue;
      }

      // Load the STL file (async)
      const mesh = await Loader.loadSTL(stlPath);

      if (!mesh) {
        console.error(`  ✗ Error: Failed to load mesh\n`);
        continue;
      }

      // Create slicer instance
      const slicer = new Polyslice(slicerConfig);

      // Generate G-code
      const startTime = Date.now();
      const gcode = slicer.slice(mesh);
      const endTime = Date.now();
      const slicingTime = ((endTime - startTime) / 1000).toFixed(2);

      // Write output file
      const outputPath = path.join(outputDir, geometry.output);
      fs.writeFileSync(outputPath, gcode);

      const fileSizeKB = (gcode.length / 1024).toFixed(2);
      console.log(`  ✓ ${geometry.output} (${fileSizeKB} KB) - ${slicingTime}s\n`);

    } catch (error) {
      console.error(`  ✗ Error processing ${geometry.name}:`, error.message);
      console.log('');
    }
  }

  console.log('Shape skirt adhesion examples sliced successfully!');
}

// Run the async process
processGeometries().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
