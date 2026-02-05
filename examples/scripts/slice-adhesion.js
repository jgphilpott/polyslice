/**
 * Slice script for adhesion examples
 *
 * This script slices cube and cylinder geometries with different adhesion types
 * and saves the G-code to resources/gcode/adhesion subdirectories for version control.
 */

const { Polyslice, Loader } = require('../../src/index');
const path = require('path');
const fs = require('fs');

console.log('Slicing Adhesion Examples');
console.log('=========================\n');

// Base configuration for all slicing operations
const baseSlicerConfig = {
  // Adhesion settings (will be overridden per variant)
  adhesionEnabled: true,
  adhesionType: 'skirt',
  skirtDistance: 5,
  skirtLineCount: 3,

  // Basic slicing settings
  layerHeight: 0.2,
  nozzleDiameter: 0.4,
  shellWallThickness: 0.8,
  shellSkinThickness: 0.8,
  infillDensity: 20,
  infillPattern: 'grid',
  infillPatternCentering: 'object',

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
  { name: 'Cube', file: 'cube/cube-1cm.stl' },
  { name: 'Cylinder', file: 'cylinder/cylinder-1cm.stl' }
];

// Define adhesion variants to generate
const adhesionVariants = [
  {
    name: 'Circular Skirt',
    config: { adhesionType: 'skirt', skirtType: 'circular' },
    outputSubdir: 'skirt/circular'
  },
  {
    name: 'Shape Skirt',
    config: { adhesionType: 'skirt', skirtType: 'shape' },
    outputSubdir: 'skirt/shape'
  },
  {
    name: 'Brim',
    config: { adhesionType: 'brim' },
    outputSubdir: 'brim'
  },
  {
    name: 'Raft',
    config: { adhesionType: 'raft' },
    outputSubdir: 'raft'
  }
];

// Base output directory
const baseOutputDir = path.join(__dirname, '../../resources/gcode/adhesion');

// Process geometries with async/await
async function processGeometries() {
  let totalCount = 0;
  const totalVariants = geometries.length * adhesionVariants.length;

  for (const variant of adhesionVariants) {
    console.log(`\n${variant.name}`);
    console.log('─'.repeat(variant.name.length));

    // Create output directory for this variant
    const outputDir = path.join(baseOutputDir, variant.outputSubdir);
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    for (const geometry of geometries) {
      totalCount++;
      console.log(`[${totalCount}/${totalVariants}] Slicing ${geometry.name}...`);

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

        // Ensure the cylinder stands upright (STL sources can differ in orientation).
        // Rotate 90° about X so the cylinder's axis aligns with Z.
        if (geometry.name === 'Cylinder') {
          mesh.rotation.x = Math.PI / 2;
          mesh.updateMatrixWorld(true);
        }

        // Create slicer instance with variant-specific config
        const slicerConfig = { ...baseSlicerConfig, ...variant.config };
        const slicer = new Polyslice(slicerConfig);

        // Generate G-code
        const startTime = Date.now();
        const gcode = slicer.slice(mesh);
        const endTime = Date.now();
        const slicingTime = ((endTime - startTime) / 1000).toFixed(2);

        // Write output file
        const outputFilename = `${geometry.name.toLowerCase()}.gcode`;
        const outputPath = path.join(outputDir, outputFilename);
        fs.writeFileSync(outputPath, gcode);

        const fileSizeKB = (gcode.length / 1024).toFixed(2);
        console.log(`  ✓ ${outputFilename} (${fileSizeKB} KB) - ${slicingTime}s`);

      } catch (error) {
        console.error(`  ✗ Error processing ${geometry.name}:`, error.message);
      }
    }
  }

  console.log('\nAdhesion examples sliced successfully!');
}

// Run the async process
processGeometries().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
