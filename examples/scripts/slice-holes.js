/**
 * Example showing how to slice sheets with holes punched in them
 * This demonstrates the slicer's ability to handle complex geometries with internal voids
 * using CSG (Constructive Solid Geometry) operations to create holes in a thin sheet
 */

const { Polyslice, Printer, Filament } = require('../../src/index');
const THREE = require('three');
const { Brush, Evaluator, SUBTRACTION } = require('three-bvh-csg');
const path = require('path');
const fs = require('fs');

console.log('Polyslice Hole Slicing Example');
console.log('==============================\n');

// Create printer and filament configuration objects.
const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

console.log('Printer & Filament Configuration:');
console.log(`- Printer: ${printer.model}`);
console.log(`- Build Volume: ${printer.getSizeX()}x${printer.getSizeY()}x${printer.getSizeZ()}mm`);
console.log(`- Filament: ${filament.name} (${filament.type.toUpperCase()})`);
console.log(`- Brand: ${filament.brand}\n`);

// Base output directory.
const outputDir = path.join(__dirname, '../output');

// Ensure output directory exists.
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
  console.log(`Created output directory: ${outputDir}\n`);
}

/**
 * Create a thin sheet (box) with holes punched in it using CSG.
 * @param {number} width - Width of the sheet in millimeters.
 * @param {number} height - Height of the sheet in millimeters.
 * @param {number} thickness - Thickness of the sheet in millimeters.
 * @param {number} holeRadius - Radius of each hole in millimeters.
 * @param {number} gridSize - Size of the hole grid (e.g., 2 for 2x2, 3 for 3x3).
 * @returns {THREE.Mesh} The sheet mesh with holes positioned at the build plate.
 */
function createSheetWithHoles(width = 50, height = 50, thickness = 2, holeRadius = 3, gridSize = 1) {
  // Create the base sheet geometry.
  const sheetGeometry = new THREE.BoxGeometry(width, height, thickness);
  const sheetMesh = new THREE.Mesh(sheetGeometry);

  // Convert sheet to CSG brush.
  const sheetBrush = new Brush(sheetGeometry);
  sheetBrush.updateMatrixWorld();

  // Create CSG evaluator.
  const csgEvaluator = new Evaluator();

  // Calculate spacing between holes.
  const spacing = Math.min(width, height) / (gridSize + 1);

  // Calculate offset to center the grid.
  const offsetX = -width / 2 + spacing;
  const offsetY = -height / 2 + spacing;

  // Create hole cylinders and subtract them from the sheet.
  let resultBrush = sheetBrush;

  for (let row = 0; row < gridSize; row++) {
    for (let col = 0; col < gridSize; col++) {
      // Calculate hole position.
      const x = offsetX + col * spacing;
      const y = offsetY + row * spacing;

      // Create cylinder for hole (taller than sheet to ensure complete penetration).
      const holeGeometry = new THREE.CylinderGeometry(
        holeRadius,
        holeRadius,
        thickness * 2,
        32
      );

      // Rotate cylinder to align with Z-axis (sheets are in XY plane).
      const holeMesh = new Brush(holeGeometry);
      holeMesh.rotation.x = Math.PI / 2;
      holeMesh.position.set(x, y, 0);
      holeMesh.updateMatrixWorld();

      // Subtract hole from sheet.
      resultBrush = csgEvaluator.evaluate(resultBrush, holeMesh, SUBTRACTION);
    }
  }

  // Create final mesh from CSG result.
  const finalMesh = new THREE.Mesh(resultBrush.geometry, new THREE.MeshBasicMaterial());

  // Position sheet so bottom is at Z=0.
  finalMesh.position.set(0, 0, thickness / 2);
  finalMesh.updateMatrixWorld();

  return finalMesh;
}

/**
 * Slice a mesh and save the G-code to a file.
 * @param {THREE.Mesh} mesh - The mesh to slice.
 * @param {string} filename - Name of the output file.
 * @returns {Object} Statistics about the slicing operation.
 */
