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

    describe 'Path Detail Preservation', ->

        test 'should preserve circular path detail when creating insets', ->

            # Create a circular path with many points (simulating a sliced cylinder).
            numPoints = 32
            radius = 5
            path = []

            for i in [0...numPoints]
                angle = (i / numPoints) * Math.PI * 2
                path.push({
                    x: Math.cos(angle) * radius
                    y: Math.sin(angle) * radius
                    z: 0
                })

            # Create inset with small offset (typical nozzle diameter / 2).
            insetDistance = 0.2
            insetPath = paths.createInsetPath(path, insetDistance, false)

            # The inset should preserve most points (at least 90% of original).
            # Previously, simplification would reduce 32 points to ~4, losing circular detail.
            minExpectedPoints = Math.floor(numPoints * 0.9)
            expect(insetPath.length).toBeGreaterThanOrEqual(minExpectedPoints)

        test 'should preserve path detail from typical cylinder slice', ->

            # Create a path with 24 points (similar to cylinder slice at 32 segments).
            numPoints = 24
            radius = 5
            path = []

            for i in [0...numPoints]
                angle = (i / numPoints) * Math.PI * 2
                path.push({
                    x: Math.cos(angle) * radius
                    y: Math.sin(angle) * radius
                    z: 0
                })

            insetDistance = 0.2
            insetPath = paths.createInsetPath(path, insetDistance, false)

            # Should preserve most points (at least 90% of original).
            minExpectedPoints = Math.floor(numPoints * 0.9)
            expect(insetPath.length).toBeGreaterThanOrEqual(minExpectedPoints)

        test 'should preserve detail from high-resolution sphere slice', ->

            # Create a path with 64 points (high-resolution sphere).
            numPoints = 64
            radius = 5
            path = []

            for i in [0...numPoints]
                angle = (i / numPoints) * Math.PI * 2
                path.push({
                    x: Math.cos(angle) * radius
                    y: Math.sin(angle) * radius
                    z: 0
                })

            insetDistance = 0.2
            insetPath = paths.createInsetPath(path, insetDistance, false)

            # Should preserve almost all points (at least 90% of original).
            minExpectedPoints = Math.floor(numPoints * 0.9)
            expect(insetPath.length).toBeGreaterThanOrEqual(minExpectedPoints)

    describe 'Degenerate Path Handling', ->

        # Helper: returns true if insetPath has a backtracking vertex (dot < dotThreshold).
        hasBacktracking = (insetPath, dotThreshold = -0.99) ->

            return false if insetPath.length < 3

            for i in [0...insetPath.length]

                prevIdx = if i is 0 then insetPath.length - 1 else i - 1
                nextIdx = if i is insetPath.length - 1 then 0 else i + 1

                prev = insetPath[prevIdx]
                curr = insetPath[i]
                next = insetPath[nextIdx]

                inX = curr.x - prev.x
                inY = curr.y - prev.y
                inLen = Math.sqrt(inX * inX + inY * inY)

                outX = next.x - curr.x
                outY = next.y - curr.y
                outLen = Math.sqrt(outX * outX + outY * outY)

                if inLen > 0.001 and outLen > 0.001

                    dot = (inX / inLen) * (outX / outLen) + (inY / inLen) * (outY / outLen)
                    return true if dot < dotThreshold

            return false

        test 'should remove duplicate consecutive points', ->

            # Create a path with duplicate consecutive points (common in problematic STL files).
            path = [
                { x: 0, y: 0, z: 0 }
                { x: 10, y: 0, z: 0 }
                { x: 10, y: 0.005, z: 0 }  # Near-duplicate (within 0.01mm)
                { x: 10, y: 10, z: 0 }
                { x: 10.005, y: 10, z: 0 }  # Near-duplicate (within 0.01mm)
                { x: 0, y: 10, z: 0 }
            ]

            insetPath = paths.createInsetPath(path, 1, false)

            # Should handle duplicates and create valid inset or return empty if too degenerate.
            # At minimum, should not crash or produce extreme coordinates.
            if insetPath.length > 0
                for point in insetPath
                    expect(Math.abs(point.x)).toBeLessThan(100)
                    expect(Math.abs(point.y)).toBeLessThan(100)

            undefined

        test 'should reject paths that produce extreme intersection coordinates', ->

            # Create a path that would produce extreme intersections due to near-parallel edges.
            # This simulates the problematic small holes from obj_2_Assembly_B.stl.
            path = [
                { x: 65.86, y: 163.91, z: 0 }
                { x: 63.83, y: 166.51, z: 0 }
                { x: 63.84, y: 166.50, z: 0 }  # Near-duplicate causing near-parallel edge
                { x: 66.94, y: 164.00, z: 0 }
                { x: 66.94, y: 163.99, z: 0 }  # Near-duplicate causing near-parallel edge
            ]

            insetPath = paths.createInsetPath(path, 0.2, true)

            # Should return empty path instead of extreme coordinates.
            # This prevents invalid G-code like X-1938, Y-3020.
            if insetPath.length > 0
                # If not rejected, validate coordinates are reasonable.
                for point in insetPath
                    expect(Math.abs(point.x)).toBeLessThan(300)
                    expect(Math.abs(point.y)).toBeLessThan(300)

            undefined

        test 'should validate intersection distance from centroid', ->

            # Create a degenerate path that previously produced extreme intersections.
            path = [
                { x: 0, y: 0, z: 0 }
                { x: 2, y: 0, z: 0 }
                { x: 2.001, y: 0.001, z: 0 }  # Near-parallel edge
                { x: 2, y: 2, z: 0 }
                { x: 0, y: 2, z: 0 }
            ]

            insetPath = paths.createInsetPath(path, 0.5, false)

            # Should either reject (empty) or produce reasonable coordinates.
            if insetPath.length > 0
                # Path size is ~2x2mm, so max allowed distance from centroid is ~20mm (10x path size).
                centroidX = 1
                centroidY = 1

                for point in insetPath
                    distFromCentroid = Math.sqrt((point.x - centroidX) ** 2 + (point.y - centroidY) ** 2)
                    # Validate not too far from centroid (using generous threshold for test).
                    expect(distFromCentroid).toBeLessThan(50)

            undefined

        test 'should handle very small paths with near-duplicate points', ->

            # Small path with points very close together (< 0.01mm).
            path = [
                { x: 10, y: 10, z: 0 }
                { x: 10.005, y: 10, z: 0 }
                { x: 10.005, y: 10.005, z: 0 }
                { x: 10, y: 10.005, z: 0 }
            ]

            insetPath = paths.createInsetPath(path, 0.2, false)

            # Should return empty (too small after deduplication) or valid coordinates.
            # Should NOT produce extreme coordinates.
            if insetPath.length > 0
                for point in insetPath
                    expect(Math.abs(point.x)).toBeLessThan(100)
                    expect(Math.abs(point.y)).toBeLessThan(100)
            else
                # Returning empty is acceptable for degenerate paths.
                expect(insetPath.length).toBe(0)

            undefined

        test 'should preserve valid paths without duplicates', ->

            # Normal path without duplicates should work as before.
            path = [
                { x: 0, y: 0, z: 0 }
                { x: 20, y: 0, z: 0 }
                { x: 20, y: 20, z: 0 }
                { x: 0, y: 20, z: 0 }
            ]

            insetPath = paths.createInsetPath(path, 2, false)

            # Should successfully create inset.
            expect(insetPath.length).toBeGreaterThan(0)
            expect(insetPath.length).toBe(4)  # Square should have 4 corners.

            # Validate coordinates are reasonable.
            for point in insetPath
                expect(point.x).toBeGreaterThan(0)
                expect(point.x).toBeLessThan(20)
                expect(point.y).toBeGreaterThan(0)
                expect(point.y).toBeLessThan(20)

            undefined

        test 'should handle near-tangent edges without producing extreme inset points', ->

            # A C-shaped path where two adjacent nearly-horizontal edges (e.g. from a sphere-box
            # intersection) have opposite computed normals due to pointInPolygon precision.
            # This previously caused inset intersections ~84mm from the vertex, producing
            # an insetWidth of 84mm instead of ~11mm, failing the widthReduction validation.
            # The fix: use a vertex-distance threshold so near-parallel diverging offset lines
            # fall back to the midpoint instead of producing a geometrically invalid result.
            cShapePath = [
                { x: -6.0000, y: -12.5000, z: 0 }
                { x:  5.8000, y: -12.5000, z: 0 }
                { x:  5.8000, y:  12.5000, z: 0 }
                { x: -6.0000, y:  12.5000, z: 0 }
                { x: -6.0000, y:  10.1342, z: 0 }
                { x: -5.8898, y:  10.1342, z: 0 }
                { x: -5.7776, y:  10.1326, z: 0 }
                { x: -5.6609, y:  10.1298, z: 0 }
                { x: -5.4000, y:   9.5000, z: 0 }
                { x: -5.0000, y:   7.0000, z: 0 }
                { x: -4.5000, y:   0.0000, z: 0 }
                { x: -5.0000, y:  -7.0000, z: 0 }
                { x: -5.4000, y:  -9.5000, z: 0 }
                { x: -5.6609, y: -10.1298, z: 0 }
                { x: -5.7776, y: -10.1326, z: 0 }
                { x: -5.8898, y: -10.1342, z: 0 }
                { x: -6.0000, y: -10.1342, z: 0 }
            ]

            insetPath = paths.createInsetPath(cShapePath, 0.4, false)

            # Should produce a valid inset path (not empty).
            expect(insetPath.length).toBeGreaterThan(0)

            # All inset points must stay within reasonable bounds (original bbox +/- 1mm).
            for point in insetPath
                expect(point.x).toBeGreaterThan(-7)
                expect(point.x).toBeLessThan(7)
                expect(point.y).toBeGreaterThan(-13.5)
                expect(point.y).toBeLessThan(13.5)

            undefined

        test 'should not produce spikes when path has a backtracking vertex near a junction', ->

            # Regression test for the Z11.7 sideways dome jagged inner wall issue.
            # A path where vertex B=(5.0002,5) is a near-backtracking vertex (dot ≈ -0.9999,
            # nearly 180° turn) between A=(5.0001,5) and C=(5.0001,5.000001).
            # The old single-pass code kept B (cross > 0.0001) but it produces near-anti-parallel
            # offset lines, generating a spike in the inset extending beyond the outer wall.
            # The fix filters it with the dot < -0.99 check, eliminating the spike.
            path = [
                { x: 0, y: 0, z: 11.7 }
                { x: 10, y: 0, z: 11.7 }
                { x: 10, y: 5, z: 11.7 }
                { x: 5.0001, y: 5, z: 11.7 }       # A: approaching backtrack
                { x: 5.0002, y: 5, z: 11.7 }       # B: backtracking vertex (dot ≈ -0.9999)
                { x: 5.0001, y: 5.000001, z: 11.7 } # C: doubles back left
                { x: 5.0000, y: 5, z: 11.7 }       # D: continues left
                { x: 0, y: 5, z: 11.7 }
            ]

            insetPath = paths.createInsetPath(path, 0.4, false)

            # Should produce a valid inset for the overall rectangular shape.
            expect(insetPath.length).toBeGreaterThan(0)

            # The inset must not contain backtracking vertices (dot < -0.97).
            # Such vertices would produce spikes extending beyond the outer wall.
            expect(hasBacktracking(insetPath)).toBe(false)

            undefined

        test 'should handle cascading backtracking vertices (Z11.9 case)', ->

            # Regression test for the cascading backtracking case at Z11.9.
            # Path has two consecutive near-backtracking vertices:
            #   C=(4.0001,5) is backtracking between B=(4,5) and D=(3.9999,5.000001).
            #   After the single-pass removes C, B=(4,5) becomes backtracking between
            #   A=(3.9999,5) and D (A→B goes right, B→D goes left: dot = -0.9999).
            # The while-loop iterative fix handles this cascading case correctly.
            path = [
                { x: 0, y: 0, z: 11.9 }
                { x: 10, y: 0, z: 11.9 }
                { x: 10, y: 5, z: 11.9 }
                { x: 3.9999, y: 5, z: 11.9 }       # A: approaching cascade
                { x: 4.0000, y: 5, z: 11.9 }       # B: exposed as backtracking after C removed
                { x: 4.0001, y: 5, z: 11.9 }       # C: first backtracking vertex (dot ≈ -0.9999)
                { x: 3.9999, y: 5.000001, z: 11.9 } # D: new neighbor after cascade
                { x: 0, y: 5, z: 11.9 }
            ]

            insetPath = paths.createInsetPath(path, 0.4, false)

            # Should produce a valid inset for the overall rectangular shape.
            expect(insetPath.length).toBeGreaterThan(0)

            # The inset must not contain backtracking vertices (dot < -0.97).
            expect(hasBacktracking(insetPath)).toBe(false)

            undefined

        test 'should produce infill boundary for concave C-shaped path with sphere-arc junction', ->

            # Simulates the innerWall at sideways dome layer ~60 where a C-shaped cross-section
            # (box minus sphere arc) previously failed widthReduction validation because concave
            # re-entrant corners cause the inset to expand slightly in the X dimension.
            # The fix: allow up to insetDistance*2 expansion (for concavity) in the bounding box
            # check, instead of requiring a minimum positive reduction.
            cShapePath = [
                { x: -5.9340, y: -11.9000, z: 0 }
                { x:  5.4000, y: -11.9000, z: 0 }
                { x:  5.4000, y:  11.9000, z: 0 }
                { x: -5.9340, y:  11.9000, z: 0 }
                { x: -5.9340, y:   9.8799, z: 0 }
                { x: -5.8019, y:   9.8581, z: 0 }
                { x: -5.6136, y:   9.8581, z: 0 }
                { x: -5.4000, y:   9.5000, z: 0 }
                { x: -5.2000, y:   8.0000, z: 0 }
                { x: -5.0000, y:   0.0000, z: 0 }
                { x: -5.2000, y:  -8.0000, z: 0 }
                { x: -5.4000, y:  -9.5000, z: 0 }
                { x: -5.6136, y:  -9.8581, z: 0 }
                { x: -5.8019, y:  -9.8581, z: 0 }
                { x: -5.9340, y:  -9.8799, z: 0 }
            ]

            insetPath = paths.createInsetPath(cShapePath, 0.4, false)

            # Should produce a valid inset path (not empty).
            expect(insetPath.length).toBeGreaterThan(0)

            # All inset points must stay within original bbox + insetDistance margin.
            for point in insetPath
                expect(point.x).toBeGreaterThan(-7)
                expect(point.x).toBeLessThan(7)
                expect(point.y).toBeGreaterThan(-13)
                expect(point.y).toBeLessThan(13)

            undefined
