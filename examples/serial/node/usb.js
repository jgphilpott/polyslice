/**
 * Send Single G-code Line via Serial Port (Node.js)
 *
 * This script demonstrates how to use the Polyslice Exporter to send a single
 * G-code command (G28 - Home All Axes) to a 3D printer via serial port.
 *
 * Usage:
 *   node examples/serial/node/usb.js
 *
 * Note: Requires serialport package: npm install serialport
 *       Update the port path below for your system.
 */

const { Exporter } = require('../../../src/index');

// Configuration - update for your system.
const PORT_PATH = '/dev/ttyUSB0';        // Linux example
// const PORT_PATH = '/dev/tty.usbserial-10';  // macOS example
// const PORT_PATH = 'COM3';                // Windows example
const BAUD_RATE = 115200;

async function main() {
    console.log('Polyslice Exporter - Send Single Line Example');
    console.log('==============================================\n');

    // Connect to serial port using Exporter.
    console.log(`Connecting to ${PORT_PATH} at ${BAUD_RATE} baud...`);

    try {
        await Exporter.connectSerial({
            path: PORT_PATH,
            baudRate: BAUD_RATE
        });
        console.log('✓ Connected!\n');
    } catch (error) {
        console.error(`✗ Connection failed: ${error.message}`);
        process.exit(1);
    }

    // Set up data listener for responses.
    Exporter.serialPort.on('data', function(data) {
        console.log('Received:', data.toString().trim());
    });

    // Send G28 command (Home All Axes) using Exporter.sendLine().
    console.log('Sending: G28 (Home All Axes)');

    try {
        await Exporter.sendLine('G28');
        console.log('✓ Command sent!\n');
    } catch (error) {
        console.error(`✗ Send failed: ${error.message}`);
    }

    // Wait a moment for printer response, then disconnect.
    console.log('Waiting for response...');
    setTimeout(async () => {
        console.log('\nDisconnecting...');

        try {
            await Exporter.disconnectSerial();
            console.log('✓ Disconnected');
        } catch (error) {
            console.error(`✗ Disconnect failed: ${error.message}`);
        }

        process.exit(0);
    }, 5000);
}

main().catch(error => {
    console.error(`Fatal error: ${error.message}`);
    process.exit(1);
});
