/**
 * Test Strip Example - Pre-print and Post-print sequence testing
 * 
 * This example demonstrates the pre-print and post-print sequences using
 * Printer and Filament configuration objects for easy customization.
 * 
 * The sequence will:
 * 1. Heat up nozzle and bed
 * 2. Autohome the nozzle
 * 3. Raise nozzle slightly
 * 4. Lay down a test strip along Y axis (if enabled)
 * 5. Complete post-print sequence (turn off, move home, triple beep)
 * 
 * This G-code can be tested on a real printer to verify the sequences work correctly.
 */

const { Polyslice, Printer, Filament } = require('../../src/index');

console.log('Polyslice Test Strip Example');
console.log('============================');
console.log('\n');

// Create printer and filament configuration objects.
// These can be easily customized for different setups.
const printer = new Printer('Ender3'); // Or 'PrusaI3MK3S', 'Ender5', etc.
const filament = new Filament('GenericPLA'); // Or 'GenericPETG', 'GenericABS', etc.

console.log('Printer & Filament Configuration:');
console.log(`- Printer: ${printer.model}`);
console.log(`- Build Volume: ${printer.getSizeX()}x${printer.getSizeY()}x${printer.getSizeZ()}mm`);
console.log(`- Filament: ${filament.name} (${filament.type.toUpperCase()})`);
console.log(`- Brand: ${filament.brand}`);
console.log('\n');

// Create a new slicer instance with test strip enabled.
const slicer = new Polyslice({
  printer: printer,
  filament: filament,
  autohome: true,
  workspacePlane: 'XY',
  lengthUnit: 'millimeters',
  timeUnit: 'seconds',
  testStrip: true,
  includeMetadata: true
});

console.log('Slicer Configuration:');
console.log(`- Autohome: ${slicer.getAutohome()}`);
console.log(`- Workspace Plane: ${slicer.getWorkspacePlane()}`);
console.log(`- Length Unit: ${slicer.getLengthUnit()}`);
console.log(`- Nozzle Temperature: ${slicer.getNozzleTemperature()}°C`);
console.log(`- Bed Temperature: ${slicer.getBedTemperature()}°C`);
console.log(`- Fan Speed: ${slicer.getFanSpeed()}%`);
console.log(`- Test Strip Enabled: ${slicer.getTestStrip()}`);
console.log(`- Include Metadata: ${slicer.getIncludeMetadata()}`);
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
