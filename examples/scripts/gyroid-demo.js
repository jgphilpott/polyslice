/**
 * Gyroid Infill Pattern Demonstration
 * This example shows how to use the gyroid infill pattern in Polyslice.
 * The gyroid is a triply periodic minimal surface that creates strong,
 * isotropic infill with natural variation between layers.
 */

const Polyslice = require('../../src/index');
const THREE = require('three');

console.log('Polyslice Gyroid Infill Pattern Demo');
console.log('====================================\n');

// Create a three.js scene.
const scene = new THREE.Scene();

// Create a simple cube geometry for demonstration.
const geometry = new THREE.BoxGeometry(20, 20, 10);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const cube = new THREE.Mesh(geometry, material);

// Position the cube.
cube.position.set(0, 0, 5);
scene.add(cube);

console.log('Created test cube:');
console.log('- Dimensions: 20mm x 20mm x 10mm');
console.log(`- Position: (${cube.position.x}, ${cube.position.y}, ${cube.position.z})`);
console.log('');

// Create a slicer instance configured for gyroid infill.
const slicer = new Polyslice({
  nozzleDiameter: 0.4,
  layerHeight: 0.2,
  shellWallThickness: 0.8,
  shellSkinThickness: 0.4,
  infillDensity: 20,
  infillPattern: 'gyroid',
  verbose: true,
  autohome: true,
  testStrip: false
});

console.log('Slicer configuration:');
console.log(`- Nozzle diameter: ${slicer.getNozzleDiameter()}mm`);
console.log(`- Layer height: ${slicer.getLayerHeight()}mm`);
console.log(`- Infill density: ${slicer.getInfillDensity()}%`);
console.log(`- Infill pattern: ${slicer.getInfillPattern()}`);
console.log('');

// Generate G-code.
console.log('Generating G-code with gyroid infill...');
const gcode = slicer.slice(cube);

console.log('\nG-code generation complete!');
console.log(`Total size: ${gcode.length} characters`);
console.log('');

// Analyze the G-code.
const lines = gcode.split('\n');
const infillLines = lines.filter(line => line.includes('; TYPE: FILL'));
const extrusionMoves = gcode.match(/G1.*E[\d.]+/g);

console.log('G-code analysis:');
console.log(`- Total lines: ${lines.length}`);
console.log(`- Infill sections: ${infillLines.length}`);
console.log(`- Extrusion moves: ${extrusionMoves ? extrusionMoves.length : 0}`);
console.log('');

// Show a sample of the infill G-code.
console.log('Sample of gyroid infill G-code:');
console.log('================================');

let inInfillSection = false;
let sampleCount = 0;
const maxSamples = 20;

for (const line of lines) {
  if (line.includes('; TYPE: FILL')) {
    inInfillSection = true;
    console.log(line);
    continue;
  }
  
  if (inInfillSection && line.trim() !== '') {
    if (line.includes(';LAYER:') || line.includes('; TYPE:')) {
      inInfillSection = false;
      break;
    }
    
    console.log(line);
    sampleCount++;
    
    if (sampleCount >= maxSamples) {
      console.log('...');
      break;
    }
  }
}

console.log('');
console.log('Key features of gyroid infill:');
console.log('- Creates strong, isotropic structure');
console.log('- Pattern varies naturally between layers');
console.log('- Excellent strength-to-weight ratio');
console.log('- Smooth curves instead of sharp angles');
console.log('- Based on mathematical minimal surface');
console.log('');

// Compare different infill densities.
console.log('Comparing different gyroid densities:');
console.log('=====================================');

const densities = [10, 20, 50];
for (const density of densities) {
  const testSlicer = new Polyslice({
    nozzleDiameter: 0.4,
    layerHeight: 0.2,
    shellWallThickness: 0.8,
    shellSkinThickness: 0.4,
    infillDensity: density,
    infillPattern: 'gyroid',
    verbose: false
  });
  
  const testGcode = testSlicer.slice(cube);
  const testExtrusions = testGcode.match(/G1.*E[\d.]+/g);
  
  console.log(`- ${density}% density: ${testExtrusions ? testExtrusions.length : 0} extrusion moves`);
}

console.log('');
console.log('Demo complete!');
