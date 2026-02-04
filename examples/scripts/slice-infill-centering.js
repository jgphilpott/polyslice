/**
 * Demonstration script for infill pattern centering modes.
 * 
 * This script slices two cubes at different positions using both:
 * - Object centering (patterns centered on each object's boundary)
 * - Global centering (patterns centered on build plate center)
 * 
 * Run with: npm run compile && node examples/scripts/slice-infill-centering.js
 */

const fs = require('fs');
const path = require('path');
const THREE = require('three');
const Polyslice = require('../../src/index');

console.log('\n=== Infill Pattern Centering Demonstration ===\n');

// Create output directory if it doesn't exist
const outputDir = path.join(__dirname, '../output');
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

// Create two identical cubes at different positions
function createTestScene() {
  const cube1 = new THREE.Mesh(
    new THREE.BoxGeometry(10, 10, 10),
    new THREE.MeshBasicMaterial()
  );
  cube1.position.set(0, 0, 5);
  cube1.updateMatrixWorld();

  const cube2 = new THREE.Mesh(
    new THREE.BoxGeometry(10, 10, 10),
    new THREE.MeshBasicMaterial()
  );
  cube2.position.set(30, 30, 5);
  cube2.updateMatrixWorld();

  return [cube1, cube2];
}

// Configure slicer with common settings
function configureSlicer(slicer, centeringMode) {
  slicer.setNozzleDiameter(0.4);
  slicer.setShellWallThickness(0.8); // 2 walls
  slicer.setShellSkinThickness(0.4); // 2 bottom + 2 top layers
  slicer.setLayerHeight(0.2);
  slicer.setInfillDensity(20);
  slicer.setInfillPattern('grid');
  slicer.setInfillPatternCentering(centeringMode);
  slicer.setVerbose(true);
  slicer.setMetadata(true);
  return slicer;
}

// Analyze G-code to extract infill line coordinates
function analyzeInfillLines(gcode) {
  const lines = gcode.split('\n');
  let inFillSection = false;
  const infillCoordinates = [];

  for (const line of lines) {
    if (line.includes('; TYPE: FILL')) {
      inFillSection = true;
      continue;
    }
    if (line.includes('; TYPE:') && !line.includes('; TYPE: FILL')) {
      inFillSection = false;
      continue;
    }

    if (inFillSection && line.startsWith('G1') && line.includes('E')) {
      // Extract X and Y coordinates
      const xMatch = line.match(/X([\d.-]+)/);
      const yMatch = line.match(/Y([\d.-]+)/);
      if (xMatch && yMatch) {
        infillCoordinates.push({
          x: parseFloat(xMatch[1]),
          y: parseFloat(yMatch[1])
        });
      }
    }
  }

  return infillCoordinates;
}

