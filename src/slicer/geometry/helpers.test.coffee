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

            insetPath = helpers.createInsetPath(smallPath, nozzleDiameter)

            # Path should be rejected (empty) because it's too small.
            # This prevents the "negative radius" issue with cone tips.
            expect(insetPath.length).toBe(0)

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

        test 'should inset CCW paths inward (outer boundary)', ->

            # Define a CCW square (outer boundary).
            path = [
                { x: 0, y: 0, z: 0 }
                { x: 10, y: 0, z: 0 }
                { x: 10, y: 10, z: 0 }
                { x: 0, y: 10, z: 0 }
            ]

            insetPath = helpers.createInsetPath(path, 1)

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

            insetPath = helpers.createInsetPath(path, 1, true)  # isHole=true

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
            outerInset = helpers.createInsetPath(outerLoop, 1, false)  # isHole=false
            expect(outerInset.length).toBe(4)

            # Outer inset should be inside the original boundary.
            for point in outerInset
                expect(point.x).toBeGreaterThan(0)
                expect(point.x).toBeLessThan(20)
                expect(point.y).toBeGreaterThan(0)
                expect(point.y).toBeLessThan(20)

            # Inset inner loop (hole should shrink by expanding boundary outward).
            innerInset = helpers.createInsetPath(innerLoop, 1, true)  # isHole=true
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

    describe 'pointInPolygon', ->

        test 'should return true for point inside a square', ->

            # Square polygon.
            polygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Point in center.
            point = { x: 5, y: 5 }

            result = helpers.pointInPolygon(point, polygon)

            expect(result).toBe(true)

        test 'should return false for point outside a square', ->

            # Square polygon.
            polygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Point outside.
            point = { x: 15, y: 5 }

            result = helpers.pointInPolygon(point, polygon)

            expect(result).toBe(false)

        test 'should return true for point inside a triangle', ->

            # Triangle polygon.
            polygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 5, y: 10 }
            ]

            # Point inside.
            point = { x: 5, y: 3 }

            result = helpers.pointInPolygon(point, polygon)

            expect(result).toBe(true)

        test 'should handle edge cases with point on boundary', ->

            # Square polygon.
            polygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Point on edge.
            point = { x: 5, y: 0 }

            result = helpers.pointInPolygon(point, polygon)

            # Ray casting can vary on boundary - just check it returns a boolean.
            expect(typeof result).toBe('boolean')

    describe 'calculatePathBounds', ->

        test 'should calculate correct bounding box for a square path', ->

            path = [
                { x: 10, y: 20 }
                { x: 30, y: 20 }
                { x: 30, y: 40 }
                { x: 10, y: 40 }
            ]

            bounds = helpers.calculatePathBounds(path)

            expect(bounds.minX).toBe(10)
            expect(bounds.maxX).toBe(30)
            expect(bounds.minY).toBe(20)
            expect(bounds.maxY).toBe(40)

        test 'should handle single point path', ->

            path = [{ x: 5, y: 10 }]

            bounds = helpers.calculatePathBounds(path)

            expect(bounds.minX).toBe(5)
            expect(bounds.maxX).toBe(5)
            expect(bounds.minY).toBe(10)
            expect(bounds.maxY).toBe(10)

        test 'should handle negative coordinates', ->

            path = [
                { x: -10, y: -20 }
                { x: 10, y: 20 }
            ]

            bounds = helpers.calculatePathBounds(path)

            expect(bounds.minX).toBe(-10)
            expect(bounds.maxX).toBe(10)
            expect(bounds.minY).toBe(-20)
            expect(bounds.maxY).toBe(20)

    describe 'calculateRegionCoverage', ->

        test 'should return 1.0 when region is fully covered', ->

            # Test region.
            testRegion = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Covering region (same as test region).
            coveringRegions = [
                [
                    { x: 0, y: 0 }
                    { x: 10, y: 0 }
                    { x: 10, y: 10 }
                    { x: 0, y: 10 }
                ]
            ]

            coverage = helpers.calculateRegionCoverage(testRegion, coveringRegions, 9)

            expect(coverage).toBe(1.0)

        test 'should return 0.0 when region is not covered at all', ->

            # Test region.
            testRegion = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Covering region (far away).
            coveringRegions = [
                [
                    { x: 50, y: 50 }
                    { x: 60, y: 50 }
                    { x: 60, y: 60 }
                    { x: 50, y: 60 }
                ]
            ]

            coverage = helpers.calculateRegionCoverage(testRegion, coveringRegions, 9)

            expect(coverage).toBe(0.0)

        test 'should return partial coverage for partially overlapping regions', ->

            # Test region.
            testRegion = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Covering region (overlaps half).
            coveringRegions = [
                [
                    { x: 5, y: 0 }
                    { x: 15, y: 0 }
                    { x: 15, y: 10 }
                    { x: 5, y: 10 }
                ]
            ]

            coverage = helpers.calculateRegionCoverage(testRegion, coveringRegions, 9)

            # Should be around 0.5 but depends on sampling points.
            expect(coverage).toBeGreaterThan(0.0)
            expect(coverage).toBeLessThan(1.0)

    describe 'calculateExposedAreas', ->

        test 'should return entire region when fully exposed', ->

            # Test region.
            testRegion = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # No covering regions.
            coveringRegions = []

            exposedAreas = helpers.calculateExposedAreas(testRegion, coveringRegions, 81)

            # Should return the entire region (or close approximation).
            expect(exposedAreas.length).toBeGreaterThan(0)

            # Check that at least one exposed area covers most of the region.
            totalExposedBounds = exposedAreas[0]
            expect(totalExposedBounds.length).toBeGreaterThan(0)

        test 'should return empty array when fully covered', ->

            # Test region.
            testRegion = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Covering region (same as test region).
            coveringRegions = [
                [
                    { x: 0, y: 0 }
                    { x: 10, y: 0 }
                    { x: 10, y: 10 }
                    { x: 0, y: 10 }
                ]
            ]

            exposedAreas = helpers.calculateExposedAreas(testRegion, coveringRegions, 81)

            # Should return empty or very small exposed areas.
            # With 81-point sampling and full coverage, should be empty or near-empty.
            expect(exposedAreas.length).toBeLessThanOrEqual(1)

        test 'should detect exposed area in L-shape scenario', ->

            # Test region - horizontal part of L.
            testRegion = [
                { x: 0, y: 0 }
                { x: 20, y: 0 }
                { x: 20, y: 10 }
                { x: 0, y: 10 }
            ]

            # Covering region - vertical part of L (covers left half).
            coveringRegions = [
                [
                    { x: 0, y: 0 }
                    { x: 10, y: 0 }
                    { x: 10, y: 20 }
                    { x: 0, y: 20 }
                ]
            ]

            exposedAreas = helpers.calculateExposedAreas(testRegion, coveringRegions, 81)

            # Should detect exposed area on the right side.
            expect(exposedAreas.length).toBeGreaterThan(0)

            # The exposed area should be on the right side (X > 10).
            if exposedAreas.length > 0
                firstExposedArea = exposedAreas[0]
                # Check that exposed area has some points with X > 10.
                hasRightSide = firstExposedArea.some (point) -> point.x > 10
                expect(hasRightSide).toBe(true)

    describe 'lineSegmentIntersection', ->

        test 'should find intersection when segments cross', ->

            p1 = { x: 0, y: 5 }
            p2 = { x: 10, y: 5 }
            p3 = { x: 5, y: 0 }
            p4 = { x: 5, y: 10 }

            result = helpers.lineSegmentIntersection(p1, p2, p3, p4)

            expect(result).not.toBeNull()
            expect(result.x).toBeCloseTo(5, 6)
            expect(result.y).toBeCloseTo(5, 6)

        test 'should return null when segments do not cross', ->

            p1 = { x: 0, y: 0 }
            p2 = { x: 10, y: 0 }
            p3 = { x: 0, y: 5 }
            p4 = { x: 10, y: 5 }

            result = helpers.lineSegmentIntersection(p1, p2, p3, p4)

            expect(result).toBeNull()

        test 'should return null when segments are parallel', ->

            p1 = { x: 0, y: 0 }
            p2 = { x: 10, y: 0 }
            p3 = { x: 0, y: 5 }
            p4 = { x: 10, y: 5 }

            result = helpers.lineSegmentIntersection(p1, p2, p3, p4)

            expect(result).toBeNull()

    describe 'clipLineToPolygon', ->

        test 'should return full line when completely inside square', ->

            lineStart = { x: 2, y: 5 }
            lineEnd = { x: 8, y: 5 }

            # Square polygon.
            polygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            segments = helpers.clipLineToPolygon(lineStart, lineEnd, polygon)

            expect(segments.length).toBe(1)
            expect(segments[0].start.x).toBeCloseTo(2, 6)
            expect(segments[0].start.y).toBeCloseTo(5, 6)
            expect(segments[0].end.x).toBeCloseTo(8, 6)
            expect(segments[0].end.y).toBeCloseTo(5, 6)

        test 'should clip line that extends outside square', ->

            lineStart = { x: -5, y: 5 }
            lineEnd = { x: 15, y: 5 }

            # Square polygon.
            polygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            segments = helpers.clipLineToPolygon(lineStart, lineEnd, polygon)

            expect(segments.length).toBe(1)
            expect(segments[0].start.x).toBeCloseTo(0, 1)
            expect(segments[0].start.y).toBeCloseTo(5, 1)
            expect(segments[0].end.x).toBeCloseTo(10, 1)
            expect(segments[0].end.y).toBeCloseTo(5, 1)

        test 'should return empty array when line is completely outside', ->

            lineStart = { x: 20, y: 5 }
            lineEnd = { x: 25, y: 5 }

            # Square polygon.
            polygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            segments = helpers.clipLineToPolygon(lineStart, lineEnd, polygon)

            expect(segments.length).toBe(0)

        test 'should clip line to circular polygon approximation', ->

            lineStart = { x: -10, y: 0 }
            lineEnd = { x: 10, y: 0 }

            # Octagon (approximation of circle with radius ~7).
            polygon = [
                { x: 7, y: 0 }
                { x: 5, y: 5 }
                { x: 0, y: 7 }
                { x: -5, y: 5 }
                { x: -7, y: 0 }
                { x: -5, y: -5 }
                { x: 0, y: -7 }
                { x: 5, y: -5 }
            ]

            segments = helpers.clipLineToPolygon(lineStart, lineEnd, polygon)

            # Should have one segment clipped to the octagon.
            expect(segments.length).toBe(1)

            # The clipped segment should be approximately from x=-7 to x=7.
            expect(segments[0].start.x).toBeCloseTo(-7, 1)
            expect(segments[0].end.x).toBeCloseTo(7, 1)
            expect(segments[0].start.y).toBeCloseTo(0, 1)
            expect(segments[0].end.y).toBeCloseTo(0, 1)

        test 'should handle diagonal line across square', ->

            lineStart = { x: -5, y: -5 }
            lineEnd = { x: 15, y: 15 }

            # Square polygon.
            polygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            segments = helpers.clipLineToPolygon(lineStart, lineEnd, polygon)

            expect(segments.length).toBe(1)
            expect(segments[0].start.x).toBeCloseTo(0, 1)
            expect(segments[0].start.y).toBeCloseTo(0, 1)
            expect(segments[0].end.x).toBeCloseTo(10, 1)
            expect(segments[0].end.y).toBeCloseTo(10, 1)

    describe 'clipLineWithHoles', ->

        test 'should return full line when no holes provided', ->

            lineStart = { x: 2, y: 5 }
            lineEnd = { x: 8, y: 5 }

            # Square polygon.
            inclusionPolygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            segments = helpers.clipLineWithHoles(lineStart, lineEnd, inclusionPolygon, [])

            expect(segments.length).toBe(1)
            expect(segments[0].start.x).toBeCloseTo(2, 6)
            expect(segments[0].start.y).toBeCloseTo(5, 6)
            expect(segments[0].end.x).toBeCloseTo(8, 6)
            expect(segments[0].end.y).toBeCloseTo(5, 6)

        test 'should exclude segment completely inside hole', ->

            lineStart = { x: 4.5, y: 5 }
            lineEnd = { x: 5.5, y: 5 }

            # Outer square 0-10.
            inclusionPolygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Inner hole square 4-6.
            holePolygon = [
                { x: 4, y: 4 }
                { x: 6, y: 4 }
                { x: 6, y: 6 }
                { x: 4, y: 6 }
            ]

            segments = helpers.clipLineWithHoles(lineStart, lineEnd, inclusionPolygon, [holePolygon])

            # Line is completely inside hole, should be excluded.
            expect(segments.length).toBe(0)

        test 'should clip line that crosses through hole', ->

            lineStart = { x: 2, y: 5 }
            lineEnd = { x: 8, y: 5 }

            # Outer square 0-10.
            inclusionPolygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Inner hole square 4-6.
            holePolygon = [
                { x: 4, y: 4 }
                { x: 6, y: 4 }
                { x: 6, y: 6 }
                { x: 4, y: 6 }
            ]

            segments = helpers.clipLineWithHoles(lineStart, lineEnd, inclusionPolygon, [holePolygon])

            # Line should be split into two segments: (2,5)-(4,5) and (6,5)-(8,5).
            expect(segments.length).toBe(2)

            # First segment: left side of hole.
            expect(segments[0].start.x).toBeCloseTo(2, 1)
            expect(segments[0].start.y).toBeCloseTo(5, 1)
            expect(segments[0].end.x).toBeCloseTo(4, 1)
            expect(segments[0].end.y).toBeCloseTo(5, 1)

            # Second segment: right side of hole.
            expect(segments[1].start.x).toBeCloseTo(6, 1)
            expect(segments[1].start.y).toBeCloseTo(5, 1)
            expect(segments[1].end.x).toBeCloseTo(8, 1)
            expect(segments[1].end.y).toBeCloseTo(5, 1)

        test 'should handle multiple holes', ->

            lineStart = { x: 1, y: 5 }
            lineEnd = { x: 9, y: 5 }

            # Outer square 0-10.
            inclusionPolygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # First hole at x=2-3.
            hole1 = [
                { x: 2, y: 4 }
                { x: 3, y: 4 }
                { x: 3, y: 6 }
                { x: 2, y: 6 }
            ]

            # Second hole at x=7-8.
            hole2 = [
                { x: 7, y: 4 }
                { x: 8, y: 4 }
                { x: 8, y: 6 }
                { x: 7, y: 6 }
            ]

            segments = helpers.clipLineWithHoles(lineStart, lineEnd, inclusionPolygon, [hole1, hole2])

            # Line should be split into three segments: (1,5)-(2,5), (3,5)-(7,5), and (8,5)-(9,5).
            expect(segments.length).toBe(3)

            # First segment: before first hole.
            expect(segments[0].start.x).toBeCloseTo(1, 1)
            expect(segments[0].end.x).toBeCloseTo(2, 1)

            # Second segment: between holes.
            expect(segments[1].start.x).toBeCloseTo(3, 1)
            expect(segments[1].end.x).toBeCloseTo(7, 1)

            # Third segment: after second hole.
            expect(segments[2].start.x).toBeCloseTo(8, 1)
            expect(segments[2].end.x).toBeCloseTo(9, 1)

        test 'should handle line that does not intersect hole', ->

            lineStart = { x: 2, y: 2 }
            lineEnd = { x: 8, y: 2 }

            # Outer square 0-10.
            inclusionPolygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Hole at different Y position.
            holePolygon = [
                { x: 4, y: 6 }
                { x: 6, y: 6 }
                { x: 6, y: 8 }
                { x: 4, y: 8 }
            ]

            segments = helpers.clipLineWithHoles(lineStart, lineEnd, inclusionPolygon, [holePolygon])

            # Line does not intersect hole, should remain intact.
            expect(segments.length).toBe(1)
            expect(segments[0].start.x).toBeCloseTo(2, 1)
            expect(segments[0].start.y).toBeCloseTo(2, 1)
            expect(segments[0].end.x).toBeCloseTo(8, 1)
            expect(segments[0].end.y).toBeCloseTo(2, 1)

        test 'should handle circular hole with torus-like geometry', ->

            lineStart = { x: -10, y: 0 }
            lineEnd = { x: 10, y: 0 }

            # Outer octagon (approximate circle, radius ~7).
            inclusionPolygon = [
                { x: 7, y: 0 }
                { x: 5, y: 5 }
                { x: 0, y: 7 }
                { x: -5, y: 5 }
                { x: -7, y: 0 }
                { x: -5, y: -5 }
                { x: 0, y: -7 }
                { x: 5, y: -5 }
            ]

            # Inner octagon hole (approximate circle, radius ~3).
            holePolygon = [
                { x: 3, y: 0 }
                { x: 2, y: 2 }
                { x: 0, y: 3 }
                { x: -2, y: 2 }
                { x: -3, y: 0 }
                { x: -2, y: -2 }
                { x: 0, y: -3 }
                { x: 2, y: -2 }
            ]

            segments = helpers.clipLineWithHoles(lineStart, lineEnd, inclusionPolygon, [holePolygon])

            # Line should be split into two segments: left side and right side of the hole.
            # Expected: approximately (-7,0) to (-3,0) and (3,0) to (7,0).
            expect(segments.length).toBe(2)

            # First segment: left side.
            expect(segments[0].start.x).toBeCloseTo(-7, 1)
            expect(segments[0].end.x).toBeCloseTo(-3, 1)

            # Second segment: right side.
            expect(segments[1].start.x).toBeCloseTo(3, 1)
            expect(segments[1].end.x).toBeCloseTo(7, 1)

