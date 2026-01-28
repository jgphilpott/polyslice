# Tests for bounding box calculations.

bounds = require('./bounds')
Polyslice = require('../../index')

describe 'Bounds', ->

    describe 'isWithinBounds', ->

        slicer = null

        beforeEach ->

            slicer = new Polyslice({progressCallback: null})

        test 'should check build plate bounds', ->

            # Within bounds.
            expect(bounds.isWithinBounds(slicer, 0, 0)).toBe(true)
            expect(bounds.isWithinBounds(slicer, 100, 100)).toBe(true)
            expect(bounds.isWithinBounds(slicer, -100, -100)).toBe(true)
            expect(bounds.isWithinBounds(slicer, 110, 110)).toBe(true) # Exactly at edge.

            # Outside bounds.
            expect(bounds.isWithinBounds(slicer, 111, 0)).toBe(false)
            expect(bounds.isWithinBounds(slicer, 0, 111)).toBe(false)
            expect(bounds.isWithinBounds(slicer, -111, 0)).toBe(false)
            expect(bounds.isWithinBounds(slicer, 0, -111)).toBe(false)

            # Invalid inputs.
            expect(bounds.isWithinBounds(slicer, '100', 100)).toBe(false)
            expect(bounds.isWithinBounds(slicer, 100, null)).toBe(false)

    describe 'calculatePathBounds', ->

        test 'should calculate correct bounding box for a square path', ->

            path = [
                { x: 10, y: 20 }
                { x: 30, y: 20 }
                { x: 30, y: 40 }
                { x: 10, y: 40 }
            ]

            result = bounds.calculatePathBounds(path)

            expect(result.minX).toBe(10)
            expect(result.maxX).toBe(30)
            expect(result.minY).toBe(20)
            expect(result.maxY).toBe(40)

        test 'should handle single point path', ->

            path = [{ x: 5, y: 10 }]

            result = bounds.calculatePathBounds(path)

            expect(result.minX).toBe(5)
            expect(result.maxX).toBe(5)
            expect(result.minY).toBe(10)
            expect(result.maxY).toBe(10)

        test 'should handle negative coordinates', ->

            path = [
                { x: -10, y: -20 }
                { x: 10, y: 20 }
            ]

            result = bounds.calculatePathBounds(path)

            expect(result.minX).toBe(-10)
            expect(result.maxX).toBe(10)
            expect(result.minY).toBe(-20)
            expect(result.maxY).toBe(20)

        test 'should return null for null path', ->

            result = bounds.calculatePathBounds(null)

            expect(result).toBeNull()

        test 'should return null for empty path', ->

            result = bounds.calculatePathBounds([])

            expect(result).toBeNull()

    describe 'boundsOverlap', ->

        test 'should return true for overlapping bounds', ->

            bounds1 = { minX: 0, maxX: 10, minY: 0, maxY: 10 }
            bounds2 = { minX: 5, maxX: 15, minY: 5, maxY: 15 }

            result = bounds.boundsOverlap(bounds1, bounds2)

            expect(result).toBe(true)

        test 'should return false for non-overlapping bounds', ->

            bounds1 = { minX: 0, maxX: 10, minY: 0, maxY: 10 }
            bounds2 = { minX: 20, maxX: 30, minY: 20, maxY: 30 }

            result = bounds.boundsOverlap(bounds1, bounds2)

            expect(result).toBe(false)

        test 'should return true for touching bounds with tolerance', ->

            bounds1 = { minX: 0, maxX: 10, minY: 0, maxY: 10 }
            bounds2 = { minX: 10.05, maxX: 20, minY: 0, maxY: 10 }

            result = bounds.boundsOverlap(bounds1, bounds2, 0.1)

            expect(result).toBe(true)

        test 'should return false for null bounds', ->

            bounds1 = { minX: 0, maxX: 10, minY: 0, maxY: 10 }

            expect(bounds.boundsOverlap(null, bounds1)).toBe(false)
            expect(bounds.boundsOverlap(bounds1, null)).toBe(false)

    describe 'calculateOverlapArea', ->

        test 'should calculate correct overlap area', ->

            bounds1 = { minX: 0, maxX: 10, minY: 0, maxY: 10 }
            bounds2 = { minX: 5, maxX: 15, minY: 5, maxY: 15 }

            result = bounds.calculateOverlapArea(bounds1, bounds2)

            # Overlap is from (5,5) to (10,10) = 5x5 = 25
            expect(result).toBe(25)

        test 'should return 0 for non-overlapping bounds', ->

            bounds1 = { minX: 0, maxX: 10, minY: 0, maxY: 10 }
            bounds2 = { minX: 20, maxX: 30, minY: 20, maxY: 30 }

            result = bounds.calculateOverlapArea(bounds1, bounds2)

            expect(result).toBe(0)

        test 'should return 0 for null bounds', ->

            bounds1 = { minX: 0, maxX: 10, minY: 0, maxY: 10 }

            expect(bounds.calculateOverlapArea(null, bounds1)).toBe(0)
            expect(bounds.calculateOverlapArea(bounds1, null)).toBe(0)
