# Tests for infill-skin phase module

infillSkinPhase = require('./infill-skin-phase')

describe 'Infill-Skin Phase', ->

    # Mock slicer object
    createMockSlicer = ->
        return {
            getNozzleDiameter: -> 0.4
            getInfillDensity: -> 20
            getExposureDetection: -> false
            gcode: ''
            cumulativeE: 0
            calculateExtrusion: (distance, nozzleDiameter) -> distance * 0.1
        }

    describe 'processStructureInfillAndSkin', ->

        test 'should be defined and callable', ->

            expect(infillSkinPhase.processStructureInfillAndSkin).toBeDefined()
            expect(typeof infillSkinPhase.processStructureInfillAndSkin).toBe('function')

        test 'should return early for hole paths', ->

            slicer = createMockSlicer()
            path = [{ x: 0, y: 0 }, { x: 10, y: 0 }, { x: 10, y: 10 }, { x: 0, y: 10 }]
            pathIndex = 0
            currentPath = path
            pathIsHole = [true] # Mark as hole
            lastPathEndPoint = { x: 5, y: 5, z: 0 }

            # Function should return early for holes
            result = infillSkinPhase.processStructureInfillAndSkin(
                slicer, path, pathIndex, currentPath, {}, pathIsHole, [1],
                0, 0, 0, 0, 1, 10, [], [], [], [], [], [],
                [], [], {}, lastPathEndPoint, (->)
            )

            # Should return the lastPathEndPoint unchanged
            expect(result).toEqual(lastPathEndPoint)

        test 'should return early for invalid current path', ->

            slicer = createMockSlicer()
            path = [{ x: 0, y: 0 }, { x: 10, y: 0 }]
            pathIndex = 0
            currentPath = null
            pathIsHole = [false]
            lastPathEndPoint = { x: 5, y: 5, z: 0 }

            result = infillSkinPhase.processStructureInfillAndSkin(
                slicer, path, pathIndex, currentPath, {}, pathIsHole, [0],
                0, 0, 0, 0, 1, 10, [], [], [], [], [], [],
                [], [], {}, lastPathEndPoint, (->)
            )

            # Should return the lastPathEndPoint unchanged
            expect(result).toEqual(lastPathEndPoint)

        test 'should return early for paths with less than 3 points', ->

            slicer = createMockSlicer()
            path = [{ x: 0, y: 0 }, { x: 10, y: 0 }]
            pathIndex = 0
            currentPath = [{ x: 0, y: 0 }, { x: 10, y: 0 }]
            pathIsHole = [false]
            lastPathEndPoint = { x: 5, y: 5, z: 0 }

            result = infillSkinPhase.processStructureInfillAndSkin(
                slicer, path, pathIndex, currentPath, {}, pathIsHole, [0],
                0, 0, 0, 0, 1, 10, [], [], [], [], [], [],
                [], [], {}, lastPathEndPoint, (->)
            )

            # Should return the lastPathEndPoint unchanged (path < 3 points)
            expect(result).toEqual(lastPathEndPoint)


