/**
 * Example showing how to slice sheets with holes punched in them
 * This demonstrates the slicer's ability to handle complex geometries with internal voids
 * using CSG (Constructive Solid Geometry) operations to create holes in a thin sheet
 */

const { Polyslice, Printer, Filament } = require('../../src/index');
const THREE = require('three');
const { Polytree } = require('@jgphilpott/polytree');
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

// STL output directory for generated meshes.
const stlDir = path.join(__dirname, '../../resources/stl/holes');
// Target directory for G-code artifacts (wayfinding tests/outputs).
const gcodeDir = path.join(__dirname, '../../resources/gcode/wayfinding/holes');

// Ensure output directories exist.
if (!fs.existsSync(stlDir)) {
  fs.mkdirSync(stlDir, { recursive: true });
  console.log(`Created STL directory: ${stlDir}\n`);
}

if (!fs.existsSync(gcodeDir)) {
  fs.mkdirSync(gcodeDir, { recursive: true });
  console.log(`Created G-code directory: ${gcodeDir}\n`);
}

// STL export toggle and output folder.
const exportSTL = true;
const meshesDir = stlDir; // write STL to resources/stl

/**
 * Create a thin sheet (box) with holes punched in it using CSG.
 * @param {number} width - Width of the sheet in millimeters.
 * @param {number} height - Height of the sheet in millimeters.
 * @param {number} thickness - Thickness of the sheet in millimeters.
 * @param {number} holeRadius - Radius of each hole in millimeters.
 * @param {number} gridSize - Size of the hole grid (e.g., 2 for 2x2, 3 for 3x3).
 * @returns {Promise<THREE.Mesh>} The sheet mesh with holes positioned at the build plate.
 */
async function createSheetWithHoles(width = 50, height = 50, thickness = 5, holeRadius = 3, gridSize = 1) {
  // Create the base sheet geometry.
  const sheetGeometry = new THREE.BoxGeometry(width, height, thickness);
  const sheetMesh = new THREE.Mesh(sheetGeometry, new THREE.MeshBasicMaterial());

  // Calculate spacing between holes.
  const spacing = Math.min(width, height) / (gridSize + 1);

  // Calculate offset to center the grid.
  const offsetX = -width / 2 + spacing;
  const offsetY = -height / 2 + spacing;

  // Create hole cylinders and subtract them from the sheet.
  let resultMesh = sheetMesh;

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
      const holeMesh = new THREE.Mesh(holeGeometry, new THREE.MeshBasicMaterial());
      holeMesh.rotation.x = Math.PI / 2;
      holeMesh.position.set(x, y, 0);
      holeMesh.updateMatrixWorld();

      // Subtract hole from sheet using Polytree.
      resultMesh = await Polytree.subtract(resultMesh, holeMesh);
    }
  }

  // Wrap in a new THREE.Mesh to ensure full compatibility with three.js tools.
  const finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material);
  finalMesh.position.set(0, 0, thickness / 2);
  finalMesh.updateMatrixWorld();

  return finalMesh;
}

/**
 * Export a mesh as an STL file (binary) using three's STLExporter (dynamic import for Node CJS).
 * @param {THREE.Mesh|THREE.Object3D} object - The mesh/object to export.
 * @param {string} outPath - Output file path ending with .stl
 * @returns {Promise<string>} - Resolves with the written path
 */
async function exportMeshAsSTL(object, outPath) {
  // Dynamic import because three's examples are ESM-only.
  const mod = await import('three/examples/jsm/exporters/STLExporter.js');
  const STLExporter = mod.STLExporter || mod.default?.STLExporter || mod.default;

  const exporter = new STLExporter();
  const data = exporter.parse(object, { binary: true });

  // The exporter may return a DataView, ArrayBuffer, or string.
  let nodeBuffer;
  if (typeof data === 'string') {
    nodeBuffer = Buffer.from(data, 'utf8');
  } else if (ArrayBuffer.isView(data)) {
    // DataView or typed array
    nodeBuffer = Buffer.from(data.buffer, data.byteOffset || 0, data.byteLength);
  } else if (data instanceof ArrayBuffer) {
    nodeBuffer = Buffer.from(data);
  } else {
    throw new Error('Unexpected STLExporter output type');
  }

  fs.writeFileSync(outPath, nodeBuffer);
  return outPath;
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
    shellSkinThickness: 0.4,
    shellWallThickness: 0.4,
    lengthUnit: 'millimeters',
    timeUnit: 'seconds',
    infillPatternCentering: 'global',
    infillPattern: 'grid',
    infillDensity: 20,
    bedTemperature: 0,
    layerHeight: 0.2,
    testStrip: false,
    metadata: false,
    verbose: true
  });

  const startTime = Date.now();
  const gcode = slicer.slice(mesh);
  const endTime = Date.now();

  const outputPath = path.join(gcodeDir, filename);
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
const sheetThickness = 1.4;
const holeRadius = 2;

