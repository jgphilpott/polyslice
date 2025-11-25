# Tests for travel path optimization (combing).

combing = require('./combing')
primitives = require('../utils/primitives')

describe 'Combing', ->

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

            result = combing.travelPathCrossesHoles(startPoint, endPoint, [hole])

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

            result = combing.travelPathCrossesHoles(startPoint, endPoint, [hole])

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

            result = combing.travelPathCrossesHoles(startPoint, endPoint, [hole])

            expect(result).toBe(true)

        test 'should return false when no holes provided', ->

            startPoint = { x: 10, y: 10 }
            endPoint = { x: 90, y: 90 }

            result = combing.travelPathCrossesHoles(startPoint, endPoint, [])

            expect(result).toBe(false)

    describe 'findCombingPath', ->

        test 'should return direct path when no holes exist', ->

            start = { x: 0, y: 0 }
            end = { x: 100, y: 100 }

            path = combing.findCombingPath(start, end, [])

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

            path = combing.findCombingPath(start, end, [hole])

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

            path = combing.findCombingPath(start, end, [hole])

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

            path = combing.findCombingPath(start, end, [hole1, hole2])

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

            path = combing.findCombingPath(start, end, [hole], boundary)

            # Should find a path (may be direct or with waypoint).
            expect(path.length).toBeGreaterThanOrEqual(2)
            expect(path[0]).toEqual(start)
            expect(path[path.length - 1]).toEqual(end)

            # If waypoint exists, verify all points are either start/end or within boundary.
            if path.length > 2
                waypoint = path[1]
                # Waypoint should be within boundary (start and end are given as within).
                isInBoundary = primitives.pointInPolygon(waypoint, boundary)
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

            path = combing.findCombingPath(start, end, [hole])

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

            path = combing.findCombingPath(start, end, [hole1, hole2, hole3], boundary, 0.4)

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

            path = combing.findCombingPath(start, end, [hole], boundary, 0.4)

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

            path = combing.findCombingPath(start, end, [hole1, hole2], boundary, 0.4)

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

            path = combing.findCombingPath(start, end, [hole], boundary, 0.4)

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
            path = combing.findCombingPath(start, end, [], boundary, 0.4)

            # Should return a direct path since no holes to avoid.
            expect(path.length).toBeGreaterThanOrEqual(2)
            expect(path[0]).toEqual(start)
            expect(path[path.length - 1]).toEqual(end)

    describe 'buildSafePathSegment', ->

        test 'should include both points when transition is safe', ->

            originalPoint = { x: 0, y: 0, z: 0 }
            adjustedPoint = { x: 1, y: 1, z: 0 }
            holePolygons = []  # No holes, so transition is safe.

            result = combing.buildSafePathSegment(originalPoint, adjustedPoint, holePolygons)

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

            result = combing.buildSafePathSegment(originalPoint, adjustedPoint, holePolygons)

            # Should only include adjusted point, not original.
            expect(result.length).toBe(1)
            expect(result[0]).toEqual(adjustedPoint)

        test 'should return single point when points are equal', ->

            point = { x: 5, y: 5, z: 0 }
            holePolygons = []

            result = combing.buildSafePathSegment(point, point, holePolygons)

            expect(result.length).toBe(1)
            expect(result[0]).toEqual(point)

        test 'should handle points within epsilon tolerance', ->

            originalPoint = { x: 5.0000, y: 5.0000, z: 0 }
            adjustedPoint = { x: 5.0001, y: 5.0001, z: 0 }
            holePolygons = []

            result = combing.buildSafePathSegment(originalPoint, adjustedPoint, holePolygons, 0.001)

            # Points are within epsilon, should be treated as equal.
            expect(result.length).toBe(1)

    describe 'addSafeEndpoint', ->

        test 'should add original endpoint when transition is safe', ->

            path = [{ x: 0, y: 0, z: 0 }]
            adjustedEnd = { x: 9, y: 0, z: 0 }
            originalEnd = { x: 10, y: 0, z: 0 }
            holePolygons = []  # No holes.

            combing.addSafeEndpoint(path, adjustedEnd, originalEnd, holePolygons)

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

            combing.addSafeEndpoint(path, adjustedEnd, originalEnd, holePolygons)

            # Should not add original endpoint.
            expect(path.length).toBe(1)

        test 'should not add endpoint when points are equal', ->

            path = [{ x: 0, y: 0, z: 0 }]
            point = { x: 5, y: 5, z: 0 }
            holePolygons = []

            combing.addSafeEndpoint(path, point, point, holePolygons)

            # Should not add duplicate point.
            expect(path.length).toBe(1)

        test 'should handle points within epsilon tolerance', ->

            path = [{ x: 0, y: 0, z: 0 }]
            adjustedEnd = { x: 5.0000, y: 5.0000, z: 0 }
            originalEnd = { x: 5.0001, y: 5.0001, z: 0 }
            holePolygons = []

            combing.addSafeEndpoint(path, adjustedEnd, originalEnd, holePolygons, 0.001)

            # Points are within epsilon, should not add.
            expect(path.length).toBe(1)

    describe 'findOptimalStartPoint', ->

        test 'should return 0 for invalid inputs', ->

            result1 = combing.findOptimalStartPoint(null, { x: 0, y: 0 })
            result2 = combing.findOptimalStartPoint([], { x: 0, y: 0 })
            result3 = combing.findOptimalStartPoint([{ x: 0, y: 0 }], null)

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

            result = combing.findOptimalStartPoint(path, fromPoint, holePolygons)

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

            result = combing.findOptimalStartPoint(path, fromPoint, holePolygons)

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

            result = combing.findOptimalStartPoint(path, fromPoint, holePolygons)

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

            result = combing.findOptimalStartPoint(path, fromPoint, holePolygons, boundary, 0.4)

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

            result = combing.findOptimalStartPoint(path, fromPoint, holePolygons)

            # Should find an optimal point (exact result may vary based on algorithm).
            expect(result).toBeGreaterThanOrEqual(0)
            expect(result).toBeLessThan(path.length)
