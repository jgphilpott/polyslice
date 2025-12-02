---
applyTo: 'src/exporters/**/*.coffee'
---

# Exporters Module Overview

The exporters module handles G-code output for Polyslice. Located in `src/exporters/`.

## Purpose

- Save G-code to files (browser download or Node.js file system)
- Stream G-code to 3D printers via serial port
- Work in both Node.js and browser environments
- Provide cross-platform serial communication

## Exporter Class

Located in `src/exporters/exporter.coffee`.

### Singleton Pattern

The module exports a singleton instance:

```coffeescript
exporter = new Exporter()

# Node.js
module.exports = exporter

# Browser
window.PolysliceExporter = exporter
```

### Constructor

```coffeescript
constructor: ->
    @serialPort = null
    @writer = null
    @reader = null
    @connected = false
```

### Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `DEFAULT_ACK_TIMEOUT` | `null` | Default timeout for acknowledgment-based streaming (null = no timeout) |

## File Export

### saveToFile

Saves G-code to a file with environment-appropriate method.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `gcode` | String | required | G-code content to save |
| `filename` | String | `'output.gcode'` | Output filename |

**Returns:** `Promise<String>` - Resolves with filepath (Node.js) or filename (browser)

```coffeescript
exporter.saveToFile(gcode, 'output.gcode')
    .then (filepath) -> console.log("Saved to: #{filepath}")
    .catch (error) -> console.error(error)
```

### Browser Behavior

Triggers a download via temporary anchor element:

```coffeescript
_saveToFileBrowser: (gcode, filename) ->
    blob = new Blob([gcode], { type: 'text/plain' })
    url = URL.createObjectURL(blob)
    link = document.createElement('a')
    link.href = url
    link.download = filename
    link.click()
    URL.revokeObjectURL(url)
```

### Node.js Behavior

Writes directly to file system:

```coffeescript
_saveToFileNode: (gcode, filename) ->
    fs = require('fs')
    path = require('path')
    filepath = path.resolve(filename)
    fs.writeFile(filepath, gcode, 'utf8', callback)
```

## Serial Port Communication

### connectSerial

Connects to a 3D printer via serial port.

**Parameters:**

| Parameter | Type | Default | Environment | Description |
|-----------|------|---------|-------------|-------------|
| `options.path` | String | `'/dev/ttyUSB0'` | Node.js only | Serial port path |
| `options.baudRate` | Number | `115200` | Both | Connection baud rate |
| `options.dataBits` | Number | `8` | Both | Data bits |
| `options.stopBits` | Number | `1` | Both | Stop bits |
| `options.parity` | String | `'none'` | Both | Parity setting |
| `options.flowControl` | String | `'none'` | Browser only | Flow control |
| `options.filters` | Object | `{}` | Browser only | USB device filters for port selection |

**Returns:** `Promise<SerialPort>` - Resolves with the connected serial port

```coffeescript
exporter.connectSerial({
    path: '/dev/ttyUSB0'      # Node.js only
    baudRate: 115200          # Default
    dataBits: 8               # Default
    stopBits: 1               # Default
    parity: 'none'            # Default
    flowControl: 'none'       # Browser only
})
```

### Browser Serial (Web Serial API)

Uses navigator.serial with user permission prompt:

```coffeescript
_connectSerialBrowser: (options) ->
    navigator.serial.requestPort(options.filters or {})
        .then (port) =>
            @serialPort = port
            @serialPort.open(connectionOptions)
                .then =>
                    @connected = true
                    @writer = @serialPort.writable.getWriter()
                    @reader = @serialPort.readable.getReader()
```

### Node.js Serial

Uses the `serialport` npm package:

```coffeescript
_connectSerialNode: (options) ->
    { SerialPort } = require('serialport')
    @serialPort = new SerialPort({
        path: options.path or '/dev/ttyUSB0'
        baudRate: options.baudRate or 115200
    })
```

