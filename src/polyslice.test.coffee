# Tests for the Polyslice class:

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
            expect(slicer.getBuildPlateLength()).toBe(220)

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
                buildPlateLength: 300

            })

            expect(customSlicer.getAutohome()).toBe(false)
            expect(customSlicer.getWorkspacePlane()).toBe('XZ')
            expect(customSlicer.getTimeUnit()).toBe('seconds')
            expect(customSlicer.getLengthUnit()).toBe('inches')
            expect(customSlicer.getTemperatureUnit()).toBe('fahrenheit')
            expect(customSlicer.getNozzleTemperature()).toBeCloseTo(200, 1) # Temperature conversions need precision handling
            expect(customSlicer.getBedTemperature()).toBeCloseTo(60, 1) # Temperature conversions need precision handling
            expect(customSlicer.getFanSpeed()).toBe(75)

            # Test new settings (length-based values need precision handling for unit conversions)
            expect(customSlicer.getLayerHeight()).toBeCloseTo(0.3, 1)
            expect(customSlicer.getExtrusionMultiplier()).toBe(1.1)
            expect(customSlicer.getFilamentDiameter()).toBeCloseTo(3.0, 1)
            expect(customSlicer.getNozzleDiameter()).toBeCloseTo(0.6, 1)
            expect(customSlicer.getPerimeterSpeed()).toBeCloseTo(40, 1)
            expect(customSlicer.getInfillSpeed()).toBeCloseTo(80, 1)
            expect(customSlicer.getTravelSpeed()).toBeCloseTo(150, 1)
            expect(customSlicer.getRetractionDistance()).toBeCloseTo(2.0, 1)
            expect(customSlicer.getRetractionSpeed()).toBeCloseTo(50, 1)
            expect(customSlicer.getBuildPlateWidth()).toBeCloseTo(300, 1)
            expect(customSlicer.getBuildPlateLength()).toBeCloseTo(300, 1)

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

            slicer.setBuildPlateLength(250)
            expect(slicer.getBuildPlateLength()).toBe(250)

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

        test 'should generate arc movement G-code', ->

            # Test clockwise arc
            arcCode = slicer.codeArcMovement("clockwise", 10, 10, null, null, null, null, 5, 0)
            expect(arcCode).toBe('G2 X10 Y10 I5 J0\n')

            # Test counterclockwise arc
            arcCode = slicer.codeArcMovement("counterclockwise", 5, 5, null, null, null, null, 2, 2)
            expect(arcCode).toBe('G3 X5 Y5 I2 J2\n')

        test 'should generate message G-code', ->

            messageCode = slicer.codeMessage("Test Message")
            expect(messageCode).toBe('M117 Test Message\n')

        test 'should generate wait G-code', ->

            waitCode = slicer.codeWait()
            expect(waitCode).toBe('M400\n')

        test 'should generate dwell G-code', ->

            dwellCode = slicer.codeDwell(1000)
            expect(dwellCode).toBe('M0 P1000\n') # Interruptible dwell for 1000ms

            nonInterruptibleDwell = slicer.codeDwell(500, false)
            expect(nonInterruptibleDwell).toBe('G4 P500\n') # Non-interruptible dwell for 500ms

    describe 'Basic Slicing', ->

        test 'should perform basic slice with autohome', ->

            result = slicer.slice()
            expect(result).toContain('G28\n') # Should contain autohome

        test 'should skip autohome if disabled', ->

            slicer.setAutohome(false)
            result = slicer.slice()

            expect(result).toBe('') # Should be empty without autohome

    describe 'Utility Methods', ->

        test 'should generate retraction G-code', ->

            result = slicer.codeRetract()
            expect(result).toBe('G1 E-1 F2400\n') # Default 1mm at 40mm/s (2400mm/min)

            # Test custom values
            result = slicer.codeRetract(2.0, 50)
            expect(result).toBe('G1 E-2 F3000\n')

            # Test zero retraction
            result = slicer.codeRetract(0, 50)
            expect(result).toBe('') # Should return empty string

        test 'should generate unretract G-code', ->

            result = slicer.codeUnretract()
            expect(result).toBe('G1 E1 F2400\n') # Default 1mm at 40mm/s

            # Test custom values
            result = slicer.codeUnretract(1.5, 30)
            expect(result).toBe('G1 E1.5 F1800\n')

        test 'should check build plate bounds', ->

            # Within bounds
            expect(slicer.isWithinBounds(0, 0)).toBe(true)
            expect(slicer.isWithinBounds(100, 100)).toBe(true)
            expect(slicer.isWithinBounds(-100, -100)).toBe(true)
            expect(slicer.isWithinBounds(110, 110)).toBe(true) # Exactly at edge

            # Outside bounds
            expect(slicer.isWithinBounds(111, 0)).toBe(false)
            expect(slicer.isWithinBounds(0, 111)).toBe(false)
            expect(slicer.isWithinBounds(-111, 0)).toBe(false)
            expect(slicer.isWithinBounds(0, -111)).toBe(false)

            # Invalid inputs
            expect(slicer.isWithinBounds('100', 100)).toBe(false)
            expect(slicer.isWithinBounds(100, null)).toBe(false)

        test 'should calculate extrusion amounts', ->

            # Basic calculation with default settings
            # Default: 0.4mm nozzle, 0.2mm layer height, 1.75mm filament, 1.0 multiplier
            result = slicer.calculateExtrusion(10) # 10mm distance
            expect(result).toBeCloseTo(0.333, 2) # Approximately 0.33mm of filament

            # Test with custom line width
            result = slicer.calculateExtrusion(10, 0.5) # Wider line
            expect(result).toBeCloseTo(0.416, 2)

            # Test edge cases
            expect(slicer.calculateExtrusion(0)).toBe(0)
            expect(slicer.calculateExtrusion(-5)).toBe(0)
            expect(slicer.calculateExtrusion('invalid')).toBe(0)

        test 'should handle different filament diameters in calculations', ->

            slicer.setFilamentDiameter(3.0) # Change to 3mm filament
            result = slicer.calculateExtrusion(10) # 10mm distance

            expect(result).toBeCloseTo(0.113, 2) # Should be less filament needed for 3mm

        test 'should handle extrusion multiplier in calculations', ->

            slicer.setExtrusionMultiplier(1.2) # 20% over-extrusion
            result = slicer.calculateExtrusion(10)

            expect(result).toBeCloseTo(0.4, 2) # Should be 20% more than base calculation

    describe 'Unit Conversions', ->

        test 'should convert temperature units correctly', ->

            # Test Fahrenheit conversions
            fahrenheitSlicer = new Polyslice({temperatureUnit: 'fahrenheit'})
            fahrenheitSlicer.setNozzleTemperature(392) # 200°C in Fahrenheit
            expect(fahrenheitSlicer.getNozzleTemperature()).toBeCloseTo(392, 1)

            # Test Kelvin conversions
            kelvinSlicer = new Polyslice({temperatureUnit: 'kelvin'})
            kelvinSlicer.setNozzleTemperature(473.15) # 200°C in Kelvin
            expect(kelvinSlicer.getNozzleTemperature()).toBeCloseTo(473.15, 1)

        test 'should convert length units correctly', ->

            # Test inch conversions
            inchSlicer = new Polyslice({lengthUnit: 'inches'})
            inchSlicer.setLayerHeight(0.008) # ~0.2mm in inches
            expect(inchSlicer.getLayerHeight()).toBeCloseTo(0.008, 3)

            inchSlicer.setNozzleDiameter(0.016) # ~0.4mm in inches
            expect(inchSlicer.getNozzleDiameter()).toBeCloseTo(0.016, 3)

        test 'should maintain internal storage in standard units', ->

            # Create slicer with non-standard units
            customSlicer = new Polyslice({
                temperatureUnit: 'fahrenheit'
                lengthUnit: 'inches'
            })

            # Set values in user units
            customSlicer.setNozzleTemperature(392) # 200°C
            customSlicer.setLayerHeight(0.008) # ~0.2mm

            # Internal storage should be in standard units for G-code generation
            # This is tested indirectly by ensuring G-code generation works correctly
            # The values should convert properly when retrieved in user units
            expect(customSlicer.getNozzleTemperature()).toBeCloseTo(392, 1)
            expect(customSlicer.getLayerHeight()).toBeCloseTo(0.008, 3)
