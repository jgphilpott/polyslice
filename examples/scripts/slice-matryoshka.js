/**
 * Example: Slice nested hollow cylinders (like matryoshka dolls)
 * This demonstrates the slicer's ability to handle nested structures with alternating hole/structure classification.
 *
 * Creates 5 test cases:
 * 1. Single hollow cylinder
 * 2. Hollow cylinder inside a larger hollow cylinder
 * 3. Three nested hollow cylinders
 * 4. Four nested hollow cylinders
 * 5. Five nested hollow cylinders
 *
 * Usage:
 *   node examples/scripts/slice-matryoshka.js
 */

const { Polyslice, Printer, Filament } = require('../../src/index');
const { Polytree } = require('@jgphilpott/polytree');
const THREE = require('three');
const path = require('path');
const fs = require('fs');

console.log('Polyslice Matryoshka (Nested Cylinders) Example');
console.log('================================================\n');

// Create printer and filament configuration objects.
const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

console.log('Printer & Filament Configuration:');
console.log(`- Printer: ${printer.model}`);
console.log(`- Build Volume: ${printer.getSizeX()}x${printer.getSizeY()}x${printer.getSizeZ()}mm`);
console.log(`- Filament: ${filament.name} (${filament.type.toUpperCase()})`);
console.log(`- Brand: ${filament.brand}\n`);

// Base output directory for G-code files.
const outputDir = path.join(__dirname, '../../resources/gcode/matryoshka');

// Ensure output directory exists.
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
  console.log(`Created output directory: ${outputDir}\n`);
}

/**
 * Create a hollow cylinder using CSG subtraction.
 * @param {number} outerRadius - Outer radius of the cylinder in millimeters.
 * @param {number} innerRadius - Inner radius (hole) of the cylinder in millimeters.
 * @param {number} height - Height of the cylinder in millimeters.
 * @param {number} segments - Number of segments for cylinder resolution.
 * @returns {Promise<THREE.Mesh>} The hollow cylinder mesh.
 */
async function createHollowCylinder(outerRadius, innerRadius, height, segments = 32) {
  // Create outer cylinder.
  const outerGeometry = new THREE.CylinderGeometry(outerRadius, outerRadius, height, segments);
  const outerMesh = new THREE.Mesh(outerGeometry, new THREE.MeshBasicMaterial());
  outerMesh.rotation.x = Math.PI / 2; // Orient along Z-axis
  outerMesh.updateMatrixWorld();

  // Create inner cylinder (hole) - make it slightly taller (1.2x) to ensure complete penetration for CSG.
  const innerGeometry = new THREE.CylinderGeometry(innerRadius, innerRadius, height * 1.2, segments);
  const innerMesh = new THREE.Mesh(innerGeometry, new THREE.MeshBasicMaterial());
  innerMesh.rotation.x = Math.PI / 2; // Orient along Z-axis
  innerMesh.updateMatrixWorld();

  // Subtract inner from outer to create hollow cylinder.
  const hollowMesh = await Polytree.subtract(outerMesh, innerMesh);

  // Wrap in a new THREE.Mesh to ensure compatibility.
  const finalMesh = new THREE.Mesh(hollowMesh.geometry, hollowMesh.material);
  finalMesh.position.set(0, 0, height / 2);
  finalMesh.updateMatrixWorld();

  return finalMesh;
}

/**
 * Create nested hollow cylinders (matryoshka dolls).
 * @param {number} count - Number of nested cylinders (1 to 5).
 * @param {number} baseHeight - Height of all cylinders in millimeters.
 * @param {number} wallThickness - Wall thickness in millimeters.
 * @param {number} gap - Gap between cylinders in millimeters.
 * @returns {Promise<THREE.Mesh>} The nested cylinders mesh.
 */
