# Tests for helper utility methods

Polyslice = require('../index')

describe 'Helper Utilities', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Bounds Checking', ->

        test 'should check build plate bounds', ->

            # Within bounds.
            expect(slicer.isWithinBounds(0, 0)).toBe(true)
            expect(slicer.isWithinBounds(100, 100)).toBe(true)
            expect(slicer.isWithinBounds(-100, -100)).toBe(true)
            expect(slicer.isWithinBounds(110, 110)).toBe(true) # Exactly at edge.

            # Outside bounds.
            expect(slicer.isWithinBounds(111, 0)).toBe(false)
            expect(slicer.isWithinBounds(0, 111)).toBe(false)
            expect(slicer.isWithinBounds(-111, 0)).toBe(false)
            expect(slicer.isWithinBounds(0, -111)).toBe(false)

            # Invalid inputs.
            expect(slicer.isWithinBounds('100', 100)).toBe(false)
            expect(slicer.isWithinBounds(100, null)).toBe(false)

    describe 'Extrusion Calculations', ->

        test 'should calculate extrusion amounts', ->

            # Basic calculation with default settings.
            # Default: 0.4mm nozzle, 0.2mm layer height, 1.75mm filament, 1.0 multiplier.
            result = slicer.calculateExtrusion(10) # 10mm distance.
            expect(result).toBeCloseTo(0.333, 2) # Approximately 0.33mm of filament.

            # Test with custom line width.
            result = slicer.calculateExtrusion(10, 0.5) # Wider line.
            expect(result).toBeCloseTo(0.416, 2)

            # Test edge cases.
            expect(slicer.calculateExtrusion(0)).toBe(0)
            expect(slicer.calculateExtrusion(-5)).toBe(0)
            expect(slicer.calculateExtrusion('invalid')).toBe(0)

        test 'should handle different filament diameters in calculations', ->

            slicer.setFilamentDiameter(3.0) # Change to 3mm filament.
            result = slicer.calculateExtrusion(10) # 10mm distance.

            expect(result).toBeCloseTo(0.113, 2) # Should be less filament needed for 3mm.

        test 'should handle extrusion multiplier in calculations', ->

            slicer.setExtrusionMultiplier(1.2) # 20% over-extrusion.
            result = slicer.calculateExtrusion(10)

            expect(result).toBeCloseTo(0.4, 2) # Should be 20% more than base calculation.
