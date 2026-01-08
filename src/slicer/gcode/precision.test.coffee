# Tests for G-code precision formatting.

Polyslice = require('../../polyslice')
coders = require('./coders')

describe 'G-code Precision Formatting', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice({
            verbose: false
        })

    describe 'formatPrecision helper', ->

        it 'should format numbers to specified decimal places', ->

            # Test with various precision levels.
            expect(coders.formatPrecision(1.23456789, 0)).toBe('1')
            expect(coders.formatPrecision(1.23456789, 1)).toBe('1.2')
            expect(coders.formatPrecision(1.23456789, 2)).toBe('1.23')
            expect(coders.formatPrecision(1.23456789, 3)).toBe('1.235')
            expect(coders.formatPrecision(1.23456789, 5)).toBe('1.23457')

        it 'should remove trailing zeros', ->

            # Trailing zeros should be removed.
            expect(coders.formatPrecision(1.0, 3)).toBe('1')
            expect(coders.formatPrecision(1.5, 3)).toBe('1.5')
            expect(coders.formatPrecision(1.50, 3)).toBe('1.5')
            expect(coders.formatPrecision(1.500, 3)).toBe('1.5')
            expect(coders.formatPrecision(10.0, 2)).toBe('10')

        it 'should handle zero correctly', ->

            expect(coders.formatPrecision(0, 0)).toBe('0')
            expect(coders.formatPrecision(0, 3)).toBe('0')
            expect(coders.formatPrecision(0.0, 5)).toBe('0')

        it 'should handle negative numbers', ->

            expect(coders.formatPrecision(-1.23456, 2)).toBe('-1.23')
            expect(coders.formatPrecision(-5.0, 3)).toBe('-5')
            expect(coders.formatPrecision(-0.001, 3)).toBe('-0.001')

        it 'should round correctly', ->

            # Test rounding behavior.
            expect(coders.formatPrecision(1.235, 2)).toBe('1.24')
            expect(coders.formatPrecision(1.234, 2)).toBe('1.23')
            expect(coders.formatPrecision(1.995, 2)).toBe('2')
            expect(coders.formatPrecision(0.0005, 3)).toBe('0.001')

        it 'should handle invalid input', ->

            # Invalid inputs should be returned as-is.
            expect(coders.formatPrecision(NaN, 3)).toBe(NaN)
            expect(coders.formatPrecision(null, 3)).toBe(null)
            expect(coders.formatPrecision(undefined, 3)).toBe(undefined)

    describe 'Default precision settings', ->

        it 'should use default precision values', ->

            expect(slicer.getCoordinatePrecision()).toBe(3)
            expect(slicer.getExtrusionPrecision()).toBe(5)
            expect(slicer.getFeedratePrecision()).toBe(0)

        it 'should format coordinates with 3 decimals by default', ->

            gcode = coders.codeLinearMovement(slicer, 100.123456789, 200.987654321, 0.001)

            expect(gcode).toContain('X100.123')
            expect(gcode).toContain('Y200.988')
            expect(gcode).toContain('Z0.001')

        it 'should format extrusion with 5 decimals by default', ->

            gcode = coders.codeLinearMovement(slicer, 100, 100, 0.2, 1.23456789)

            expect(gcode).toContain('E1.23457')

        it 'should format feedrate with 0 decimals by default', ->

            gcode = coders.codeLinearMovement(slicer, 100, 100, 0.2, null, 1800.567)

            expect(gcode).toContain('F1801')

    describe 'Custom precision settings', ->

        it 'should accept custom coordinate precision', ->

            slicer.setCoordinatePrecision(2)
            expect(slicer.getCoordinatePrecision()).toBe(2)

            gcode = coders.codeLinearMovement(slicer, 100.123456, 200.987654, 0.001)

            expect(gcode).toContain('X100.12')
            expect(gcode).toContain('Y200.99')
            expect(gcode).toContain('Z0')

        it 'should accept custom extrusion precision', ->

            slicer.setExtrusionPrecision(3)
            expect(slicer.getExtrusionPrecision()).toBe(3)

            gcode = coders.codeLinearMovement(slicer, 100, 100, 0.2, 1.23456789)

            expect(gcode).toContain('E1.235')

        it 'should accept custom feedrate precision', ->

            slicer.setFeedratePrecision(2)
            expect(slicer.getFeedratePrecision()).toBe(2)

            gcode = coders.codeLinearMovement(slicer, 100, 100, 0.2, null, 1800.567)

            expect(gcode).toContain('F1800.57')

        it 'should validate precision range (0-10)', ->

            # Valid range.
            slicer.setCoordinatePrecision(0)
            expect(slicer.getCoordinatePrecision()).toBe(0)

            slicer.setCoordinatePrecision(10)
            expect(slicer.getCoordinatePrecision()).toBe(10)

            # Invalid values should be ignored.
            slicer.setCoordinatePrecision(15)
            expect(slicer.getCoordinatePrecision()).toBe(10) # Should remain at last valid value.

            slicer.setCoordinatePrecision(-1)
            expect(slicer.getCoordinatePrecision()).toBe(10) # Should remain at last valid value.

        it 'should floor non-integer precision values', ->

            slicer.setCoordinatePrecision(3.7)
            expect(slicer.getCoordinatePrecision()).toBe(3)

            slicer.setExtrusionPrecision(5.2)
            expect(slicer.getExtrusionPrecision()).toBe(5)

    describe 'Method chaining', ->

        it 'should support method chaining for precision setters', ->

            result = slicer
                .setCoordinatePrecision(2)
                .setExtrusionPrecision(4)
                .setFeedratePrecision(1)

            expect(result).toBe(slicer)
            expect(slicer.getCoordinatePrecision()).toBe(2)
            expect(slicer.getExtrusionPrecision()).toBe(4)
            expect(slicer.getFeedratePrecision()).toBe(1)

    describe 'Arc movement precision', ->

        it 'should apply precision to arc movement coordinates', ->

            slicer.setCoordinatePrecision(2)

            gcode = coders.codeArcMovement(
                slicer,
                'clockwise',
                100.123456,
                200.987654,
                0.5,
                1.23456789,
                1800,
                null,
                10.123456,
                20.987654,
                null,
                null
            )

            expect(gcode).toContain('X100.12')
            expect(gcode).toContain('Y200.99')
            expect(gcode).toContain('Z0.5')
            expect(gcode).toContain('I10.12')
            expect(gcode).toContain('J20.99')

    describe 'Trailing zero removal', ->

        it 'should remove trailing zeros from coordinates', ->

            gcode = coders.codeLinearMovement(slicer, 100.0, 200.0, 1.0)

            expect(gcode).toContain('X100 ')
            expect(gcode).toContain('Y200 ')
            expect(gcode).toContain('Z1')

        it 'should preserve significant digits', ->

            gcode = coders.codeLinearMovement(slicer, 100.1, 200.01, 1.001)

            expect(gcode).toContain('X100.1')
            expect(gcode).toContain('Y200.01')
            expect(gcode).toContain('Z1.001')

    describe 'Edge cases', ->

        it 'should handle very small numbers', ->

            gcode = coders.codeLinearMovement(slicer, 0.0001, 0.0001, 0.0001)

            expect(gcode).toContain('X0')
            expect(gcode).toContain('Y0')
            expect(gcode).toContain('Z0')

        it 'should handle very large numbers', ->

            gcode = coders.codeLinearMovement(slicer, 999999.123456, 888888.987654)

            expect(gcode).toContain('X999999.123')
            expect(gcode).toContain('Y888888.988')