// Main demonstration
async function main() {
  const [cube1, cube2] = createTestScene();

  console.log('Cube 1 position: (0, 0, 5)');
  console.log('Cube 2 position: (30, 30, 5)');
  console.log('Build plate: 220mm × 220mm (centered at 110, 110)\n');

  // Test 1: Object Centering (default)
  console.log('--- Test 1: Object Centering ---');
  console.log('Pattern is centered on each object\'s boundary.\n');

  const slicerObject = new Polyslice({ progressCallback: null });
  configureSlicer(slicerObject, 'object');

  console.log('Slicing cube 1 with object centering...');
  const gcodeObject1 = slicerObject.slice(cube1);
  const infillObject1 = analyzeInfillLines(gcodeObject1);
  
  // Reset for second cube
  slicerObject.gcode = '';
  console.log('Slicing cube 2 with object centering...');
  const gcodeObject2 = slicerObject.slice(cube2);
  const infillObject2 = analyzeInfillLines(gcodeObject2);

  console.log(`Cube 1 infill lines: ${infillObject1.length}`);
  console.log(`Cube 2 infill lines: ${infillObject2.length}`);
  
  if (infillObject1.length > 0) {
    console.log(`Cube 1 infill range: X [${Math.min(...infillObject1.map(p => p.x)).toFixed(1)}, ${Math.max(...infillObject1.map(p => p.x)).toFixed(1)}], Y [${Math.min(...infillObject1.map(p => p.y)).toFixed(1)}, ${Math.max(...infillObject1.map(p => p.y)).toFixed(1)}]`);
  }
  if (infillObject2.length > 0) {
    console.log(`Cube 2 infill range: X [${Math.min(...infillObject2.map(p => p.x)).toFixed(1)}, ${Math.max(...infillObject2.map(p => p.x)).toFixed(1)}], Y [${Math.min(...infillObject2.map(p => p.y)).toFixed(1)}, ${Math.max(...infillObject2.map(p => p.y)).toFixed(1)}]`);
  }

  // Save files
  const outputObject1 = path.join(outputDir, 'cube1-object-centering.gcode');
  const outputObject2 = path.join(outputDir, 'cube2-object-centering.gcode');
  fs.writeFileSync(outputObject1, gcodeObject1);
  fs.writeFileSync(outputObject2, gcodeObject2);
  console.log(`\nSaved: ${outputObject1}`);
  console.log(`Saved: ${outputObject2}`);

  // Test 2: Global Centering
  console.log('\n--- Test 2: Global Centering ---');
  console.log('Pattern is centered on build plate center (110, 110).\n');

  const slicerGlobal = new Polyslice({ progressCallback: null });
  configureSlicer(slicerGlobal, 'global');

  console.log('Slicing cube 1 with global centering...');
  const gcodeGlobal1 = slicerGlobal.slice(cube1);
  const infillGlobal1 = analyzeInfillLines(gcodeGlobal1);
  
  // Reset for second cube
  slicerGlobal.gcode = '';
  console.log('Slicing cube 2 with global centering...');
  const gcodeGlobal2 = slicerGlobal.slice(cube2);
  const infillGlobal2 = analyzeInfillLines(gcodeGlobal2);

  console.log(`Cube 1 infill lines: ${infillGlobal1.length}`);
  console.log(`Cube 2 infill lines: ${infillGlobal2.length}`);
  
  if (infillGlobal1.length > 0) {
    console.log(`Cube 1 infill range: X [${Math.min(...infillGlobal1.map(p => p.x)).toFixed(1)}, ${Math.max(...infillGlobal1.map(p => p.x)).toFixed(1)}], Y [${Math.min(...infillGlobal1.map(p => p.y)).toFixed(1)}, ${Math.max(...infillGlobal1.map(p => p.y)).toFixed(1)}]`);
  }
  if (infillGlobal2.length > 0) {
    console.log(`Cube 2 infill range: X [${Math.min(...infillGlobal2.map(p => p.x)).toFixed(1)}, ${Math.max(...infillGlobal2.map(p => p.x)).toFixed(1)}], Y [${Math.min(...infillGlobal2.map(p => p.y)).toFixed(1)}, ${Math.max(...infillGlobal2.map(p => p.y)).toFixed(1)}]`);
  }

  // Save files
  const outputGlobal1 = path.join(outputDir, 'cube1-global-centering.gcode');
  const outputGlobal2 = path.join(outputDir, 'cube2-global-centering.gcode');
  fs.writeFileSync(outputGlobal1, gcodeGlobal1);
  fs.writeFileSync(outputGlobal2, gcodeGlobal2);
  console.log(`\nSaved: ${outputGlobal1}`);
  console.log(`Saved: ${outputGlobal2}`);

  // Summary
  console.log('\n=== Summary ===');
  console.log('\nObject Centering:');
  console.log('  - Each object has its own pattern center');
  console.log('  - Patterns are independent per object');
  console.log('  - Good for ensuring consistent infill within each part');
  console.log('\nGlobal Centering:');
  console.log('  - All objects share the same pattern grid');
  console.log('  - Pattern is centered on the build plate');
  console.log('  - Good for multi-object prints where pattern alignment matters');
  console.log('  - May result in incomplete pattern coverage at object edges');
  console.log('\nAll output files saved to:', outputDir);
  console.log('\n');
}

// Run the demonstration
main().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