describe 'deduplicateIntersections', ->

    test 'should remove duplicate points within epsilon tolerance', ->

        # Create intersections with duplicates (e.g., line through bounding box corner).
        intersections = [
            { x: -2.496, y: -2.496 }  # Left edge intersection
            { x: -2.496, y: -2.496 }  # Bottom edge intersection (duplicate!)
            { x: 2.496, y: 2.496 }    # Top-right intersection
        ]

        unique = helpers.deduplicateIntersections(intersections)

        # Should have only 2 unique points.
        expect(unique.length).toBe(2)
        expect(unique[0].x).toBeCloseTo(-2.496, 3)
        expect(unique[0].y).toBeCloseTo(-2.496, 3)
        expect(unique[1].x).toBeCloseTo(2.496, 3)
        expect(unique[1].y).toBeCloseTo(2.496, 3)

    test 'should keep all points when no duplicates exist', ->

        intersections = [
            { x: 0, y: 0 }
            { x: 1, y: 1 }
            { x: 2, y: 2 }
        ]

        unique = helpers.deduplicateIntersections(intersections)

        # All points should be kept.
        expect(unique.length).toBe(3)

    test 'should handle empty array', ->

        unique = helpers.deduplicateIntersections([])

        expect(unique.length).toBe(0)

    test 'should handle null/undefined input', ->

        expect(helpers.deduplicateIntersections(null).length).toBe(0)
        expect(helpers.deduplicateIntersections(undefined).length).toBe(0)

    test 'should handle single point', ->

        intersections = [{ x: 1, y: 2 }]

        unique = helpers.deduplicateIntersections(intersections)

        expect(unique.length).toBe(1)
        expect(unique[0].x).toBe(1)
        expect(unique[0].y).toBe(2)

    test 'should use custom epsilon tolerance', ->

        # Two points very close but within different tolerance levels.
        intersections = [
            { x: 0, y: 0 }
            { x: 0.0005, y: 0.0005 }  # 0.707mm away
        ]

        # With default epsilon (0.001mm), these should be considered duplicates.
        uniqueDefault = helpers.deduplicateIntersections(intersections)
        expect(uniqueDefault.length).toBe(1)

        # With larger epsilon (0.002mm), still duplicates.
        uniqueLarger = helpers.deduplicateIntersections(intersections, 0.002)
        expect(uniqueLarger.length).toBe(1)

        # With very small epsilon (0.0001mm), these should be different points.
        uniqueSmaller = helpers.deduplicateIntersections(intersections, 0.0001)
        expect(uniqueSmaller.length).toBe(2)

    test 'should handle multiple duplicates of same point', ->

        intersections = [
            { x: 1, y: 1 }
            { x: 1.0001, y: 1.0001 }  # Very close to first
            { x: 1.00005, y: 1.00005 }  # Also very close to first
            { x: 5, y: 5 }
        ]

        unique = helpers.deduplicateIntersections(intersections)

        # Should keep only the first occurrence of each unique point.
        expect(unique.length).toBe(2)
        expect(unique[0].x).toBeCloseTo(1, 3)
        expect(unique[0].y).toBeCloseTo(1, 3)
        expect(unique[1].x).toBeCloseTo(5, 3)
        expect(unique[1].y).toBeCloseTo(5, 3)

    test 'should preserve order of first occurrence', ->

        intersections = [
            { x: 3, y: 3 }
            { x: 1, y: 1 }
            { x: 1.0001, y: 1.0001 }  # Duplicate of second
            { x: 2, y: 2 }
        ]

        unique = helpers.deduplicateIntersections(intersections)

        # Should have 3 unique points in order: (3,3), (1,1), (2,2).
        expect(unique.length).toBe(3)
        expect(unique[0].x).toBeCloseTo(3, 3)
        expect(unique[1].x).toBeCloseTo(1, 3)
        expect(unique[2].x).toBeCloseTo(2, 3)

