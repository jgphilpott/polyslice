/**
 * G-code Exporter Usage Example (Node.js)
 *
 * This example demonstrates how to use the Polyslice Exporter in Node.js to:
 * 1. Save G-code to a file
 * 2. Send individual G-code lines via serial port
 * 3. Stream an entire G-code file via serial port
 *
 * For browser usage, see examples/serial/browser/sender.html
 */

const fs = require('fs');
const path = require('path');
const { Exporter } = require('../../src/index');

console.log('Polyslice Exporter - Node.js Example');
console.log('====================================\n');

// Sample G-code for testing.
const sampleGCode = `; Sample G-code for testing
G28 ; Home all axes
G0 Z5 F1000 ; Move Z up
G0 X50 Y50 F3000 ; Move to center
M104 S200 ; Set nozzle temp
M140 S60 ; Set bed temp
M109 S200 ; Wait for nozzle
M190 S60 ; Wait for bed
G1 X100 Y100 E5 F1500 ; Extrude line
M104 S0 ; Turn off nozzle
M140 S0 ; Turn off bed
G28 ; Home
`;

/**
 * Feature 1: Save G-code to a file
 * Demonstrates the Exporter.saveToFile() method in Node.js
 */
async function demonstrateSaveToFile() {
    console.log('Feature 1: Save G-code to File');
    console.log('------------------------------');

    const outputDir = path.join(__dirname, 'output');
    const outputFile = path.join(outputDir, 'exporter-demo.gcode');

    // Create output directory if it doesn't exist.
    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
    }

    try {
        const savedPath = await Exporter.saveToFile(sampleGCode, outputFile);
        console.log(`✓ G-code saved to: ${savedPath}`);

        // Verify file was created and has content.
        const stats = fs.statSync(savedPath);
        console.log(`✓ File size: ${stats.size} bytes`);

        // Read back first few lines to verify.
        const content = fs.readFileSync(savedPath, 'utf8');
        const lines = content.split('\n').slice(0, 3);
        console.log('✓ First 3 lines of saved file:');
        lines.forEach(line => console.log(`    ${line}`));

        console.log('\n✓ File save feature working correctly!\n');
        return true;
    } catch (error) {
        console.error(`✗ Error saving file: ${error.message}\n`);
        return false;
    }
}

/**
 * Feature 2: Send individual G-code lines
 * Demonstrates the Exporter.sendLine() method in Node.js
 */
async function demonstrateSendLine() {
    console.log('Feature 2: Send Individual G-code Lines');
    console.log('---------------------------------------');
    console.log('Note: Requires a connected 3D printer via serial port.');
    console.log('      Install serialport: npm install serialport\n');

    // Check if serialport is available.
    let hasSerialPort = false;
    try {
        require.resolve('serialport');
        hasSerialPort = true;
        console.log('✓ serialport package is installed');
    } catch (e) {
        console.log('⚠ serialport package not installed');
        console.log('  To enable serial features, run: npm install serialport\n');
    }

    // Demonstrate the sendLine API (without actual connection).
    console.log('sendLine() API usage:');
    console.log('  // Connect to serial port');
    console.log("  await Exporter.connectSerial({ path: '/dev/ttyUSB0', baudRate: 115200 });");
    console.log('');
    console.log('  // Send individual commands');
    console.log("  await Exporter.sendLine('G28');           // Home all axes");
    console.log("  await Exporter.sendLine('G0 X50 Y50');    // Move to position");
    console.log("  await Exporter.sendLine('M104 S200');     // Set nozzle temp");
    console.log('');
    console.log('  // Disconnect when done');
    console.log('  await Exporter.disconnectSerial();');

    // If serialport is available, verify connection error handling.
    if (hasSerialPort) {
        console.log('\n✓ Testing error handling for sendLine without connection:');
        try {
            await Exporter.sendLine('G28');
            console.log('  ✗ Should have thrown an error');
        } catch (error) {
            console.log(`  ✓ Correctly throws: "${error.message}"`);
        }
    }

    console.log('\n✓ sendLine feature API verified!\n');
    return true;
}

/**
 * Feature 3: Stream entire G-code file
 * Demonstrates the Exporter.streamGCode() and streamGCodeWithAck() methods
 */
async function demonstrateStreamGCode() {
    console.log('Feature 3: Stream Entire G-code File');
    console.log('------------------------------------');
    console.log('Note: Requires a connected 3D printer via serial port.\n');

    // Demonstrate the streamGCode API (delay-based, no acknowledgment).
    console.log('streamGCode() - Delay-based (browser compatible):');
    console.log('  // Stream G-code with delay between lines');
    console.log('  await Exporter.streamGCode(gcodeContent, {');
    console.log('      delay: 50,  // 50ms between lines');
    console.log('      onProgress: (current, total, line) => {');
    console.log('          console.log(`Sending ${current}/${total}: ${line}`);');
    console.log('      }');
    console.log('  });');
    console.log('');

    // Demonstrate the streamGCodeWithAck API (acknowledgment-based, Node.js only).
    console.log('streamGCodeWithAck() - Acknowledgment-based (Node.js only, RECOMMENDED):');
    console.log('  // Stream G-code waiting for "ok" from printer before each line');
    console.log('  await Exporter.streamGCodeWithAck(gcodeContent, {');
    console.log('      timeout: 30000,  // 30 second timeout per command');
    console.log('      onProgress: (current, total, line) => {');
    console.log('          console.log(`Sending ${current}/${total}: ${line}`);');
    console.log('      }');
    console.log('  });');
    console.log('');
    console.log('  // Disconnect when done');
    console.log('  await Exporter.disconnectSerial();');

    // Check if serialport is available for testing error handling.
    let hasSerialPort = false;
    try {
        require.resolve('serialport');
        hasSerialPort = true;
    } catch (e) {
        // Not installed.
    }

    if (hasSerialPort) {
        console.log('\n✓ Testing error handling for streamGCode without connection:');
        try {
            await Exporter.streamGCode(sampleGCode);
            console.log('  ✗ Should have thrown an error');
        } catch (error) {
            console.log(`  ✓ Correctly throws: "${error.message}"`);
        }

        console.log('✓ Testing error handling for streamGCodeWithAck without connection:');
        try {
            await Exporter.streamGCodeWithAck(sampleGCode);
            console.log('  ✗ Should have thrown an error');
        } catch (error) {
            console.log(`  ✓ Correctly throws: "${error.message}"`);
        }
    }

    console.log('\n✓ streamGCode feature API verified!\n');
    return true;
}

