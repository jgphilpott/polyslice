# G-code Exporter

The Exporter module provides functionality to save G-code to files and stream it to 3D printers via serial port.

## Features

- **File Export**: Save G-code to local files (Node.js) or trigger downloads (browser)
- **Serial Communication**: Connect to 3D printers via serial port
- **Cross-Platform**: Works in both Node.js and browser environments
- **Streaming**: Send G-code line-by-line with progress tracking
- **Acknowledgment-Based Streaming**: Wait for printer "ok" response before each line (Node.js only)
- **Async API**: All methods return Promises for easy integration

## Usage

### Saving to File

```javascript
const { Exporter } = require("@jgphilpott/polyslice");

// Generate G-code
const gcode = `G28
G0 X10 Y10
M104 S200`;

// Save to file
await Exporter.saveToFile(gcode, "output.gcode");
```

**Browser**: Triggers a download dialog
**Node.js**: Saves to the file system

### Serial Port Communication

#### Connecting

```javascript
// In Node.js (requires 'serialport' package)
await Exporter.connectSerial({
    path: "/dev/ttyUSB0",  // or "COM3" on Windows
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
await Exporter.sendLine("G28");

// Read the response
const response = await Exporter.readResponse(1000);
console.log(response);  // e.g., "ok"
```

#### Streaming G-code

There are two methods for streaming G-code to a printer:

##### Method 1: Delay-Based Streaming (`streamGCode`)

Uses a fixed delay between lines. Works in both browser and Node.js environments.

```javascript
await Exporter.streamGCode(gcode, {
    delay: 100,  // milliseconds between lines
    onProgress: (current, total, line) => {
        console.log(`${current}/${total}: ${line}`);
    }
});
```

##### Method 2: Acknowledgment-Based Streaming (`streamGCodeWithAck`) - RECOMMENDED for Node.js

Waits for the printer's "ok" acknowledgment before sending each line. This is the recommended method for Node.js as it ensures proper command execution and prevents buffer overflow.

```javascript
await Exporter.streamGCodeWithAck(gcode, {
    timeout: 60000,  // optional: timeout per command in ms (default: null = no timeout)
    onProgress: (current, total, line) => {
        const percent = Math.round((current / total) * 100);
        console.log(`Progress: ${current}/${total} (${percent}%) - ${line}`);
    }
});
```

> **Note**: `streamGCodeWithAck` is only available in Node.js. Browser environments should use `streamGCode` with an appropriate delay.

#### Disconnecting

```javascript
await Exporter.disconnectSerial();
```

## Complete Examples

### Sending an Entire G-code File (Node.js)

```javascript
const fs = require("fs");
const { Exporter } = require("@jgphilpott/polyslice");

async function printFile(filepath) {
    // Read G-code file
    const gcode = fs.readFileSync(filepath, "utf8");
    
    // Connect to printer
    await Exporter.connectSerial({
        path: "/dev/ttyUSB0",
        baudRate: 115200
    });
    
    console.log("Connected! Starting print...");
    
    // Stream with acknowledgment (recommended for Node.js)
    const result = await Exporter.streamGCodeWithAck(gcode, {
        onProgress: (current, total, line) => {
            const percent = Math.round((current / total) * 100);
            process.stdout.write(`\rProgress: ${percent}%`);
        }
    });
    
    console.log(`\nComplete! Sent ${result.totalLines} lines.`);
    
    // Disconnect
    await Exporter.disconnectSerial();
}

printFile("myprint.gcode").catch(console.error);
```

### Browser: Streaming with Progress

```javascript
// Assumes Polyslice is loaded via script tag
const exporter = window.PolysliceExporter;

async function streamToPrinter(gcode) {
    // Connect (will prompt user to select port)
    await exporter.connectSerial({ baudRate: 115200 });
    
    // Stream with delay (browser must use delay-based method)
    await exporter.streamGCode(gcode, {
        delay: 50,  // 50ms between lines
        onProgress: (current, total, line) => {
            document.getElementById("progress").textContent = 
                `${current}/${total}: ${line}`;
        }
    });
    
    // Disconnect
    await exporter.disconnectSerial();
}
```

