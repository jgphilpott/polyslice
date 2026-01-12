# Tests for build plate boundary checking helper.

describe 'Boundary Helper', ->

    Polyslice = null
    boundaryHelper = null

    beforeAll ->

        Polyslice = require('../../../polyslice')
        boundaryHelper = require('./boundary')

    describe 'checkBuildPlateBoundaries', ->

        test 'should detect when adhesion is within boundaries', ->

            slicer = new Polyslice({
                buildPlateWidth: 220
                buildPlateLength: 220
            })

            # Create a bounding box that fits within build plate.
            boundingBox = {
                min: { x: -5, y: -5, z: 0 }
                max: { x: 5, y: 5, z: 10 }
            }

            result = boundaryHelper.checkBuildPlateBoundaries(slicer, boundingBox, 110, 110)

            # Should be within boundaries (centered on 220x220 plate).
            expect(result.exceeds).toBe(false)
            expect(result.minX).toBe(105)
            expect(result.maxX).toBe(115)
            expect(result.minY).toBe(105)
            expect(result.maxY).toBe(115)

        test 'should detect when adhesion exceeds boundaries', ->

            slicer = new Polyslice({
                buildPlateWidth: 220
                buildPlateLength: 220
            })

            # Create a bounding box that exceeds build plate.
            boundingBox = {
                min: { x: -120, y: -120, z: 0 }
                max: { x: 120, y: 120, z: 10 }
            }

            result = boundaryHelper.checkBuildPlateBoundaries(slicer, boundingBox, 110, 110)

            # Should exceed boundaries.
            expect(result.exceeds).toBe(true)
            expect(result.minX).toBe(-10)  # 110 - 120 = -10 (exceeds 0)
            expect(result.maxX).toBe(230)  # 110 + 120 = 230 (exceeds 220)

        test 'should detect when adhesion exceeds left boundary', ->

            slicer = new Polyslice({
                buildPlateWidth: 220
                buildPlateLength: 220
            })

            boundingBox = {
                min: { x: -150, y: -5, z: 0 }
                max: { x: 5, y: 5, z: 10 }
            }

            result = boundaryHelper.checkBuildPlateBoundaries(slicer, boundingBox, 110, 110)

            expect(result.exceeds).toBe(true)
            expect(result.minX).toBeLessThan(0)

        test 'should detect when adhesion exceeds right boundary', ->

            slicer = new Polyslice({
                buildPlateWidth: 220
                buildPlateLength: 220
            })

            boundingBox = {
                min: { x: -5, y: -5, z: 0 }
                max: { x: 150, y: 5, z: 10 }
            }

            result = boundaryHelper.checkBuildPlateBoundaries(slicer, boundingBox, 110, 110)

            expect(result.exceeds).toBe(true)
            expect(result.maxX).toBeGreaterThan(220)

    describe 'addBoundaryWarning', ->

        test 'should add warning when boundaries exceeded and verbose enabled', ->

            slicer = new Polyslice({ verbose: true })
            slicer.gcode = ""

            boundaryInfo = {
                exceeds: true
                minX: -10
                maxX: 230
                minY: 5
                maxY: 215
                buildPlateWidth: 220
                buildPlateLength: 220
            }

            boundaryHelper.addBoundaryWarning(slicer, boundaryInfo, 'Skirt')

            expect(slicer.gcode).toContain('WARNING: Skirt extends beyond build plate boundaries')
            expect(slicer.gcode).toContain('Skirt bounds: X(-10.00, 230.00)')
            expect(slicer.gcode).toContain('Build plate: X(0, 220) Y(0, 220)')

        test 'should not add warning when boundaries not exceeded', ->

            slicer = new Polyslice({ verbose: true })
            slicer.gcode = ""

            boundaryInfo = {
                exceeds: false
                minX: 10
                maxX: 210
                minY: 10
                maxY: 210
                buildPlateWidth: 220
                buildPlateLength: 220
            }

            boundaryHelper.addBoundaryWarning(slicer, boundaryInfo, 'Skirt')

            expect(slicer.gcode).toBe("")

        test 'should not add warning when verbose disabled', ->

            slicer = new Polyslice({ verbose: false })
            slicer.gcode = ""

            boundaryInfo = {
                exceeds: true
                minX: -10
                maxX: 230
                minY: 5
                maxY: 215
                buildPlateWidth: 220
                buildPlateLength: 220
            }

            boundaryHelper.addBoundaryWarning(slicer, boundaryInfo, 'Skirt')

            expect(slicer.gcode).toBe("")

    describe 'calculateCircularSkirtBounds', ->

        test 'should calculate bounds for circular skirt', ->

            bounds = boundaryHelper.calculateCircularSkirtBounds(110, 110, 20)

            expect(bounds.min.x).toBe(90)
            expect(bounds.max.x).toBe(130)
            expect(bounds.min.y).toBe(90)
            expect(bounds.max.y).toBe(130)

        test 'should handle large radius', ->

            bounds = boundaryHelper.calculateCircularSkirtBounds(110, 110, 150)

            expect(bounds.min.x).toBe(-40)
            expect(bounds.max.x).toBe(260)
            expect(bounds.min.y).toBe(-40)
            expect(bounds.max.y).toBe(260)

    describe 'calculatePathBounds', ->

        test 'should calculate bounds for a path', ->

            path = [
                { x: 10, y: 20 }
                { x: 30, y: 40 }
                { x: 50, y: 10 }
            ]

            bounds = boundaryHelper.calculatePathBounds(path)

            expect(bounds.min.x).toBe(10)
            expect(bounds.max.x).toBe(50)
            expect(bounds.min.y).toBe(10)
            expect(bounds.max.y).toBe(40)

        test 'should handle offset parameter', ->

            path = [
                { x: 10, y: 20 }
                { x: 30, y: 40 }
            ]

            bounds = boundaryHelper.calculatePathBounds(path, 5)

            expect(bounds.min.x).toBe(5)   # 10 - 5
            expect(bounds.max.x).toBe(35)  # 30 + 5
            expect(bounds.min.y).toBe(15)  # 20 - 5
            expect(bounds.max.y).toBe(45)  # 40 + 5

        test 'should return null for empty path', ->

            bounds = boundaryHelper.calculatePathBounds([])

            expect(bounds).toBeNull()

        test 'should return null for null path', ->

            bounds = boundaryHelper.calculatePathBounds(null)

            expect(bounds).toBeNull()
