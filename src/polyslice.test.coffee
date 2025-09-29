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

            # Test new slicing and extrusion settings
            expect(slicer.getLayerHeight()).toBe(0.2)
            expect(slicer.getExtrusionMultiplier()).toBe(1.0)
            expect(slicer.getFilamentDiameter()).toBe(1.75)
            expect(slicer.getNozzleDiameter()).toBe(0.4)

            # Test new speed settings
            expect(slicer.getPerimeterSpeed()).toBe(30)
            expect(slicer.getInfillSpeed()).toBe(60)
            expect(slicer.getTravelSpeed()).toBe(120)

            # Test new retraction settings
            expect(slicer.getRetractionDistance()).toBe(1.0)
            expect(slicer.getRetractionSpeed()).toBe(40)

            # Test new build plate settings
            expect(slicer.getBuildPlateWidth()).toBe(220)
            expect(slicer.getBuildPlateHeight()).toBe(220)

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

                # New slicing and extrusion settings
                layerHeight: 0.3
                extrusionMultiplier: 1.1
                filamentDiameter: 3.0
                nozzleDiameter: 0.6

                # New speed settings
                perimeterSpeed: 40
                infillSpeed: 80
                travelSpeed: 150

                # New retraction settings
                retractionDistance: 2.0
                retractionSpeed: 50

                # New build plate settings
                buildPlateWidth: 300
                buildPlateHeight: 300
            })

            expect(customSlicer.getAutohome()).toBe(false)
            expect(customSlicer.getWorkspacePlane()).toBe('XZ')
            expect(customSlicer.getTimeUnit()).toBe('seconds')
            expect(customSlicer.getLengthUnit()).toBe('inches')
            expect(customSlicer.getTemperatureUnit()).toBe('fahrenheit')
            expect(customSlicer.getNozzleTemperature()).toBe(200)
            expect(customSlicer.getBedTemperature()).toBe(60)
            expect(customSlicer.getFanSpeed()).toBe(75)

            # Test new settings
            expect(customSlicer.getLayerHeight()).toBe(0.3)
            expect(customSlicer.getExtrusionMultiplier()).toBe(1.1)
            expect(customSlicer.getFilamentDiameter()).toBe(3.0)
            expect(customSlicer.getNozzleDiameter()).toBe(0.6)
            expect(customSlicer.getPerimeterSpeed()).toBe(40)
            expect(customSlicer.getInfillSpeed()).toBe(80)
            expect(customSlicer.getTravelSpeed()).toBe(150)
            expect(customSlicer.getRetractionDistance()).toBe(2.0)
            expect(customSlicer.getRetractionSpeed()).toBe(50)
            expect(customSlicer.getBuildPlateWidth()).toBe(300)
            expect(customSlicer.getBuildPlateHeight()).toBe(300)

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

        test 'should set and get layer height', ->

            slicer.setLayerHeight(0.15)
            expect(slicer.getLayerHeight()).toBe(0.15)

            slicer.setLayerHeight(0.3)
            expect(slicer.getLayerHeight()).toBe(0.3)

            # Should ignore zero and negative values.
            slicer.setLayerHeight(0)
            expect(slicer.getLayerHeight()).toBe(0.3) # unchanged

            slicer.setLayerHeight(-0.1)
            expect(slicer.getLayerHeight()).toBe(0.3) # unchanged

        test 'should set and get extrusion multiplier', ->

            slicer.setExtrusionMultiplier(0.9)
            expect(slicer.getExtrusionMultiplier()).toBe(0.9)

            slicer.setExtrusionMultiplier(1.2)
            expect(slicer.getExtrusionMultiplier()).toBe(1.2)

            # Should ignore zero and negative values.
            slicer.setExtrusionMultiplier(0)
            expect(slicer.getExtrusionMultiplier()).toBe(1.2) # unchanged

            slicer.setExtrusionMultiplier(-0.5)
            expect(slicer.getExtrusionMultiplier()).toBe(1.2) # unchanged

        test 'should set and get filament diameter', ->

            slicer.setFilamentDiameter(3.0)
            expect(slicer.getFilamentDiameter()).toBe(3.0)

            slicer.setFilamentDiameter(2.85)
            expect(slicer.getFilamentDiameter()).toBe(2.85)

            # Should ignore zero and negative values.
            slicer.setFilamentDiameter(0)
            expect(slicer.getFilamentDiameter()).toBe(2.85) # unchanged

        test 'should set and get nozzle diameter', ->

            slicer.setNozzleDiameter(0.6)
            expect(slicer.getNozzleDiameter()).toBe(0.6)

            slicer.setNozzleDiameter(0.8)
            expect(slicer.getNozzleDiameter()).toBe(0.8)

            # Should ignore zero and negative values.
            slicer.setNozzleDiameter(0)
            expect(slicer.getNozzleDiameter()).toBe(0.8) # unchanged

        test 'should set and get speed settings', ->

            # Test perimeter speed
            slicer.setPerimeterSpeed(25)
            expect(slicer.getPerimeterSpeed()).toBe(25)

            # Test infill speed
            slicer.setInfillSpeed(80)
            expect(slicer.getInfillSpeed()).toBe(80)

            # Test travel speed
            slicer.setTravelSpeed(200)
            expect(slicer.getTravelSpeed()).toBe(200)

            # Should ignore zero and negative values.
            slicer.setPerimeterSpeed(0)
            expect(slicer.getPerimeterSpeed()).toBe(25) # unchanged

        test 'should set and get retraction settings', ->

            slicer.setRetractionDistance(1.5)
            expect(slicer.getRetractionDistance()).toBe(1.5)

            slicer.setRetractionSpeed(60)
            expect(slicer.getRetractionSpeed()).toBe(60)

            # Should allow zero retraction distance.
            slicer.setRetractionDistance(0)
            expect(slicer.getRetractionDistance()).toBe(0)

            # Should ignore negative values.
            slicer.setRetractionDistance(-1)
            expect(slicer.getRetractionDistance()).toBe(0) # unchanged

        test 'should set and get build plate dimensions', ->

            slicer.setBuildPlateWidth(300)
            expect(slicer.getBuildPlateWidth()).toBe(300)

            slicer.setBuildPlateHeight(250)
            expect(slicer.getBuildPlateHeight()).toBe(250)

            # Should ignore zero and negative values.
            slicer.setBuildPlateWidth(0)
            expect(slicer.getBuildPlateWidth()).toBe(300) # unchanged

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
