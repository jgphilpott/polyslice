/**
 * Print Sequences Example - Demonstrating Pre-print and Post-print Options
 *
 * This example shows different ways to use pre-print and post-print sequences:
 * 1. Basic sequence with test strip
 * 2. Sequence without test strip
 * 3. Simultaneous heating (faster)
 * 4. Post-print without buzzer
 * 5. Custom raise heights
 */

const Polyslice = require('../../src/index');

console.log('Polyslice Print Sequences Example');
console.log('==================================');
console.log('\n');

// Example 1: Basic sequence with test strip
console.log('Example 1: Basic Pre-print with Test Strip');
console.log('-------------------------------------------');
const slicer1 = new Polyslice({
  autohome: true,
  nozzleTemperature: 200,
  bedTemperature: 60,
  fanSpeed: 100,
  testStrip: true
});

let gcode1 = slicer1.codePrePrint();
console.log('Pre-print G-code (first 10 lines):');
console.log(gcode1.split('\n').slice(0, 10).join('\n'));
console.log('...\n');

// Example 2: Without test strip
console.log('Example 2: Pre-print WITHOUT Test Strip');
console.log('----------------------------------------');
const slicer2 = new Polyslice({
  autohome: true,
  nozzleTemperature: 200,
  bedTemperature: 60,
  testStrip: false
});

let gcode2 = slicer2.codePrePrint();
console.log('Pre-print G-code (shorter without test strip):');
console.log(gcode2);

// Example 3: Simultaneous heating (faster pre-print)
console.log('Example 3: Pre-print with Simultaneous Heating');
console.log('-----------------------------------------------');
const slicer3 = new Polyslice({
  autohome: true,
  nozzleTemperature: 200,
  bedTemperature: 60,
  testStrip: false
});

let gcode3 = slicer3.codePrePrint(10, false); // false = heat simultaneously
console.log('Pre-print G-code with parallel heating:');
console.log(gcode3);

// Example 4: Post-print without buzzer
console.log('Example 4: Post-print WITHOUT Buzzer');
console.log('-------------------------------------');
const slicer4 = new Polyslice();

let gcode4 = slicer4.codePostPrint(10, false); // false = no buzzer
console.log('Post-print G-code (silent):');
console.log(gcode4);

// Example 5: Custom raise heights
console.log('Example 5: Custom Raise Heights');
console.log('--------------------------------');
const slicer5 = new Polyslice({
  nozzleTemperature: 200,
  bedTemperature: 60
});

let gcode5 = '';
gcode5 += slicer5.codePrePrint(5); // Raise only 5mm during pre-print
gcode5 += slicer5.codePostPrint(20); // Raise 20mm during post-print

console.log('Combined G-code with custom raise heights:');
console.log('Pre-print raises to 5mm, post-print raises to 20mm');
console.log(`Total lines: ${gcode5.split('\n').filter(l => l.trim()).length}`);
console.log('\n');

// Example 6: Complete print workflow
console.log('Example 6: Complete Print Workflow');
console.log('-----------------------------------');
const slicer6 = new Polyslice({
  autohome: true,
  nozzleTemperature: 210,
  bedTemperature: 60,
  fanSpeed: 80,
  testStrip: true
});

let completeGcode = '';
completeGcode += slicer6.codePrePrint();
completeGcode += slicer6.codeMessage('Ready to print - insert actual print G-code here');
// In a real scenario, you would add your actual print layers here
completeGcode += slicer6.codePostPrint();

console.log('Complete workflow G-code summary:');
const lines = completeGcode.split('\n').filter(line => line.trim() !== '');
console.log(`- Total lines: ${lines.length}`);
console.log(`- First line: ${lines[0]}`);
console.log(`- Last line: ${lines[lines.length - 1]}`);
console.log('\n');

console.log('Summary:');
console.log('========');
console.log('- codePrePrint(raiseHeight=10, heatNozzleFirst=true)');
console.log('  * Autohomes, raises nozzle, heats up, optionally prints test strip');
console.log('- codePostPrint(raiseHeight=10, soundBuzzer=true)');
console.log('  * Retracts, raises, moves home, turns off, optionally beeps');
console.log('- codeTestStrip(length=60, width=5, height=0.3)');
console.log('  * Prints a rectangular test strip to verify extrusion');
console.log('\nAll methods are ready for real printer testing!');
