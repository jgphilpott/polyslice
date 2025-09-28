# Tests for the Polyslice class

Polyslice = require('./index')

describe 'Polyslice', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Constructor and Default Values', ->

        test 'should create a new instance with default options', ->

            expect(slicer).toBeInstanceOf(Polyslice)
            expect(slicer.getAutohome()).toBe(true)
            expect(slicer.getWorkspacePlane()).toBe('XY')
            expect(slicer.getTimeUnit()).toBe('milliseconds')
            expect(slicer.getLengthUnit()).toBe('millimeters')
            expect(slicer.getTemperatureUnit()).toBe('celsius')
            expect(slicer.getNozzleTemperature()).toBe(0)
            expect(slicer.getBedTemperature()).toBe(0)
            expect(slicer.getFanSpeed()).toBe(100)

        test 'should create instance with custom options', ->

            customSlicer = new Polyslice({
                autohome: false
                workspacePlane: 'XZ'
                timeUnit: 'seconds'
                lengthUnit: 'inches'
                temperatureUnit: 'fahrenheit'
                nozzleTemperature: 200
                bedTemperature: 60
                fanSpeed: 75
            })

            expect(customSlicer.getAutohome()).toBe(false)
            expect(customSlicer.getWorkspacePlane()).toBe('XZ')
            expect(customSlicer.getTimeUnit()).toBe('seconds')
            expect(customSlicer.getLengthUnit()).toBe('inches')
            expect(customSlicer.getTemperatureUnit()).toBe('fahrenheit')
            expect(customSlicer.getNozzleTemperature()).toBe(200)
            expect(customSlicer.getBedTemperature()).toBe(60)
            expect(customSlicer.getFanSpeed()).toBe(75)

    describe 'Setters and Getters', ->

        test 'should set and get workspace plane', ->

            slicer.setWorkspacePlane('XZ')
            expect(slicer.getWorkspacePlane()).toBe('XZ')

            slicer.setWorkspacePlane('YZ')
            expect(slicer.getWorkspacePlane()).toBe('YZ')

            # Should ignore invalid values.
            slicer.setWorkspacePlane('invalid')
            expect(slicer.getWorkspacePlane()).toBe('YZ') # unchanged

        test 'should set and get time unit', ->

            slicer.setTimeUnit('seconds')
            expect(slicer.getTimeUnit()).toBe('seconds')

            slicer.setTimeUnit('milliseconds')
            expect(slicer.getTimeUnit()).toBe('milliseconds')

            # Should ignore invalid values.
            slicer.setTimeUnit('invalid')
            expect(slicer.getTimeUnit()).toBe('milliseconds') # unchanged

        test 'should set and get temperatures', ->

            slicer.setNozzleTemperature(210)
            expect(slicer.getNozzleTemperature()).toBe(210)

            slicer.setBedTemperature(65)
            expect(slicer.getBedTemperature()).toBe(65)

            # Should ignore negative values.
            slicer.setNozzleTemperature(-10)
            expect(slicer.getNozzleTemperature()).toBe(210) # unchanged

        test 'should set and get fan speed', ->

            slicer.setFanSpeed(50)
            expect(slicer.getFanSpeed()).toBe(50)

            # Should ignore values outside range.
            slicer.setFanSpeed(-10)
            expect(slicer.getFanSpeed()).toBe(50) # unchanged

            slicer.setFanSpeed(150)
            expect(slicer.getFanSpeed()).toBe(50) # unchanged

    describe 'G-code Generation', ->

        test 'should generate autohome G-code', ->

            gcode = slicer.codeAutohome()
            expect(gcode).toBe('G28\n')

            xcodeHome = slicer.codeAutohome(true, false, false)
            expect(xcodeHome).toBe('G28 X\n')

        test 'should generate workspace plane G-code', ->

            expect(slicer.codeWorkspacePlane()).toBe('G17\n') # XY plane

            slicer.setWorkspacePlane('XZ')
            expect(slicer.codeWorkspacePlane()).toBe('G18\n')

            slicer.setWorkspacePlane('YZ')
            expect(slicer.codeWorkspacePlane()).toBe('G19\n')

        test 'should generate length unit G-code', ->

            expect(slicer.codeLengthUnit()).toBe('G21\n') # millimeters

            slicer.setLengthUnit('inches')
            expect(slicer.codeLengthUnit()).toBe('G20\n')

        test 'should generate temperature unit G-code', ->

            expect(slicer.codeTemperatureUnit()).toBe('M149 C\n') # celsius

            slicer.setTemperatureUnit('fahrenheit')
            expect(slicer.codeTemperatureUnit()).toBe('M149 F\n')

            slicer.setTemperatureUnit('kelvin')
            expect(slicer.codeTemperatureUnit()).toBe('M149 K\n')

        test 'should generate linear movement G-code', ->

            moveCode = slicer.codeLinearMovement(10, 20, 5)
            expect(moveCode).toBe('G0 X10 Y20 Z5\n') # G0 for non-extruding move

            extrudeCode = slicer.codeLinearMovement(10, 20, 5, 0.1, 1500)
            expect(extrudeCode).toBe('G1 X10 Y20 Z5 E0.1 F1500\n') # G1 for extruding move

        test 'should generate temperature G-code', ->

            nozzleCode = slicer.codeNozzleTemperature(200, false)
            expect(nozzleCode).toBe('M104 S200\n') # Set without waiting

            bedCode = slicer.codeBedTemperature(60, false)
            expect(bedCode).toBe('M140 S60\n') # Set without waiting

        test 'should generate fan speed G-code', ->

            fanCode = slicer.codeFanSpeed(50)
            expect(fanCode).toBe('M106 S127\n') # 50% * 2.55 = 127.5, rounded to 127

            fanOffCode = slicer.codeFanSpeed(0)
            expect(fanOffCode).toBe('M107\n') # Fan off

    describe 'Basic Slicing', ->

        test 'should perform basic slice with autohome', ->

            result = slicer.slice()
            expect(result).toContain('G28\n') # Should contain autohome

        test 'should skip autohome if disabled', ->

            slicer.setAutohome(false)
            result = slicer.slice()
            expect(result).toBe('') # Should be empty without autohome
