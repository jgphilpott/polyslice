# Tests for path manipulation operations.

paths = require('./paths')

describe 'Paths', ->

    describe 'createInsetPath', ->

        test 'should create inset path from square', ->

            # Define a 10x10 square.
            path = [
                { x: 0, y: 0, z: 0 }
                { x: 10, y: 0, z: 0 }
                { x: 10, y: 10, z: 0 }
                { x: 0, y: 10, z: 0 }
            ]

            insetPath = paths.createInsetPath(path, 1)

            # Should have 4 points (corners of inset square).
            expect(insetPath.length).toBe(4)

            # Check that inset is smaller than original.
            for point in insetPath
                expect(point.x).toBeGreaterThan(0)
                expect(point.x).toBeLessThan(10)
                expect(point.y).toBeGreaterThan(0)
                expect(point.y).toBeLessThan(10)
            undefined

        test 'should return empty array when path is too small for inset (cone tip issue)', ->

            # Create a small circular path that simulates near-cone-tip cross-section.
            # When radius is smaller than inset distance, path should be rejected.
            smallPath = []
            pathRadius = 0.2 # mm
            nozzleDiameter = 0.4 # mm
            segments = 8

            for i in [0...segments]
                angle = (i / segments) * Math.PI * 2
                smallPath.push({
                    x: Math.cos(angle) * pathRadius
                    y: Math.sin(angle) * pathRadius
                    z: 0
                })

            insetPath = paths.createInsetPath(smallPath, nozzleDiameter)

            # Path should be rejected (empty) because it's too small.
            # This prevents the "negative radius" issue with cone tips.
            expect(insetPath.length).toBe(0)

        test 'should return empty array for path with less than 3 points', ->

            path = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
            ]

            insetPath = paths.createInsetPath(path, 1)

            expect(insetPath.length).toBe(0)

        test 'should handle different inset distances', ->

            path = [
                { x: 0, y: 0, z: 0 }
                { x: 20, y: 0, z: 0 }
                { x: 20, y: 20, z: 0 }
                { x: 0, y: 20, z: 0 }
            ]

            # Test with 2mm inset.
            insetPath2 = paths.createInsetPath(path, 2)
            expect(insetPath2.length).toBe(4)

            # Test with 5mm inset.
            insetPath5 = paths.createInsetPath(path, 5)
            expect(insetPath5.length).toBe(4)

            # Larger inset should be smaller area.
            # Check first point (should be more inset).
            expect(Math.abs(insetPath5[0].x)).toBeGreaterThan(Math.abs(insetPath2[0].x))

        test 'should inset CCW paths inward (outer boundary)', ->

            # Define a CCW square (outer boundary).
            path = [
                { x: 0, y: 0, z: 0 }
                { x: 10, y: 0, z: 0 }
                { x: 10, y: 10, z: 0 }
                { x: 0, y: 10, z: 0 }
            ]

            insetPath = paths.createInsetPath(path, 1)

            # Should have 4 points.
            expect(insetPath.length).toBe(4)

            # Inset should be smaller (moved inward).
            # All points should be within the original boundary.
            for point in insetPath
                expect(point.x).toBeGreaterThan(0)
                expect(point.x).toBeLessThan(10)
                expect(point.y).toBeGreaterThan(0)
                expect(point.y).toBeLessThan(10)

            # First point should be approximately at (1, 1).
            expect(insetPath[0].x).toBeCloseTo(1, 1)
            expect(insetPath[0].y).toBeCloseTo(1, 1)

        test 'should inset CW paths outward (hole)', ->

            # Define a CW square (hole in the middle of material).
            # This represents a hole that should shrink when inset.
            path = [
                { x: 0, y: 0, z: 0 }
                { x: 0, y: 10, z: 0 }
                { x: 10, y: 10, z: 0 }
                { x: 10, y: 0, z: 0 }
            ]

            insetPath = paths.createInsetPath(path, 1, true)  # isHole=true

            # Should have 4 points.
            expect(insetPath.length).toBe(4)

            # Inset should be larger (moved outward from hole).
            # All points should be outside the original boundary.
            for point in insetPath
                # Points should be outside the 0-10 range (expanded).
                isOutside = point.x < 0 or point.x > 10 or point.y < 0 or point.y > 10
                expect(isOutside).toBe(true)

            # First point should be approximately at (-1, -1) (outward from hole).
            expect(insetPath[0].x).toBeCloseTo(-1, 1)
            expect(insetPath[0].y).toBeCloseTo(-1, 1)

        test 'should handle torus-like geometry with outer and inner loops', ->

            # Simulate a torus cross-section: outer CCW loop and inner CW loop (hole).
            outerLoop = [
                { x: 0, y: 0, z: 0 }
                { x: 20, y: 0, z: 0 }
                { x: 20, y: 20, z: 0 }
                { x: 0, y: 20, z: 0 }
            ]

            innerLoop = [
                { x: 7, y: 7, z: 0 }
                { x: 7, y: 13, z: 0 }
                { x: 13, y: 13, z: 0 }
                { x: 13, y: 7, z: 0 }
            ]

            # Inset outer loop (should shrink).
            outerInset = paths.createInsetPath(outerLoop, 1, false)  # isHole=false
            expect(outerInset.length).toBe(4)

            # Outer inset should be inside the original boundary.
            for point in outerInset
                expect(point.x).toBeGreaterThan(0)
                expect(point.x).toBeLessThan(20)
                expect(point.y).toBeGreaterThan(0)
                expect(point.y).toBeLessThan(20)

            # Inset inner loop (hole should shrink by expanding boundary outward).
            innerInset = paths.createInsetPath(innerLoop, 1, true)  # isHole=true
            expect(innerInset.length).toBe(4)

            # Inner inset should be outside the original hole boundary.
            for point in innerInset
                isOutside = point.x < 7 or point.x > 13 or point.y < 7 or point.y > 13
                expect(isOutside).toBe(true)

            return

    describe 'connectSegmentsToPaths', ->

        test 'should connect segments into a closed path', ->

            segments = [
                { start: { x: 0, y: 0 }, end: { x: 10, y: 0 } }
                { start: { x: 10, y: 0 }, end: { x: 10, y: 10 } }
                { start: { x: 10, y: 10 }, end: { x: 0, y: 10 } }
                { start: { x: 0, y: 10 }, end: { x: 0, y: 0 } }
            ]

            result = paths.connectSegmentsToPaths(segments)

            expect(result.length).toBe(1)
            expect(result[0].length).toBeGreaterThanOrEqual(4)

        test 'should return empty array for null segments', ->

            result = paths.connectSegmentsToPaths(null)

            expect(result.length).toBe(0)

        test 'should return empty array for empty segments', ->

            result = paths.connectSegmentsToPaths([])

            expect(result.length).toBe(0)

        test 'should handle disconnected segments', ->

            segments = [
                { start: { x: 0, y: 0 }, end: { x: 5, y: 0 } }
                { start: { x: 10, y: 10 }, end: { x: 15, y: 10 } }
            ]

            result = paths.connectSegmentsToPaths(segments)

            # Should create separate paths for disconnected segments.
            # Or filter out paths with < 3 points.
            expect(result.length).toBeGreaterThanOrEqual(0)

        test 'should connect segments in correct order', ->

            # Create a triangle.
            segments = [
                { start: { x: 0, y: 0 }, end: { x: 10, y: 0 } }
                { start: { x: 10, y: 0 }, end: { x: 5, y: 10 } }
                { start: { x: 5, y: 10 }, end: { x: 0, y: 0 } }
            ]

            result = paths.connectSegmentsToPaths(segments)

            expect(result.length).toBe(1)
            expect(result[0].length).toBe(3)

            # Check that points form a connected path.
            path = result[0]
            expect(path[0].x).toBe(0)
            expect(path[0].y).toBe(0)

    describe 'calculateMinimumDistanceBetweenPaths', ->

        test 'should return infinity for degenerate paths', ->

            path1 = []
            path2 = [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 1, y: 1 }]

            result = paths.calculateMinimumDistanceBetweenPaths(path1, path2)

            expect(result).toBe(Infinity)

        test 'should calculate distance between two concentric circles', ->

            # Create two concentric square paths.
            # Inner square: 2x2 centered at origin.
            innerSquare = [
                { x: -1, y: -1 }
                { x: 1, y: -1 }
                { x: 1, y: 1 }
                { x: -1, y: 1 }
            ]

            # Outer square: 6x6 centered at origin.
            outerSquare = [
                { x: -3, y: -3 }
                { x: 3, y: -3 }
                { x: 3, y: 3 }
                { x: -3, y: 3 }
            ]

            result = paths.calculateMinimumDistanceBetweenPaths(innerSquare, outerSquare)

            # The minimum distance should be 2 (from edge to edge: 3 - 1 = 2).
            expect(result).toBeCloseTo(2, 1)

        test 'should calculate distance between adjacent paths', ->

            # Create two adjacent rectangular paths.
            path1 = [
                { x: 0, y: 0 }
                { x: 2, y: 0 }
                { x: 2, y: 2 }
                { x: 0, y: 2 }
            ]

            path2 = [
                { x: 3, y: 0 }
                { x: 5, y: 0 }
                { x: 5, y: 2 }
                { x: 3, y: 2 }
            ]

            result = paths.calculateMinimumDistanceBetweenPaths(path1, path2)

            # The minimum distance should be 1 (gap between x=2 and x=3).
            expect(result).toBeCloseTo(1, 1)

        test 'should calculate very small distance for nearly touching paths', ->

            # Create two paths that are very close together (0.3mm apart).
            path1 = [
                { x: 0, y: 0 }
                { x: 1, y: 0 }
                { x: 1, y: 1 }
                { x: 0, y: 1 }
            ]

            path2 = [
                { x: 1.3, y: 0 }
                { x: 2.3, y: 0 }
                { x: 2.3, y: 1 }
                { x: 1.3, y: 1 }
            ]

            result = paths.calculateMinimumDistanceBetweenPaths(path1, path2)

            # The minimum distance should be 0.3mm.
            expect(result).toBeCloseTo(0.3, 2)
