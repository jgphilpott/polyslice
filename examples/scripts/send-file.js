/**
 * Send G-code File via Serial Port (Node.js)
 *
 * This script demonstrates how to use the Polyslice Exporter to send an entire
 * G-code file to a 3D printer via serial port in a Node.js environment.
 *
 * Uses streamGCodeWithAck() which waits for printer acknowledgment ("ok")
 * before sending each line, ensuring proper command execution.
 *
 * Usage:
 *   node examples/scripts/send-file.js path/to/file.gcode [options]
 *
 * Options:
 *   --port <path>       Serial port path (default: /dev/ttyUSB0)
 *   --baud <rate>       Baud rate (default: 115200)
 *   --timeout <ms>      Timeout per command in ms (default: no timeout)
 *
 * Examples:
 *   node examples/scripts/send-file.js myprint.gcode
 *   node examples/scripts/send-file.js myprint.gcode --port /dev/ttyACM0 --baud 250000
 *   node examples/scripts/send-file.js myprint.gcode --timeout 60000
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
        timeout: null  // No timeout by default.
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
        } else if (arg === '--timeout' && args[i + 1]) {
            const timeout = parseInt(args[++i], 10);
            if (!isNaN(timeout) && timeout > 0) {
                options.timeout = timeout;
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
  --port <path>       Serial port path (default: /dev/ttyUSB0)
  --baud <rate>       Baud rate (default: 115200)
  --timeout <ms>      Timeout per command in ms (default: no timeout)

Examples:
  node examples/scripts/send-file.js myprint.gcode
  node examples/scripts/send-file.js myprint.gcode --port /dev/ttyACM0
  node examples/scripts/send-file.js myprint.gcode --baud 250000 --timeout 60000
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
    console.log(`Timeout: ${options.timeout ? options.timeout + 'ms' : 'none'}\n`);

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

    // Stream G-code to printer with acknowledgment.
    // Uses streamGCodeWithAck() which waits for printer "ok" before each line.
    console.log('Streaming G-code (waiting for acknowledgment on each line)...');
    const startTime = Date.now();

    // Build streaming options.
    const streamOptions = {
        onProgress: (current, total, line) => {
            const percent = Math.round((current / total) * 100);
            const displayLine = (line || '').substring(0, 30);
            process.stdout.write(`\r  Progress: ${current}/${total} (${percent}%) - ${displayLine}...`);
        }
    };

    // Only add timeout if specified.
    if (options.timeout) {
        streamOptions.timeout = options.timeout;
    }

    try {
        const result = await Exporter.streamGCodeWithAck(gcode, streamOptions);

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