### Complete Workflow: Slice and Print

```javascript
const { Polyslice, Exporter, Printer, Filament } = require("@jgphilpott/polyslice");

async function sliceAndPrint(mesh) {
    // 1. Configure slicer
    const slicer = new Polyslice({
        printer: new Printer("Ender3"),
        filament: new Filament("GenericPLA")
    });
    
    // 2. Generate G-code
    const gcode = slicer.slice(mesh);
    
    // 3. Save a copy to file
    await Exporter.saveToFile(gcode, "print-backup.gcode");
    
    // 4. Connect to printer
    await Exporter.connectSerial({
        path: "/dev/ttyUSB0",
        baudRate: 115200
    });
    
    // 5. Stream to printer with acknowledgment
    await Exporter.streamGCodeWithAck(gcode, {
        onProgress: (current, total) => {
            console.log(`${Math.round((current / total) * 100)}%`);
        }
    });
    
    // 6. Disconnect
    await Exporter.disconnectSerial();
    
    console.log("Print complete!");
}
```

## API Reference

### `saveToFile(gcode, filename)`

Save G-code to a file.

**Parameters:**
- `gcode` (string): The G-code content to save
- `filename` (string): The filename (default: `"output.gcode"`)

**Returns:** `Promise<string>` - The saved file path

**Behavior:**
- **Browser**: Triggers a download dialog
- **Node.js**: Writes to the file system, returns absolute path

---

### `connectSerial(options)`

Connect to a serial port.

**Parameters:**
- `options.path` (string): Serial port path (Node.js only, e.g., `"/dev/ttyUSB0"`, `"COM3"`)
- `options.baudRate` (number): Baud rate (default: `115200`)
- `options.dataBits` (number): Data bits (default: `8`)
- `options.stopBits` (number): Stop bits (default: `1`)
- `options.parity` (string): Parity - `"none"`, `"even"`, `"odd"` (default: `"none"`)
- `options.flowControl` (string): Flow control - `"none"`, `"hardware"` (default: `"none"`)
- `options.filters` (object): USB vendor/product ID filters (browser only)

**Returns:** `Promise<SerialPort>` - The connected serial port object

**Behavior:**
- **Browser**: Prompts user to select a serial port via Web Serial API
- **Node.js**: Connects directly to the specified path using the `serialport` package

---

### `disconnectSerial()`

Disconnect from the serial port.

**Returns:** `Promise<void>`

---

### `sendLine(line)`

Send a single G-code line to the serial port.

**Parameters:**
- `line` (string): The G-code line to send (newline is added automatically)

**Returns:** `Promise<void>`

**Throws:** Error if not connected to a serial port

---

### `streamGCode(gcode, options)`

Stream G-code line-by-line to the serial port using delay-based timing.

> **Note**: This method does NOT wait for printer acknowledgment. For Node.js, consider using `streamGCodeWithAck()` instead.

**Parameters:**
- `gcode` (string): The complete G-code to stream
- `options.delay` (number): Delay between lines in milliseconds (default: `0`)
- `options.onProgress` (function): Callback function `(current, total, line) => void`

**Returns:** `Promise<{ totalLines: number, success: boolean }>`

**Behavior:**
- Skips empty lines and comment-only lines (starting with `;`)
- Works in both browser and Node.js environments

---

### `streamGCodeWithAck(gcode, options)`

Stream G-code line-by-line to the serial port, waiting for printer acknowledgment ("ok") before sending each line. **Node.js only.**

This is the **recommended method for Node.js** as it:
- Ensures each command is processed before sending the next
- Prevents printer buffer overflow
- Provides reliable print execution

