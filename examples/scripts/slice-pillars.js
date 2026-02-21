/**
 * Example showing how to slice arrays of independent pillars (cylinders)
 * This demonstrates the slicer's ability to handle multiple separate objects
 * arranged in grid patterns from 1x1 up to 5x5 arrays
 */

const { Polyslice, Printer, Filament } = require('../../src/index');
const THREE = require('three');
const path = require('path');
const fs = require('fs');

console.log('Polyslice Pillar Slicing Example');
console.log('================================\n');

// Create printer and filament configuration objects.
const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

console.log('Printer & Filament Configuration:');
console.log(`- Printer: ${printer.model}`);
console.log(`- Build Volume: ${printer.getSizeX()}x${printer.getSizeY()}x${printer.getSizeZ()}mm`);
console.log(`- Filament: ${filament.name} (${filament.type.toUpperCase()})`);
console.log(`- Brand: ${filament.brand}\n`);

// STL output directory for generated meshes.
const stlDir = path.join(__dirname, '../../resources/stl/pillars');
// Target directory for G-code artifacts (wayfinding tests/outputs).
const gcodeDir = path.join(__dirname, '../../resources/gcode/wayfinding/pillars');

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
 * Convert a THREE.Group containing multiple meshes into a single mesh with
 * all transforms baked into geometry.
 *
 * Polyslice's mesh extraction is designed around slicing a single mesh. If we
 * pass a Group, only the first mesh may get sliced. Merging ensures all
 * pillars are included.
 *
 * @param {THREE.Group|THREE.Object3D} object
 * @returns {Promise<THREE.Mesh>}
 */
async function toMergedMesh(object) {
  object.updateMatrixWorld(true);

  const geometries = [];
  object.traverse((child) => {
    if (!child || !child.isMesh || !child.geometry) return;

    child.updateMatrixWorld(true);
    const geometryClone = child.geometry.clone();
    geometryClone.applyMatrix4(child.matrixWorld);
    geometries.push(geometryClone);
  });

  if (geometries.length === 0) {
    throw new Error("No mesh geometries found to merge.");
  }

  // Dynamic import because three's examples are ESM-only.
  const mod = await import('three/examples/jsm/utils/BufferGeometryUtils.js');
  const mergeGeometries = mod.mergeGeometries || mod.BufferGeometryUtils?.mergeGeometries;
  if (!mergeGeometries) {
    throw new Error('Could not load mergeGeometries from BufferGeometryUtils');
  }

  const mergedGeometry = mergeGeometries(geometries, false);
  if (!mergedGeometry) {
    throw new Error('Failed to merge geometries');
  }

  const mergedMesh = new THREE.Mesh(mergedGeometry, new THREE.MeshBasicMaterial());
  mergedMesh.updateMatrixWorld(true);
  return mergedMesh;
}

/**
 * Create an array of independent pillar cylinders arranged in a grid.
 * @param {number} pillarRadius - Radius of each pillar in millimeters.
 * @param {number} pillarHeight - Height of each pillar in millimeters.
 * @param {number} gridSize - Size of the pillar grid (e.g., 2 for 2x2, 3 for 3x3).
 * @returns {THREE.Group} A group containing all pillar meshes positioned at the build plate.
 */
function createPillarArray(pillarRadius = 3, pillarHeight = 1.2, gridSize = 1) {
  const group = new THREE.Group();

  // Calculate spacing between pillars.
  const spacing = (pillarRadius * 2 + 4); // 4mm gap between pillars

  // Calculate offset to center the grid.
  const totalWidth = spacing * (gridSize - 1);
  const offsetX = -totalWidth / 2;
  const offsetY = -totalWidth / 2;

  // Create pillar cylinders.
  for (let row = 0; row < gridSize; row++) {
    for (let col = 0; col < gridSize; col++) {
      // Calculate pillar position.
      const x = offsetX + col * spacing;
      const y = offsetY + row * spacing;

      // Create cylinder for pillar (aligned with Z-axis).
      const pillarGeometry = new THREE.CylinderGeometry(
        pillarRadius,
        pillarRadius,
        pillarHeight,
        32
      );

      // Rotate cylinder to align with Z-axis (default is Y-axis).
      const pillarMesh = new THREE.Mesh(pillarGeometry, new THREE.MeshBasicMaterial());
      pillarMesh.rotation.x = Math.PI / 2;
      pillarMesh.position.set(x, y, pillarHeight / 2);
      pillarMesh.updateMatrixWorld();

      group.add(pillarMesh);
    }
  }

  return group;
}

