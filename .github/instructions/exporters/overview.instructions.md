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

## File Export

### saveToFile

Saves G-code to a file with environment-appropriate method:

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

### Connection

Connect to a 3D printer via serial port:

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

### Disconnection

```coffeescript
exporter.disconnectSerial()
    .then -> console.log('Disconnected')
```

## G-code Streaming

### streamGCode

Streams G-code line-by-line to connected printer:

```coffeescript
exporter.streamGCode(gcode, {
    delay: 100                           # ms between lines (optional)
    onProgress: (current, total, line) ->
        console.log("#{current}/#{total}: #{line}")
})
```

### Line-by-Line Sending

```coffeescript
sendNextLine = =>
    if currentLine >= lines.length
        resolve({ totalLines: lines.length, success: true })
        return

    line = lines[currentLine].trim()
    currentLine++

    # Skip comments and empty lines
    if line.startsWith(';') or line.length is 0
        setTimeout sendNextLine, 0
        return

    @sendLine(line).then =>
        if delay > 0
            setTimeout sendNextLine, delay
        else
            sendNextLine()
```

### Single Line Sending

```coffeescript
exporter.sendLine('G28')  # Send single command
    .then -> console.log('Sent')
```

### Reading Responses

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

## Usage with Polyslice

```coffeescript
Polyslice = require('@jgphilpott/polyslice')
exporter = Polyslice.exporter

# Slice a mesh
slicer = new Polyslice()
gcode = slicer.slice(mesh)

# Save to file
exporter.saveToFile(gcode, 'print.gcode')

# Or stream to printer
exporter.connectSerial({ baudRate: 115200 })
    .then -> exporter.streamGCode(gcode, { delay: 50 })
    .then -> exporter.disconnectSerial()
```

## Error Handling

```coffeescript
# Not connected
exporter.sendLine('G28')  # Rejects: "Not connected to serial port"

# Browser without Web Serial API
exporter.connectSerial()  # Rejects: "Web Serial API is not supported"

# Node.js without serialport package
exporter.connectSerial()  # Rejects: "serialport package not found"
```

## Important Conventions

1. **Promise-based API**: All methods return Promises
2. **Environment detection**: Uses `typeof window` to determine environment
3. **Singleton pattern**: Single exporter instance for the application
4. **Connection state**: Track `@connected` flag for all serial operations
5. **Cleanup**: Properly release locks and close ports on disconnect
6. **Progress callbacks**: Optional callbacks for streaming progress
