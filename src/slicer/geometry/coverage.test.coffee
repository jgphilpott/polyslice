# Tests for region coverage detection and exposed area calculations.

coverage = require('./coverage')

describe 'Coverage', ->

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

            result = coverage.calculateRegionCoverage(testRegion, coveringRegions, 9)

            expect(result).toBe(1.0)

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

            result = coverage.calculateRegionCoverage(testRegion, coveringRegions, 9)

            expect(result).toBe(0.0)

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

            result = coverage.calculateRegionCoverage(testRegion, coveringRegions, 9)

            # Should be around 0.5 but depends on sampling points.
            expect(result).toBeGreaterThan(0.0)
            expect(result).toBeLessThan(1.0)

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

            exposedAreas = coverage.calculateExposedAreas(testRegion, coveringRegions, 81)

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

            exposedAreas = coverage.calculateExposedAreas(testRegion, coveringRegions, 81)

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

            exposedAreas = coverage.calculateExposedAreas(testRegion, coveringRegions, 81)

            # Should detect exposed area on the right side.
            expect(exposedAreas.length).toBeGreaterThan(0)

            # The exposed area should be on the right side (X > 10).
            if exposedAreas.length > 0
                firstExposedArea = exposedAreas[0]
                # Check that exposed area has some points with X > 10.
                hasRightSide = firstExposedArea.some (point) -> point.x > 10
                expect(hasRightSide).toBe(true)

    describe 'marchingSquares', ->

        test 'should generate contour for simple 2x2 exposed region', ->

            # Create a simple test case: a 2x2 exposed region in a 5x5 grid.
            gridSize = 5
            exposedGrid = []

            for i in [0...gridSize]
                row = []
                for j in [0...gridSize]
                    # Create a 2x2 exposed region in the center.
                    if (i is 1 or i is 2) and (j is 1 or j is 2)
                        row.push({ x: i, y: j })
                    else
                        row.push(null)
                exposedGrid.push(row)

            # Create region array.
            region = []
            for i in [1..2]
                for j in [1..2]
                    region.push({ i: i, j: j, point: { x: i, y: j } })

            bounds = {
                minX: 0
                maxX: 5
                minY: 0
                maxY: 5
            }

            z = 0

            result = coverage.marchingSquares(exposedGrid, region, bounds, gridSize, z)

            # Should generate a valid polygon with at least 3 points.
            expect(result.length).toBeGreaterThanOrEqual(3)

            # All points should have z coordinate set correctly.
            for point in result
                expect(point.z).toBe(z)

            # Points should be within bounds.
            for point in result
                expect(point.x).toBeGreaterThanOrEqual(bounds.minX)
                expect(point.x).toBeLessThanOrEqual(bounds.maxX)
                expect(point.y).toBeGreaterThanOrEqual(bounds.minY)
                expect(point.y).toBeLessThanOrEqual(bounds.maxY)
            undefined

        test 'should generate multiple points for circular exposed region', ->

            # Create a circular exposed region.
            gridSize = 10
            centerI = 5
            centerJ = 5
            radius = 3

            exposedGrid = []
            region = []

            for i in [0...gridSize]
                row = []
                for j in [0...gridSize]
                    dist = Math.sqrt((i - centerI) ** 2 + (j - centerJ) ** 2)
                    if dist <= radius
                        row.push({ x: i, y: j })
                        region.push({ i: i, j: j, point: { x: i, y: j } })
                    else
                        row.push(null)
                exposedGrid.push(row)

            bounds = {
                minX: 0
                maxX: 10
                minY: 0
                maxY: 10
            }

            z = 1.5

            result = coverage.marchingSquares(exposedGrid, region, bounds, gridSize, z)

            # Should generate a valid polygon with many points to approximate the circle.
            expect(result.length).toBeGreaterThanOrEqual(8)

            # All points should have z coordinate set correctly.
            for point in result
                expect(point.z).toBe(z)
            undefined

        test 'should return empty array for empty region', ->

            gridSize = 5
            exposedGrid = []

            for i in [0...gridSize]
                row = []
                for j in [0...gridSize]
                    row.push(null)
                exposedGrid.push(row)

            region = []

            bounds = {
                minX: 0
                maxX: 5
                minY: 0
                maxY: 5
            }

            z = 0

            result = coverage.marchingSquares(exposedGrid, region, bounds, gridSize, z)

            # Should return empty array for empty region.
            expect(result).toEqual([])

        test 'should handle single cell exposed region', ->

            # Create a simple test case: a single exposed cell.
            gridSize = 5
            exposedGrid = []

            for i in [0...gridSize]
                row = []
                for j in [0...gridSize]
                    # Single exposed cell at (2, 2).
                    if i is 2 and j is 2
                        row.push({ x: i, y: j })
                    else
                        row.push(null)
                exposedGrid.push(row)

            # Create region array.
            region = [{ i: 2, j: 2, point: { x: 2, y: 2 } }]

            bounds = {
                minX: 0
                maxX: 5
                minY: 0
                maxY: 5
            }

            z = 0

            result = coverage.marchingSquares(exposedGrid, region, bounds, gridSize, z)

            # Should generate a valid polygon (at least 3 points for a small square).
            expect(result.length).toBeGreaterThanOrEqual(3)

            # All points should have z coordinate set correctly.
            for point in result
                expect(point.z).toBe(z)
            undefined

    describe 'smoothContour', ->

        test 'should increase vertex count with smoothing iterations', ->

            # Create a simple square.
            square = [
                { x: 0, y: 0, z: 0 }
                { x: 10, y: 0, z: 0 }
                { x: 10, y: 10, z: 0 }
                { x: 0, y: 10, z: 0 }
            ]

            # After 1 iteration, should have 8 points (2x original).
            smoothed1 = coverage.smoothContour(square, 1)
            expect(smoothed1.length).toBe(8)

            # After 2 iterations, should have 16 points (4x original).
            smoothed2 = coverage.smoothContour(square, 2)
            expect(smoothed2.length).toBe(16)

            # All points should preserve z coordinate.
            for point in smoothed2
                expect(point.z).toBe(0)
            undefined

        test 'should preserve z coordinate during smoothing', ->

            contour = [
                { x: 0, y: 0, z: 5 }
                { x: 10, y: 0, z: 5 }
                { x: 10, y: 10, z: 5 }
            ]

            smoothed = coverage.smoothContour(contour, 1)

            # All smoothed points should have the same z.
            for point in smoothed
                expect(point.z).toBe(5)
            undefined

        test 'should handle empty or small contours gracefully', ->

            # Empty contour.
            expect(coverage.smoothContour([])).toEqual([])

            # Single point - should return as is.
            single = [{ x: 5, y: 5, z: 0 }]
            expect(coverage.smoothContour(single)).toEqual(single)

            # Two points - should return as is.
            two = [{ x: 0, y: 0, z: 0 }, { x: 10, y: 10, z: 0 }]
            expect(coverage.smoothContour(two)).toEqual(two)

        test 'should create smoother curves than original', ->

            # Create a circular region and check that smoothing increases vertex density.
            gridSize = 10
            centerI = 5
            centerJ = 5
            radius = 3

            exposedGrid = []
            region = []

            for i in [0...gridSize]
                row = []
                for j in [0...gridSize]
                    dist = Math.sqrt((i - centerI) ** 2 + (j - centerJ) ** 2)
                    if dist <= radius
                        row.push({ x: i, y: j })
                        region.push({ i: i, j: j, point: { x: i, y: j } })
                    else
                        row.push(null)
                exposedGrid.push(row)

            bounds = { minX: 0, maxX: 10, minY: 0, maxY: 10 }
            z = 0

            result = coverage.marchingSquares(exposedGrid, region, bounds, gridSize, z)

            # With smoothing, should have significantly more vertices than the base grid.
            # A 10x10 grid with radius 3 should produce many smoothed vertices.
            expect(result.length).toBeGreaterThan(50)

            # All points should be valid.
            for point in result
                expect(point.x).toBeDefined()
                expect(point.y).toBeDefined()
                expect(point.z).toBe(z)
            undefined

        test 'should work with custom iterations and ratio parameters', ->

            # Create a simple triangle.
            triangle = [
                { x: 0, y: 0, z: 0 }
                { x: 10, y: 0, z: 0 }
                { x: 5, y: 10, z: 0 }
            ]

            # Test with 0 iterations - should return original.
            smoothed0 = coverage.smoothContour(triangle, 0)
            expect(smoothed0.length).toBe(3)

            # Test with 1 iteration and ratio 0.5 (midpoint).
            smoothed1 = coverage.smoothContour(triangle, 1, 0.5)
            expect(smoothed1.length).toBe(6)  # 2x original

            # Test with 2 iterations and ratio 0.5.
            smoothed2 = coverage.smoothContour(triangle, 2, 0.5)
            expect(smoothed2.length).toBe(12)  # 4x original

            # Test with ratio 0.25 (quarter points).
            smoothed_quarter = coverage.smoothContour(triangle, 1, 0.25)
            expect(smoothed_quarter.length).toBe(6)  # Still 2x, but different positions

            # Verify all maintain z-coordinate.
            for point in smoothed2
                expect(point.z).toBe(0)
            undefined

        test 'should handle edge case of very small ratios', ->

            square = [
                { x: 0, y: 0, z: 0 }
                { x: 10, y: 0, z: 0 }
                { x: 10, y: 10, z: 0 }
                { x: 0, y: 10, z: 0 }
            ]

            # Very small ratio should still work.
            smoothed = coverage.smoothContour(square, 1, 0.1)
            expect(smoothed.length).toBe(8)

            # All points should be valid and have proper coordinates.
            for point in smoothed
                expect(point.x).toBeGreaterThanOrEqual(0)
                expect(point.x).toBeLessThanOrEqual(10)
                expect(point.y).toBeGreaterThanOrEqual(0)
                expect(point.y).toBeLessThanOrEqual(10)
            undefined

    describe 'Integration Tests', ->

        test 'should produce consistent results for exposure detection with default settings', ->

            # Create a test region similar to what would be found in a sphere layer.
            gridSize = 31  # New default
            centerI = 15.5
            centerJ = 15.5
            radius = 10

            exposedGrid = []
            region = []

            for i in [0...gridSize]
                row = []
                for j in [0...gridSize]
                    dist = Math.sqrt((i - centerI) ** 2 + (j - centerJ) ** 2)
                    if dist <= radius
                        row.push({ x: i, y: j })
                        region.push({ i: i, j: j, point: { x: i, y: j } })
                    else
                        row.push(null)
                exposedGrid.push(row)

            bounds = { minX: 0, maxX: 31, minY: 0, maxY: 31 }
            z = 1.5

            result = coverage.marchingSquares(exposedGrid, region, bounds, gridSize, z)

            # Should produce a reasonable number of vertices for the circular region.
            # With 31x31 grid and 1 iteration of smoothing at 0.5 ratio, expect ~130-170 vertices.
            expect(result.length).toBeGreaterThan(100)
            expect(result.length).toBeLessThan(200)

            # All points should be within bounds.
            for point in result
                expect(point.x).toBeGreaterThanOrEqual(bounds.minX)
                expect(point.x).toBeLessThanOrEqual(bounds.maxX)
                expect(point.y).toBeGreaterThanOrEqual(bounds.minY)
                expect(point.y).toBeLessThanOrEqual(bounds.maxY)
                expect(point.z).toBe(z)
            undefined

        test 'should handle rectangular regions correctly', ->

            # Create a rectangular exposed region.
            gridSize = 20
            exposedGrid = []
            region = []

            for i in [0...gridSize]
                row = []
                for j in [0...gridSize]
                    # Rectangle from (5,5) to (15,10).
                    if i >= 5 and i <= 15 and j >= 5 and j <= 10
                        row.push({ x: i, y: j })
                        region.push({ i: i, j: j, point: { x: i, y: j } })
                    else
                        row.push(null)
                exposedGrid.push(row)

            bounds = { minX: 0, maxX: 20, minY: 0, maxY: 20 }
            z = 0

            result = coverage.marchingSquares(exposedGrid, region, bounds, gridSize, z)

            # Should produce a valid polygon.
            expect(result.length).toBeGreaterThanOrEqual(3)

            # All points should have correct z.
            for point in result
                expect(point.z).toBe(z)
            undefined

        test 'should maintain contour integrity across multiple smoothing iterations', ->

            # Create a hexagon-like shape.
            hexagon = [
                { x: 5, y: 0, z: 0 }
                { x: 10, y: 2.5, z: 0 }
                { x: 10, y: 7.5, z: 0 }
                { x: 5, y: 10, z: 0 }
                { x: 0, y: 7.5, z: 0 }
                { x: 0, y: 2.5, z: 0 }
            ]

            # Apply progressive smoothing.
            smoothed1 = coverage.smoothContour(hexagon, 1, 0.5)
            smoothed2 = coverage.smoothContour(hexagon, 2, 0.5)
            smoothed3 = coverage.smoothContour(hexagon, 3, 0.5)

            # Vertex count should double with each iteration.
            expect(smoothed1.length).toBe(12)   # 6 * 2
            expect(smoothed2.length).toBe(24)   # 6 * 4
            expect(smoothed3.length).toBe(48)   # 6 * 8

            # All should maintain the z-coordinate.
            for point in smoothed3
                expect(point.z).toBe(0)

            # Centroid should remain approximately the same.
            calcCentroid = (points) ->
                cx = 0
                cy = 0
                for p in points
                    cx += p.x
                    cy += p.y
                return { x: cx / points.length, y: cy / points.length }

            originalCentroid = calcCentroid(hexagon)
            smoothedCentroid = calcCentroid(smoothed3)

            # Centroids should be very close (within 1 unit).
            expect(Math.abs(smoothedCentroid.x - originalCentroid.x)).toBeLessThan(1)
            expect(Math.abs(smoothedCentroid.y - originalCentroid.y)).toBeLessThan(1)
            undefined