// Dynamic sizing controls
// - minHoleGap: minimum clearance between adjacent hole edges (mm)
// - edgeMarginMin: minimum margin from hole edge to sheet edge (mm)
const minHoleGap = 2;      // mm between hole edges
const edgeMarginMin = 5;   // mm from outermost hole edge to sheet boundary

// Compute dynamic sheet width/height for a given grid size so holes have
// adequate spacing and edge margins using the placement scheme in createSheetWithHoles.
function computeSheetSize(gridSize, holeRadius) {
  // Required center-to-center spacing s to satisfy:
  //   - gap between holes >= minHoleGap  => s >= 2*R + minHoleGap
  //   - margin at edges  >= edgeMarginMin => s - R >= edgeMarginMin => s >= R + edgeMarginMin
  const s = Math.max(2 * holeRadius + minHoleGap, holeRadius + edgeMarginMin);
  // With the example's placement, width = s * (gridSize + 1)
  const width = s * (gridSize + 1);
  const height = width; // square sheet
  return { width, height, spacing: s };
}

console.log('Sheet Configuration (dynamic sizing):');
console.log(`- Hole Radius: ${holeRadius}mm`);
console.log(`- Min Hole Gap: ${minHoleGap}mm`);
console.log(`- Edge Margin: ${edgeMarginMin}mm`);
console.log(`- Grid Sizes: ${gridSizes.map(size => `${size}x${size}`).join(', ')}`);
console.log(`- STL Output Dir: ${stlDir}`);
console.log(`- G-code Output Dir: ${gcodeDir}\n`);

console.log('Starting hole slicing...\n');
console.log('='.repeat(90));

(async () => {
  const totalStartTime = Date.now();
  const results = [];

  for (const gridSize of gridSizes) {
    const totalHoles = gridSize * gridSize;
  const dimension = `${gridSize}x${gridSize}`;
  const gcodeFilename = `${dimension}.gcode`;
  const stlFilename = `holes-${dimension}.stl`;

    console.log(`\nProcessing ${gridSize}x${gridSize} grid (${totalHoles} hole${totalHoles > 1 ? 's' : ''})...`);

    try {
      // Compute dynamic sheet size for this grid
      const { width, height, spacing } = computeSheetSize(gridSize, holeRadius);
      console.log(`  Sheet: ${width.toFixed(1)} x ${height.toFixed(1)} x ${sheetThickness} mm (spacing=${spacing.toFixed(1)}mm)`);

      // Create sheet with holes.
      const mesh = await createSheetWithHoles(width, height, sheetThickness, holeRadius, gridSize);

      // Optionally export STL before slicing.
      if (exportSTL) {
        const stlPath = path.join(meshesDir, stlFilename);
        await exportMeshAsSTL(mesh, stlPath);
        console.log(`🧊 STL saved: ${stlFilename}`);
      }

      // Slice and save.
      const stats = sliceAndSave(mesh, gcodeFilename);

      console.log(`✅ ${gcodeFilename.padEnd(35)} | ${stats.time.toString().padStart(5)}ms | ${stats.lines.toString().padStart(6)} lines | ${stats.layers.toString().padStart(3)} layers | ${formatBytes(stats.size)}`);

      results.push({
        gridSize,
        totalHoles,
        filename: gcodeFilename,
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
  console.log(`📁 G-code Output Directory: ${gcodeDir}`);
  console.log(`📁 STL Output Directory: ${stlDir}`);

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
})();
