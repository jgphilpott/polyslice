# G-code exporter for Polyslice
# Supports saving to file and streaming via serial port
# Works in both Node.js and browser environments

class Exporter

    constructor: ->

        @serialPort = null
        @writer = null
        @reader = null
        @connected = false

    # Save G-code to a file.
    # In browser: triggers download
    # In Node.js: saves to file system
    saveToFile: (gcode, filename = 'output.gcode') ->

        return new Promise (resolve, reject) =>

            try

                if typeof window isnt 'undefined'

                    # Browser environment - trigger download.
                    @_saveToFileBrowser(gcode, filename)
                    resolve(filename)

                else

                    # Node.js environment - save to file system.
                    @_saveToFileNode(gcode, filename).then(resolve).catch(reject)

            catch error

                reject(error)

    # Browser file save implementation.
    _saveToFileBrowser: (gcode, filename) ->

        blob = new Blob([gcode], { type: 'text/plain' })
        url = URL.createObjectURL(blob)

        # Create temporary download link.
        link = document.createElement('a')
        link.href = url
        link.download = filename
        link.style.display = 'none'

        document.body.appendChild(link)
        link.click()

        # Clean up.
        setTimeout ->
            document.body.removeChild(link)
            URL.revokeObjectURL(url)
        , 100

    # Node.js file save implementation.
    _saveToFileNode: (gcode, filename) ->

        return new Promise (resolve, reject) ->

            try

                fs = require('fs')
                path = require('path')

                # Resolve absolute path.
                filepath = path.resolve(filename)

                fs.writeFile filepath, gcode, 'utf8', (error) ->

                    if error
                        reject(error)
                    else
                        resolve(filepath)

            catch error

                reject(error)

    # Connect to serial port.
    # Browser: uses Web Serial API
    # Node.js: uses serialport package
    connectSerial: (options = {}) ->

        return new Promise (resolve, reject) =>

            try

                if typeof window isnt 'undefined'

                    # Browser environment - use Web Serial API.
                    @_connectSerialBrowser(options).then(resolve).catch(reject)

                else

                    # Node.js environment - use serialport package.
                    @_connectSerialNode(options).then(resolve).catch(reject)

            catch error

                reject(error)

    # Browser serial connection using Web Serial API.
    _connectSerialBrowser: (options = {}) ->

        return new Promise (resolve, reject) =>

            try

                if not navigator.serial

                    reject(new Error('Web Serial API is not supported in this browser'))
                    return

                # Request port from user.
                navigator.serial.requestPort(options.filters or {}).then (port) =>

                    @serialPort = port

                    # Default connection options.
                    connectionOptions =
                        baudRate: options.baudRate or 115200
                        dataBits: options.dataBits or 8
                        stopBits: options.stopBits or 1
                        parity: options.parity or 'none'
                        flowControl: options.flowControl or 'none'

                    # Open port.
                    @serialPort.open(connectionOptions).then =>

                        @connected = true
                        @writer = @serialPort.writable.getWriter()
                        @reader = @serialPort.readable.getReader()

                        resolve(@serialPort)

                    .catch(reject)

                .catch(reject)

            catch error

                reject(error)

    # Node.js serial connection using serialport package.
    _connectSerialNode: (options = {}) ->

        return new Promise (resolve, reject) =>

            try

                { SerialPort } = require('serialport')

                # Default connection options.
                portPath = options.path or '/dev/ttyUSB0'
                baudRate = options.baudRate or 115200

                @serialPort = new SerialPort({
                    path: portPath
                    baudRate: baudRate
                    dataBits: options.dataBits or 8
                    stopBits: options.stopBits or 1
                    parity: options.parity or 'none'
                }, (error) =>

                    if error
                        reject(error)
                    else
                        @connected = true
                        resolve(@serialPort)

                )

            catch error

                # If serialport is not installed, provide helpful error.
                if error.code is 'MODULE_NOT_FOUND'
                    reject(new Error('serialport package not found. Install it with: npm install serialport'))
                else
                    reject(error)

    # Disconnect from serial port.
    disconnectSerial: ->

        return new Promise (resolve, reject) =>

            try

                if not @connected
                    resolve()
                    return

                if typeof window isnt 'undefined'

                    # Browser environment.
                    if @writer
                        @writer.releaseLock()
                    if @reader
                        @reader.releaseLock()
                    if @serialPort
                        @serialPort.close().then =>
                            @connected = false
                            @serialPort = null
                            @writer = null
                            @reader = null
                            resolve()
                        .catch(reject)
                    else
                        resolve()

                else

                    # Node.js environment.
                    if @serialPort
                        @serialPort.close (error) =>
                            if error
                                reject(error)
                            else
                                @connected = false
                                @serialPort = null
                                resolve()
                    else
                        resolve()

            catch error

                reject(error)

    # Send G-code line via serial port.
    sendLine: (line) ->

        return new Promise (resolve, reject) =>

            if not @connected
                reject(new Error('Not connected to serial port'))
                return

            try

                if typeof window isnt 'undefined'

                    # Browser environment - use writer.
                    encoder = new TextEncoder()
                    data = encoder.encode(line + '\n')
                    @writer.write(data).then(resolve).catch(reject)

                else

                    # Node.js environment - use serialport write.
                    @serialPort.write(line + '\n', (error) ->
                        if error
                            reject(error)
                        else
                            resolve()
                    )

            catch error

                reject(error)

    # Stream G-code to serial port.
    # Sends line by line with optional delay between lines.
    streamGCode: (gcode, options = {}) ->

        return new Promise (resolve, reject) =>

            if not @connected
                reject(new Error('Not connected to serial port'))
                return

            try

                lines = gcode.split('\n').filter (line) ->
                    line.trim().length > 0

                delay = options.delay or 0
                currentLine = 0

                sendNextLine = =>

                    if currentLine >= lines.length
                        resolve({ totalLines: lines.length, success: true })
                        return

                    line = lines[currentLine].trim()
                    currentLine++

                    # Skip comments and empty lines.
                    if line.startsWith(';') or line.length is 0
                        setTimeout sendNextLine, 0
                        return

                    # Call progress callback if provided.
                    if options.onProgress
                        options.onProgress(currentLine, lines.length, line)

                    @sendLine(line).then =>
                        if delay > 0
                            setTimeout sendNextLine, delay
                        else
                            sendNextLine()
                    .catch(reject)

                sendNextLine()

            catch error

                reject(error)

    # Read from serial port (for responses).
    readResponse: (timeout = 1000) ->

        return new Promise (resolve, reject) =>

            if not @connected
                reject(new Error('Not connected to serial port'))
                return

            try

                if typeof window isnt 'undefined'

                    # Browser environment - read from reader.
                    timeoutHandle = setTimeout ->
                        reject(new Error('Read timeout'))
                    , timeout

                    @reader.read().then (result) =>
                        clearTimeout(timeoutHandle)
                        if result.done
                            resolve(null)
                        else
                            decoder = new TextDecoder()
                            resolve(decoder.decode(result.value))
                    .catch (error) =>
                        clearTimeout(timeoutHandle)
                        reject(error)

                else

                    # Node.js environment - read from serialport.
                    timeoutHandle = setTimeout =>
                        @serialPort.removeListener('data', dataHandler)
                        reject(new Error('Read timeout'))
                    , timeout

                    dataHandler = (data) =>
                        clearTimeout(timeoutHandle)
                        @serialPort.removeListener('data', dataHandler)
                        resolve(data.toString())

                    @serialPort.on('data', dataHandler)

            catch error

                reject(error)

# Create singleton instance.
exporter = new Exporter()

# Export for Node.js
if typeof module isnt 'undefined' and module.exports

    module.exports = exporter

# Export for browser environments.
if typeof window isnt 'undefined'

    window.PolysliceExporter = exporter
