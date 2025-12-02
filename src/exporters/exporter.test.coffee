# Tests for the Exporter module

Exporter = require('./exporter')
fs = require('fs')
path = require('path')
os = require('os')

# Test directory for file operations (using cross-platform temp directory).
TEST_DIR = path.join(os.tmpdir(), 'polyslice-exporter-tests')

describe 'Exporter', ->

    # Store original state to restore after tests.
    originalConnected = null
    originalSerialPort = null
    originalWriter = null
    originalReader = null

    # Ensure test directory exists before tests.
    beforeAll ->

        # Save original state.
        originalConnected = Exporter.connected
        originalSerialPort = Exporter.serialPort
        originalWriter = Exporter.writer
        originalReader = Exporter.reader

        if not fs.existsSync(TEST_DIR)
            fs.mkdirSync(TEST_DIR, { recursive: true })

    # Clean up test directory after all tests.
    afterAll ->

        # Restore original state to prevent test pollution.
        Exporter.connected = originalConnected
        Exporter.serialPort = originalSerialPort
        Exporter.writer = originalWriter
        Exporter.reader = originalReader

        if fs.existsSync(TEST_DIR)
            fs.rmSync(TEST_DIR, { recursive: true, force: true })

    # Reset exporter state before each test to prevent pollution.
    beforeEach ->

        Exporter.connected = false
        Exporter.serialPort = null
        Exporter.writer = null
        Exporter.reader = null

    describe 'Constructor and Initial State', ->

        test 'should export a singleton instance', ->

            expect(Exporter).toBeDefined()

        test 'should initialize with connected = false', ->

            expect(Exporter.connected).toBe(false)

        test 'should initialize with serialPort = null', ->

            expect(Exporter.serialPort).toBeNull()

        test 'should initialize with writer = null', ->

            expect(Exporter.writer).toBeNull()

        test 'should initialize with reader = null', ->

            expect(Exporter.reader).toBeNull()

        test 'should have DEFAULT_ACK_TIMEOUT set to null', ->

            expect(Exporter.DEFAULT_ACK_TIMEOUT).toBeNull()

    describe 'Public Methods Existence', ->

        test 'should have saveToFile method', ->

            expect(typeof Exporter.saveToFile).toBe('function')

        test 'should have connectSerial method', ->

            expect(typeof Exporter.connectSerial).toBe('function')

        test 'should have disconnectSerial method', ->

            expect(typeof Exporter.disconnectSerial).toBe('function')

        test 'should have sendLine method', ->

            expect(typeof Exporter.sendLine).toBe('function')

        test 'should have streamGCode method', ->

            expect(typeof Exporter.streamGCode).toBe('function')

        test 'should have streamGCodeWithAck method', ->

            expect(typeof Exporter.streamGCodeWithAck).toBe('function')

        test 'should have readResponse method', ->

            expect(typeof Exporter.readResponse).toBe('function')

    describe 'Node.js File Saving', ->

        test 'should save file in Node.js environment', ->

            gcode = '; Test G-code\nG28\nG0 X10 Y10'
            filename = path.join(TEST_DIR, 'test-output.gcode')

            result = await Exporter.saveToFile(gcode, filename)

            expect(result).toBe(filename)

            # Verify file was created.
            expect(fs.existsSync(filename)).toBe(true)

            # Verify file content.
            content = fs.readFileSync(filename, 'utf8')
            expect(content).toBe(gcode)

        test 'should save file with default filename when not provided', ->

            gcode = 'G28\nG0 X0 Y0'

            result = await Exporter.saveToFile(gcode)

            # Result should be an absolute path ending with output.gcode.
            expect(result).toContain('output.gcode')
            expect(fs.existsSync(result)).toBe(true)

            # Clean up.
            fs.unlinkSync(result)

        test 'should save empty G-code file', ->

            gcode = ''
            filename = path.join(TEST_DIR, 'empty-output.gcode')

            result = await Exporter.saveToFile(gcode, filename)

            expect(result).toBe(filename)
            expect(fs.existsSync(filename)).toBe(true)

            content = fs.readFileSync(filename, 'utf8')
            expect(content).toBe('')

        test 'should save file with special characters in G-code', ->

            gcode = '; Comment with special chars: @#$%^&*()\nG28 ; Home all axes'
            filename = path.join(TEST_DIR, 'special-chars.gcode')

            result = await Exporter.saveToFile(gcode, filename)

            expect(result).toBe(filename)
            content = fs.readFileSync(filename, 'utf8')
            expect(content).toBe(gcode)

        test 'should save large G-code file', ->

            # Generate a large G-code file (1000 lines).
            lines = []
            for i in [0...1000]
                lines.push("G1 X#{i} Y#{i} Z#{i * 0.1}")
            gcode = lines.join('\n')

            filename = path.join(TEST_DIR, 'large-output.gcode')

            result = await Exporter.saveToFile(gcode, filename)

            expect(result).toBe(filename)
            expect(fs.existsSync(filename)).toBe(true)

            content = fs.readFileSync(filename, 'utf8')
            expect(content).toBe(gcode)

        test 'should overwrite existing file', ->

            filename = path.join(TEST_DIR, 'overwrite-test.gcode')

            # Write first content.
            await Exporter.saveToFile('G28\n', filename)
            expect(fs.readFileSync(filename, 'utf8')).toBe('G28\n')

            # Overwrite with new content.
            await Exporter.saveToFile('G0 X100\n', filename)
            expect(fs.readFileSync(filename, 'utf8')).toBe('G0 X100\n')

    describe 'Serial Port Error Handling', ->

        test 'should reject sendLine when not connected', ->

            await expect(Exporter.sendLine('G28')).rejects.toThrow('Not connected to serial port')

        test 'should reject streamGCode when not connected', ->

            await expect(Exporter.streamGCode('G28\nG0 X10')).rejects.toThrow('Not connected to serial port')

        test 'should reject streamGCodeWithAck when not connected', ->

            await expect(Exporter.streamGCodeWithAck('G28\nG0 X10')).rejects.toThrow('Not connected to serial port')

        test 'should reject readResponse when not connected', ->

            await expect(Exporter.readResponse()).rejects.toThrow('Not connected to serial port')

    describe 'Disconnect Behavior', ->

        test 'should resolve successfully when disconnecting while already disconnected', ->

            # State is already set by beforeEach: connected = false, serialPort = null.

            # Should resolve without error.
            result = await Exporter.disconnectSerial()
            expect(result).toBeUndefined()

        test 'should resolve successfully when disconnecting multiple times', ->

            # First disconnect (already disconnected).
            await Exporter.disconnectSerial()
            expect(Exporter.connected).toBe(false)

            # Second disconnect (still disconnected).
            await Exporter.disconnectSerial()
            expect(Exporter.connected).toBe(false)

    describe 'streamGCodeWithAck Browser Environment Check', ->

        test 'should have streamGCodeWithAck method that checks environment', ->

            # The method exists.
            expect(typeof Exporter.streamGCodeWithAck).toBe('function')

            # Since we're in Node.js and not connected, it should fail with connection error first.
            await expect(Exporter.streamGCodeWithAck('G28')).rejects.toThrow('Not connected to serial port')

    describe 'Streaming G-code Method Signatures', ->

        # These tests verify behavior by inspecting the streamGCode implementation.
        # Since we can't actually connect without hardware, we test the method structure.

        test 'should have streamGCode as a function', ->

            # Verify streamGCode is a function.
            expect(typeof Exporter.streamGCode).toBe('function')

        test 'should have streamGCodeWithAck as a function', ->

            # Verify streamGCodeWithAck is a function.
            expect(typeof Exporter.streamGCodeWithAck).toBe('function')

        test 'should require gcode parameter for streamGCode (at least 1 param)', ->

            # Function.length returns number of parameters before first default value.
            # Since options has a default, length is 1 (just gcode).
            expect(Exporter.streamGCode.length).toBeGreaterThanOrEqual(1)

        test 'should require gcode parameter for streamGCodeWithAck (at least 1 param)', ->

            # Function.length returns number of parameters before first default value.
            # Since options has a default, length is 1 (just gcode).
            expect(Exporter.streamGCodeWithAck.length).toBeGreaterThanOrEqual(1)

    describe 'DEFAULT_ACK_TIMEOUT Property', ->

        test 'should have DEFAULT_ACK_TIMEOUT as null (no timeout by default)', ->

            expect(Exporter.DEFAULT_ACK_TIMEOUT).toBeNull()

        test 'should have DEFAULT_ACK_TIMEOUT be a property not a function', ->

            expect(typeof Exporter.DEFAULT_ACK_TIMEOUT).not.toBe('function')

    describe 'Connection State Properties', ->

        test 'should track connection state with connected property', ->

            # Initially false.
            expect(typeof Exporter.connected).toBe('boolean')
            expect(Exporter.connected).toBe(false)

        test 'should have serialPort property', ->

            expect('serialPort' of Exporter).toBe(true)

        test 'should have writer property', ->

            expect('writer' of Exporter).toBe(true)

        test 'should have reader property', ->

            expect('reader' of Exporter).toBe(true)

    describe 'File Path Resolution', ->

        test 'should resolve relative paths to absolute paths', ->

            gcode = 'G28'
            filename = 'relative-test.gcode'

            result = await Exporter.saveToFile(gcode, filename)

            # Result should be absolute path.
            expect(path.isAbsolute(result)).toBe(true)
            expect(result).toContain(filename)

            # Clean up.
            if fs.existsSync(result)
                fs.unlinkSync(result)

        test 'should handle absolute paths correctly', ->

            gcode = 'G28'
            filename = path.join(TEST_DIR, 'absolute-path-test.gcode')

            result = await Exporter.saveToFile(gcode, filename)

            expect(result).toBe(filename)
            expect(fs.existsSync(filename)).toBe(true)

