# Tests for tree support generation sub-module.

treeSupport = require('./tree')

describe 'Tree Support Module', ->

    test 'should exist as a module', ->
        expect(treeSupport).toBeDefined()

    test 'should have generateTreePattern method', ->
        expect(typeof treeSupport.generateTreePattern).toBe('function')

    test 'should have groupPointsIntoLines method', ->
        expect(typeof treeSupport.groupPointsIntoLines).toBe('function')

    test 'should have getFaceZAtPoint method', ->
        expect(typeof treeSupport.getFaceZAtPoint).toBe('function')

    test 'should have isOnTrunkGrid method', ->
        expect(typeof treeSupport.isOnTrunkGrid).toBe('function')

    describe 'getFaceZAtPoint', ->

        # Helper: build a face with given vertices.
        makeFace = (v0, v1, v2) ->
            return {
                vertices: [
                    { x: v0[0], y: v0[1], z: v0[2] }
                    { x: v1[0], y: v1[1], z: v1[2] }
                    { x: v2[0], y: v2[1], z: v2[2] }
                ]
            }

        test 'should return face Z for a point inside a horizontal face', ->

            # Horizontal face at Z=10 spanning x=0-10, y=0-10 (right triangle).
            face = makeFace([0, 0, 10], [10, 0, 10], [0, 10, 10])

            result = treeSupport.getFaceZAtPoint(2, 2, [face])

            expect(result).toBeCloseTo(10, 5)

        test 'should return null for a point outside all face projections', ->

            face = makeFace([0, 0, 10], [5, 0, 10], [0, 5, 10])

            result = treeSupport.getFaceZAtPoint(8, 8, [face])

            expect(result).toBeNull()

        test 'should return interpolated Z for a point on a sloped face', ->

            # Sloped face: Z=10 at y=0, Z=0 at y=10. At (5,5) Z should be ~5.
            face = makeFace([0, 0, 10], [10, 0, 10], [0, 10, 0])
            face2 = makeFace([10, 0, 10], [10, 10, 0], [0, 10, 0])

            result = treeSupport.getFaceZAtPoint(5, 5, [face, face2])

            expect(result).toBeCloseTo(5, 1)

    describe 'isOnTrunkGrid', ->

        test 'should return true for a point at the grid origin', ->

            result = treeSupport.isOnTrunkGrid(0, 0, 0, 0, 1.6, 0.3)

            expect(result).toBe(true)

        test 'should return true for a point at a trunk grid position', ->

            # x = 1.8 is close enough to the trunk column at 1.6 (|1.8-1.6|=0.2 < 0.3).
            result = treeSupport.isOnTrunkGrid(1.8, 0, 0, 0, 1.6, 0.3)

            expect(result).toBe(true)

        test 'should return false for a point between trunk grid positions', ->

            # x = 1.0 → nearest trunk column at 1.6, dist 0.6 > 0.3.
            result = treeSupport.isOnTrunkGrid(1.0, 0, 0, 0, 1.6, 0.3)

            expect(result).toBe(false)

    describe 'groupPointsIntoLines', ->

        test 'should group points into X-direction lines', ->

            points = [
                { x: 1, y: 0 }
                { x: 2, y: 0 }
                { x: 1, y: 1 }
                { x: 2, y: 1 }
            ]

            lines = treeSupport.groupPointsIntoLines(points, true)

            # Should produce 2 horizontal lines (grouped by y)
            expect(lines.length).toBe(2)

        test 'should group points into Y-direction lines', ->

            points = [
                { x: 0, y: 1 }
                { x: 0, y: 2 }
                { x: 1, y: 1 }
                { x: 1, y: 2 }
            ]

            lines = treeSupport.groupPointsIntoLines(points, false)

            # Should produce 2 vertical lines (grouped by x)
            expect(lines.length).toBe(2)

        test 'should sort X-direction lines by x coordinate', ->

            points = [
                { x: 3, y: 0 }
                { x: 1, y: 0 }
                { x: 2, y: 0 }
            ]

            lines = treeSupport.groupPointsIntoLines(points, true)

            expect(lines.length).toBe(1)
            expect(lines[0][0].x).toBe(1)
            expect(lines[0][1].x).toBe(2)
            expect(lines[0][2].x).toBe(3)

    describe 'generateTreePattern', ->

        # Helper: create a minimal slicer-like object for testing.
        makeSlicer = ->

            slicer = new (require('../../../index'))({
                progressCallback: null
            })

            slicer.gcode = ''
            slicer.cumulativeE = 0

            return slicer

        # Helper: create a region above a given Z with a single triangular face.
        makeRegion = (minX, maxX, minY, maxY, regionZ) ->

            # Build two faces that together cover the full rectangle.
            faces = [
                {
                    vertices: [
                        { x: minX, y: minY, z: regionZ }
                        { x: maxX, y: minY, z: regionZ }
                        { x: maxX, y: maxY, z: regionZ }
                    ]
                }
                {
                    vertices: [
                        { x: minX, y: minY, z: regionZ }
                        { x: maxX, y: maxY, z: regionZ }
                        { x: minX, y: maxY, z: regionZ }
                    ]
                }
            ]

            return {
                faces: faces
                minX: minX
                maxX: maxX
                minY: minY
                maxY: maxY
                minZ: regionZ
                maxZ: regionZ
                centerX: (minX + maxX) / 2
                centerY: (minY + maxY) / 2
            }

        test 'should produce G-code with extrusion moves for branch zone', ->

            slicer = makeSlicer()
            region = makeRegion(-10, 10, -10, 10, 15)

            nozzleDiameter = slicer.getNozzleDiameter()
            layerHeight = slicer.getLayerHeight()

            # Layer z=14 is within BRANCH_HEIGHT (8mm) of region.maxZ=15 → branch zone.
            treeSupport.generateTreePattern(
                slicer, region, 14, 0,
                100, 100,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            expect(slicer.gcode.length).toBeGreaterThan(0)

            # Must contain at least one extruding G1 move with E parameter.
            expect(slicer.gcode).toMatch(/G1 .*E[\d.]+/)

        test 'should produce G-code with extrusion moves for trunk zone', ->

            slicer = makeSlicer()
            region = makeRegion(-10, 10, -10, 10, 30)

            nozzleDiameter = slicer.getNozzleDiameter()
            layerHeight = slicer.getLayerHeight()

            # Layer z=0.2 is more than BRANCH_HEIGHT (8mm) below region.maxZ=30 → trunk zone.
            treeSupport.generateTreePattern(
                slicer, region, 0.2, 0,
                100, 100,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            expect(slicer.gcode.length).toBeGreaterThan(0)

            # Must contain at least one extruding G1 move with E parameter.
            expect(slicer.gcode).toMatch(/G1 .*E[\d.]+/)

        test 'trunk zone should have fewer extrusion moves than branch zone for same region', ->

            nozzleDiameter = 0.4
            layerHeight = 0.2
            region = makeRegion(-10, 10, -10, 10, 30)

            # Branch zone: z=28 is within BRANCH_HEIGHT of region maxZ=30.
            slicerBranch = makeSlicer()

            treeSupport.generateTreePattern(
                slicerBranch, region, 28, 0,
                100, 100,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            # Trunk zone: z=0.2 is far below region maxZ=30.
            slicerTrunk = makeSlicer()

            treeSupport.generateTreePattern(
                slicerTrunk, region, 0.2, 0,
                100, 100,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            # Count only extruding G1 moves (those with E parameter).
            branchExtrusions = slicerBranch.gcode.split('\n').filter (l) -> /^G1 .*E/.test(l)
            trunkExtrusions = slicerTrunk.gcode.split('\n').filter (l) -> /^G1 .*E/.test(l)

            # Trunk zone should use fewer extrusion moves (convergence / coarser grid).
            expect(trunkExtrusions.length).toBeLessThan(branchExtrusions.length)

        test 'should return true when support G-code is emitted', ->

            slicer = makeSlicer()
            region = makeRegion(-10, 10, -10, 10, 15)

            nozzleDiameter = slicer.getNozzleDiameter()
            layerHeight = slicer.getLayerHeight()

            result = treeSupport.generateTreePattern(
                slicer, region, 14, 0,
                100, 100,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            expect(result).toBe(true)

        test 'should return false and emit no G-code when current z is above the overhang', ->

            slicer = makeSlicer()
            region = makeRegion(-5, 5, -5, 5, 2)  # overhang at z=2

            nozzleDiameter = slicer.getNozzleDiameter()
            layerHeight = slicer.getLayerHeight()

            # z=5 is above the region maxZ=2 → wedge check rejects all points.
            result = treeSupport.generateTreePattern(
                slicer, region, 5, 0,
                100, 100,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            expect(result).toBe(false)
            expect(slicer.gcode).toBe('')
