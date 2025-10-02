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

            # Test new infill settings
            expect(slicer.getInfillDensity()).toBe(20)
            expect(slicer.getInfillPattern()).toBe('grid')
            expect(slicer.getShellHorizontalThickness()).toBe(0.8)
            expect(slicer.getShellVerticalThickness()).toBe(0.8)

            # Test new support settings
            expect(slicer.getSupportEnabled()).toBe(false)
            expect(slicer.getSupportType()).toBe('normal')
            expect(slicer.getSupportPlacement()).toBe('buildPlate')

            # Test new adhesion settings
            expect(slicer.getAdhesionEnabled()).toBe(false)
            expect(slicer.getAdhesionType()).toBe('skirt')

            # Test new test strip and outline settings
            expect(slicer.getTestStrip()).toBe(false)
            expect(slicer.getOutline()).toBe(true)

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

        test 'should convert speed units correctly', ->

            # Test inch/second conversions
            inchSpeedSlicer = new Polyslice({speedUnit: 'inchSecond'})
            inchSpeedSlicer.setPerimeterSpeed(1.18) # ~30mm/s in inches/s
            expect(inchSpeedSlicer.getPerimeterSpeed()).toBeCloseTo(1.18, 2)

            # Test meter/second conversions
            meterSpeedSlicer = new Polyslice({speedUnit: 'meterSecond'})
            meterSpeedSlicer.setTravelSpeed(0.12) # ~120mm/s in meters/s
            expect(meterSpeedSlicer.getTravelSpeed()).toBeCloseTo(0.12, 2)

            # Test default millimeter/second
            defaultSlicer = new Polyslice()
            defaultSlicer.setInfillSpeed(60)
            expect(defaultSlicer.getInfillSpeed()).toBe(60)

    describe 'Advanced Slicing Settings', ->

        test 'should set and get infill settings', ->

            slicer.setInfillDensity(25)
            expect(slicer.getInfillDensity()).toBe(25)

            slicer.setInfillPattern('gyroid')
            expect(slicer.getInfillPattern()).toBe('gyroid')

            slicer.setInfillPattern('honeycomb')
            expect(slicer.getInfillPattern()).toBe('honeycomb')

            # Test invalid pattern (should not change)
            slicer.setInfillPattern('invalid')
            expect(slicer.getInfillPattern()).toBe('honeycomb')

            # Test density boundaries
            slicer.setInfillDensity(0)
            expect(slicer.getInfillDensity()).toBe(0)

            slicer.setInfillDensity(100)
            expect(slicer.getInfillDensity()).toBe(100)

        test 'should set and get shell thickness settings', ->

            slicer.setShellHorizontalThickness(1.2)
            expect(slicer.getShellHorizontalThickness()).toBe(1.2)

            slicer.setShellVerticalThickness(1.0)
            expect(slicer.getShellVerticalThickness()).toBe(1.0)

            # Test with inches
            inchSlicer = new Polyslice({lengthUnit: 'inches'})
            inchSlicer.setShellHorizontalThickness(0.047) # ~1.2mm
            expect(inchSlicer.getShellHorizontalThickness()).toBeCloseTo(0.047, 3)

        test 'should set and get support settings', ->

            expect(slicer.getSupportEnabled()).toBe(false)

            slicer.setSupportEnabled(true)
            expect(slicer.getSupportEnabled()).toBe(true)

            slicer.setSupportType('tree')
            expect(slicer.getSupportType()).toBe('tree')

            slicer.setSupportPlacement('everywhere')
            expect(slicer.getSupportPlacement()).toBe('everywhere')

            # Test invalid type (should not change)
            slicer.setSupportType('invalid')
            expect(slicer.getSupportType()).toBe('tree')

        test 'should set and get adhesion settings', ->

            expect(slicer.getAdhesionEnabled()).toBe(false)

            slicer.setAdhesionEnabled(true)
            expect(slicer.getAdhesionEnabled()).toBe(true)

            slicer.setAdhesionType('brim')
            expect(slicer.getAdhesionType()).toBe('brim')

            slicer.setAdhesionType('raft')
            expect(slicer.getAdhesionType()).toBe('raft')

            # Test invalid type (should not change)
            slicer.setAdhesionType('invalid')
            expect(slicer.getAdhesionType()).toBe('raft')

        test 'should support all infill patterns', ->

            patterns = ['grid', 'lines', 'triangles', 'cubic', 'gyroid', 'honeycomb']

            for pattern in patterns
                slicer.setInfillPattern(pattern)
                expect(slicer.getInfillPattern()).toBe(pattern)

            return # Explicitly return undefined for Jest

        test 'should set and get test strip and outline settings', ->

            # Test defaults
            expect(slicer.getTestStrip()).toBe(false)
            expect(slicer.getOutline()).toBe(true)

            # Test setting test strip
            slicer.setTestStrip(true)
            expect(slicer.getTestStrip()).toBe(true)

            slicer.setTestStrip(false)
            expect(slicer.getTestStrip()).toBe(false)

            # Test setting outline
            slicer.setOutline(false)
            expect(slicer.getOutline()).toBe(false)

            slicer.setOutline(true)
            expect(slicer.getOutline()).toBe(true)

            # Test chaining
            result = slicer.setTestStrip(true).setOutline(false)
            expect(result).toBe(slicer)
            expect(slicer.getTestStrip()).toBe(true)
            expect(slicer.getOutline()).toBe(false)

        test 'should accept test strip and outline in constructor', ->

            customSlicer = new Polyslice({
                testStrip: true
                outline: false
            })

            expect(customSlicer.getTestStrip()).toBe(true)
            expect(customSlicer.getOutline()).toBe(false)

    describe 'Printer and Filament Integration', ->

        Printer = require('./config/printer')
        Filament = require('./config/filament')

        test 'should initialize with null printer and filament by default', ->

            expect(slicer.getPrinter()).toBeNull()
            expect(slicer.getFilament()).toBeNull()

        test 'should accept Printer instance in constructor', ->

            printer = new Printer('Ender3')
            slicerWithPrinter = new Polyslice({ printer: printer })

            expect(slicerWithPrinter.getPrinter()).toBe(printer)
            expect(slicerWithPrinter.getBuildPlateWidth()).toBe(220)
            expect(slicerWithPrinter.getBuildPlateLength()).toBe(220)
            expect(slicerWithPrinter.getNozzleDiameter()).toBe(0.4)
            expect(slicerWithPrinter.getFilamentDiameter()).toBe(1.75)

        test 'should accept Filament instance in constructor', ->

            filament = new Filament('GenericPLA')
            slicerWithFilament = new Polyslice({ filament: filament })

            expect(slicerWithFilament.getFilament()).toBe(filament)
            expect(slicerWithFilament.getNozzleTemperature()).toBe(200)
            expect(slicerWithFilament.getBedTemperature()).toBe(60)
            expect(slicerWithFilament.getFanSpeed()).toBe(100)
            expect(slicerWithFilament.getRetractionDistance()).toBe(5)
            expect(slicerWithFilament.getRetractionSpeed()).toBe(45)

        test 'should accept both Printer and Filament in constructor', ->

            printer = new Printer('PrusaI3MK3S')
            filament = new Filament('PrusamentPLA')
            slicerWithBoth = new Polyslice({ printer: printer, filament: filament })

            expect(slicerWithBoth.getPrinter()).toBe(printer)
            expect(slicerWithBoth.getFilament()).toBe(filament)

            # Printer settings
            expect(slicerWithBoth.getBuildPlateWidth()).toBe(250)
            expect(slicerWithBoth.getBuildPlateLength()).toBe(210)
            expect(slicerWithBoth.getNozzleDiameter()).toBe(0.4)

            # Filament settings
            expect(slicerWithBoth.getNozzleTemperature()).toBe(215)
            expect(slicerWithBoth.getBedTemperature()).toBe(60)
            expect(slicerWithBoth.getFanSpeed()).toBe(100)

            # Filament diameter should come from filament, not printer
            expect(slicerWithBoth.getFilamentDiameter()).toBe(1.75)

        test 'should allow custom options to override printer settings', ->

            printer = new Printer('Ender3')
            slicerWithOverride = new Polyslice({
                printer: printer
                buildPlateWidth: 250
                nozzleDiameter: 0.6
            })

            # Custom values override printer values
            expect(slicerWithOverride.getBuildPlateWidth()).toBe(250)
            expect(slicerWithOverride.getNozzleDiameter()).toBe(0.6)

            # Non-overridden values use printer defaults
            expect(slicerWithOverride.getBuildPlateLength()).toBe(220)

        test 'should allow custom options to override filament settings', ->

            filament = new Filament('GenericPLA')
            slicerWithOverride = new Polyslice({
                filament: filament
                nozzleTemperature: 210
                bedTemperature: 0
                fanSpeed: 80
            })

            # Custom values override filament values
            expect(slicerWithOverride.getNozzleTemperature()).toBe(210)
            expect(slicerWithOverride.getBedTemperature()).toBe(0)
            expect(slicerWithOverride.getFanSpeed()).toBe(80)

            # Non-overridden values use filament defaults
            expect(slicerWithOverride.getRetractionDistance()).toBe(5)

        test 'should allow custom options to override both printer and filament', ->

            printer = new Printer('Ender3')
            filament = new Filament('GenericPETG')
            slicerWithOverrides = new Polyslice({
                printer: printer
                filament: filament
                buildPlateWidth: 200
                nozzleTemperature: 250
            })

            # Custom values override
            expect(slicerWithOverrides.getBuildPlateWidth()).toBe(200)
            expect(slicerWithOverrides.getNozzleTemperature()).toBe(250)

            # Printer values used where not overridden
            expect(slicerWithOverrides.getBuildPlateLength()).toBe(220)

            # Filament values used where not overridden
            expect(slicerWithOverrides.getBedTemperature()).toBe(80)
            expect(slicerWithOverrides.getFanSpeed()).toBe(50)

        test 'should update settings with setPrinter method', ->

            printer = new Printer('Ender3')
            slicer.setPrinter(printer)

            expect(slicer.getPrinter()).toBe(printer)
            expect(slicer.getBuildPlateWidth()).toBe(220)
            expect(slicer.getBuildPlateLength()).toBe(220)
            expect(slicer.getNozzleDiameter()).toBe(0.4)

        test 'should update settings with setFilament method', ->

            filament = new Filament('GenericABS')
            slicer.setFilament(filament)

            expect(slicer.getFilament()).toBe(filament)
            expect(slicer.getNozzleTemperature()).toBe(240)
            expect(slicer.getBedTemperature()).toBe(100)
            expect(slicer.getFanSpeed()).toBe(0) # ABS uses no fan

        test 'should override existing settings when setPrinter is called', ->

            # Start with Ender3
            printer1 = new Printer('Ender3')
            slicerTest = new Polyslice({ printer: printer1 })
            expect(slicerTest.getBuildPlateWidth()).toBe(220)

            # Switch to larger printer
            printer2 = new Printer('CR10')
            slicerTest.setPrinter(printer2)
            expect(slicerTest.getBuildPlateWidth()).toBe(300)
            expect(slicerTest.getBuildPlateLength()).toBe(300)

        test 'should override existing settings when setFilament is called', ->

            # Start with PLA
            filament1 = new Filament('GenericPLA')
            slicerTest = new Polyslice({ filament: filament1 })
            expect(slicerTest.getNozzleTemperature()).toBe(200)

            # Switch to PETG
            filament2 = new Filament('GenericPETG')
            slicerTest.setFilament(filament2)
            expect(slicerTest.getNozzleTemperature()).toBe(240)
            expect(slicerTest.getBedTemperature()).toBe(80)

        test 'should allow setting printer to null', ->

            printer = new Printer('Ender3')
            slicerTest = new Polyslice({ printer: printer })
            expect(slicerTest.getPrinter()).toBe(printer)

            slicerTest.setPrinter(null)
            expect(slicerTest.getPrinter()).toBeNull()

        test 'should allow setting filament to null', ->

            filament = new Filament('GenericPLA')
            slicerTest = new Polyslice({ filament: filament })
            expect(slicerTest.getFilament()).toBe(filament)

            slicerTest.setFilament(null)
            expect(slicerTest.getFilament()).toBeNull()

        test 'should return this for method chaining with setPrinter', ->

            printer = new Printer('Ender3')
            result = slicer.setPrinter(printer)
            expect(result).toBe(slicer)

        test 'should return this for method chaining with setFilament', ->

            filament = new Filament('GenericPLA')
            result = slicer.setFilament(filament)
            expect(result).toBe(slicer)

        test 'should work with different printer sizes', ->

            # Test with compact printer
            compact = new Printer('PrusaMini')
            slicerCompact = new Polyslice({ printer: compact })
            expect(slicerCompact.getBuildPlateWidth()).toBe(180)
            expect(slicerCompact.getBuildPlateLength()).toBe(180)

            # Test with large printer
            large = new Printer('CR10S5')
            slicerLarge = new Polyslice({ printer: large })
            expect(slicerLarge.getBuildPlateWidth()).toBe(500)
            expect(slicerLarge.getBuildPlateLength()).toBe(500)

        test 'should work with different filament types', ->

            # Test with TPU (flexible)
            tpu = new Filament('GenericTPU')
            slicerTPU = new Polyslice({ filament: tpu })
            expect(slicerTPU.getNozzleTemperature()).toBe(220)
            expect(slicerTPU.getRetractionDistance()).toBe(2) # TPU uses minimal retraction

            # Test with Nylon
            nylon = new Filament('GenericNylon')
            slicerNylon = new Polyslice({ filament: nylon })
            expect(slicerNylon.getNozzleTemperature()).toBe(250)
            expect(slicerNylon.getBedTemperature()).toBe(80)

        test 'should handle 2.85mm filament from printer and filament', ->

            # Ultimaker printer with 2.85mm filament
            printer = new Printer('UltimakerS5')
            filament = new Filament('UltimakerPLA')
            slicerUltimaker = new Polyslice({ printer: printer, filament: filament })

            # Filament diameter should come from filament, not printer
            expect(slicerUltimaker.getFilamentDiameter()).toBe(2.85)

