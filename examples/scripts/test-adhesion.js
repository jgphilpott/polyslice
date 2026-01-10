/**
 * Example demonstrating the adhesion (skirt) feature with five different geometries
 * 
 * This script slices each of the five example STL files from resources/stl:
 * - Cube (10mm)
 * - Cone (10mm)
 * - Cylinder (10mm)
 * - Sphere (10mm)
 * - Torus (10mm)
 * 
 * Each geometry is sliced with adhesion (skirt) enabled to demonstrate
 * the build plate adhesion feature.
 */

const { Polyslice, Loader } = require('../../src/index');
const path = require('path');
const fs = require('fs');

console.log('Polyslice Adhesion Feature Demonstration');
console.log('=========================================\n');

// Configuration for all slicing operations
const slicerConfig = {
  // Adhesion settings - the feature being demonstrated
  adhesionEnabled: true,
  adhesionType: 'skirt',
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
  metadata: true
};

console.log('Adhesion Configuration:');
console.log(`- Adhesion Type: ${slicerConfig.adhesionType}`);
console.log(`- Distance from Model: ${slicerConfig.adhesionDistance}mm`);
console.log(`- Number of Loops: ${slicerConfig.adhesionLineCount}`);
console.log(`- Layer Height: ${slicerConfig.layerHeight}mm`);
console.log(`- Infill Density: ${slicerConfig.infillDensity}%\n`);

// Define the geometries to slice
const geometries = [
  { name: 'Cube', file: 'cube/cube-1cm.stl' },
  { name: 'Cone', file: 'cone/cone-1cm.stl' },
  { name: 'Cylinder', file: 'cylinder/cylinder-1cm.stl' },
  { name: 'Sphere', file: 'sphere/sphere-1cm.stl' },
  { name: 'Torus', file: 'torus/torus-1cm.stl' }
];

// Create output directory
const outputDir = path.join(__dirname, '../../output/adhesion-examples');
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

console.log(`Output directory: ${outputDir}\n`);
console.log('='.repeat(60));
console.log('\n');

// Process geometries with async/await
async function processGeometries() {
  for (let index = 0; index < geometries.length; index++) {
    const geometry = geometries[index];
    console.log(`[${index + 1}/${geometries.length}] Processing ${geometry.name}...`);
    console.log('-'.repeat(60));
    
    try {
      // Build the full path to the STL file
      const stlPath = path.join(__dirname, '../../resources/stl', geometry.file);
      
      if (!fs.existsSync(stlPath)) {
        console.error(`  ✗ Error: File not found: ${stlPath}\n`);
        continue;
      }
      
      console.log(`  - Loading: ${geometry.file}`);
      
      // Load the STL file (async)
      const mesh = await Loader.loadSTL(stlPath);
      
      if (!mesh) {
        console.error(`  ✗ Error: Failed to load mesh\n`);
        continue;
      }
      
      console.log(`  - Mesh loaded successfully`);
      console.log(`  - Vertices: ${mesh.geometry.attributes.position.count}`);
    
    // Create slicer instance
    const slicer = new Polyslice(slicerConfig);
    
    console.log(`  - Slicing with adhesion enabled...`);
    
    // Generate G-code
    const startTime = Date.now();
    const gcode = slicer.slice(mesh);
    const endTime = Date.now();
    const slicingTime = ((endTime - startTime) / 1000).toFixed(2);
    
    // Analyze the G-code
    const lines = gcode.split('\n');
    const totalLines = lines.length;
    const hasSkirt = gcode.includes('TYPE: SKIRT');
    
    // Extract skirt section
    const skirtStartIdx = lines.findIndex(line => line.includes('TYPE: SKIRT'));
    const nextTypeIdx = lines.findIndex((line, idx) => 
      idx > skirtStartIdx && line.includes('TYPE:') && !line.includes('TYPE: SKIRT')
    );
    const layerStartIdx = lines.findIndex((line, idx) => 
      idx > skirtStartIdx && line.includes('LAYER:')
    );
    
    const skirtEndIdx = nextTypeIdx > 0 ? nextTypeIdx : layerStartIdx;
    const skirtLines = skirtEndIdx > skirtStartIdx ? skirtEndIdx - skirtStartIdx : 0;
    
    // Count extrusion moves in skirt
    let skirtMoves = 0;
    if (skirtStartIdx >= 0 && skirtEndIdx > skirtStartIdx) {
      const skirtSection = lines.slice(skirtStartIdx, skirtEndIdx).join('\n');
      skirtMoves = (skirtSection.match(/G1.*E\d/g) || []).length;
    }
    
    console.log(`  - Slicing completed in ${slicingTime}s`);
    console.log(`  - Total G-code lines: ${totalLines}`);
    console.log(`  - Skirt present: ${hasSkirt ? '✓' : '✗'}`);
    console.log(`  - Skirt lines: ${skirtLines}`);
    console.log(`  - Skirt extrusion moves: ${skirtMoves}`);
    
    // Write output file
    const outputFilename = `${geometry.name.toLowerCase()}-with-skirt.gcode`;
    const outputPath = path.join(outputDir, outputFilename);
    fs.writeFileSync(outputPath, gcode);
    
    const fileSizeKB = (gcode.length / 1024).toFixed(2);
    console.log(`  - Output saved: ${outputFilename} (${fileSizeKB} KB)`);
    
    // Show preview of skirt section
    if (skirtStartIdx >= 0 && skirtLines > 0) {
      console.log(`  - Skirt preview (first 5 lines):`);
      const previewLines = lines.slice(skirtStartIdx, Math.min(skirtStartIdx + 6, skirtEndIdx));
      previewLines.forEach(line => {
        if (line.trim()) {
          console.log(`    ${line}`);
        }
      });
    }
    
      console.log(`  ✓ ${geometry.name} completed successfully\n`);
      
    } catch (error) {
      console.error(`  ✗ Error processing ${geometry.name}:`, error.message);
      console.error(error.stack);
      console.log('');
    }
  }

  console.log('='.repeat(60));
  console.log('\nAdhesion Feature Demonstration Complete!\n');

  console.log('Summary:');
  console.log(`- Geometries processed: ${geometries.length}`);
  console.log(`- Output directory: ${outputDir}`);
  console.log(`- Adhesion type: ${slicerConfig.adhesionType}`);
  console.log(`- Distance: ${slicerConfig.adhesionDistance}mm`);
  console.log(`- Loop count: ${slicerConfig.adhesionLineCount}`);

  console.log('\nGenerated files:');
  geometries.forEach(geometry => {
    const filename = `${geometry.name.toLowerCase()}-with-skirt.gcode`;
    const filepath = path.join(outputDir, filename);
    if (fs.existsSync(filepath)) {
      const stats = fs.statSync(filepath);
      const sizeKB = (stats.size / 1024).toFixed(2);
      console.log(`  ✓ ${filename} (${sizeKB} KB)`);
    }
  });

  console.log('\nYou can inspect the generated G-code files to see the skirt');
  console.log('adhesion feature in action. Look for "; TYPE: SKIRT" comments.');
}

// Run the async process
processGeometries().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
