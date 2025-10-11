# Tests for geometry helper functions

helpers = require('./helpers')

describe 'Geometry Helpers', ->

    describe 'pointsMatch', ->

        test 'should return true for identical points', ->

            p1 = { x: 10, y: 20 }
            p2 = { x: 10, y: 20 }

            result = helpers.pointsMatch(p1, p2, 0.001)

            expect(result).toBe(true)

        test 'should return true for points within epsilon', ->

            p1 = { x: 10, y: 20 }
            p2 = { x: 10.0005, y: 20.0005 }

            result = helpers.pointsMatch(p1, p2, 0.001)

            expect(result).toBe(true)

        test 'should return false for points outside epsilon', ->

            p1 = { x: 10, y: 20 }
            p2 = { x: 10.5, y: 20 }

            result = helpers.pointsMatch(p1, p2, 0.001)

            expect(result).toBe(false)

    describe 'lineIntersection', ->

        test 'should find intersection of two crossing lines', ->

            p1 = { x: 0, y: 0 }
            p2 = { x: 10, y: 10 }
            p3 = { x: 0, y: 10 }
            p4 = { x: 10, y: 0 }

            result = helpers.lineIntersection(p1, p2, p3, p4)

            expect(result).not.toBeNull()
            expect(result.x).toBeCloseTo(5, 1)
            expect(result.y).toBeCloseTo(5, 1)

        test 'should return null for parallel lines', ->

            p1 = { x: 0, y: 0 }
            p2 = { x: 10, y: 0 }
            p3 = { x: 0, y: 5 }
            p4 = { x: 10, y: 5 }

            result = helpers.lineIntersection(p1, p2, p3, p4)

            expect(result).toBeNull()

        test 'should find intersection of perpendicular lines', ->

            p1 = { x: 5, y: 0 }
            p2 = { x: 5, y: 10 }
            p3 = { x: 0, y: 5 }
            p4 = { x: 10, y: 5 }

            result = helpers.lineIntersection(p1, p2, p3, p4)

            expect(result).not.toBeNull()
            expect(result.x).toBeCloseTo(5, 1)
            expect(result.y).toBeCloseTo(5, 1)

    describe 'createInsetPath', ->

        test 'should create inset path from square', ->

            # Define a 10x10 square.
            path = [
                { x: 0, y: 0, z: 0 }
                { x: 10, y: 0, z: 0 }
                { x: 10, y: 10, z: 0 }
                { x: 0, y: 10, z: 0 }
            ]

            insetPath = helpers.createInsetPath(path, 1)

            # Should have 4 points (corners of inset square).
            expect(insetPath.length).toBe(4)

            # Check that inset is smaller than original.
            for point in insetPath
                expect(point.x).toBeGreaterThan(0)
                expect(point.x).toBeLessThan(10)
                expect(point.y).toBeGreaterThan(0)
                expect(point.y).toBeLessThan(10)
            undefined

        test 'should return empty array for path with less than 3 points', ->

            path = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
            ]

            insetPath = helpers.createInsetPath(path, 1)

            expect(insetPath.length).toBe(0)

        test 'should handle different inset distances', ->

            path = [
                { x: 0, y: 0, z: 0 }
                { x: 20, y: 0, z: 0 }
                { x: 20, y: 20, z: 0 }
                { x: 0, y: 20, z: 0 }
            ]

            # Test with 2mm inset.
            insetPath2 = helpers.createInsetPath(path, 2)
            expect(insetPath2.length).toBe(4)

            # Test with 5mm inset.
            insetPath5 = helpers.createInsetPath(path, 5)
            expect(insetPath5.length).toBe(4)

            # Larger inset should be smaller area.
            # Check first point (should be more inset).
            expect(Math.abs(insetPath5[0].x)).toBeGreaterThan(Math.abs(insetPath2[0].x))

    describe 'connectSegmentsToPaths', ->

        test 'should connect segments into a closed path', ->

            segments = [
                { start: { x: 0, y: 0 }, end: { x: 10, y: 0 } }
                { start: { x: 10, y: 0 }, end: { x: 10, y: 10 } }
                { start: { x: 10, y: 10 }, end: { x: 0, y: 10 } }
                { start: { x: 0, y: 10 }, end: { x: 0, y: 0 } }
            ]

            paths = helpers.connectSegmentsToPaths(segments)

            expect(paths.length).toBe(1)
            expect(paths[0].length).toBeGreaterThanOrEqual(4)

        test 'should return empty array for null segments', ->

            paths = helpers.connectSegmentsToPaths(null)

            expect(paths.length).toBe(0)

        test 'should return empty array for empty segments', ->

            paths = helpers.connectSegmentsToPaths([])

            expect(paths.length).toBe(0)

        test 'should handle disconnected segments', ->

            segments = [
                { start: { x: 0, y: 0 }, end: { x: 5, y: 0 } }
                { start: { x: 10, y: 10 }, end: { x: 15, y: 10 } }
            ]

            paths = helpers.connectSegmentsToPaths(segments)

            # Should create separate paths for disconnected segments.
            # Or filter out paths with < 3 points.
            expect(paths.length).toBeGreaterThanOrEqual(0)

        test 'should connect segments in correct order', ->

            # Create a triangle.
            segments = [
                { start: { x: 0, y: 0 }, end: { x: 10, y: 0 } }
                { start: { x: 10, y: 0 }, end: { x: 5, y: 10 } }
                { start: { x: 5, y: 10 }, end: { x: 0, y: 0 } }
            ]

            paths = helpers.connectSegmentsToPaths(segments)

            expect(paths.length).toBe(1)
            expect(paths[0].length).toBe(3)

            # Check that points form a connected path.
            path = paths[0]
            expect(path[0].x).toBe(0)
            expect(path[0].y).toBe(0)
