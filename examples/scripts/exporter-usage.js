/**
 * G-code Exporter Usage Example
 * 
 * This example demonstrates how to use the Polyslice Exporter to:
 * 1. Save G-code to a file (Node.js and browser)
 * 2. Connect to a 3D printer via serial port
 * 3. Stream G-code to the printer
 */

const { Exporter } = require('../../src/index');

console.log('Polyslice Exporter Example');
console.log('=========================\n');

// Generate some sample G-code
const sampleGCode = `; Sample G-code for testing
G28 ; Home all axes
G0 Z5 ; Move Z up
G0 X50 Y50 ; Move to center
M104 S200 ; Set nozzle temp
M140 S60 ; Set bed temp
M109 S200 ; Wait for nozzle
M190 S60 ; Wait for bed
G1 X100 Y100 E5 F1500 ; Extrude line
M104 S0 ; Turn off nozzle
M140 S0 ; Turn off bed
G28 ; Home
`;

console.log('Generated sample G-code:');
console.log(sampleGCode);
console.log('\n' + '='.repeat(50) + '\n');

// Example 1: Save to file
console.log('Example 1: Save G-code to file');
console.log('------------------------------\n');

async function saveExample() {
    try {
        const filename = 'output.gcode';
        const savedPath = await Exporter.saveToFile(sampleGCode, filename);
        console.log(`✓ G-code saved to: ${savedPath}`);
    } catch (error) {
        console.error('✗ Error saving file:', error.message);
    }
}

// Example 2: Connect to serial port (Node.js)
console.log('\nExample 2: Connect to serial port');
console.log('----------------------------------\n');
console.log('Note: This example requires a physical 3D printer connected.');
console.log('In Node.js: npm install serialport');
console.log('In Browser: Uses Web Serial API (Chrome/Edge only)\n');

async function serialExample() {
    try {
        // Connect to serial port
        console.log('Connecting to serial port...');
        
        // For Node.js
        // await Exporter.connectSerial({
        //     path: '/dev/ttyUSB0',  // or COM3 on Windows
        //     baudRate: 115200
        // });
        
        // For Browser
        // await Exporter.connectSerial({
        //     baudRate: 115200
        // });
        
        console.log('✓ Connected to serial port');
        
        // Send a single line
        // await Exporter.sendLine('G28');
        console.log('✓ Sent: G28');
        
        // Stream G-code with progress
        // await Exporter.streamGCode(sampleGCode, {
        //     delay: 100,  // 100ms between lines
        //     onProgress: (current, total, line) => {
        //         console.log(`Progress: ${current}/${total} - ${line}`);
        //     }
        // });
        
        console.log('✓ G-code streamed successfully');
        
        // Disconnect
        // await Exporter.disconnectSerial();
        console.log('✓ Disconnected from serial port');
        
    } catch (error) {
        console.error('✗ Serial error:', error.message);
    }
}

// Example 3: Complete workflow
console.log('\nExample 3: Complete workflow');
console.log('----------------------------\n');

async function completeWorkflow() {
    const Polyslice = require('../../src/index');
    const { Printer, Filament } = require('../../src/index');
    
    console.log('1. Create slicer with printer and filament');
    const slicer = new Polyslice({
        printer: new Printer('Ender3'),
        filament: new Filament('PrusamentPLA')
    });
    
    console.log('✓ Slicer created\n');
    
    console.log('2. Generate G-code');
    let gcode = '';
    gcode += slicer.codeAutohome();
    gcode += slicer.codeNozzleTemperature(210, true);
    gcode += slicer.codeBedTemperature(60, true);
    gcode += slicer.codeLinearMovement(10, 10, 0.2, null, 3000);
    gcode += slicer.codeLinearMovement(10, 50, 0.2, 2.0, 1200);
    gcode += slicer.codeAutohome();
    
    console.log('✓ G-code generated\n');
    
    console.log('3. Save to file');
    try {
        await Exporter.saveToFile(gcode, 'complete-workflow.gcode');
        console.log('✓ G-code saved to file\n');
    } catch (error) {
        console.error('✗ Error saving:', error.message);
    }
    
    console.log('4. (Optional) Stream to printer');
    console.log('   - Uncomment serial connection code above');
    console.log('   - await Exporter.connectSerial({ baudRate: 115200 })');
    console.log('   - await Exporter.streamGCode(gcode)');
    console.log('   - await Exporter.disconnectSerial()');
}

// Run examples
async function runExamples() {
    await saveExample();
    console.log('\n' + '='.repeat(50) + '\n');
    await serialExample();
    console.log('\n' + '='.repeat(50) + '\n');
    await completeWorkflow();
    
    console.log('\n' + '='.repeat(50));
    console.log('\nExamples completed!');
    console.log('\nBrowser Usage:');
    console.log('  const { Exporter } = Polyslice;');
    console.log('  await Exporter.saveToFile(gcode, "output.gcode");');
    console.log('  await Exporter.connectSerial({ baudRate: 115200 });');
    console.log('  await Exporter.streamGCode(gcode);');
}

runExamples().catch(console.error);