function sliceAndSave(mesh, filename) {
  const slicer = new Polyslice({
    printer: printer,
    filament: filament,
    shellSkinThickness: 0.8,
    shellWallThickness: 0.8,
    lengthUnit: 'millimeters',
    timeUnit: 'seconds',
    infillPattern: 'grid',
    infillDensity: 20,
    bedTemperature: 0,
    layerHeight: 0.2,
    wipeNozzle: false,
    testStrip: false,
    metadata: true,
    verbose: true
  });

  const startTime = Date.now();
  const gcode = slicer.slice(mesh);
  const endTime = Date.now();

  const outputPath = path.join(outputDir, filename);
  fs.writeFileSync(outputPath, gcode);

  const sizeBytes = fs.statSync(outputPath).size;
  const lines = gcode.split('\n').filter(line => line.trim() !== '');
  const layerLines = lines.filter(line => line.includes('LAYER:'));

  return {
    time: endTime - startTime,
    lines: lines.length,
    layers: layerLines.length,
    size: sizeBytes,
    path: outputPath
  };
}

/**
 * Format bytes into a human-readable size string.
 * @param {number} bytes - Number of bytes.
 * @returns {string} Formatted size string.
 */
function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  const kb = bytes / 1024;
  if (kb < 1024) return `${kb.toFixed(1)} KB`;
  const mb = kb / 1024;
  return `${mb.toFixed(2)} MB`;
}

// Configuration for hole grids to generate.
const gridSizes = [1, 2, 3, 4, 5];
const sheetWidth = 50;
const sheetHeight = 50;
const sheetThickness = 2;
const holeRadius = 3;

console.log('Sheet Configuration:');
console.log(`- Dimensions: ${sheetWidth}mm x ${sheetHeight}mm x ${sheetThickness}mm`);
console.log(`- Hole Radius: ${holeRadius}mm`);
console.log(`- Grid Sizes: ${gridSizes.join('x, ')}x`);
console.log(`- Output Directory: ${outputDir}\n`);

console.log('Starting hole slicing...\n');
console.log('='.repeat(90));

const totalStartTime = Date.now();
const results = [];

for (const gridSize of gridSizes) {
  const totalHoles = gridSize * gridSize;
  const filename = `sheet-${gridSize}x${gridSize}-holes.gcode`;

  console.log(`\nProcessing ${gridSize}x${gridSize} grid (${totalHoles} hole${totalHoles > 1 ? 's' : ''})...`);

  try {
    // Create sheet with holes.
    const mesh = createSheetWithHoles(sheetWidth, sheetHeight, sheetThickness, holeRadius, gridSize);

    // Slice and save.
    const stats = sliceAndSave(mesh, filename);

    console.log(`✅ ${filename.padEnd(35)} | ${stats.time.toString().padStart(5)}ms | ${stats.lines.toString().padStart(6)} lines | ${stats.layers.toString().padStart(3)} layers | ${formatBytes(stats.size)}`);

    results.push({
      gridSize,
      totalHoles,
      filename,
      ...stats
    });
  } catch (error) {
    console.error(`❌ Failed to process ${gridSize}x${gridSize} grid: ${error.message}`);
    console.error(error.stack);
  }
}

const totalEndTime = Date.now();
const totalTime = totalEndTime - totalStartTime;

console.log('\n' + '='.repeat(90));
console.log('Hole Slicing Complete');
console.log('='.repeat(90));
console.log(`✅ Successfully generated ${results.length}/${gridSizes.length} files`);
console.log(`⏱️  Total Time: ${totalTime}ms (${(totalTime / 1000).toFixed(2)}s)`);
console.log(`📁 Output Directory: ${outputDir}`);

if (results.length > 0) {
  console.log('\nGenerated Files:');
  results.forEach(result => {
    console.log(`  - ${result.filename}: ${result.totalHoles} hole${result.totalHoles > 1 ? 's' : ''}, ${result.layers} layers, ${formatBytes(result.size)}`);
  });

  console.log('\n✅ Hole slicing completed successfully!');
  console.log('\nGenerated G-code files can be used with:');
  console.log('- 3D printer or simulator');
  console.log('- G-code visualizer (examples/visualizer/)');
  console.log('- Analysis and testing of hole slicing capabilities');
}
