# Tests for the Exporter module

Exporter = require('./exporter')

describe 'Exporter', ->

    describe 'File Operations', ->

        test 'should have saveToFile method', ->

            expect(typeof Exporter.saveToFile).toBe('function')

        test 'should export a singleton instance', ->

            expect(Exporter).toBeDefined()
            expect(typeof Exporter.saveToFile).toBe('function')
            expect(typeof Exporter.connectSerial).toBe('function')
            expect(typeof Exporter.disconnectSerial).toBe('function')
            expect(typeof Exporter.sendLine).toBe('function')
            expect(typeof Exporter.streamGCode).toBe('function')
            expect(typeof Exporter.readResponse).toBe('function')

    describe 'Serial Port Operations', ->

        test 'should have connectSerial method', ->

            expect(typeof Exporter.connectSerial).toBe('function')

        test 'should have disconnectSerial method', ->

            expect(typeof Exporter.disconnectSerial).toBe('function')

        test 'should have sendLine method', ->

            expect(typeof Exporter.sendLine).toBe('function')

        test 'should have streamGCode method', ->

            expect(typeof Exporter.streamGCode).toBe('function')

        test 'should have readResponse method', ->

            expect(typeof Exporter.readResponse).toBe('function')

        test 'should start with connected = false', ->

            expect(Exporter.connected).toBe(false)

        test 'should reject sendLine when not connected', ->

            expect(Exporter.sendLine('G28')).rejects.toThrow('Not connected to serial port')

        test 'should reject streamGCode when not connected', ->

            expect(Exporter.streamGCode('G28\nG0 X10')).rejects.toThrow('Not connected to serial port')

        test 'should reject readResponse when not connected', ->

            expect(Exporter.readResponse()).rejects.toThrow('Not connected to serial port')

    describe 'Node.js File Saving', ->

        test 'should save file in Node.js environment', ->

            gcode = '; Test G-code\nG28\nG0 X10 Y10'
            filename = '/tmp/test-output.gcode'

            Exporter.saveToFile(gcode, filename).then (result) ->

                expect(result).toBe(filename)

                # Verify file was created.
                fs = require('fs')
                expect(fs.existsSync(filename)).toBe(true)

                # Clean up.
                fs.unlinkSync(filename)