**Parameters:**
- `gcode` (string): The complete G-code to stream
- `options.timeout` (number|null): Timeout per command in milliseconds (default: `null` = no timeout). When specified, an error is thrown if acknowledgment is not received within this time.
- `options.onProgress` (function): Callback function `(current, total, line) => void`

**Returns:** `Promise<{ totalLines: number, success: boolean }>`

**Throws:**
- Error if not connected
- Error if called from browser environment
- Error if timeout is reached without acknowledgment (when timeout is specified)

**Example with timeout:**
```javascript
await Exporter.streamGCodeWithAck(gcode, {
    timeout: 60000,  // 60 second timeout per command
    onProgress: (current, total, line) => {
        console.log(`${current}/${total}: ${line}`);
    }
});
```

**Example without timeout (default):**
```javascript
// Will wait indefinitely for each acknowledgment
await Exporter.streamGCodeWithAck(gcode, {
    onProgress: (current, total, line) => {
        console.log(`${current}/${total}: ${line}`);
    }
});
```

---

### `readResponse(timeout)`

Read a response from the serial port.

**Parameters:**
- `timeout` (number): Timeout in milliseconds (default: `1000`)

**Returns:** `Promise<string>` - The response string

**Throws:** Error if read times out or if not connected

## Environment Compatibility

### Node.js

Requires the `serialport` package for serial communication:

```bash
npm install serialport
```

File saving uses the built-in `fs` module.

**Serial Port Paths:**
- Linux: `/dev/ttyUSB0`, `/dev/ttyACM0`
- macOS: `/dev/tty.usbserial-XXXX`, `/dev/tty.usbmodem-XXXX`
- Windows: `COM3`, `COM4`, etc.

### Browser

- File saving uses the Blob API and `URL.createObjectURL()`
- Serial communication uses the [Web Serial API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API)
- Supported browsers: Chrome 89+, Edge 89+, Opera 76+
- No additional dependencies required

## Choosing a Streaming Method

| Method | Environment | Use Case |
|--------|-------------|----------|
| `streamGCode` | Browser + Node.js | Simple streaming with fixed delay |
| `streamGCodeWithAck` | Node.js only | **Recommended** - Reliable streaming with acknowledgment |

**When to use `streamGCode`:**
- Browser-based applications
- Quick testing with short G-code snippets
- When acknowledgment isn't critical

**When to use `streamGCodeWithAck`:**
- Production prints in Node.js
- Long-running print jobs
- When reliability is important
- When you need to ensure each command completes

## Examples

See these example files for complete usage:

- `examples/scripts/exporter-usage.js` - Basic exporter usage demonstrating file saving and serial connection patterns
- `examples/scripts/send-file.js` - Command-line tool to send entire G-code files to a printer using `streamGCodeWithAck`
- `examples/serial/node/usb.js` - Simple Node.js example showing single-command serial communication
- `examples/serial/browser/sender.js` - Full-featured browser-based G-code sender with UI

## Notes

- Web Serial API requires user interaction (button click) to request port access
- Serial communication requires proper permissions on the operating system
- G-code comments (lines starting with `;`) are automatically skipped during streaming
- Empty lines are filtered out during streaming
- The Exporter is a singleton - use `Exporter` directly, not `new Exporter()`
- In browser, access via `window.PolysliceExporter`

## Troubleshooting

### "Not connected to serial port"

Ensure you've called `connectSerial()` and awaited it before sending commands.

### "serialport package not found"

Install the serialport package for Node.js:
```bash
npm install serialport
```

### "Web Serial API is not supported"

Use a supported browser: Chrome 89+, Edge 89+, or Opera 76+.

### Timeout errors with `streamGCodeWithAck`

Some commands (like heating) take a long time. Either:
- Use a longer timeout value
- Use `timeout: null` (default) to wait indefinitely
- Use `M104`/`M140` (non-blocking) instead of `M109`/`M190` (blocking)

### Permission denied on serial port (Linux)

Add your user to the `dialout` group:
```bash
sudo usermod -a -G dialout $USER
# Log out and back in for changes to take effect
```

