# Tests for geometry helpers re-export facade.
# Main tests are in the individual module test files:
#   - utils/primitives.test.coffee
#   - utils/bounds.test.coffee
#   - utils/clipping.test.coffee
#   - utils/paths.test.coffee
#   - geometry/combing.test.coffee
#   - geometry/coverage.test.coffee

helpers = require('./helpers')

describe 'Geometry Helpers Facade', ->

    describe 'Re-exports from primitives', ->

        test 'should re-export pointsMatch', ->

            expect(helpers.pointsMatch).toBeDefined()

        test 'should re-export lineIntersection', ->

            expect(helpers.lineIntersection).toBeDefined()

        test 'should re-export pointInPolygon', ->

            expect(helpers.pointInPolygon).toBeDefined()

        test 'should re-export lineSegmentIntersection', ->

            expect(helpers.lineSegmentIntersection).toBeDefined()

        test 'should re-export deduplicateIntersections', ->

            expect(helpers.deduplicateIntersections).toBeDefined()

    describe 'Re-exports from bounds', ->

        test 'should re-export calculatePathBounds', ->

            expect(helpers.calculatePathBounds).toBeDefined()

        test 'should re-export boundsOverlap', ->

            expect(helpers.boundsOverlap).toBeDefined()

    describe 'Re-exports from clipping', ->

        test 'should re-export clipLineToPolygon', ->

            expect(helpers.clipLineToPolygon).toBeDefined()

        test 'should re-export clipLineWithHoles', ->

            expect(helpers.clipLineWithHoles).toBeDefined()

        test 'should re-export subtractSkinAreasFromInfill', ->

            expect(helpers.subtractSkinAreasFromInfill).toBeDefined()

    describe 'Re-exports from paths', ->

        test 'should re-export connectSegmentsToPaths', ->

            expect(helpers.connectSegmentsToPaths).toBeDefined()

        test 'should re-export createInsetPath', ->

            expect(helpers.createInsetPath).toBeDefined()

        test 'should re-export calculateMinimumDistanceBetweenPaths', ->

            expect(helpers.calculateMinimumDistanceBetweenPaths).toBeDefined()

    describe 'Re-exports from combing', ->

        test 'should re-export travelPathCrossesHoles', ->

            expect(helpers.travelPathCrossesHoles).toBeDefined()

        test 'should re-export findCombingPath', ->

            expect(helpers.findCombingPath).toBeDefined()

        test 'should re-export findOptimalStartPoint', ->

            expect(helpers.findOptimalStartPoint).toBeDefined()

    describe 'Re-exports from coverage', ->

        test 'should re-export calculateRegionCoverage', ->

            expect(helpers.calculateRegionCoverage).toBeDefined()

        test 'should re-export calculateExposedAreas', ->

            expect(helpers.calculateExposedAreas).toBeDefined()

        test 'should re-export marchingSquares', ->

            expect(helpers.marchingSquares).toBeDefined()

        test 'should re-export smoothContour', ->

            expect(helpers.smoothContour).toBeDefined()

    describe 'Backward Compatibility', ->

        test 'pointsMatch should work correctly through facade', ->

            p1 = { x: 10, y: 20 }
            p2 = { x: 10, y: 20 }

            result = helpers.pointsMatch(p1, p2, 0.001)

            expect(result).toBe(true)

        test 'calculatePathBounds should work correctly through facade', ->

            path = [
                { x: 10, y: 20 }
                { x: 30, y: 40 }
            ]

            bounds = helpers.calculatePathBounds(path)

            expect(bounds.minX).toBe(10)
            expect(bounds.maxX).toBe(30)
            expect(bounds.minY).toBe(20)
            expect(bounds.maxY).toBe(40)

        test 'createInsetPath should work correctly through facade', ->

            path = [
                { x: 0, y: 0, z: 0 }
                { x: 10, y: 0, z: 0 }
                { x: 10, y: 10, z: 0 }
                { x: 0, y: 10, z: 0 }
            ]

            insetPath = helpers.createInsetPath(path, 1)

            expect(insetPath.length).toBe(4)

        test 'pointInPolygon should work correctly through facade', ->

            polygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            insidePoint = { x: 5, y: 5 }
            outsidePoint = { x: 15, y: 5 }

            expect(helpers.pointInPolygon(insidePoint, polygon)).toBe(true)
            expect(helpers.pointInPolygon(outsidePoint, polygon)).toBe(false)