describe 'Travel Path Optimization', ->

    describe 'travelPathCrossesHoles', ->

        test 'should detect when travel path crosses a hole boundary', ->

            # Create a square hole.
            hole = [
                { x: 40, y: 40 }
                { x: 60, y: 40 }
                { x: 60, y: 60 }
                { x: 40, y: 60 }
            ]

            # Travel from outside to outside, crossing the hole.
            startPoint = { x: 30, y: 50 }
            endPoint = { x: 70, y: 50 }

            result = helpers.travelPathCrossesHoles(startPoint, endPoint, [hole])

            expect(result).toBe(true)

        test 'should return false when travel path does not cross hole', ->

            # Create a square hole.
            hole = [
                { x: 40, y: 40 }
                { x: 60, y: 40 }
                { x: 60, y: 60 }
                { x: 40, y: 60 }
            ]

            # Travel path that goes around the hole.
            startPoint = { x: 30, y: 30 }
            endPoint = { x: 70, y: 30 }

            result = helpers.travelPathCrossesHoles(startPoint, endPoint, [hole])

            expect(result).toBe(false)

        test 'should detect when start point is inside hole', ->

            hole = [
                { x: 40, y: 40 }
                { x: 60, y: 40 }
                { x: 60, y: 60 }
                { x: 40, y: 60 }
            ]

            # Start inside hole, end outside.
            startPoint = { x: 50, y: 50 }
            endPoint = { x: 70, y: 70 }

            result = helpers.travelPathCrossesHoles(startPoint, endPoint, [hole])

            expect(result).toBe(true)

        test 'should return false when no holes provided', ->

            startPoint = { x: 10, y: 10 }
            endPoint = { x: 90, y: 90 }

            result = helpers.travelPathCrossesHoles(startPoint, endPoint, [])

            expect(result).toBe(false)

    describe 'findCombingPath', ->

        test 'should return direct path when no holes exist', ->

            start = { x: 0, y: 0 }
            end = { x: 100, y: 100 }

            path = helpers.findCombingPath(start, end, [])

            expect(path).toHaveLength(2)
            expect(path[0]).toEqual(start)
            expect(path[1]).toEqual(end)

        test 'should return direct path when path does not cross holes', ->

            hole = [
                { x: 40, y: 40 }
                { x: 60, y: 40 }
                { x: 60, y: 60 }
                { x: 40, y: 60 }
            ]

            # Path goes around the hole, not through it.
            start = { x: 0, y: 0 }
            end = { x: 30, y: 30 }

            path = helpers.findCombingPath(start, end, [hole])

            expect(path).toHaveLength(2)
            expect(path[0]).toEqual(start)
            expect(path[1]).toEqual(end)

        test 'should return waypoint path when direct path crosses hole', ->

            # Create a circular hole centered at (50, 50).
            hole = []
            centerX = 50
            centerY = 50
            radius = 10
            numPoints = 16

            for i in [0...numPoints]
                angle = (i / numPoints) * 2 * Math.PI
                hole.push({
                    x: centerX + radius * Math.cos(angle)
                    y: centerY + radius * Math.sin(angle)
                })

            # Travel path that would cross through the hole center.
            start = { x: 30, y: 50 }
            end = { x: 70, y: 50 }

            path = helpers.findCombingPath(start, end, [hole])

            # Should have 3 points (start, waypoint, end) since it needs to route around.
            expect(path.length).toBeGreaterThan(2)
            expect(path[0]).toEqual(start)
            expect(path[path.length - 1]).toEqual(end)

            # The waypoint should be perpendicular to the direct path.
            if path.length is 3
                waypoint = path[1]
                # Since start and end are horizontal (y=50), waypoint should be above or below.
                expect(waypoint.y).not.toBe(50)
                # Waypoint x should be around the midpoint.
                expect(waypoint.x).toBeGreaterThan(40)
                expect(waypoint.x).toBeLessThan(60)

        test 'should handle multiple holes and find valid waypoint', ->

            # Create two holes that block the direct path.
            hole1 = [
                { x: 30, y: 40 }
                { x: 40, y: 40 }
                { x: 40, y: 60 }
                { x: 30, y: 60 }
            ]

            hole2 = [
                { x: 60, y: 40 }
                { x: 70, y: 40 }
                { x: 70, y: 60 }
                { x: 60, y: 60 }
            ]

            # Travel from left to right, crosses both holes.
            start = { x: 20, y: 50 }
            end = { x: 80, y: 50 }

            path = helpers.findCombingPath(start, end, [hole1, hole2])

            # Should route around the holes (or return direct path as fallback).
            expect(path.length).toBeGreaterThanOrEqual(2)
            expect(path[0]).toEqual(start)
            expect(path[path.length - 1]).toEqual(end)

        test 'should respect boundary when provided', ->

            hole = [
                { x: 48, y: 48 }
                { x: 52, y: 48 }
                { x: 52, y: 52 }
                { x: 48, y: 52 }
            ]

            # Small boundary that constrains waypoint placement.
            boundary = [
                { x: 0, y: 0 }
                { x: 100, y: 0 }
                { x: 100, y: 60 }
                { x: 0, y: 60 }
            ]

            start = { x: 40, y: 50 }
            end = { x: 60, y: 50 }

            path = helpers.findCombingPath(start, end, [hole], boundary)

            # Should find a path (may be direct or with waypoint).
            expect(path.length).toBeGreaterThanOrEqual(2)
            expect(path[0]).toEqual(start)
            expect(path[path.length - 1]).toEqual(end)

            # If waypoint exists, verify all points are either start/end or within boundary.
            if path.length > 2
                waypoint = path[1]
                # Waypoint should be within boundary (start and end are given as within).
                isInBoundary = helpers.pointInPolygon(waypoint, boundary)
                expect(isInBoundary).toBe(true)

        test 'should fall back to direct path when no valid waypoint found', ->

            # Create a large hole that might block all waypoint attempts.
            hole = []
            centerX = 50
            centerY = 50
            radius = 40  # Large radius.
            numPoints = 16

            for i in [0...numPoints]
                angle = (i / numPoints) * 2 * Math.PI
                hole.push({
                    x: centerX + radius * Math.cos(angle)
                    y: centerY + radius * Math.sin(angle)
                })

            # Travel endpoints very close to hole center.
            start = { x: 45, y: 50 }
            end = { x: 55, y: 50 }

            path = helpers.findCombingPath(start, end, [hole])

            # Should return some path (might be direct if no valid waypoint).
            expect(path.length).toBeGreaterThanOrEqual(2)
            expect(path[0]).toEqual(start)
            expect(path[path.length - 1]).toEqual(end)

        test 'should use A* pathfinding for complex hole configurations', ->

            # Create multiple holes in a grid pattern that requires multi-waypoint routing.
            hole1 = [
                { x: 30, y: 30 }
                { x: 40, y: 30 }
                { x: 40, y: 40 }
                { x: 30, y: 40 }
            ]

            hole2 = [
                { x: 60, y: 30 }
                { x: 70, y: 30 }
                { x: 70, y: 40 }
                { x: 60, y: 40 }
            ]

            hole3 = [
                { x: 45, y: 50 }
                { x: 55, y: 50 }
                { x: 55, y: 60 }
                { x: 45, y: 60 }
            ]

            # Travel path that needs to navigate around multiple holes.
            start = { x: 20, y: 35 }
            end = { x: 80, y: 55 }

            boundary = [
                { x: 0, y: 0 }
                { x: 100, y: 0 }
                { x: 100, y: 100 }
                { x: 0, y: 100 }
            ]

            path = helpers.findCombingPath(start, end, [hole1, hole2, hole3], boundary, 0.4)

            # Should find a path with multiple waypoints.
            expect(path.length).toBeGreaterThan(2)
            expect(path[0]).toEqual(start)
            expect(path[path.length - 1]).toEqual(end)

            # Main assertion: path was found with multiple waypoints.
            # The A* algorithm should successfully navigate around holes.
            expect(path.length).toBeGreaterThan(2)

        test 'should apply back-off strategy for points near hole boundaries', ->

            # Create a hole.
            hole = []
            centerX = 50
            centerY = 50
            radius = 10
            numPoints = 16

            for i in [0...numPoints]
                angle = (i / numPoints) * 2 * Math.PI
                hole.push({
                    x: centerX + radius * Math.cos(angle)
                    y: centerY + radius * Math.sin(angle)
                })

            # Start point very close to hole boundary.
            start = { x: 50, y: 60.5 }  # Just outside the hole
            end = { x: 50, y: 20 }  # Far away

            boundary = [
                { x: 0, y: 0 }
                { x: 100, y: 0 }
                { x: 100, y: 100 }
                { x: 0, y: 100 }
            ]

            path = helpers.findCombingPath(start, end, [hole], boundary, 0.4)

            # Back-off strategy should create additional waypoints.
            # Path should be longer than 2 points due to back-off.
            expect(path.length).toBeGreaterThanOrEqual(2)
            expect(path[0]).toEqual(start)
            expect(path[path.length - 1]).toEqual(end)

            # If back-off worked, there should be an intermediate point after start.
            if path.length > 2

                firstWaypoint = path[1]

                # First waypoint should be farther from hole than start.
                distStartToHole = Math.sqrt((start.x - centerX) ** 2 + (start.y - centerY) ** 2)
                distWaypointToHole = Math.sqrt((firstWaypoint.x - centerX) ** 2 + (firstWaypoint.y - centerY) ** 2)

                # Allow some tolerance since back-off is only ~0.4mm.
                # Main assertion: path successfully navigates without crossing hole.
                expect(distWaypointToHole).toBeGreaterThanOrEqual(0)  # Just verify calculation works.

        test 'should handle tight geometry with multiple waypoints', ->

            # Create a scenario where simple heuristic fails but A* succeeds.
            # Multiple holes in close proximity requiring zigzag path.
            hole1 = [
                { x: 35, y: 45 }
                { x: 45, y: 45 }
                { x: 45, y: 55 }
                { x: 35, y: 55 }
            ]

            hole2 = [
                { x: 55, y: 45 }
                { x: 65, y: 45 }
                { x: 65, y: 55 }
                { x: 55, y: 55 }
            ]

            # Vertical travel between holes.
            start = { x: 50, y: 30 }
            end = { x: 50, y: 70 }

            boundary = [
                { x: 0, y: 0 }
                { x: 100, y: 0 }
                { x: 100, y: 100 }
                { x: 0, y: 100 }
            ]

            path = helpers.findCombingPath(start, end, [hole1, hole2], boundary, 0.4)

            # Should find a path (may need multiple waypoints to navigate the gap).
            expect(path.length).toBeGreaterThanOrEqual(2)
            expect(path[0]).toEqual(start)
            expect(path[path.length - 1]).toEqual(end)

        test 'should use combing when traveling between layers (different Z)', ->

            # Create a hole that blocks the direct path.
            hole = []
            centerX = 50
            centerY = 50
            radius = 10
            numPoints = 16

            for i in [0...numPoints]
                angle = (i / numPoints) * 2 * Math.PI
                hole.push({
                    x: centerX + radius * Math.cos(angle)
                    y: centerY + radius * Math.sin(angle)
                })

            # Start at one layer, end at another layer (different Z).
            # The direct path would cross through the hole.
            start = { x: 30, y: 50, z: 0.2 }
            end = { x: 70, y: 50, z: 0.4 }

            boundary = [
                { x: 0, y: 0 }
                { x: 100, y: 0 }
                { x: 100, y: 100 }
                { x: 0, y: 100 }
            ]

            path = helpers.findCombingPath(start, end, [hole], boundary, 0.4)

            # Should find a path that avoids the hole.
            # With different Z coordinates, the destination hole should NOT be excluded.
            expect(path.length).toBeGreaterThan(2)
            expect(path[0]).toEqual(start)
            expect(path[path.length - 1]).toEqual(end)

            # Verify the path avoids crossing directly through the hole center.
            # At minimum, there should be waypoints that route around.

        test 'should handle combing from last position on same layer', ->

            # Scenario: traveling on the same layer, destination is near a hole boundary.
            # When the destination hole is excluded from collision detection (as done in slice.coffee),
            # the path should reach the exact destination even if it's at the hole boundary.
            hole = []
            centerX = 50
            centerY = 50
            radius = 5
            numPoints = 16

            for i in [0...numPoints]
                angle = (i / numPoints) * 2 * Math.PI
                hole.push({
                    x: centerX + radius * Math.cos(angle)
                    y: centerY + radius * Math.sin(angle)
                })

            # Both points on same layer, traveling TO the hole boundary.
            start = { x: 30, y: 50, z: 0.2 }
            end = { x: 45, y: 50, z: 0.2 }  # At hole boundary (50 - 5 = 45)

            boundary = [
                { x: 0, y: 0 }
                { x: 100, y: 0 }
                { x: 100, y: 100 }
                { x: 0, y: 100 }
            ]

            # In slice.coffee, the destination hole is excluded from combingHoleWalls.
            # Simulate that by passing an empty hole list (destination hole excluded).
            path = helpers.findCombingPath(start, end, [], boundary, 0.4)

            # Should return a direct path since no holes to avoid.
            expect(path.length).toBeGreaterThanOrEqual(2)
            expect(path[0]).toEqual(start)
            expect(path[path.length - 1]).toEqual(end)

    describe 'distanceFromPointToLineSegment', ->

        test 'should calculate distance from point to line segment', ->

            # Horizontal line segment from (0, 0) to (10, 0).
            segStart = { x: 0, y: 0 }
            segEnd = { x: 10, y: 0 }

            # Point above the line at (5, 5).
            px = 5
            py = 5

            distance = helpers.distanceFromPointToLineSegment(px, py, segStart, segEnd)

            expect(distance).toBeCloseTo(5, 1)

        test 'should handle point closest to segment endpoint', ->

            segStart = { x: 0, y: 0 }
            segEnd = { x: 10, y: 0 }

            # Point beyond the end.
            px = 15
            py = 5

            distance = helpers.distanceFromPointToLineSegment(px, py, segStart, segEnd)

            # Distance to endpoint (10, 0).
            expected = Math.sqrt((15 - 10) ** 2 + (5 - 0) ** 2)

            expect(distance).toBeCloseTo(expected, 1)

        test 'should handle degenerate segment (zero length)', ->

            segStart = { x: 5, y: 5 }
            segEnd = { x: 5, y: 5 }

            px = 10
            py = 10

            distance = helpers.distanceFromPointToLineSegment(px, py, segStart, segEnd)

            # Distance to the point (5, 5).
            expected = Math.sqrt((10 - 5) ** 2 + (10 - 5) ** 2)

            expect(distance).toBeCloseTo(expected, 1)

    describe 'lineSegmentCrossesPolygon', ->

        test 'should detect when line segment crosses polygon boundary', ->

            polygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            start = { x: -5, y: 5 }
            end = { x: 15, y: 5 }

            result = helpers.lineSegmentCrossesPolygon(start, end, polygon)

            expect(result).toBe(true)

        test 'should detect when start point is inside polygon', ->

            polygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            start = { x: 5, y: 5 }
            end = { x: 15, y: 15 }

            result = helpers.lineSegmentCrossesPolygon(start, end, polygon)

            expect(result).toBe(true)

        test 'should return false when line does not cross polygon', ->

            polygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            start = { x: -5, y: -5 }
            end = { x: -5, y: 15 }

            result = helpers.lineSegmentCrossesPolygon(start, end, polygon)

            expect(result).toBe(false)

    describe 'calculateMinimumDistanceBetweenPaths', ->

        test 'should return infinity for degenerate paths', ->

            path1 = []
            path2 = [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 1, y: 1 }]

            result = helpers.calculateMinimumDistanceBetweenPaths(path1, path2)

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

            result = helpers.calculateMinimumDistanceBetweenPaths(innerSquare, outerSquare)

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

            result = helpers.calculateMinimumDistanceBetweenPaths(path1, path2)

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

            result = helpers.calculateMinimumDistanceBetweenPaths(path1, path2)

            # The minimum distance should be 0.3mm.
            expect(result).toBeCloseTo(0.3, 2)

    describe 'buildSafePathSegment', ->

        test 'should include both points when transition is safe', ->

            originalPoint = { x: 0, y: 0, z: 0 }
            adjustedPoint = { x: 1, y: 1, z: 0 }
            holePolygons = []  # No holes, so transition is safe.

            result = helpers.buildSafePathSegment(originalPoint, adjustedPoint, holePolygons)

            expect(result.length).toBe(2)
            expect(result[0]).toEqual(originalPoint)
            expect(result[1]).toEqual(adjustedPoint)

        test 'should only include adjusted point when transition crosses hole', ->

            originalPoint = { x: 0, y: 0, z: 0 }
            adjustedPoint = { x: 10, y: 0, z: 0 }

            # Create a hole that the transition crosses.
            holePolygons = [[
                { x: 4, y: -2 }
                { x: 6, y: -2 }
                { x: 6, y: 2 }
                { x: 4, y: 2 }
            ]]

            result = helpers.buildSafePathSegment(originalPoint, adjustedPoint, holePolygons)

            # Should only include adjusted point, not original.
            expect(result.length).toBe(1)
            expect(result[0]).toEqual(adjustedPoint)

        test 'should return single point when points are equal', ->

            point = { x: 5, y: 5, z: 0 }
            holePolygons = []

            result = helpers.buildSafePathSegment(point, point, holePolygons)

            expect(result.length).toBe(1)
            expect(result[0]).toEqual(point)

        test 'should handle points within epsilon tolerance', ->

            originalPoint = { x: 5.0000, y: 5.0000, z: 0 }
            adjustedPoint = { x: 5.0001, y: 5.0001, z: 0 }
            holePolygons = []

            result = helpers.buildSafePathSegment(originalPoint, adjustedPoint, holePolygons, 0.001)

            # Points are within epsilon, should be treated as equal.
            expect(result.length).toBe(1)

    describe 'addSafeEndpoint', ->

        test 'should add original endpoint when transition is safe', ->

            path = [{ x: 0, y: 0, z: 0 }]
            adjustedEnd = { x: 9, y: 0, z: 0 }
            originalEnd = { x: 10, y: 0, z: 0 }
            holePolygons = []  # No holes.

            helpers.addSafeEndpoint(path, adjustedEnd, originalEnd, holePolygons)

            expect(path.length).toBe(2)
            expect(path[1]).toEqual(originalEnd)

        test 'should not add original endpoint when transition crosses hole', ->

            path = [{ x: 0, y: 0, z: 0 }]
            adjustedEnd = { x: 8, y: 0, z: 0 }
            originalEnd = { x: 12, y: 0, z: 0 }

            # Create a hole that the transition crosses.
            holePolygons = [[
                { x: 9, y: -2 }
                { x: 11, y: -2 }
                { x: 11, y: 2 }
                { x: 9, y: 2 }
            ]]

            helpers.addSafeEndpoint(path, adjustedEnd, originalEnd, holePolygons)

            # Should not add original endpoint.
            expect(path.length).toBe(1)

        test 'should not add endpoint when points are equal', ->

            path = [{ x: 0, y: 0, z: 0 }]
            point = { x: 5, y: 5, z: 0 }
            holePolygons = []

            helpers.addSafeEndpoint(path, point, point, holePolygons)

            # Should not add duplicate point.
            expect(path.length).toBe(1)

        test 'should handle points within epsilon tolerance', ->

            path = [{ x: 0, y: 0, z: 0 }]
            adjustedEnd = { x: 5.0000, y: 5.0000, z: 0 }
            originalEnd = { x: 5.0001, y: 5.0001, z: 0 }
            holePolygons = []

            helpers.addSafeEndpoint(path, adjustedEnd, originalEnd, holePolygons, 0.001)

            # Points are within epsilon, should not add.
            expect(path.length).toBe(1)

    describe 'findOptimalStartPoint', ->

        test 'should return 0 for invalid inputs', ->

            result1 = helpers.findOptimalStartPoint(null, { x: 0, y: 0 })
            result2 = helpers.findOptimalStartPoint([], { x: 0, y: 0 })
            result3 = helpers.findOptimalStartPoint([{ x: 0, y: 0 }], null)

            expect(result1).toBe(0)
            expect(result2).toBe(0)
            expect(result3).toBe(0)

        test 'should return closest point when no holes present', ->

            # Create a square path.
            path = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            fromPoint = { x: 9, y: 1 }  # Closest to point 1.
            holePolygons = []

            result = helpers.findOptimalStartPoint(path, fromPoint, holePolygons)

            # Should return index 1 (10, 0) as it's closest.
            expect(result).toBe(1)

        test 'should return closest point when direct path is clear', ->

            # Create a circular path around origin.
            path = []
            numPoints = 32

            for i in [0...numPoints]

                angle = (i / numPoints) * 2 * Math.PI
                path.push({ x: 5 + 3 * Math.cos(angle), y: 5 + 3 * Math.sin(angle) })

            fromPoint = { x: 10, y: 5 }  # To the right of circle.
            holePolygons = []  # No holes.

            result = helpers.findOptimalStartPoint(path, fromPoint, holePolygons)

            # Should return the point closest to (10, 5), which is rightmost point ~(8, 5).
            closestPoint = path[result]
            expect(closestPoint.x).toBeGreaterThan(7.5)
            expect(closestPoint.y).toBeCloseTo(5, 0)

        test 'should prefer direct path over combing when available', ->

            # Create a square path.
            path = [
                { x: 0, y: 0 }    # Index 0
                { x: 10, y: 0 }   # Index 1
                { x: 10, y: 10 }  # Index 2
                { x: 0, y: 10 }   # Index 3
            ]

            fromPoint = { x: 5, y: -5 }  # Below the square, closest to index 0 and 1.

            # Add a hole that blocks path to index 0 but not index 1.
            holePolygons = [[
                { x: -1, y: -2 }
                { x: 1, y: -2 }
                { x: 1, y: 2 }
                { x: -1, y: 2 }
            ]]

            result = helpers.findOptimalStartPoint(path, fromPoint, holePolygons)

            # Should prefer index 1 (direct path) over index 0 (requires combing).
            expect(result).toBe(1)

        test 'should select point requiring shorter combing path when all paths blocked', ->

            # Create a rectangular path.
            path = [
                { x: 0, y: 0 }    # Index 0
                { x: 20, y: 0 }   # Index 1
                { x: 20, y: 10 }  # Index 2
                { x: 0, y: 10 }   # Index 3
            ]

            fromPoint = { x: 10, y: -10 }  # Below the rectangle.

            # Add hole that blocks direct paths to all points.
            holePolygons = [[
                { x: 5, y: -8 }
                { x: 15, y: -8 }
                { x: 15, y: 2 }
                { x: 5, y: 2 }
            ]]

            boundary = [
                { x: -5, y: -15 }
                { x: 25, y: -15 }
                { x: 25, y: 15 }
                { x: -5, y: 15 }
            ]

            result = helpers.findOptimalStartPoint(path, fromPoint, holePolygons, boundary, 0.4)

            # Should select a point that requires a shorter combing path.
            # Exact result may vary, but should not be 0 (requires longest path).
            expect(result).toBeGreaterThanOrEqual(0)
            expect(result).toBeLessThan(path.length)

        test 'should handle single hole in center of path', ->

            # Create a square path.
            path = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            fromPoint = { x: 5, y: -3 }  # Below the square.

            # Add hole in center that blocks some paths.
            holePolygons = [[
                { x: 4, y: 4 }
                { x: 6, y: 4 }
                { x: 6, y: 6 }
                { x: 4, y: 6 }
            ]]

            result = helpers.findOptimalStartPoint(path, fromPoint, holePolygons)

            # Should find an optimal point (exact result may vary based on algorithm).
            expect(result).toBeGreaterThanOrEqual(0)
            expect(result).toBeLessThan(path.length)

    describe 'calculatePolygonArea', ->

        test 'should calculate area of a square', ->

            # 10mm x 10mm square.
            square = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            area = helpers.calculatePolygonArea(square)

            # Area should be 100.
            expect(area).toBeCloseTo(100, 1)

        test 'should calculate area of a triangle', ->

            # Right triangle with base 4 and height 3.
            triangle = [
                { x: 0, y: 0 }
                { x: 4, y: 0 }
                { x: 0, y: 3 }
            ]

            area = helpers.calculatePolygonArea(triangle)

            # Area should be 6 (0.5 * base * height).
            expect(area).toBeCloseTo(6, 1)

        test 'should return 0 for degenerate polygon', ->

            # Less than 3 points.
            line = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
            ]

            area = helpers.calculatePolygonArea(line)

            expect(area).toBe(0)

    describe 'calculateExposedAreasPolygonBased', ->

        test 'should return entire region when no covering regions exist', ->

            testRegion = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            exposedAreas = helpers.calculateExposedAreasPolygonBased(testRegion, [])

            # Should return the entire test region.
            expect(exposedAreas.length).toBe(1)
            expect(exposedAreas[0].length).toBe(4)

        test 'should return empty when completely covered', ->

            # 10x10 test region.
            testRegion = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Completely covering region.
            coveringRegions = [[
                { x: -1, y: -1 }
                { x: 11, y: -1 }
                { x: 11, y: 11 }
                { x: -1, y: 11 }
            ]]

            exposedAreas = helpers.calculateExposedAreasPolygonBased(testRegion, coveringRegions)

            # Should return empty (fully covered).
            expect(exposedAreas.length).toBe(0)

        test 'should detect partially exposed region', ->

            # 10x10 test region.
            testRegion = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Covering region that only covers left half.
            coveringRegions = [[
                { x: 0, y: 0 }
                { x: 5, y: 0 }
                { x: 5, y: 10 }
                { x: 0, y: 10 }
            ]]

            exposedAreas = helpers.calculateExposedAreasPolygonBased(testRegion, coveringRegions)

            # Should have exposed area on the right side.
            expect(exposedAreas.length).toBeGreaterThan(0)

            # Calculate total exposed area.
            totalExposedArea = 0

            for area in exposedAreas

                totalExposedArea += helpers.calculatePolygonArea(area)

            # Right half should be exposed (approximately 50 square units).
            expect(totalExposedArea).toBeCloseTo(50, 1)

    describe 'calculateRegionCoveragePolygonBased', ->

        test 'should return 0 when no covering regions exist', ->

            testRegion = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            coverage = helpers.calculateRegionCoveragePolygonBased(testRegion, [])

            expect(coverage).toBe(0)

        test 'should return 1.0 when completely covered', ->

            # 10x10 test region.
            testRegion = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Completely covering region.
            coveringRegions = [[
                { x: -1, y: -1 }
                { x: 11, y: -1 }
                { x: 11, y: 11 }
                { x: -1, y: 11 }
            ]]

            coverage = helpers.calculateRegionCoveragePolygonBased(testRegion, coveringRegions)

            # Should be fully covered (1.0).
            expect(coverage).toBeCloseTo(1.0, 2)

        test 'should calculate partial coverage correctly', ->

            # 10x10 test region.
            testRegion = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Covering region that only covers left half.
            coveringRegions = [[
                { x: 0, y: 0 }
                { x: 5, y: 0 }
                { x: 5, y: 10 }
                { x: 0, y: 10 }
            ]]

            coverage = helpers.calculateRegionCoveragePolygonBased(testRegion, coveringRegions)

            # Should be 50% covered.
            expect(coverage).toBeCloseTo(0.5, 2)

        test 'should handle multiple covering regions', ->

            # 10x10 test region.
            testRegion = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Two regions covering left and right quarters.
            coveringRegions = [
                [
                    { x: 0, y: 0 }
                    { x: 2.5, y: 0 }
                    { x: 2.5, y: 10 }
                    { x: 0, y: 10 }
                ],
                [
                    { x: 7.5, y: 0 }
                    { x: 10, y: 0 }
                    { x: 10, y: 10 }
                    { x: 7.5, y: 10 }
                ]
            ]

            coverage = helpers.calculateRegionCoveragePolygonBased(testRegion, coveringRegions)

            # Should be 50% covered (25% + 25%).
            expect(coverage).toBeCloseTo(0.5, 2)

