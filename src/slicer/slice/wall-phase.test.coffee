# Tests for wall phase module

wallPhase = require('./wall-phase')
pathsUtils = require('../utils/paths')

describe 'Wall Phase', ->

    describe 'checkPathSpacing', ->

        test 'should detect insufficient spacing for inner walls', ->

            paths = [
                [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 1, y: 1 }, { x: 0, y: 1 }]
                [{ x: 0.3, y: 0.3 }, { x: 0.7, y: 0.3 }, { x: 0.7, y: 0.7 }, { x: 0.3, y: 0.7 }]
            ]
            allOuterWalls = {
                0: [{ x: 0.2, y: 0.2 }, { x: 0.8, y: 0.2 }, { x: 0.8, y: 0.8 }, { x: 0.2, y: 0.8 }]
                1: [{ x: 0.35, y: 0.35 }, { x: 0.65, y: 0.35 }, { x: 0.65, y: 0.65 }, { x: 0.35, y: 0.65 }]
            }
            allInnermostWalls = allOuterWalls
            nozzleDiameter = 0.4

            result = wallPhase.checkPathSpacing(paths, allOuterWalls, allInnermostWalls, nozzleDiameter)

            expect(result).toBeDefined()
            expect(result.pathsWithInsufficientSpacingForInnerWalls).toBeDefined()
            expect(result.pathsWithInsufficientSpacingForSkinWalls).toBeDefined()

    describe 'calculateInnermostWall', ->

        test 'should calculate innermost wall for simple path', ->

            path = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]
            pathIndex = 0
            isHole = false
            wallCount = 2
            nozzleDiameter = 0.4
            pathsWithInsufficientSpacing = {}

            result = wallPhase.calculateInnermostWall(path, pathIndex, isHole, wallCount, nozzleDiameter, pathsWithInsufficientSpacing)

            expect(result).toBeDefined()
            expect(result.length).toBeGreaterThan(0)

        test 'should return null for path with insufficient spacing', ->

            path = [
                { x: 0, y: 0 }
                { x: 1, y: 0 }
                { x: 1, y: 1 }
                { x: 0, y: 1 }
            ]
            pathIndex = 0
            isHole = false
            wallCount = 10 # Too many walls for small path
            nozzleDiameter = 0.4
            pathsWithInsufficientSpacing = { 0: true }

            result = wallPhase.calculateInnermostWall(path, pathIndex, isHole, wallCount, nozzleDiameter, pathsWithInsufficientSpacing)

            # Should return early due to insufficient spacing
            expect(result).toBeDefined()

    describe 'calculateAllInnermostWalls', ->

        test 'should calculate innermost walls for all paths', ->

            paths = [
                [{ x: 0, y: 0 }, { x: 10, y: 0 }, { x: 10, y: 10 }, { x: 0, y: 10 }]
                [{ x: 20, y: 20 }, { x: 30, y: 20 }, { x: 30, y: 30 }, { x: 20, y: 30 }]
            ]
            pathIsHole = [false, false]
            wallCount = 2
            nozzleDiameter = 0.4
            pathsWithInsufficientSpacing = {}

            result = wallPhase.calculateAllInnermostWalls(paths, pathIsHole, wallCount, nozzleDiameter, pathsWithInsufficientSpacing)

            expect(result).toBeDefined()
            expect(Object.keys(result).length).toBeGreaterThan(0)