### disconnectSerial

Disconnects from serial port and cleans up resources.

**Returns:** `Promise<void>` - Resolves when disconnected

```coffeescript
exporter.disconnectSerial()
    .then -> console.log('Disconnected')
```

Cleanup behavior:
- Browser: Releases writer/reader locks, closes port
- Node.js: Closes serial port connection
- Resets `@connected`, `@serialPort`, `@writer`, `@reader` to initial state

## G-code Streaming

Two streaming methods are available for sending G-code to a connected printer:

| Method | Environment | Flow Control | Recommended For |
|--------|-------------|--------------|-----------------|
| `streamGCode` | Both | Delay-based | Browser, simple streaming |
| `streamGCodeWithAck` | Node.js only | Acknowledgment-based | Node.js production use |

### streamGCode

Streams G-code line-by-line with optional delay between lines. Does NOT wait for printer acknowledgment.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `gcode` | String | required | Complete G-code to stream |
| `options.delay` | Number | `0` | Milliseconds between lines |
| `options.onProgress` | Function | `null` | Progress callback `(current, total, line)` |

**Returns:** `Promise<Object>` - Resolves with `{ totalLines: Number, success: Boolean }`

```coffeescript
exporter.streamGCode(gcode, {
    delay: 100                           # ms between lines (optional)
    onProgress: (current, total, line) ->
        console.log("#{current}/#{total}: #{line}")
})
```

**Behavior:**
- Splits G-code into lines, filters empty lines
- Skips comment lines (starting with `;`) and empty lines
- Sends each line with optional delay between sends
- Calls progress callback before each line is sent

### streamGCodeWithAck

**Node.js only.** Streams G-code waiting for printer "ok" acknowledgment before sending each line. This is the **recommended method for Node.js** to ensure proper command execution.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `gcode` | String | required | Complete G-code to stream |
| `options.timeout` | Number | `null` | Timeout in ms for each acknowledgment (`null` = no timeout) |
| `options.onProgress` | Function | `null` | Progress callback `(current, total, line)` |

**Returns:** `Promise<Object>` - Resolves with `{ totalLines: Number, success: Boolean }`

```coffeescript
# Basic usage (no timeout - waits indefinitely for each acknowledgment)
exporter.streamGCodeWithAck(gcode, {
    onProgress: (current, total, line) ->
        console.log("#{current}/#{total}: #{line}")
})

# With timeout (rejects if printer doesn't respond within timeout)
exporter.streamGCodeWithAck(gcode, {
    timeout: 30000  # 30 seconds per command
    onProgress: (current, total, line) ->
        console.log("#{current}/#{total}: #{line}")
})
```

**Acknowledgment Detection:**

The method detects Marlin firmware "ok" responses:
- Looks for `ok` at the start of a line or after newline
- Case-insensitive matching
- Handles both `ok` and `ok ` (with trailing content)

**Internal State:**

| Flag | Purpose |
|------|---------|
| `waitingForAck` | Prevents premature acknowledgment detection from previous responses |
| `responseBuffer` | Accumulates serial data until acknowledgment is found |
| `isComplete` | Prevents further processing after completion or error |

**Error Handling:**
- Rejects if not connected: `"Not connected to serial port"`
- Rejects in browser: `"streamGCodeWithAck is only available in Node.js. Use streamGCode in browser."`
- Rejects on timeout: `"Timeout waiting for acknowledgment on line N: <line>"`

### sendLine

Sends a single G-code line via serial port.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `line` | String | G-code command to send (newline added automatically) |

**Returns:** `Promise<void>` - Resolves when line is sent

```coffeescript
exporter.sendLine('G28')  # Send single command
    .then -> console.log('Sent')
```

### readResponse

Reads response from serial port with timeout.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `timeout` | Number | `1000` | Timeout in milliseconds |

**Returns:** `Promise<String|null>` - Resolves with response text, or null if stream ended

