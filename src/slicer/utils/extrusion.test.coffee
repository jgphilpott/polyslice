# Tests for extrusion calculation utilities.

extrusion = require('./extrusion')
Polyslice = require('../../index')

describe 'Extrusion', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'calculateExtrusion', ->

        test 'should calculate extrusion amounts', ->

            # Basic calculation with default settings.
            # Default: 0.4mm nozzle, 0.2mm layer height, 1.75mm filament, 1.0 multiplier.
            result = extrusion.calculateExtrusion(slicer, 10) # 10mm distance.
            expect(result).toBeCloseTo(0.333, 2) # Approximately 0.33mm of filament.

            # Test with custom line width.
            result = extrusion.calculateExtrusion(slicer, 10, 0.5) # Wider line.
            expect(result).toBeCloseTo(0.416, 2)

            # Test edge cases.
            expect(extrusion.calculateExtrusion(slicer, 0)).toBe(0)
            expect(extrusion.calculateExtrusion(slicer, -5)).toBe(0)
            expect(extrusion.calculateExtrusion(slicer, 'invalid')).toBe(0)

        test 'should handle different filament diameters in calculations', ->

            slicer.setFilamentDiameter(3.0) # Change to 3mm filament.
            result = extrusion.calculateExtrusion(slicer, 10) # 10mm distance.

            expect(result).toBeCloseTo(0.113, 2) # Should be less filament needed for 3mm.

        test 'should handle extrusion multiplier in calculations', ->

            slicer.setExtrusionMultiplier(1.2) # 20% over-extrusion.
            result = extrusion.calculateExtrusion(slicer, 10)

            expect(result).toBeCloseTo(0.4, 2) # Should be 20% more than base calculation.