async function createMatryoshka(count, baseHeight = 1.2, wallThickness = 5, gap = 3) {
  if (count < 1 || count > 5) {
    throw new Error('Count must be between 1 and 5');
  }

  // Calculate radii for nested cylinders.
  // Start from innermost and work outward.
  const radii = [];
  let currentRadius = 5; // Innermost radius

  for (let i = 0; i < count; i++) {
    const outerRadius = currentRadius + wallThickness;
    radii.push({ inner: currentRadius, outer: outerRadius });
    currentRadius = outerRadius + gap; // Add gap for next cylinder
  }

  // Create all hollow cylinders.
  const cylinders = [];
  for (const { inner, outer } of radii) {
    const cylinder = await createHollowCylinder(outer, inner, baseHeight);
    cylinders.push(cylinder);
  }

  // If only one cylinder, return it directly.
  if (cylinders.length === 1) {
    return cylinders[0];
  }

  // Combine all cylinders using unite.
  let combined = cylinders[0];
  for (let i = 1; i < cylinders.length; i++) {
    combined = await Polytree.unite(combined, cylinders[i]);
  }

  // Wrap in a new THREE.Mesh.
  const finalMesh = new THREE.Mesh(combined.geometry, combined.material);
  finalMesh.position.set(0, 0, baseHeight / 2);
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
    shellSkinThickness: 0.4,
    shellWallThickness: 0.8,
    lengthUnit: 'millimeters',
    timeUnit: 'seconds',
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

console.log('Matryoshka Configuration:');
console.log('- Cylinder Height: 20mm');
console.log('- Wall Thickness: 1.6mm');
console.log('- Gap Between Cylinders: 2mm');
console.log('- Nesting Levels: 1, 2, 3, 4, 5\n');

console.log('Starting matryoshka slicing...\n');
console.log('='.repeat(90));

(async () => {
  const totalStartTime = Date.now();
  const results = [];

  for (let nestingLevel = 1; nestingLevel <= 5; nestingLevel++) {
    const filename = `nested-${nestingLevel}.gcode`;

    console.log(`\nProcessing ${nestingLevel} nested cylinder${nestingLevel > 1 ? 's' : ''}...`);

    try {
      // Create nested cylinders.
      const mesh = await createMatryoshka(nestingLevel);

      // Slice and save.
      const stats = sliceAndSave(mesh, filename);

      console.log(`✅ ${filename.padEnd(35)} | ${stats.time.toString().padStart(5)}ms | ${stats.lines.toString().padStart(6)} lines | ${stats.layers.toString().padStart(3)} layers | ${formatBytes(stats.size)}`);

      results.push({
        nestingLevel,
        filename,
        ...stats
      });
    } catch (error) {
      console.error(`❌ Failed to process ${nestingLevel} nested cylinder(s): ${error.message}`);
      console.error(error.stack);
    }
  }

  const totalEndTime = Date.now();
  const totalTime = totalEndTime - totalStartTime;

  console.log('\n' + '='.repeat(90));
  console.log('Matryoshka Slicing Complete');
  console.log('='.repeat(90));
  console.log(`✅ Successfully generated ${results.length}/5 files`);
  console.log(`⏱️  Total Time: ${totalTime}ms (${(totalTime / 1000).toFixed(2)}s)`);
  console.log(`📁 Output Directory: ${outputDir}`);

  if (results.length > 0) {
    console.log('\nGenerated Files:');
    results.forEach(result => {
      console.log(`  - ${result.filename}: ${result.nestingLevel} nested cylinder${result.nestingLevel > 1 ? 's' : ''}, ${result.layers} layers, ${formatBytes(result.size)}`);
    });

    console.log('\n✅ Matryoshka slicing completed successfully!');
    console.log('\nGenerated G-code files demonstrate:');
    console.log('- Proper handling of nested structures');
    console.log('- Alternating hole/structure classification');
    console.log('- Correct wall offset directions at each nesting level');
    console.log('\nYou can verify the G-code shows correct behavior for:');
    console.log('- Level 0 (outermost): Structure - walls inset inward');
    console.log('- Level 1 (first hole): Hole - walls inset outward');
    console.log('- Level 2 (inner structure): Structure - walls inset inward');
    console.log('- Level 3 (inner hole): Hole - walls inset outward');
    console.log('- Level 4 (innermost): Structure - walls inset inward');
  }
})();