/**
 * Export a mesh or group as an STL file (binary) using three's STLExporter (dynamic import for Node CJS).
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
 * Slice a mesh or group and save the G-code to a file.
 * @param {THREE.Mesh|THREE.Group} meshOrGroup - The mesh or group to slice.
 * @param {string} filename - Name of the output file.
 * @returns {Object} Statistics about the slicing operation.
 */
function sliceAndSave(meshOrGroup, filename) {
  const slicer = new Polyslice({
    printer: printer,
    filament: filament,
    shellSkinThickness: 0.4,
    shellWallThickness: 0.8,
    lengthUnit: 'millimeters',
    timeUnit: 'seconds',
    infillPatternCentering: 'object',
    infillPattern: 'grid',
    infillDensity: 20,
    bedTemperature: 0,
    layerHeight: 0.2,
    testStrip: false,
    metadata: false,
    verbose: true
  });

  const startTime = Date.now();
  const gcode = slicer.slice(meshOrGroup);
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

// Configuration for pillar grids to generate.
const gridSizes = [1, 2, 3, 4, 5];
const pillarHeight = 1.2;
const pillarRadius = 3;

console.log('Pillar Configuration:');
console.log(`- Pillar Radius: ${pillarRadius}mm`);
console.log(`- Pillar Height: ${pillarHeight}mm`);
console.log(`- Grid Sizes: ${gridSizes.map(size => `${size}x${size}`).join(', ')}`);
console.log(`- STL Output Dir: ${stlDir}`);
console.log(`- G-code Output Dir: ${gcodeDir}\n`);

console.log('Starting pillar slicing...\n');
console.log('='.repeat(90));

(async () => {
  const totalStartTime = Date.now();
  const results = [];

  for (const gridSize of gridSizes) {
    const totalPillars = gridSize * gridSize;
  const dimension = `${gridSize}x${gridSize}`;
  const gcodeFilename = `${dimension}.gcode`;
  const stlFilename = `pillars-${dimension}.stl`;

    console.log(`\nProcessing ${gridSize}x${gridSize} grid (${totalPillars} pillar${totalPillars > 1 ? 's' : ''})...`);

    try {
      // Create pillar array.
      const group = createPillarArray(pillarRadius, pillarHeight, gridSize);

  // Merge all pillars into one mesh so the slicer processes them all.
  const mergedMesh = await toMergedMesh(group);

      // Optionally export STL before slicing.
      if (exportSTL) {
        const stlPath = path.join(meshesDir, stlFilename);
        await exportMeshAsSTL(group, stlPath);
        console.log(`🧊 STL saved: ${stlFilename}`);
      }

      // Slice and save.
      const stats = sliceAndSave(mergedMesh, gcodeFilename);

      console.log(`✅ ${gcodeFilename.padEnd(35)} | ${stats.time.toString().padStart(5)}ms | ${stats.lines.toString().padStart(6)} lines | ${stats.layers.toString().padStart(3)} layers | ${formatBytes(stats.size)}`);

      results.push({
        gridSize,
        totalPillars,
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
  console.log('Pillar Slicing Complete');
  console.log('='.repeat(90));
  console.log(`✅ Successfully generated ${results.length}/${gridSizes.length} files`);
  console.log(`⏱️  Total Time: ${totalTime}ms (${(totalTime / 1000).toFixed(2)}s)`);
  console.log(`📁 G-code Output Directory: ${gcodeDir}`);
  console.log(`📁 STL Output Directory: ${stlDir}`);

  if (results.length > 0) {
    console.log('\nGenerated Files:');
    results.forEach(result => {
      console.log(`  - ${result.filename}: ${result.totalPillars} pillar${result.totalPillars > 1 ? 's' : ''}, ${result.layers} layers, ${formatBytes(result.size)}`);
    });

    console.log('\n✅ Pillar slicing completed successfully!');
    console.log('\nGenerated G-code files can be used with:');
    console.log('- 3D printer or simulator');
    console.log('- G-code visualizer (examples/visualizer/)');
    console.log('- Analysis and testing of multi-object slicing capabilities');
  }
})();
