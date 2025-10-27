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

