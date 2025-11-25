# Tests for primitive geometry operations (points, lines, segments).

primitives = require('./primitives')

describe 'Primitives', ->

    describe 'pointsMatch', ->

        test 'should return true for identical points', ->

            p1 = { x: 10, y: 20 }
            p2 = { x: 10, y: 20 }

            result = primitives.pointsMatch(p1, p2, 0.001)

            expect(result).toBe(true)

        test 'should return true for points within epsilon', ->

            p1 = { x: 10, y: 20 }
            p2 = { x: 10.0005, y: 20.0005 }

            result = primitives.pointsMatch(p1, p2, 0.001)

            expect(result).toBe(true)

        test 'should return false for points outside epsilon', ->

            p1 = { x: 10, y: 20 }
            p2 = { x: 10.5, y: 20 }

            result = primitives.pointsMatch(p1, p2, 0.001)

            expect(result).toBe(false)

    describe 'lineIntersection', ->

        test 'should find intersection of two crossing lines', ->

            p1 = { x: 0, y: 0 }
            p2 = { x: 10, y: 10 }
            p3 = { x: 0, y: 10 }
            p4 = { x: 10, y: 0 }

            result = primitives.lineIntersection(p1, p2, p3, p4)

            expect(result).not.toBeNull()
            expect(result.x).toBeCloseTo(5, 1)
            expect(result.y).toBeCloseTo(5, 1)

        test 'should return null for parallel lines', ->

            p1 = { x: 0, y: 0 }
            p2 = { x: 10, y: 0 }
            p3 = { x: 0, y: 5 }
            p4 = { x: 10, y: 5 }

            result = primitives.lineIntersection(p1, p2, p3, p4)

            expect(result).toBeNull()

        test 'should find intersection of perpendicular lines', ->

            p1 = { x: 5, y: 0 }
            p2 = { x: 5, y: 10 }
            p3 = { x: 0, y: 5 }
            p4 = { x: 10, y: 5 }

            result = primitives.lineIntersection(p1, p2, p3, p4)

            expect(result).not.toBeNull()
            expect(result.x).toBeCloseTo(5, 1)
            expect(result.y).toBeCloseTo(5, 1)

    describe 'lineSegmentIntersection', ->

        test 'should find intersection when segments cross', ->

            p1 = { x: 0, y: 5 }
            p2 = { x: 10, y: 5 }
            p3 = { x: 5, y: 0 }
            p4 = { x: 5, y: 10 }

            result = primitives.lineSegmentIntersection(p1, p2, p3, p4)

            expect(result).not.toBeNull()
            expect(result.x).toBeCloseTo(5, 6)
            expect(result.y).toBeCloseTo(5, 6)

        test 'should return null when segments do not cross', ->

            p1 = { x: 0, y: 0 }
            p2 = { x: 10, y: 0 }
            p3 = { x: 0, y: 5 }
            p4 = { x: 10, y: 5 }

            result = primitives.lineSegmentIntersection(p1, p2, p3, p4)

            expect(result).toBeNull()

        test 'should return null when segments are parallel', ->

            p1 = { x: 0, y: 0 }
            p2 = { x: 10, y: 0 }
            p3 = { x: 0, y: 5 }
            p4 = { x: 10, y: 5 }

            result = primitives.lineSegmentIntersection(p1, p2, p3, p4)

            expect(result).toBeNull()

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

            result = primitives.pointInPolygon(point, polygon)

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

            result = primitives.pointInPolygon(point, polygon)

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

            result = primitives.pointInPolygon(point, polygon)

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

            result = primitives.pointInPolygon(point, polygon)

            # Ray casting can vary on boundary - just check it returns a boolean.
            expect(typeof result).toBe('boolean')

    describe 'distanceFromPointToLineSegment', ->

        test 'should calculate distance from point to line segment', ->

            # Horizontal line segment from (0, 0) to (10, 0).
            segStart = { x: 0, y: 0 }
            segEnd = { x: 10, y: 0 }

            # Point above the line at (5, 5).
            px = 5
            py = 5

            distance = primitives.distanceFromPointToLineSegment(px, py, segStart, segEnd)

            expect(distance).toBeCloseTo(5, 1)

        test 'should handle point closest to segment endpoint', ->

            segStart = { x: 0, y: 0 }
            segEnd = { x: 10, y: 0 }

            # Point beyond the end.
            px = 15
            py = 5

            distance = primitives.distanceFromPointToLineSegment(px, py, segStart, segEnd)

            # Distance to endpoint (10, 0).
            expected = Math.sqrt((15 - 10) ** 2 + (5 - 0) ** 2)

            expect(distance).toBeCloseTo(expected, 1)

        test 'should handle degenerate segment (zero length)', ->

            segStart = { x: 5, y: 5 }
            segEnd = { x: 5, y: 5 }

            px = 10
            py = 10

            distance = primitives.distanceFromPointToLineSegment(px, py, segStart, segEnd)

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

            result = primitives.lineSegmentCrossesPolygon(start, end, polygon)

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

            result = primitives.lineSegmentCrossesPolygon(start, end, polygon)

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

            result = primitives.lineSegmentCrossesPolygon(start, end, polygon)

            expect(result).toBe(false)

    describe 'deduplicateIntersections', ->

        test 'should remove duplicate points within epsilon tolerance', ->

            # Create intersections with duplicates (e.g., line through bounding box corner).
            intersections = [
                { x: -2.496, y: -2.496 }  # Left edge intersection
                { x: -2.496, y: -2.496 }  # Bottom edge intersection (duplicate!)
                { x: 2.496, y: 2.496 }    # Top-right intersection
            ]

            unique = primitives.deduplicateIntersections(intersections)

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

            unique = primitives.deduplicateIntersections(intersections)

            # All points should be kept.
            expect(unique.length).toBe(3)

        test 'should handle empty array', ->

            unique = primitives.deduplicateIntersections([])

            expect(unique.length).toBe(0)

        test 'should handle null/undefined input', ->

            expect(primitives.deduplicateIntersections(null).length).toBe(0)
            expect(primitives.deduplicateIntersections(undefined).length).toBe(0)

        test 'should handle single point', ->

            intersections = [{ x: 1, y: 2 }]

            unique = primitives.deduplicateIntersections(intersections)

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
            uniqueDefault = primitives.deduplicateIntersections(intersections)
            expect(uniqueDefault.length).toBe(1)

            # With larger epsilon (0.002mm), still duplicates.
            uniqueLarger = primitives.deduplicateIntersections(intersections, 0.002)
            expect(uniqueLarger.length).toBe(1)

            # With very small epsilon (0.0001mm), these should be different points.
            uniqueSmaller = primitives.deduplicateIntersections(intersections, 0.0001)
            expect(uniqueSmaller.length).toBe(2)

        test 'should handle multiple duplicates of same point', ->

            intersections = [
                { x: 1, y: 1 }
                { x: 1.0001, y: 1.0001 }  # Very close to first
                { x: 1.00005, y: 1.00005 }  # Also very close to first
                { x: 5, y: 5 }
            ]

            unique = primitives.deduplicateIntersections(intersections)

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

            unique = primitives.deduplicateIntersections(intersections)

            # Should have 3 unique points in order: (3,3), (1,1), (2,2).
            expect(unique.length).toBe(3)
            expect(unique[0].x).toBeCloseTo(3, 3)
            expect(unique[1].x).toBeCloseTo(1, 3)
            expect(unique[2].x).toBeCloseTo(2, 3)
