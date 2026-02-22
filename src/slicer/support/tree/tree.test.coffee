# Tests for tree support generation sub-module.

treeSupport = require('./tree')

describe 'Tree Support Module', ->

    test 'should exist as a module', ->
        expect(treeSupport).toBeDefined()

    test 'should have generateTreePattern method', ->
        expect(typeof treeSupport.generateTreePattern).toBe('function')

    test 'should have groupPointsIntoLines method', ->
        expect(typeof treeSupport.groupPointsIntoLines).toBe('function')

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

        # Helper: create a region above a given Z.
        makeRegion = (minX, maxX, minY, maxY, regionZ) ->

            # Build a single face covering the region.
            face = {
                vertices: [
                    { x: minX, y: minY, z: regionZ }
                    { x: maxX, y: minY, z: regionZ }
                    { x: minX, y: maxY, z: regionZ }
                ]
            }

            return {
                faces: [face]
                minX: minX
                maxX: maxX
                minY: minY
                maxY: maxY
                minZ: regionZ
                maxZ: regionZ
                centerX: (minX + maxX) / 2
                centerY: (minY + maxY) / 2
            }

        test 'should produce G-code for a region in the branch zone', ->

            slicer = makeSlicer()
            region = makeRegion(-10, 10, -10, 10, 15)

            nozzleDiameter = slicer.getNozzleDiameter()
            layerHeight = slicer.getLayerHeight()
            layerSolidRegions = []

            # Layer z=14 is within BRANCH_HEIGHT (8mm) of region.maxZ=15 → branch zone.
            treeSupport.generateTreePattern(
                slicer, region, 14, 0,
                100, 100,
                nozzleDiameter, layerSolidRegions,
                'buildPlate', 0, layerHeight
            )

            expect(slicer.gcode.length).toBeGreaterThan(0)
            expect(slicer.gcode).toContain('G0')

        test 'should produce G-code for a region in the trunk zone', ->

            slicer = makeSlicer()
            region = makeRegion(-10, 10, -10, 10, 30)

            nozzleDiameter = slicer.getNozzleDiameter()
            layerHeight = slicer.getLayerHeight()
            layerSolidRegions = []

            # Layer z=0.2 is more than BRANCH_HEIGHT (8mm) below region.maxZ=30 → trunk zone.
            treeSupport.generateTreePattern(
                slicer, region, 0.2, 0,
                100, 100,
                nozzleDiameter, layerSolidRegions,
                'buildPlate', 0, layerHeight
            )

            expect(slicer.gcode.length).toBeGreaterThan(0)

        test 'trunk zone should use fewer support lines than branch zone for same region', ->

            nozzleDiameter = 0.4
            layerHeight = 0.2
            region = makeRegion(-10, 10, -10, 10, 30)

            # Branch zone.
            slicerBranch = makeSlicer()
            slicerBranch.gcode = ''
            slicerBranch.cumulativeE = 0

            treeSupport.generateTreePattern(
                slicerBranch, region, 28, 0,
                100, 100,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            # Trunk zone.
            slicerTrunk = makeSlicer()
            slicerTrunk.gcode = ''
            slicerTrunk.cumulativeE = 0

            treeSupport.generateTreePattern(
                slicerTrunk, region, 0.2, 0,
                100, 100,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            branchLines = slicerBranch.gcode.split('\n').filter (l) -> l.startsWith('G1') or l.startsWith('G0')
            trunkLines = slicerTrunk.gcode.split('\n').filter (l) -> l.startsWith('G1') or l.startsWith('G0')

            # Trunk zone should use fewer lines (coarser grid).
            expect(trunkLines.length).toBeLessThan(branchLines.length)

        test 'should return early for a region below current z', ->

            slicer = makeSlicer()
            region = makeRegion(-5, 5, -5, 5, 2)  # overhang at z=2

            nozzleDiameter = slicer.getNozzleDiameter()
            layerHeight = slicer.getLayerHeight()

            # Current z=5 is above the region maxZ=2 → interfaceGap check should skip.
            # This is handled by the caller (support.coffee), so generateTreePattern
            # may produce empty output if wedge check fails.
            initialGcode = slicer.gcode

            treeSupport.generateTreePattern(
                slicer, region, 5, 0,
                100, 100,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            # No support should be generated when current z is above the overhang.
            expect(slicer.gcode).toBe(initialGcode)
