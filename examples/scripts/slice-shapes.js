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
const shapes = ['cube', 'cylinder', 'sphere', 'cone', 'torus'];
const infillPatterns = ['grid', 'triangles', 'hexagons', 'concentric', 'gyroid', 'spiral', 'lightning'];
const densities = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

// Base output directory.
const baseOutputDir = path.join(__dirname, '../../resources/gcode/infill');

// Format bytes into a human-readable size string.
function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  const kb = bytes / 1024;
  if (kb < 1024) return `${kb.toFixed(1)} KB`;
  const mb = kb / 1024;
  if (mb < 1024) return `${mb.toFixed(2)} MB`;
  const gb = mb / 1024;
  return `${gb.toFixed(2)} GB`;
}

console.log('Batch Slicing Configuration:');
console.log(`- Shapes: ${shapes.join(', ')}`);
console.log(`- Infill Patterns: ${infillPatterns.join(', ')}`);
console.log(`- Density Range: ${densities[0]}% to ${densities[densities.length - 1]}%`);
console.log(`- Density Steps: ${densities.length} configurations`);
console.log(`- Total Files: ${shapes.length * infillPatterns.length * densities.length}`);
console.log(`- Output Directory: ${baseOutputDir}\n`);

/**
 * Create a cube mesh for slicing.
 * @param {number} size - Size of the cube in millimeters.
 * @returns {THREE.Mesh} The cube mesh positioned at the build plate.
 */
function createCube(size = 10) {
  const geometry = new THREE.BoxGeometry(size, size, size);
  const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
  const mesh = new THREE.Mesh(geometry, material);

  // Position cube so the bottom is at Z=0.
  mesh.position.set(0, 0, size / 2);
  mesh.updateMatrixWorld();

  return mesh;
}

/**
 * Create a cylinder mesh for slicing.
 * @param {number} radius - Radius of the cylinder in millimeters.
 * @param {number} height - Height of the cylinder in millimeters.
 * @returns {THREE.Mesh} The cylinder mesh positioned at the build plate.
 */
function createCylinder(radius = 5, height = 10) {
  const geometry = new THREE.CylinderGeometry(radius, radius, height, 32);
  const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
  const mesh = new THREE.Mesh(geometry, material);

  // Rotate to align with Z-axis and position so bottom is at Z=0.
  mesh.rotation.x = Math.PI / 2;
  mesh.position.set(0, 0, height / 2);
  mesh.updateMatrixWorld();

  return mesh;
}

/**
 * Create a sphere mesh for slicing.
 * @param {number} radius - Radius of the sphere in millimeters.
 * @returns {THREE.Mesh} The sphere mesh positioned at the build plate.
 */
function createSphere(radius = 5) {
  const geometry = new THREE.SphereGeometry(radius, 32, 32);
  const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
  const mesh = new THREE.Mesh(geometry, material);

  // Position sphere so the bottom is at Z=0.
  mesh.position.set(0, 0, radius);
  mesh.updateMatrixWorld();

  return mesh;
}

/**
 * Create a cone mesh for slicing.
 * @param {number} radius - Base radius of the cone in millimeters.
 * @param {number} height - Height of the cone in millimeters.
 * @returns {THREE.Mesh} The cone mesh positioned at the build plate.
 */
function createCone(radius = 5, height = 10) {
  const geometry = new THREE.ConeGeometry(radius, height, 32);
  const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
  const mesh = new THREE.Mesh(geometry, material);

  // Rotate to align with Z-axis and position so bottom is at Z=0.
  mesh.rotation.x = Math.PI / 2;
  mesh.position.set(0, 0, height / 2);
  mesh.updateMatrixWorld();

  return mesh;
}

/**
 * Create a torus mesh for slicing.
 * @param {number} radius - Major radius of the torus in millimeters.
 * @param {number} tube - Minor radius (tube) of the torus in millimeters.
 * @returns {THREE.Mesh} The torus mesh positioned at the build plate.
 */
