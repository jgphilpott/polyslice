# G-code Exporter

The Exporter module provides functionality to save G-code to files and stream it to 3D printers via serial port.

## Features

- **File Export**: Save G-code to local files (Node.js) or trigger downloads (browser)
- **Serial Communication**: Connect to 3D printers via serial port
- **Cross-Platform**: Works in both Node.js and browser environments
- **Streaming**: Send G-code line-by-line with progress tracking
- **Async API**: All methods return Promises for easy integration

## Usage

### Saving to File

```javascript
const { Exporter } = require('@jgphilpott/polyslice');

// Generate G-code
const gcode = `G28
G0 X10 Y10
M104 S200`;

// Save to file
await Exporter.saveToFile(gcode, 'output.gcode');
```

**Browser**: Triggers a download dialog
**Node.js**: Saves to the file system

### Serial Port Communication

#### Connecting

```javascript
// In Node.js (requires 'serialport' package)
await Exporter.connectSerial({
    path: '/dev/ttyUSB0',  // or 'COM3' on Windows
    baudRate: 115200
});

// In Browser (uses Web Serial API - Chrome/Edge only)
await Exporter.connectSerial({
    baudRate: 115200
});
```

#### Sending Commands

```javascript
// Send a single line
await Exporter.sendLine('G28');

// Stream G-code with progress
await Exporter.streamGCode(gcode, {
    delay: 100,  // milliseconds between lines
    onProgress: (current, total, line) => {
        console.log(`${current}/${total}: ${line}`);
    }
});
```

#### Disconnecting

```javascript
await Exporter.disconnectSerial();
```

## API Reference

### `saveToFile(gcode, filename)`

Save G-code to a file.

**Parameters:**
- `gcode` (string): The G-code content to save
- `filename` (string): The filename (default: 'output.gcode')

**Returns:** Promise<string> - The saved file path

### `connectSerial(options)`

Connect to a serial port.

**Parameters:**
- `options.path` (string): Serial port path (Node.js only, e.g., '/dev/ttyUSB0')
- `options.baudRate` (number): Baud rate (default: 115200)
- `options.dataBits` (number): Data bits (default: 8)
- `options.stopBits` (number): Stop bits (default: 1)
- `options.parity` (string): Parity ('none', 'even', 'odd', default: 'none')
- `options.flowControl` (string): Flow control (default: 'none')

**Returns:** Promise<SerialPort>

### `disconnectSerial()`

Disconnect from the serial port.

**Returns:** Promise<void>

### `sendLine(line)`

Send a single G-code line to the serial port.

**Parameters:**
- `line` (string): The G-code line to send

**Returns:** Promise<void>

### `streamGCode(gcode, options)`

Stream G-code line-by-line to the serial port.

**Parameters:**
- `gcode` (string): The complete G-code to stream
- `options.delay` (number): Delay between lines in milliseconds (default: 0)
- `options.onProgress` (function): Callback function (current, total, line) => void

**Returns:** Promise<{ totalLines: number, success: boolean }>

### `readResponse(timeout)`

Read a response from the serial port.

**Parameters:**
- `timeout` (number): Timeout in milliseconds (default: 1000)

**Returns:** Promise<string>

## Environment Compatibility

### Node.js

Requires the `serialport` package for serial communication:

```bash
npm install serialport
```

File saving uses the built-in `fs` module.

### Browser

- File saving uses the Blob API and createObjectURL
- Serial communication uses the Web Serial API (Chrome 89+, Edge 89+)
- No additional dependencies required

## Examples

See `examples/scripts/exporter-usage.js` for complete usage examples.

## Notes

- Web Serial API requires user interaction (button click) to request port access
- Serial communication requires proper permissions on the operating system
- G-code comments (lines starting with `;`) are automatically skipped during streaming
- Empty lines are filtered out during streaming