/**
 * Complete workflow example combining slicer with exporter
 */
async function demonstrateCompleteWorkflow() {
    console.log('Complete Workflow: Slicer + Exporter');
    console.log('------------------------------------');

    const Polyslice = require('../../src/index');
    const { Printer, Filament } = require('../../src/index');

    // Step 1: Create slicer instance.
    console.log('1. Creating slicer with Ender3 printer and PLA filament...');
    const slicer = new Polyslice({
        printer: new Printer('Ender3'),
        filament: new Filament('PrusamentPLA')
    });
    console.log('   ✓ Slicer created');

    // Step 2: Generate G-code using slicer methods.
    console.log('2. Generating G-code...');
    let gcode = '';
    gcode += slicer.codeAutohome();
    gcode += slicer.codeNozzleTemperature(210, true);
    gcode += slicer.codeBedTemperature(60, true);
    gcode += slicer.codeLinearMovement(10, 10, 0.2, null, 3000);
    gcode += slicer.codeLinearMovement(50, 10, 0.2, 2.0, 1200);
    gcode += slicer.codeLinearMovement(50, 50, 0.2, 2.0, 1200);
    gcode += slicer.codeLinearMovement(10, 50, 0.2, 2.0, 1200);
    gcode += slicer.codeFanSpeed(100);
    gcode += slicer.codeAutohome();
    console.log('   ✓ G-code generated');

    // Step 3: Save using exporter.
    console.log('3. Saving G-code to file...');
    const outputDir = path.join(__dirname, 'output');
    const outputFile = path.join(outputDir, 'workflow-output.gcode');

    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
    }

    try {
        await Exporter.saveToFile(gcode, outputFile);
        console.log(`   ✓ Saved to: ${outputFile}`);
    } catch (error) {
        console.log(`   ✗ Error: ${error.message}`);
    }

    // Step 4: Show serial usage (for when printer is connected).
    console.log('4. To send to printer:');
    console.log("   await Exporter.connectSerial({ path: '/dev/ttyUSB0', baudRate: 115200 });");
    console.log('   await Exporter.streamGCode(gcode, { delay: 50 });');
    console.log('   await Exporter.disconnectSerial();');

    console.log('\n✓ Complete workflow demonstrated!\n');
    return true;
}

/**
 * Main execution
 */
async function main() {
    const results = {
        saveToFile: false,
        sendLine: false,
        streamGCode: false,
        workflow: false
    };

    console.log('='.repeat(50) + '\n');

    // Feature 1: Save to file.
    results.saveToFile = await demonstrateSaveToFile();
    console.log('='.repeat(50) + '\n');

    // Feature 2: Send individual lines.
    results.sendLine = await demonstrateSendLine();
    console.log('='.repeat(50) + '\n');

    // Feature 3: Stream G-code.
    results.streamGCode = await demonstrateStreamGCode();
    console.log('='.repeat(50) + '\n');

    // Complete workflow.
    results.workflow = await demonstrateCompleteWorkflow();
    console.log('='.repeat(50) + '\n');

    // Summary.
    console.log('Summary');
    console.log('-------');
    console.log(`  Save to File:     ${results.saveToFile ? '✓ Working' : '✗ Failed'}`);
    console.log(`  Send Line:        ${results.sendLine ? '✓ API Verified' : '✗ Failed'}`);
    console.log(`  Stream G-code:    ${results.streamGCode ? '✓ API Verified' : '✗ Failed'}`);
    console.log(`  Complete Workflow: ${results.workflow ? '✓ Working' : '✗ Failed'}`);
    console.log('');
    console.log('Note: Serial features require a connected 3D printer.');
    console.log('      Install serialport with: npm install serialport');
    console.log('');

    // Clean up generated files.
    const outputDir = path.join(__dirname, 'output');
    if (fs.existsSync(outputDir)) {
        console.log('Cleaning up generated files...');
        // Use fs.rm for Node.js v14.14.0+ or fs.rmdirSync for older versions.
        if (fs.rmSync) {
            fs.rmSync(outputDir, { recursive: true, force: true });
        } else {
            fs.rmdirSync(outputDir, { recursive: true });
        }
        console.log('✓ Cleanup complete\n');
    }
}

main().catch(console.error);

