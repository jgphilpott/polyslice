/**
 * Basic example of using Polyslice
 */

const Polyslice = require('../src/index');

// Create a new slicer instance.
const slicer = new Polyslice({
  autohome: true,
  workspacePlane: 'XY',
  lengthUnit: 'millimeters',
  timeUnit: 'seconds',
  nozzleTemperature: 200,
  bedTemperature: 60,
  fanSpeed: 100
});

console.log('Polyslice Basic Example');
console.log('======================');

console.log('\n');

// Generate some basic G-code.
console.log('Configuration:');
console.log(`- Workspace Plane: ${slicer.getWorkspacePlane()}`);
console.log(`- Length Unit: ${slicer.getLengthUnit()}`);
console.log(`- Nozzle Temperature: ${slicer.getNozzleTemperature()}°C`);
console.log(`- Bed Temperature: ${slicer.getBedTemperature()}°C`);
console.log(`- Fan Speed: ${slicer.getFanSpeed()}%`);

console.log('\n');

console.log('Generated G-code:');
console.log('================');

console.log('\n');

// Generate initialization G-code.
let gcode = '';
gcode += slicer.codeAutohome();
gcode += slicer.codeWorkspacePlane();
gcode += slicer.codeLengthUnit();
gcode += slicer.codeNozzleTemperature(200, false);
gcode += slicer.codeBedTemperature(60, false);
gcode += slicer.codeFanSpeed(100);

// Add some movement.
gcode += slicer.codeLinearMovement(10, 10, 0.2, null, 1500);
gcode += slicer.codeLinearMovement(20, 10, 0.2, 0.1, 1500);
gcode += slicer.codeLinearMovement(20, 20, 0.2, 0.1, 1500);
gcode += slicer.codeLinearMovement(10, 20, 0.2, 0.1, 1500);
gcode += slicer.codeLinearMovement(10, 10, 0.2, 0.1, 1500);

// Add some ending code.
gcode += slicer.codeFanSpeed(0);
gcode += slicer.codeNozzleTemperature(0, false);
gcode += slicer.codeBedTemperature(0, false);
gcode += slicer.codeAutohome();

console.log(gcode);

console.log('Example completed successfully!');