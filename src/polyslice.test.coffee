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
            expect(slicer.getShellSkinThickness()).toBe(0.8)
            expect(slicer.getShellWallThickness()).toBe(0.8)

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

    describe 'Method Chaining', ->

        test 'should support method chaining for all setters', ->

            result = slicer
                .setWorkspacePlane('XZ')
                .setNozzleTemperature(200)
                .setBedTemperature(60)
                .setFanSpeed(75)

            expect(result).toBe(slicer)
            expect(slicer.getWorkspacePlane()).toBe('XZ')
            expect(slicer.getNozzleTemperature()).toBe(200)
            expect(slicer.getBedTemperature()).toBe(60)
            expect(slicer.getFanSpeed()).toBe(75)

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