function createTorus(radius = 5, tube = 2) {
  const geometry = new THREE.TorusGeometry(radius, tube, 16, 32);
  const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
  const mesh = new THREE.Mesh(geometry, material);

  // Position torus so the bottom is at Z=0.
  mesh.position.set(0, 0, tube);
  mesh.updateMatrixWorld();

  return mesh;
}

/**
 * Create a shape mesh based on shape name.
 * @param {string} shapeName - Name of the shape to create.
 * @returns {THREE.Mesh} The shape mesh positioned at the build plate.
 */
function createShape(shapeName) {
  switch (shapeName) {
    case 'cube':
      return createCube(10);
    case 'cylinder':
      return createCylinder(5, 10);
    case 'sphere':
      return createSphere(5);
    case 'cone':
      return createCone(5, 10);
    case 'torus':
      return createTorus(5, 2);
    default:
      throw new Error(`Unknown shape: ${shapeName}`);
  }
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
    wipeNozzle: false,
    testStrip: true,
    metadata: false,
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
  console.log(`\n${'='.repeat(70)}`);
  console.log(`Processing infill pattern: ${pattern.toUpperCase()}`);
  console.log('='.repeat(70));

  // Create output directory for this pattern.
  const patternDir = path.join(baseOutputDir, pattern);
  if (!fs.existsSync(patternDir)) {
    fs.mkdirSync(patternDir, { recursive: true });
  }

  for (const shape of shapes) {
    console.log(`\n  Shape: ${shape}`);
    console.log('  ' + '─'.repeat(66));

    // Create output directory for this shape within the pattern directory.
    const shapeDir = path.join(patternDir, shape);
    if (!fs.existsSync(shapeDir)) {
      fs.mkdirSync(shapeDir, { recursive: true });
    }

    for (const density of densities) {
      try {
        // Create a fresh shape for each slice.
        const mesh = createShape(shape);

        // Slice the shape.
        const startTime = Date.now();
        const gcode = sliceShape(mesh, pattern, density);
        const endTime = Date.now();

        // Generate output filename with just density percentage.
        const filename = `${density}%.gcode`;
        const outputPath = path.join(shapeDir, filename);

        // Save G-code to file.
        fs.writeFileSync(outputPath, gcode);

        // Compute file size.
        const sizeBytes = fs.statSync(outputPath).size;

        // Analyze the G-code.
        const lines = gcode.split('\n').filter(line => line.trim() !== '');
        const layerLines = lines.filter(line => line.includes('LAYER:'));

        console.log(`  ✅ ${filename.padEnd(42)} | ${(endTime - startTime).toString().padStart(4)}ms | ${lines.length.toString().padStart(5)} lines | ${layerLines.length.toString().padStart(2)} layers | ${formatBytes(sizeBytes)}`);

        successCount++;
      } catch (error) {
        console.error(`  ❌ Failed ${density}%: ${error.message}`);
        failCount++;
      }
    }
  }
}

const totalEndTime = Date.now();
const totalTime = totalEndTime - totalStartTime;

console.log('\n' + '='.repeat(70));
console.log('Batch Slicing Complete');
console.log('='.repeat(70));
console.log(`✅ Successful: ${successCount}/${shapes.length * infillPatterns.length * densities.length}`);
if (failCount > 0) {
  console.log(`❌ Failed: ${failCount}/${shapes.length * infillPatterns.length * densities.length}`);
}
console.log(`⏱️  Total Time: ${totalTime}ms (${(totalTime / 1000).toFixed(2)}s)`);
console.log(`📁 Output Directory: ${baseOutputDir}`);
console.log(`📂 Directory Structure: pattern/shape/density%.gcode`);
console.log(`📂 Example: ${infillPatterns[0]}/${shapes[0]}/${densities[5]}%.gcode`);

if (successCount > 0) {
  console.log('\n✅ Batch slicing completed successfully!');
  console.log('\nGenerated files can be used with:');
  console.log('- 3D printer or simulator');
  console.log('- G-code visualizer (examples/visualizer/)');
  console.log('- Analysis and testing');
}
