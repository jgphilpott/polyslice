/**
 * Advanced example showing three.js integration with Polyslice
 * This demonstrates how to work with three.js geometry and convert it to G-code
 */

const Polyslice = require('../src/index');
const THREE = require('three');

console.log('Polyslice + Three.js Integration Example');
console.log('========================================');

// Create a three.js scene
const scene = new THREE.Scene();

// Create a simple cube geometry
const geometry = new THREE.BoxGeometry(20, 20, 5);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const cube = new THREE.Mesh(geometry, material);

// Position the cube
cube.position.set(0, 0, 2.5);
scene.add(cube);

console.log('Created a cube mesh in three.js scene:');
console.log(`- Dimensions: 20mm x 20mm x 5mm`);
console.log(`- Position: (${cube.position.x}, ${cube.position.y}, ${cube.position.z})`);
console.log(`- Vertices: ${geometry.attributes.position.count}`);

// Create a slicer instance optimized for the cube
const slicer = new Polyslice({
  autohome: true,
  workspacePlane: 'XY',
  lengthUnit: 'millimeters',
  timeUnit: 'seconds',
  nozzleTemperature: 210,
  bedTemperature: 60,
  fanSpeed: 80
});

console.log('\nSlicer Configuration:');
console.log(`- Nozzle Temperature: ${slicer.getNozzleTemperature()}°C`);
console.log(`- Bed Temperature: ${slicer.getBedTemperature()}°C`);
console.log(`- Fan Speed: ${slicer.getFanSpeed()}%`);

// Generate G-code for printing the cube
console.log('\nGenerating G-code for the cube:');
console.log('==============================');

let gcode = '';

// Start sequence
gcode += slicer.codeMessage('Starting cube print...');
gcode += slicer.codeAutohome();
gcode += slicer.codeWorkspacePlane();
gcode += slicer.codeLengthUnit();

// Heat up
gcode += slicer.codeMessage('Heating up...');
gcode += slicer.codeNozzleTemperature(210, true);
gcode += slicer.codeBedTemperature(60, true);
gcode += slicer.codeFanSpeed(80);

// Print layers (simplified slicing)
const layerHeight = 0.2;
const numLayers = Math.ceil(5 / layerHeight); // 5mm height / 0.2mm layer height
const cubeSize = 20;
const centerX = cube.position.x;
const centerY = cube.position.y;

gcode += slicer.codeMessage(`Printing ${numLayers} layers...`);

for (let layer = 0; layer < numLayers; layer++) {
  const z = (layer + 1) * layerHeight;
  gcode += slicer.codeMessage(`Layer ${layer + 1}/${numLayers}`);
  
  // Move to start position
  gcode += slicer.codeLinearMovement(
    centerX - cubeSize/2, 
    centerY - cubeSize/2, 
    z, 
    null, 
    3000
  );
  
  // Print perimeter (square outline)
  const extrudeAmount = 0.05; // mm per mm of movement
  
  // Bottom edge
  gcode += slicer.codeLinearMovement(
    centerX + cubeSize/2, 
    centerY - cubeSize/2, 
    z, 
    extrudeAmount * cubeSize, 
    1200
  );
  
  // Right edge
  gcode += slicer.codeLinearMovement(
    centerX + cubeSize/2, 
    centerY + cubeSize/2, 
    z, 
    extrudeAmount * cubeSize, 
    1200
  );
  
  // Top edge
  gcode += slicer.codeLinearMovement(
    centerX - cubeSize/2, 
    centerY + cubeSize/2, 
    z, 
    extrudeAmount * cubeSize, 
    1200
  );
  
  // Left edge
  gcode += slicer.codeLinearMovement(
    centerX - cubeSize/2, 
    centerY - cubeSize/2, 
    z, 
    extrudeAmount * cubeSize, 
    1200
  );
  
  // Infill (simplified - just two crossing lines)
  if (layer > 0) { // Skip infill on first layer
    gcode += slicer.codeLinearMovement(
      centerX + cubeSize/2, 
      centerY + cubeSize/2, 
      z, 
      extrudeAmount * cubeSize * 1.414, 
      1200
    );
    
    gcode += slicer.codeLinearMovement(
      centerX + cubeSize/2, 
      centerY - cubeSize/2, 
      z, 
      null, 
      3000
    );
    
    gcode += slicer.codeLinearMovement(
      centerX - cubeSize/2, 
      centerY + cubeSize/2, 
      z, 
      extrudeAmount * cubeSize * 1.414, 
      1200
    );
  }
}

// End sequence
gcode += slicer.codeMessage('Print completed!');
gcode += slicer.codeFanSpeed(0);
gcode += slicer.codeNozzleTemperature(0, false);
gcode += slicer.codeBedTemperature(0, false);
gcode += slicer.codeAutohome();
gcode += slicer.codeMessage('Ready for next print');

// Output the results
console.log('\nGenerated G-code Preview (first 20 lines):');
const lines = gcode.split('\n').filter(line => line.trim() !== '');
lines.slice(0, 20).forEach((line, index) => {
  console.log(`${(index + 1).toString().padStart(2, '0')}: ${line}`);
});

console.log(`\n... (total ${lines.length} lines of G-code generated)`);

console.log('\nExample Summary:');
console.log('- ✅ Three.js scene created with cube mesh');
console.log('- ✅ Polyslice configured for PLA printing');
console.log('- ✅ G-code generated with proper heating sequence');
console.log(`- ✅ ${numLayers} layers sliced at ${layerHeight}mm layer height`);
console.log('- ✅ Perimeter and basic infill patterns generated');
console.log('- ✅ Proper end sequence for safe print completion');

console.log('\nNote: This is a simplified slicing example.');
console.log('Real-world slicing would require more sophisticated algorithms');
console.log('for optimal tool paths, support structures, and advanced features.');