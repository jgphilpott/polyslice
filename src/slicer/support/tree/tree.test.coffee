# Tests for tree support generation sub-module.

treeSupport = require('./tree')

describe 'Tree Support Module', ->

    test 'should exist as a module', ->
        expect(treeSupport).toBeDefined()

    test 'should have generateTreePattern method', ->
        expect(typeof treeSupport.generateTreePattern).toBe('function')

    test 'should have buildTreeStructure method', ->
        expect(typeof treeSupport.buildTreeStructure).toBe('function')

    test 'should have getFaceZAtPoint method', ->
        expect(typeof treeSupport.getFaceZAtPoint).toBe('function')

    test 'should have deduplicatePoints method', ->
        expect(typeof treeSupport.deduplicatePoints).toBe('function')

    test 'should have renderNodeAt method', ->
        expect(typeof treeSupport.renderNodeAt).toBe('function')

    describe 'renderNodeAt', ->

        # Helper: create a minimal slicer for rendering tests.
        makeSlicer = ->

            slicer = new (require('../../../index'))({
                progressCallback: null
            })

            slicer.gcode = ''
            slicer.cumulativeE = 0

            return slicer

        # Helper: extract the maximum absolute X coordinate from G-code.
        maxAbsX = (gcode) ->

            maxX = 0

            for line in gcode.split('\n')

                match = line.match(/X([\-\d.]+)/)

                if match

                    maxX = Math.max(maxX, Math.abs(parseFloat(match[1])))

            return maxX

        nozzle = 0.4
        supportLineWidth = nozzle * 0.8
        supportSpeed = 900
        travelSpeed = 9000

        test 'should emit G-code with extrusion moves', ->

            slicer = makeSlicer()

            treeSupport.renderNodeAt(
                slicer, 0, 0, 1, 0, 0,
                nozzle, 'twig', supportLineWidth, supportSpeed, travelSpeed
            )

            expect(slicer.gcode).toMatch(/G1 .*E[\d.]+/)

        test 'trunk node should have a larger cross-section radius than twig node', ->

            slicerTrunk = makeSlicer()
            slicerTwig = makeSlicer()

            # Render at centerOffset = 0 so coordinates equal local coordinates directly.
            treeSupport.renderNodeAt(
                slicerTrunk, 0, 0, 1, 0, 0,
                nozzle, 'trunk', supportLineWidth, supportSpeed, travelSpeed
            )

            treeSupport.renderNodeAt(
                slicerTwig, 0, 0, 1, 0, 0,
                nozzle, 'twig', supportLineWidth, supportSpeed, travelSpeed
            )

            # Trunk circle radius = 3.0 × nozzle; twig = 0.8 × nozzle.
            # The maximum absolute X in the trunk G-code must be substantially larger.
            expect(maxAbsX(slicerTrunk.gcode)).toBeGreaterThan(maxAbsX(slicerTwig.gcode))

        test 'branch node should have a cross-section radius between trunk and twig', ->

            slicerTrunk = makeSlicer()
            slicerBranch = makeSlicer()
            slicerTwig = makeSlicer()

            treeSupport.renderNodeAt(
                slicerTrunk, 0, 0, 1, 0, 0,
                nozzle, 'trunk', supportLineWidth, supportSpeed, travelSpeed
            )

            treeSupport.renderNodeAt(
                slicerBranch, 0, 0, 1, 0, 0,
                nozzle, 'branch', supportLineWidth, supportSpeed, travelSpeed
            )

            treeSupport.renderNodeAt(
                slicerTwig, 0, 0, 1, 0, 0,
                nozzle, 'twig', supportLineWidth, supportSpeed, travelSpeed
            )

            branchMaxX = maxAbsX(slicerBranch.gcode)

            expect(branchMaxX).toBeLessThan(maxAbsX(slicerTrunk.gcode))
            expect(branchMaxX).toBeGreaterThan(maxAbsX(slicerTwig.gcode))

        test 'should produce a closed circular perimeter (first and last circle points match)', ->

            slicer = makeSlicer()

            treeSupport.renderNodeAt(
                slicer, 0, 0, 1, 0, 0,
                nozzle, 'twig', supportLineWidth, supportSpeed, travelSpeed
            )

            # Split once; reuse for both G0 and G1 filtering.
            gcodeLines = slicer.gcode.split('\n')
            g0lines = gcodeLines.filter (l) -> l.startsWith('G0')
            g1lines = gcodeLines.filter (l) -> l.startsWith('G1')

            # There must be at least one travel and multiple extrusion moves.
            expect(g0lines.length).toBeGreaterThan(0)
            expect(g1lines.length).toBeGreaterThan(0)

            # The first G0 travel goes to the circle start at angle 0 (rightmost point).
            # After CIRCLE_SEGMENTS (=12) extrusion steps the perimeter closes: g1lines[11]
            # is the last circle vertex and must share its X coordinate with the start G0.
            startMatch = g0lines[0].match(/X([\-\d.]+)/)
            endMatch = g1lines[11]?.match(/X([\-\d.]+)/)  # index 11 = CIRCLE_SEGMENTS - 1

            # Fail loudly if the G-code format has changed and the coordinates cannot be found.
            expect(startMatch).toBeTruthy()
            expect(endMatch).toBeTruthy()

            startX = parseFloat(startMatch[1])
            endX = parseFloat(endMatch[1])

            # The circle closes: last polygon vertex matches the start vertex.
            expect(startX).toBeCloseTo(endX, 3)

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

    describe 'deduplicatePoints', ->

        test 'should keep all points that are outside the tolerance distance', ->

            points = [
                { x: 0, y: 0 }
                { x: 1, y: 0 }
                { x: 2, y: 0 }
            ]

            result = treeSupport.deduplicatePoints(points, 0.3)

            expect(result.length).toBe(3)

        test 'should remove a point that is within tolerance of a kept point', ->

            # Second point is only 0.1mm from the first — within 0.3mm tolerance.
            points = [
                { x: 0, y: 0 }
                { x: 0.1, y: 0 }
                { x: 5, y: 0 }
            ]

            result = treeSupport.deduplicatePoints(points, 0.3)

            expect(result.length).toBe(2)

        test 'should keep the first occurrence when duplicates are present', ->

            points = [
                { x: 3, y: 4 }
                { x: 3.05, y: 4.05 }
            ]

            result = treeSupport.deduplicatePoints(points, 0.2)

            # Only the first point should survive.
            expect(result.length).toBe(1)
            expect(result[0].x).toBeCloseTo(3, 5)
            expect(result[0].y).toBeCloseTo(4, 5)

        test 'should return empty array for empty input', ->

            result = treeSupport.deduplicatePoints([], 0.2)

            expect(result).toEqual([])

    describe 'buildTreeStructure', ->

        # Helper: build a region with a flat rectangular overhang at the given Z.
        makeRegion = (minX, maxX, minY, maxY, regionZ) ->

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

        test 'should return an empty array when the region is too small', ->

            # Region with 0.1mm width collapses below supportGap check.
            region = makeRegion(0, 0.1, 0, 0.1, 20)
            segments = treeSupport.buildTreeStructure(region, 0.4, 0, 0.2)

            expect(Array.isArray(segments)).toBe(true)
            expect(segments.length).toBe(0)

        test 'should return segments for a valid region', ->

            region = makeRegion(-10, 10, -10, 10, 20)
            segments = treeSupport.buildTreeStructure(region, 0.4, 0, 0.2)

            expect(segments.length).toBeGreaterThan(0)

        test 'should include a trunk segment that is perfectly vertical', ->

            # Symmetric region: trunk should sit at the XY centroid.
            region = makeRegion(-10, 10, -10, 10, 20)
            segments = treeSupport.buildTreeStructure(region, 0.4, 0, 0.2)

            # A trunk segment has the same x and y at both endpoints.
            trunkSegments = segments.filter (s) ->
                Math.abs(s.x1 - s.x2) < 0.01 and Math.abs(s.y1 - s.y2) < 0.01

            expect(trunkSegments.length).toBeGreaterThan(0)

        test 'should include branch segments that angle outward at approximately 45 degrees', ->

            region = makeRegion(-10, 10, -10, 10, 20)
            segments = treeSupport.buildTreeStructure(region, 0.4, 0, 0.2)

            # Branch and twig segments have both horizontal and vertical extent.
            angledSegments = segments.filter (s) ->
                horizontalDist = Math.sqrt((s.x2 - s.x1) ** 2 + (s.y2 - s.y1) ** 2)
                verticalDist = Math.abs(s.z2 - s.z1)
                return horizontalDist > 0.1 and verticalDist > 0.1

            expect(angledSegments.length).toBeGreaterThan(0)

            # Each angled segment must satisfy the 45-degree constraint:
            # horizontal spread ≤ vertical rise (5% tolerance for floating-point rounding).
            angledSegments.forEach (seg) ->
                horizontalDist = Math.sqrt((seg.x2 - seg.x1) ** 2 + (seg.y2 - seg.y1) ** 2)
                verticalDist = Math.abs(seg.z2 - seg.z1)
                expect(horizontalDist).toBeLessThanOrEqual(verticalDist * 1.05)

        test 'should produce more angled segments for a larger region', ->

            # A larger region needs more branches to cover the overhang.
            regionSmall = makeRegion(-5, 5, -5, 5, 20)
            regionLarge = makeRegion(-15, 15, -15, 15, 20)

            segmentsSmall = treeSupport.buildTreeStructure(regionSmall, 0.4, 0, 0.2)
            segmentsLarge = treeSupport.buildTreeStructure(regionLarge, 0.4, 0, 0.2)

            expect(segmentsLarge.length).toBeGreaterThan(segmentsSmall.length)

        test 'should emit exactly one trunk segment regardless of branch count', ->

            # A wide region has multiple branches but must have only a single vertical trunk.
            region = makeRegion(-15, 15, -15, 15, 20)
            segments = treeSupport.buildTreeStructure(region, 0.4, 0, 0.2)

            trunkSegments = segments.filter (s) -> s.type is 'trunk'

            expect(trunkSegments.length).toBe(1)

        test 'should always include a trunk segment even when overhang is wide and low', ->

            # Wide region (20mm) at a low Z (3mm) forces branchRootZ to be clamped for
            # every branch — the old code would emit no trunk in this case.
            region = makeRegion(0, 20, 0, 20, 3)
            segments = treeSupport.buildTreeStructure(region, 0.4, 0, 0.2)

            # Must still have at least one trunk segment.
            trunkSegments = segments.filter (s) -> s.type is 'trunk'

            expect(trunkSegments.length).toBeGreaterThan(0)

        test 'should cluster consistently when the same region is offset on the build plate', ->

            # Two identical geometries placed at different absolute positions.
            # Clustering anchored to region minX/minY means the number of branch nodes
            # (and therefore segments) should be the same regardless of offset.
            regionAtOrigin = makeRegion(0, 20, 0, 20, 20)
            regionOffset = makeRegion(100, 120, 200, 220, 20)

            segsOrigin = treeSupport.buildTreeStructure(regionAtOrigin, 0.4, 0, 0.2)
            segsOffset = treeSupport.buildTreeStructure(regionOffset, 0.4, 0, 0.2)

            # The number of branch nodes (and therefore branch segments) must be identical.
            branchOrigin = segsOrigin.filter (s) -> s.type is 'branch'
            branchOffset = segsOffset.filter (s) -> s.type is 'branch'

            expect(branchOffset.length).toBe(branchOrigin.length)

        test 'should not produce orphaned twigs - each twig start must match a branch endpoint', ->

            # A twig is orphaned when its (x1, y1, z1) does not coincide with the (x2, y2, z2)
            # of any branch segment.  This would mean the twig starts in mid-air with no
            # structural connection to the branch below it.
            region = makeRegion(-10, 10, -10, 10, 20)
            segments = treeSupport.buildTreeStructure(region, 0.4, 0, 0.2)

            twigSegments = segments.filter (s) -> s.type is 'twig'
            branchSegments = segments.filter (s) -> s.type is 'branch'

            expect(twigSegments.length).toBeGreaterThan(0)

            for twig in twigSegments

                # Every twig must have a branch whose endpoint coincides with the twig start.
                matchingBranch = branchSegments.some (branch) ->
                    Math.abs(branch.x2 - twig.x1) < 0.001 and
                    Math.abs(branch.y2 - twig.y1) < 0.001 and
                    Math.abs(branch.z2 - twig.z1) < 0.001

                expect(matchingBranch).toBe(true)

            return

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

        test 'should produce G-code with extrusion moves near the overhang (branch zone)', ->

            slicer = makeSlicer()
            region = makeRegion(-10, 10, -10, 10, 15)

            nozzleDiameter = slicer.getNozzleDiameter()
            layerHeight = slicer.getLayerHeight()

            # Layer z=14 is just below the overhang at z=15 (branch zone).
            treeSupport.generateTreePattern(
                slicer, region, 14, 0,
                100, 100,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            expect(slicer.gcode.length).toBeGreaterThan(0)

            # Must contain at least one extruding G1 move with E parameter.
            expect(slicer.gcode).toMatch(/G1 .*E[\d.]+/)

        test 'should produce G-code with extrusion moves far below the overhang (trunk zone)', ->

            slicer = makeSlicer()
            region = makeRegion(-10, 10, -10, 10, 30)

            nozzleDiameter = slicer.getNozzleDiameter()
            layerHeight = slicer.getLayerHeight()

            # Layer z=0.2 is far below the overhang — only the trunk cross is present.
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

            # Branch zone: z=28 is close to the overhang — branches have spread wide.
            slicerBranch = makeSlicer()

            treeSupport.generateTreePattern(
                slicerBranch, region, 28, 0,
                100, 100,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            # Trunk zone: z=0.2 is near the build plate — converges to one trunk column.
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

            # Trunk zone must have fewer extrusion moves (single column vs spread branches).
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

            # z=5 is above the region maxZ=2 → no segments span this layer.
            result = treeSupport.generateTreePattern(
                slicer, region, 5, 0,
                100, 100,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            expect(result).toBe(false)
            expect(slicer.gcode).toBe('')

        test 'should cache the tree structure in the region object', ->

            slicer = makeSlicer()
            region = makeRegion(-10, 10, -10, 10, 20)

            nozzleDiameter = slicer.getNozzleDiameter()
            layerHeight = slicer.getLayerHeight()

            # First call builds the structure.
            treeSupport.generateTreePattern(
                slicer, region, 10, 0,
                0, 0, nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            firstCache = region._treeSegments

            # Second call reuses the cached structure.
            treeSupport.generateTreePattern(
                slicer, region, 5, 0,
                0, 0, nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            expect(region._treeSegments).toBe(firstCache)
