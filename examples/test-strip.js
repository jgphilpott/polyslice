/**
 * Test Strip Example - Pre-print and Post-print sequence testing
 * 
 * This example demonstrates the pre-print and post-print sequences.
 * It will:
 * 1. Autohome the nozzle
 * 2. Raise nozzle slightly
 * 3. Heat up nozzle and bed
 * 4. Lay down a test strip (if enabled)
 * 5. Complete post-print sequence (turn off, sound buzzer)
 * 
 * This G-code can be tested on a real printer to verify the sequences work correctly.
 */

const Polyslice = require('../src/index');

console.log('Polyslice Test Strip Example');
console.log('============================');
console.log('\n');

// Create a new slicer instance with test strip enabled.
const slicer = new Polyslice({
  autohome: true,
  workspacePlane: 'XY',
  lengthUnit: 'millimeters',
  timeUnit: 'seconds',
  nozzleTemperature: 210,
  bedTemperature: 60,
  fanSpeed: 80,
  testStrip: true
});

console.log('Configuration:');
console.log(`- Autohome: ${slicer.getAutohome()}`);
console.log(`- Workspace Plane: ${slicer.getWorkspacePlane()}`);
console.log(`- Length Unit: ${slicer.getLengthUnit()}`);
console.log(`- Nozzle Temperature: ${slicer.getNozzleTemperature()}°C`);
console.log(`- Bed Temperature: ${slicer.getBedTemperature()}°C`);
console.log(`- Fan Speed: ${slicer.getFanSpeed()}%`);
console.log(`- Test Strip Enabled: ${slicer.getTestStrip()}`);
console.log('\n');

console.log('Generated G-code:');
console.log('=================');
console.log('\n');

// Generate the complete sequence.
let gcode = '';

// Pre-print sequence (includes test strip if enabled).
gcode += slicer.codePrePrint();

// Post-print sequence (includes buzzer).
gcode += slicer.codePostPrint();

// Output the G-code.
console.log(gcode);

console.log('\n');
console.log('G-code Summary:');
console.log('===============');
const lines = gcode.split('\n').filter(line => line.trim() !== '');
console.log(`- Total lines: ${lines.length}`);
console.log(`- Pre-print includes: autohome, heating, test strip`);
console.log(`- Post-print includes: retract, move home, cool down, buzzer`);
console.log('\n');

console.log('This G-code is ready to test on your 3D printer!');
console.log('It will heat up, print a test strip, and then cool down.');