```coffeescript
exporter.readResponse(timeout = 1000)
    .then (response) -> console.log(response)  # e.g., "ok"
```

## Environment Requirements

### Browser

Web Serial API is required for serial communication:
- Chrome 89+
- Edge 89+
- Opera 75+
- Not supported in Firefox/Safari

### Node.js

For serial communication, install the serialport package:

```bash
npm install serialport
```

## Usage Examples

### Save to File

```coffeescript
Polyslice = require('@jgphilpott/polyslice')
exporter = Polyslice.exporter

slicer = new Polyslice()
gcode = slicer.slice(mesh)

exporter.saveToFile(gcode, 'print.gcode')
    .then (filepath) -> console.log("Saved to: #{filepath}")
```

### Browser Streaming (Delay-Based)

```coffeescript
# Browser: Use streamGCode with delay
exporter.connectSerial({ baudRate: 115200 })
    .then -> exporter.streamGCode(gcode, { delay: 50 })
    .then (result) -> console.log("Sent #{result.totalLines} lines")
    .then -> exporter.disconnectSerial()
```

### Node.js Streaming (Recommended: Acknowledgment-Based)

```coffeescript
# Node.js: Use streamGCodeWithAck for reliable execution
exporter.connectSerial({ path: '/dev/ttyUSB0', baudRate: 115200 })
    .then -> exporter.streamGCodeWithAck(gcode, {
        onProgress: (current, total, line) ->
            percent = Math.round(current / total * 100)
            console.log("[#{percent}%] #{line}")
    })
    .then (result) -> console.log("Print complete: #{result.totalLines} lines")
    .then -> exporter.disconnectSerial()
    .catch (error) -> console.error("Print failed: #{error.message}")
```

### Node.js Streaming with Timeout

```coffeescript
# Node.js: With timeout for each command
exporter.connectSerial({ path: '/dev/ttyUSB0', baudRate: 115200 })
    .then -> exporter.streamGCodeWithAck(gcode, {
        timeout: 60000  # 60 seconds per command (for long heating commands)
        onProgress: (current, total, line) ->
            console.log("#{current}/#{total}: #{line}")
    })
    .then -> exporter.disconnectSerial()
```

## Error Handling

```coffeescript
# Not connected
exporter.sendLine('G28')  # Rejects: "Not connected to serial port"

# Browser without Web Serial API
exporter.connectSerial()  # Rejects: "Web Serial API is not supported in this browser"

# Node.js without serialport package
exporter.connectSerial()  # Rejects: "serialport package not found. Install it with: npm install serialport"

# streamGCodeWithAck in browser
exporter.streamGCodeWithAck(gcode)  # Rejects: "streamGCodeWithAck is only available in Node.js. Use streamGCode in browser."

# Acknowledgment timeout (Node.js)
exporter.streamGCodeWithAck(gcode, { timeout: 1000 })
# May reject: "Timeout waiting for acknowledgment on line 5: G28"
```

## Important Conventions

1. **Promise-based API**: All methods return Promises
2. **Environment detection**: Uses `typeof window` to determine environment
3. **Singleton pattern**: Single exporter instance for the application
4. **Connection state**: Track `@connected` flag for all serial operations
5. **Cleanup**: Properly release locks and close ports on disconnect
6. **Progress callbacks**: Optional callbacks for streaming progress
7. **Streaming method selection**:
   - Browser: Use `streamGCode` with appropriate delay
   - Node.js (simple): Use `streamGCode` with delay for basic streaming
   - Node.js (recommended): Use `streamGCodeWithAck` for reliable command execution
8. **No default timeout**: `DEFAULT_ACK_TIMEOUT` is `null`, meaning acknowledgment-based streaming waits indefinitely unless `options.timeout` is specified
9. **Acknowledgment safety**: The `waitingForAck` flag prevents false acknowledgment detection from buffered serial data
