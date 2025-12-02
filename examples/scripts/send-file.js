/**
 * Send G-code File via Serial Port (Node.js)
 *
 * This script demonstrates how to use the Polyslice Exporter to send an entire
 * G-code file to a 3D printer via serial port in a Node.js environment.
 *
 * Usage:
 *   node examples/scripts/send-file.js path/to/file.gcode [options]
 *
 * Options:
 *   --port <path>     Serial port path (default: /dev/ttyUSB0)
 *   --baud <rate>     Baud rate (default: 115200)
 *   --delay <ms>      Delay between lines in ms (default: 50)
 *
 * Examples:
 *   node examples/scripts/send-file.js myprint.gcode
 *   node examples/scripts/send-file.js myprint.gcode --port /dev/ttyACM0 --baud 250000
 *   node examples/scripts/send-file.js myprint.gcode --delay 100
 */

const fs = require('fs');
const path = require('path');
const { Exporter } = require('../../src/index');

// Parse command line arguments.
function parseArgs() {
    const args = process.argv.slice(2);
    const options = {
        file: null,
        port: '/dev/ttyUSB0',
        baud: 115200,
        delay: 50
    };

    for (let i = 0; i < args.length; i++) {
        const arg = args[i];

        if (arg === '--port' && args[i + 1]) {
            options.port = args[++i];
        } else if (arg === '--baud' && args[i + 1]) {
            const baud = parseInt(args[++i], 10);
            if (!isNaN(baud) && baud > 0) {
                options.baud = baud;
            }
        } else if (arg === '--delay' && args[i + 1]) {
            const delay = parseInt(args[++i], 10);
            if (!isNaN(delay) && delay >= 0) {
                options.delay = delay;
            }
        } else if (!arg.startsWith('--') && !options.file) {
            options.file = arg;
        }
    }

    return options;
}

// Display usage information.
function showUsage() {
    console.log(`
Send G-code File via Serial Port

Usage:
  node examples/scripts/send-file.js <file.gcode> [options]

Options:
  --port <path>     Serial port path (default: /dev/ttyUSB0)
  --baud <rate>     Baud rate (default: 115200)
  --delay <ms>      Delay between lines in ms (default: 50)

Examples:
  node examples/scripts/send-file.js myprint.gcode
  node examples/scripts/send-file.js myprint.gcode --port /dev/ttyACM0
  node examples/scripts/send-file.js myprint.gcode --baud 250000 --delay 100
`);
}

// Main function to send G-code file.
async function sendFile(options) {
    console.log('Polyslice - Send G-code File');
    console.log('============================\n');

    // Resolve file path.
    const filePath = path.resolve(options.file);
    console.log(`File: ${filePath}`);
    console.log(`Port: ${options.port}`);
    console.log(`Baud: ${options.baud}`);
    console.log(`Delay: ${options.delay}ms\n`);

    // Check if file exists.
    if (!fs.existsSync(filePath)) {
        console.error(`✗ Error: File not found: ${filePath}`);
        process.exit(1);
    }

    // Read G-code file.
    console.log('Reading G-code file...');
    let gcode;
    try {
        gcode = fs.readFileSync(filePath, 'utf8');
        const lineCount = gcode.split('\n').filter(line => line.trim().length > 0).length;
        console.log(`✓ Loaded ${lineCount} lines\n`);
    } catch (error) {
        console.error(`✗ Error reading file: ${error.message}`);
        process.exit(1);
    }

    // Connect to serial port.
    console.log('Connecting to serial port...');
    try {
        await Exporter.connectSerial({
            path: options.port,
            baudRate: options.baud
        });
        console.log('✓ Connected\n');
    } catch (error) {
        console.error(`✗ Connection failed: ${error.message}`);
        process.exit(1);
    }

    // Stream G-code to printer.
    console.log('Streaming G-code...');
    const startTime = Date.now();

    try {
        const result = await Exporter.streamGCode(gcode, {
            delay: options.delay,
            onProgress: (current, total, line) => {
                const percent = Math.round((current / total) * 100);
                const displayLine = (line || '').substring(0, 30);
                process.stdout.write(`\r  Progress: ${current}/${total} (${percent}%) - ${displayLine}...`);
            }
        });

        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
        console.log(`\n\n✓ Complete! Sent ${result.totalLines} lines in ${elapsed}s\n`);
    } catch (error) {
        console.error(`\n✗ Streaming failed: ${error.message}`);
    }

    // Disconnect.
    console.log('Disconnecting...');
    try {
        await Exporter.disconnectSerial();
        console.log('✓ Disconnected\n');
    } catch (error) {
        console.error(`✗ Disconnect failed: ${error.message}`);
    }

    console.log('Done!');
}

// Entry point.
const options = parseArgs();

if (!options.file) {
    showUsage();
    process.exit(1);
}

sendFile(options).catch(error => {
    console.error(`\n✗ Fatal error: ${error.message}`);
    process.exit(1);
});
