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

            # A twig is orphaned when it has no structural connection to any branch.
            # Each twig's XY root must coincide with a branch endpoint's XY, and the
            # twig's Z root must be within TWIG_OVERLAP_LAYERS layers below the branch
            # endpoint (the twig starts slightly lower to create a physical bond).
            layerHeight = 0.2
            overlapZ = treeSupport.TWIG_OVERLAP_LAYERS * layerHeight
            region = makeRegion(-10, 10, -10, 10, 20)
            segments = treeSupport.buildTreeStructure(region, 0.4, 0, layerHeight)

            twigSegments = segments.filter (s) -> s.type is 'twig'
            branchSegments = segments.filter (s) -> s.type is 'branch'

            expect(twigSegments.length).toBeGreaterThan(0)

            for twig in twigSegments

                # Every twig must have a branch whose XY endpoint matches the twig XY root,
                # with the twig starting at most TWIG_OVERLAP_LAYERS layers below the branch end.
                matchingBranch = branchSegments.some (branch) ->
                    Math.abs(branch.x2 - twig.x1) < 0.001 and
                    Math.abs(branch.y2 - twig.y1) < 0.001 and
                    twig.z1 <= branch.z2 + 0.001 and
                    twig.z1 >= branch.z2 - overlapZ - 0.001

                expect(matchingBranch).toBe(true)

            return

        test 'should produce valid branches and twigs for low overhang near the build plate', ->

            # A wide region at low Z forces nodeZ onto its clamp (buildPlateZ + layerHeight),
            # which previously caused branchRootZ == nodeZ (zero-height branch) and
            # twigStartZ to fall below branchRootZ.  Both must now be handled correctly.
            layerHeight = 0.2
            overlapZ = treeSupport.TWIG_OVERLAP_LAYERS * layerHeight
            region = makeRegion(-10, 10, -10, 10, 2)
            segments = treeSupport.buildTreeStructure(region, 0.4, 0, layerHeight)

            branchSegments = segments.filter (s) -> s.type is 'branch'
            twigSegments = segments.filter (s) -> s.type is 'twig'

            # Every branch must span at least one printable layer (non-zero height).
            for branch in branchSegments

                expect(branch.z2).toBeGreaterThan(branch.z1)

            # Every twig must connect to a branch and start within branchRootZ..nodeZ.
            for twig in twigSegments

                matchingBranch = branchSegments.some (branch) ->
                    Math.abs(branch.x2 - twig.x1) < 0.001 and
                    Math.abs(branch.y2 - twig.y1) < 0.001 and
                    twig.z1 >= branch.z1 - 0.001 and
                    twig.z1 <= branch.z2 + 0.001

                expect(matchingBranch).toBe(true)

            return

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

        test 'buildTreeStructure should NOT include root segments (roots are dynamic)', ->

            region = makeRegion(-10, 10, -10, 10, 20)
            segments = treeSupport.buildTreeStructure(region, 0.4, 0, 0.2)

            rootSegments = segments.filter (s) -> s.type is 'root'

            # Roots are generated dynamically in generateTreePattern, not pre-computed here.
            expect(rootSegments.length).toBe(0)

        test 'buildTreeStructure should only contain trunk, branch, and twig segment types', ->

            region = makeRegion(-10, 10, -10, 10, 20)
            segments = treeSupport.buildTreeStructure(region, 0.4, 0, 0.2)

            for seg in segments

                expect(['trunk', 'branch', 'twig']).toContain(seg.type)

            return

        test 'should emit ROOT_COUNT root cross-sections at the effective trunk base layer', ->

            slicer = makeSlicer()
            region = makeRegion(-10, 10, -10, 10, 20)

            nozzleDiameter = slicer.getNozzleDiameter()
            layerHeight = slicer.getLayerHeight()

            # First call at z=0.1 sets _effectiveTrunkBaseZ and renders roots + trunk.
            treeSupport.generateTreePattern(
                slicer, region, 0.1, 0,
                0, 0,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            # The effective trunk base must have been recorded.
            expect(region._effectiveTrunkBaseZ).toBeCloseTo(0.1, 5)

            # G-code must include extruding moves (trunk + root nodes all produce extrusions).
            expect(slicer.gcode).toMatch(/G1 .*E[\d.]+/)

        test 'base layer should have more extrusion moves than a layer above the root zone', ->

            nozzleDiameter = 0.4
            layerHeight = 0.2

            # Base layer (z=0.1): trunk + ROOT_COUNT roots → most extrusion moves.
            slicerBase = makeSlicer()
            regionBase = makeRegion(-10, 10, -10, 10, 20)

            treeSupport.generateTreePattern(
                slicerBase, regionBase, 0.1, 0,
                0, 0,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            baseExtrusionCount = slicerBase.gcode.split('\n').filter((l) -> /^G1 .*E/.test(l)).length

            # Each renderNodeAt call produces CIRCLE_SEGMENTS (12) + 2 X-arm extrusions = 14.
            # With ROOT_COUNT=4 roots plus 1 trunk, the base layer should have significantly
            # more extrusion moves than a layer above the root zone where only the trunk
            # cross-section is rendered.

            # Generate a second layer above the root zone using a fresh slicer/region pair.
            # First call at effectiveBaseZ establishes _effectiveTrunkBaseZ and root state;
            # second call at zAboveRootZone (≈ rootTopZ + layerHeight) produces trunk only.
            slicerAbove = makeSlicer()
            regionAbove = makeRegion(-10, 10, -10, 10, 20)

            treeSupport.generateTreePattern(
                slicerAbove, regionAbove, 0.1, 0,
                0, 0,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            gcodeAfterBase = slicerAbove.gcode

            # rootTopZ ≈ effectiveBaseZ + rootHeight ≈ 0.1 + 1.8 = 1.9; choose 2.0 to be safely above.
            zAboveRootZone = 2.0

            treeSupport.generateTreePattern(
                slicerAbove, regionAbove, zAboveRootZone, 0,
                0, 0,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            aboveLayerGcode = slicerAbove.gcode.substring(gcodeAfterBase.length)
            aboveLayerExtrusionCount = aboveLayerGcode.split('\n').filter((l) -> /^G1 .*E/.test(l)).length

            # Base layer (trunk + ROOT_COUNT roots) must exceed the trunk-only layer above.
            expect(baseExtrusionCount).toBeGreaterThan(aboveLayerExtrusionCount)

        test 'roots should spread outward from the trunk (not at trunk XY) at the effective base layer', ->

            slicer = makeSlicer()
            region = makeRegion(-10, 10, -10, 10, 20)

            nozzleDiameter = slicer.getNozzleDiameter()
            layerHeight = slicer.getLayerHeight()

            # z=0.1: effective base layer where roots are at maximum spread.
            treeSupport.generateTreePattern(
                slicer, region, 0.1, 0,
                0, 0,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            # Trunk is at centroid (0, 0) for a symmetric region centered on origin.
            # At the base layer (t=0), roots are at spread positions — G-code should
            # contain X coordinates larger than trunk_radius (1.2mm) away from trunk.
            trunkRadius = nozzleDiameter * 3.0
            maxX = 0

            for line in slicer.gcode.split('\n')

                match = line.match(/X([\-\d.]+)/)

                if match

                    maxX = Math.max(maxX, Math.abs(parseFloat(match[1])))

            # Root spread must extend beyond the trunk circle radius.
            expect(maxX).toBeGreaterThan(trunkRadius)

        test 'root node should have radius between trunk and branch radii', ->

            nozzle = 0.4
            supportLineWidth = nozzle * 0.8
            supportSpeed = 900
            travelSpeed = 9000

            slicerTrunk = new (require('../../../index'))({ progressCallback: null })
            slicerRoot = new (require('../../../index'))({ progressCallback: null })
            slicerBranch = new (require('../../../index'))({ progressCallback: null })

            slicerTrunk.gcode = ''
            slicerTrunk.cumulativeE = 0
            slicerRoot.gcode = ''
            slicerRoot.cumulativeE = 0
            slicerBranch.gcode = ''
            slicerBranch.cumulativeE = 0

            treeSupport.renderNodeAt(slicerTrunk, 0, 0, 1, 0, 0, nozzle, 'trunk', supportLineWidth, supportSpeed, travelSpeed)
            treeSupport.renderNodeAt(slicerRoot, 0, 0, 1, 0, 0, nozzle, 'root', supportLineWidth, supportSpeed, travelSpeed)
            treeSupport.renderNodeAt(slicerBranch, 0, 0, 1, 0, 0, nozzle, 'branch', supportLineWidth, supportSpeed, travelSpeed)

            # Extract maximum absolute X coordinate as a proxy for node radius.
            maxAbsX = (gcode) ->
                maxX = 0
                for line in gcode.split('\n')
                    match = line.match(/X([\-\d.]+)/)
                    if match
                        maxX = Math.max(maxX, Math.abs(parseFloat(match[1])))
                return maxX

            rootMaxX = maxAbsX(slicerRoot.gcode)

            # Root radius must be strictly between trunk and branch radii.
            expect(rootMaxX).toBeLessThan(maxAbsX(slicerTrunk.gcode))
            expect(rootMaxX).toBeGreaterThan(maxAbsX(slicerBranch.gcode))

        test 'should produce G-code at the base (trunk/root zone) with root cross-sections', ->

            slicer = new (require('../../../index'))({ progressCallback: null })
            slicer.gcode = ''
            slicer.cumulativeE = 0

            region = makeRegion(-10, 10, -10, 10, 20)
            nozzleDiameter = slicer.getNozzleDiameter()
            layerHeight = slicer.getLayerHeight()

            # Layer z=0.1 sets the effective trunk base; trunk + dynamic roots appear here.
            treeSupport.generateTreePattern(
                slicer, region, 0.1, 0,
                0, 0,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            # Must contain extruding G1 moves from both trunk and root nodes.
            expect(slicer.gcode).toMatch(/G1 .*E[\d.]+/)

        test 'roots should be at a 45-degree outward angle (horizontal spread equals rootHeight)', ->

            slicer = makeSlicer()
            nozzleDiameter = slicer.getNozzleDiameter()
            layerHeight = slicer.getLayerHeight()

            region = makeRegion(-10, 10, -10, 10, 20)

            # First call establishes effectiveTrunkBaseZ.
            treeSupport.generateTreePattern(
                slicer, region, layerHeight, 0,
                0, 0,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            effectiveBaseZ = region._effectiveTrunkBaseZ

            expect(effectiveBaseZ).toBeDefined()

            # Compute rootHeight as the code does.
            contactSpacing = nozzleDiameter * treeSupport.CONTACT_SPACING_MULTIPLIER
            segments = region._treeSegments
            trunkSeg = segments.find (s) -> s.type is 'trunk'
            trunkHeight = Math.abs(trunkSeg.z2 - trunkSeg.z1)
            rootSpread = Math.min(contactSpacing * treeSupport.BRANCH_CLUSTER_SIZE, trunkHeight)
            rootHeight = rootSpread * 0.5

            # At the base layer (t=0), roots are at spread positions.
            # Spread distance = rootHeight for a 45-degree angle.
            # Verify by checking _validRootIndices contains indices and that the
            # G-code X/Y extent at z=effectiveBaseZ is approximately rootHeight from trunk.
            trunkX = trunkSeg.x1
            maxDistFromTrunk = 0

            for line in slicer.gcode.split('\n')

                matchX = line.match(/X([\-\d.]+)/)
                matchY = line.match(/Y([\-\d.]+)/)

                if matchX and matchY

                    px = parseFloat(matchX[1]) - trunkX
                    py = parseFloat(matchY[1])
                    dist = Math.sqrt(px * px + py * py)
                    maxDistFromTrunk = Math.max(maxDistFromTrunk, dist)

            # The furthest G-code coordinate should not exceed trunk_radius + rootHeight + tolerance.
            # (trunk circle extends to trunkRadius = 3.0 * nozzle, root spread = rootHeight;
            # the extra nozzleDiameter accounts for G-code rounding and trunk circle extent.)
            trunkRadius = nozzleDiameter * 3.0
            maxExpectedDist = trunkRadius + rootHeight + nozzleDiameter

            expect(maxDistFromTrunk).toBeLessThanOrEqual(maxExpectedDist + 0.01)

            # And the spread must be non-trivial (roots go outward).
            expect(maxDistFromTrunk).toBeGreaterThan(trunkRadius)

        test 'roots in everywhere mode should be suppressed when they would hang in mid-air', ->

            nozzleDiameter = 0.4
            layerHeight = 0.2

            # Simulate an 'everywhere' scenario where the trunk rests on a surface
            # but no solid geometry exists in any root direction at any sample distance.
            # The broadened ray-cast checks 0.5× to 2× rootHeight; a polygon that is
            # smaller than 0.5 × rootHeight (≈ 0.9 mm with these settings) leaves all
            # root rays in empty space — all roots should be treated as hanging.

            # Trunk centroid for region (0,0,10) - (2,2,10) is approximately (1,1).
            region = makeRegion(0, 2, 0, 2, 10)
            slicer = makeSlicer()

            # Build tree structure to discover effectiveBaseZ.
            treeSupport.generateTreePattern(
                slicer, region, layerHeight, 0,
                0, 0,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            effectiveBaseZ = region._effectiveTrunkBaseZ

            expect(effectiveBaseZ).toBeDefined()

            # Now simulate an 'everywhere' region2 where we provide fake solid regions.
            # The solid region only covers the trunk center — roots pointing outward hang.
            segments2 = treeSupport.buildTreeStructure(makeRegion(0, 2, 0, 2, 10), nozzleDiameter, 0, layerHeight)
            trunkSeg2 = segments2.find (s) -> s.type is 'trunk'
            trunkX2 = trunkSeg2.x1
            trunkY2 = trunkSeg2.y1

            # Compute rootHeight so tinyRadius can be derived from it.
            # tinyRadius must be < 0.5 × rootHeight (the first sample fraction) so that
            # no sample point in the broadened ray-cast lands inside the polygon.
            contactSpacing2 = nozzleDiameter * treeSupport.CONTACT_SPACING_MULTIPLIER
            trunkHeight2 = Math.abs(trunkSeg2.z2 - trunkSeg2.z1)
            rootSpread2 = Math.min(contactSpacing2 * treeSupport.BRANCH_CLUSTER_SIZE, trunkHeight2)
            rootHeight2 = rootSpread2 * 0.5
            tinyRadius = rootHeight2 * 0.4  # Smaller than 0.5 × rootHeight (first sample)
            smallPolygon = [
                { x: trunkX2 - tinyRadius, y: trunkY2 - tinyRadius }
                { x: trunkX2 + tinyRadius, y: trunkY2 - tinyRadius }
                { x: trunkX2 + tinyRadius, y: trunkY2 + tinyRadius }
                { x: trunkX2 - tinyRadius, y: trunkY2 + tinyRadius }
            ]

            fakeLayers = [
                { z: effectiveBaseZ - layerHeight, layerIndex: 0, paths: [smallPolygon], pathIsHole: [false] }
            ]

            region2 = makeRegion(0, 2, 0, 2, 10)
            slicer2 = makeSlicer()

            # With 'everywhere' mode and solid geometry only at the trunk center,
            # the broadened ray-cast finds no solid at any sample distance — all hang.
            # Use layerIndex=1 so the fake layer (layerIndex 0) is strictly below the
            # current layer, keeping canGenerateSupportAt from blocking the trunk.
            treeSupport.generateTreePattern(
                slicer2, region2, effectiveBaseZ, 1,
                0, 0,
                nozzleDiameter, fakeLayers,
                'everywhere', 0, layerHeight
            )

            # _validRootIndices should be empty: all roots hang with no surface to land on.
            expect(region2._validRootIndices).toBeDefined()
            expect(region2._validRootIndices.length).toBe(0)

        test 'roots in everywhere mode should be detected when solid is beyond the base point (broadened ray-cast)', ->

            nozzleDiameter = 0.4
            layerHeight = 0.2

            # Compute rootHeight the same way the implementation does.
            segments = treeSupport.buildTreeStructure(makeRegion(0, 2, 0, 2, 10), nozzleDiameter, 0, layerHeight)
            trunkSeg = segments.find (s) -> s.type is 'trunk'
            trunkX = trunkSeg.x1
            trunkY = trunkSeg.y1

            contactSpacing = nozzleDiameter * treeSupport.CONTACT_SPACING_MULTIPLIER
            trunkHeight = Math.abs(trunkSeg.z2 - trunkSeg.z1)
            rootSpread = Math.min(contactSpacing * treeSupport.BRANCH_CLUSTER_SIZE, trunkHeight)
            rootHeight = rootSpread * 0.5

            # First pass in buildPlate mode to discover effectiveBaseZ.
            region = makeRegion(0, 2, 0, 2, 10)
            slicer = makeSlicer()
            treeSupport.generateTreePattern(
                slicer, region, layerHeight, 0,
                0, 0,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )
            effectiveBaseZ = region._effectiveTrunkBaseZ
            expect(effectiveBaseZ).toBeDefined()

            # Build a large polygon that covers all sample distances (0.5× to 2× rootHeight)
            # in every direction. The key detail: the polygon is only in the layer BELOW
            # effectiveBaseZ (layerIndex 0), so at the current layer (index 1) the roots
            # are not embedded and canGenerateSupportAt allows them through.
            halfSize = rootHeight * 3
            largePolygon = [
                { x: trunkX - halfSize, y: trunkY - halfSize }
                { x: trunkX + halfSize, y: trunkY - halfSize }
                { x: trunkX + halfSize, y: trunkY + halfSize }
                { x: trunkX - halfSize, y: trunkY + halfSize }
            ]

            # Layer 0 (below effectiveBaseZ) is solid everywhere.
            # Layer 1 (current layer when we call generateTreePattern with layerIndex=1) is absent,
            # so layerSolidRegions[1] is undefined → roots are not embedded at current layer.
            fakeLayers = [
                { z: effectiveBaseZ - layerHeight, layerIndex: 0, paths: [largePolygon], pathIsHole: [false] }
            ]

            region2 = makeRegion(0, 2, 0, 2, 10)
            slicer2 = makeSlicer()

            # Call at effectiveBaseZ with layerIndex=1 so the large polygon is "below".
            treeSupport.generateTreePattern(
                slicer2, region2, effectiveBaseZ, 1,
                0, 0,
                nozzleDiameter, fakeLayers,
                'everywhere', 0, layerHeight
            )

            # All root directions have solid geometry at sample distances — none hang.
            expect(region2._validRootIndices).toBeDefined()
            expect(region2._validRootIndices.length).toBe(treeSupport.ROOT_COUNT)

    describe 'isTrunkAccessible', ->

        # Helper: build a simple square polygon path.
        makeSquarePath = (cx, cy, halfSize) ->
            [
                { x: cx - halfSize, y: cy - halfSize }
                { x: cx + halfSize, y: cy - halfSize }
                { x: cx + halfSize, y: cy + halfSize }
                { x: cx - halfSize, y: cy + halfSize }
            ]

        test 'should return true when no layerSolidRegions are provided', ->

            result = treeSupport.isTrunkAccessible(0, 0, [])

            expect(result).toBe(true)

        test 'should return true when the trunk position is outside all solid geometry', ->

            solidPath = makeSquarePath(10, 10, 3)
            layers = [
                { z: 0.2, layerIndex: 0, paths: [solidPath], pathIsHole: [false] }
                { z: 0.4, layerIndex: 1, paths: [solidPath], pathIsHole: [false] }
            ]

            # Point at origin is outside the solid square at (10,10).
            result = treeSupport.isTrunkAccessible(0, 0, layers)

            expect(result).toBe(true)

        test 'should return false when the trunk position is inside solid geometry at any layer', ->

            solidPath = makeSquarePath(0, 0, 5)
            layers = [
                { z: 0.2, layerIndex: 0, paths: [solidPath], pathIsHole: [false] }
                { z: 0.4, layerIndex: 1, paths: [solidPath], pathIsHole: [false] }
            ]

            # Point at origin is inside the solid square.
            result = treeSupport.isTrunkAccessible(0, 0, layers)

            expect(result).toBe(false)

        test 'should return false when blocked on only one of multiple layers', ->

            solidAtLowZ = makeSquarePath(0, 0, 5)
            emptyLayers = []

            layers = [
                { z: 0.2, layerIndex: 0, paths: [solidAtLowZ], pathIsHole: [false] }
                { z: 0.4, layerIndex: 1, paths: [], pathIsHole: [] }
            ]

            # Blocked at layer 0 but not at layer 1 — still not accessible.
            result = treeSupport.isTrunkAccessible(0, 0, layers)

            expect(result).toBe(false)

        test 'should return true when the trunk position is inside a hole (cavity)', ->

            # Outer boundary of a box.
            outerPath = makeSquarePath(0, 0, 10)

            # Inner hole path (cavity) — nested inside the outer path.
            innerHole = makeSquarePath(0, 0, 4)

            # The inner path is a hole (odd nesting level).
            layers = [
                { z: 0.2, layerIndex: 0, paths: [outerPath, innerHole], pathIsHole: [false, true] }
            ]

            # Point at origin is inside the hole — isPointInsideSolidGeometry uses
            # even-odd winding rule: contained by 2 paths → even → not solid.
            result = treeSupport.isTrunkAccessible(0, 0, layers)

            expect(result).toBe(true)

        test 'should return true when high-Z layers are blocked but maxZ excludes them', ->

            # Simulate upright arch: hollow at low Z (trunk lives here),
            # solid at high Z (arch cap above the overhang).
            # Without maxZ this incorrectly returns false; with maxZ it must return true.
            solidCapPath = makeSquarePath(0, 0, 5)
            layers = [
                { z: 0.2, layerIndex: 0, paths: [], pathIsHole: [] }
                { z: 0.4, layerIndex: 1, paths: [], pathIsHole: [] }
                { z: 14, layerIndex: 69, paths: [solidCapPath], pathIsHole: [false] }
                { z: 16, layerIndex: 79, paths: [solidCapPath], pathIsHole: [false] }
            ]

            # Without maxZ: returns false because arch cap at z=14,16 blocks it.
            expect(treeSupport.isTrunkAccessible(0, 0, layers)).toBe(false)

            # With maxZ = trunkTopZ = 8 (below the arch cap): returns true.
            expect(treeSupport.isTrunkAccessible(0, 0, layers, 8)).toBe(true)

    describe 'findAccessibleTrunkPosition', ->

        makeSquarePath = (cx, cy, halfSize) ->
            [
                { x: cx - halfSize, y: cy - halfSize }
                { x: cx + halfSize, y: cy - halfSize }
                { x: cx + halfSize, y: cy + halfSize }
                { x: cx - halfSize, y: cy + halfSize }
            ]

        test 'should return the centroid unchanged when it is already accessible', ->

            result = treeSupport.findAccessibleTrunkPosition(5, 5, [], 1.0, 20)

            expect(result).not.toBeNull()
            expect(result.x).toBeCloseTo(5, 5)
            expect(result.y).toBeCloseTo(5, 5)

        test 'should find an accessible position when the centroid is blocked', ->

            # Solid block covers (−5,−5) to (5,5) at all layers.
            solidPath = makeSquarePath(0, 0, 5)
            layers = [
                { z: 0.2, layerIndex: 0, paths: [solidPath], pathIsHole: [false] }
                { z: 0.4, layerIndex: 1, paths: [solidPath], pathIsHole: [false] }
            ]

            result = treeSupport.findAccessibleTrunkPosition(0, 0, layers, 1.0, 30)

            expect(result).not.toBeNull()

            # The found position must be accessible at all layers.
            expect(treeSupport.isTrunkAccessible(result.x, result.y, layers)).toBe(true)

        test 'should return null when no accessible position exists within maxSearchRadius', ->

            # Solid block covers everything within radius 100 (effectively infinite).
            solidPath = makeSquarePath(0, 0, 100)
            layers = [
                { z: 0.2, layerIndex: 0, paths: [solidPath], pathIsHole: [false] }
            ]

            result = treeSupport.findAccessibleTrunkPosition(0, 0, layers, 1.0, 10)

            expect(result).toBeNull()

        test 'accessible position should be near the centroid (minimum search radius)', ->

            # Solid block at (−3,−3) to (3,3).
            solidPath = makeSquarePath(0, 0, 3)
            layers = [
                { z: 0.2, layerIndex: 0, paths: [solidPath], pathIsHole: [false] }
            ]

            result = treeSupport.findAccessibleTrunkPosition(0, 0, layers, 1.0, 30)

            expect(result).not.toBeNull()

            # The position must be outside the solid block.
            dist = Math.sqrt(result.x * result.x + result.y * result.y)

            # Closest accessible point is just outside the square at radius ≥ 3mm.
            expect(dist).toBeGreaterThan(2.9)

        test 'should return centroid unchanged when only high-Z layers are blocked (maxZ filters them)', ->

            # Solid at high Z only — centroid is accessible when maxZ excludes those layers.
            solidHighPath = makeSquarePath(0, 0, 5)
            layers = [
                { z: 0.2, layerIndex: 0, paths: [], pathIsHole: [] }
                { z: 15,  layerIndex: 70, paths: [solidHighPath], pathIsHole: [false] }
            ]

            # With maxZ = 8 (below z=15), high-Z layers are ignored → centroid is accessible.
            result = treeSupport.findAccessibleTrunkPosition(0, 0, layers, 1.0, 30, 8)

            expect(result).not.toBeNull()
            expect(result.x).toBeCloseTo(0, 5)
            expect(result.y).toBeCloseTo(0, 5)

        test 'should prefer Y-preserving result (same Y as centroid) when blocked', ->

            # Solid block completely covers the centroid at (0, 0).
            # ±X positions at same Y=0 are accessible; ±Y positions at same X=0 are also accessible.
            # The search should find (r, 0) or (-r, 0) first (same Y as centroid).
            solidPath = makeSquarePath(0, 0, 3)
            layers = [
                { z: 0.2, layerIndex: 0, paths: [solidPath], pathIsHole: [false] }
            ]

            result = treeSupport.findAccessibleTrunkPosition(0, 0, layers, 1.0, 30)

            expect(result).not.toBeNull()

            # The result must be outside the solid block.
            expect(treeSupport.isTrunkAccessible(result.x, result.y, layers)).toBe(true)

            # Y should be preserved (same as centroid Y = 0) when ±X is accessible first.
            expect(result.y).toBeCloseTo(0, 5)

        test 'should apply clearance so trunk circle does not overlap solid walls', ->

            # Solid block covers (−4,−4) to (4,4) — completely surrounds the centroid (0,0).
            # Without clearance, the search finds the first accessible position just outside
            # the solid edge (e.g., at x≈5, y=0 for a step of 1).
            # With clearance=1.5 the result must be pushed further: the nearest clearance
            # boundary point (result.x − 1.5, 0) must also be outside the solid at x=4.
            solidPath = makeSquarePath(0, 0, 4)  # solid from (−4,−4) to (4,4)
            layers = [
                { z: 0.2, layerIndex: 0, paths: [solidPath], pathIsHole: [false] }
            ]

            clearance = 1.5

            # Without clearance: first accessible point is just outside the 4mm edge.
            resultNoClearance = treeSupport.findAccessibleTrunkPosition(0, 0, layers, 1.0, 20, Infinity, 0)

            expect(resultNoClearance).not.toBeNull()
            distNoClearance = Math.sqrt(resultNoClearance.x ** 2 + resultNoClearance.y ** 2)
            expect(distNoClearance).toBeGreaterThan(3.9)

            # With clearance=1.5: the result centre must be at least (4 + 1.5) = 5.5mm from
            # the search origin so that the nearest clearance boundary point is outside the
            # solid edge at 4mm.
            resultWithClearance = treeSupport.findAccessibleTrunkPosition(0, 0, layers, 1.0, 20, Infinity, clearance)

            expect(resultWithClearance).not.toBeNull()
            distWithClearance = Math.sqrt(resultWithClearance.x ** 2 + resultWithClearance.y ** 2)
            expect(distWithClearance).toBeGreaterThanOrEqual(4 + clearance - 0.1)

            # All four cardinal clearance boundary points must also be accessible.
            for angleIdx in [0...4]

                angle = angleIdx * Math.PI / 2
                cx = resultWithClearance.x + clearance * Math.cos(angle)
                cy = resultWithClearance.y + clearance * Math.sin(angle)
                expect(treeSupport.isTrunkAccessible(cx, cy, layers)).toBe(true)

            return

    describe 'buildTreeStructure with trunk override', ->

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

        test 'should place trunk at override XY when provided', ->

            region = makeRegion(-10, 10, -10, 10, 20)
            segments = treeSupport.buildTreeStructure(region, 0.4, 0, 0.2, 25, 30)

            trunkSeg = segments.find (s) -> s.type is 'trunk'

            expect(trunkSeg).toBeDefined()
            expect(trunkSeg.x1).toBeCloseTo(25, 5)
            expect(trunkSeg.y1).toBeCloseTo(30, 5)
            expect(trunkSeg.x2).toBeCloseTo(25, 5)
            expect(trunkSeg.y2).toBeCloseTo(30, 5)

        test 'should produce centroid trunk when no override is provided', ->

            region = makeRegion(-10, 10, -10, 10, 20)
            segments = treeSupport.buildTreeStructure(region, 0.4, 0, 0.2)

            trunkSeg = segments.find (s) -> s.type is 'trunk'

            expect(trunkSeg).toBeDefined()

            # Centroid of a region symmetric around origin should be near (0,0).
            expect(Math.abs(trunkSeg.x1)).toBeLessThan(1.5)
            expect(Math.abs(trunkSeg.y1)).toBeLessThan(1.5)

        test 'branch segments should angle from the override trunk position toward nodes', ->

            region = makeRegion(-10, 10, -10, 10, 20)
            overrideX = 30
            overrideY = 0
            segments = treeSupport.buildTreeStructure(region, 0.4, 0, 0.2, overrideX, overrideY)

            branchSegs = segments.filter (s) -> s.type is 'branch'

            expect(branchSegs.length).toBeGreaterThan(0)

            # Each branch must start at the override trunk XY.
            for seg in branchSegs

                expect(seg.x1).toBeCloseTo(overrideX, 5)
                expect(seg.y1).toBeCloseTo(overrideY, 5)

            return

    describe 'generateTreePattern with relocated trunk (buildPlate enhancement)', ->

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

        makeSlicer = ->

            slicer = new (require('../../../index'))({ progressCallback: null })
            slicer.gcode = ''
            slicer.cumulativeE = 0
            return slicer

        makeSquarePath = (cx, cy, halfSize) ->
            [
                { x: cx - halfSize, y: cy - halfSize }
                { x: cx + halfSize, y: cy - halfSize }
                { x: cx + halfSize, y: cy + halfSize }
                { x: cx - halfSize, y: cy + halfSize }
            ]

        test 'should generate support even when trunk centroid is blocked by solid geometry', ->

            nozzleDiameter = 0.4
            layerHeight = 0.2

            # Overhang region centered at (0,0) with Z=15.
            region = makeRegion(-5, 5, -5, 5, 15)

            # Solid block covers the trunk centroid area (−6,−6) to (6,6) at low layers.
            solidPath = makeSquarePath(0, 0, 6)
            layerSolidRegions = [
                { z: 0.2, layerIndex: 0, paths: [solidPath], pathIsHole: [false] }
                { z: 0.4, layerIndex: 1, paths: [solidPath], pathIsHole: [false] }
                { z: 0.6, layerIndex: 2, paths: [solidPath], pathIsHole: [false] }
            ]

            slicer = makeSlicer()

            # At a layer near the overhang, support should be generated despite blocked centroid.
            result = treeSupport.generateTreePattern(
                slicer, region, 14, 14,
                0, 0,
                nozzleDiameter, layerSolidRegions,
                'buildPlate', 0, layerHeight
            )

            expect(result).toBe(true)
            expect(slicer.gcode.length).toBeGreaterThan(0)

        test 'should relocate trunk outside the blocked region in buildPlate mode', ->

            nozzleDiameter = 0.4
            layerHeight = 0.2

            # Overhang region centered at (0,0).
            region = makeRegion(-4, 4, -4, 4, 20)

            # Solid block covers (−5,−5) to (5,5): completely surrounds the centroid.
            # Only at low layers (Z ≤ trunkTopZ area) — high layers are hollow.
            solidPath = makeSquarePath(0, 0, 5)
            layerSolidRegions = [
                { z: 0.2, layerIndex: 0, paths: [solidPath], pathIsHole: [false] }
            ]

            slicer = makeSlicer()

            treeSupport.generateTreePattern(
                slicer, region, layerHeight, 0,
                0, 0,
                nozzleDiameter, layerSolidRegions,
                'buildPlate', 0, layerHeight
            )

            # The rebuilt trunk should be outside the solid block.
            trunkSeg = region._treeSegments.find (s) -> s.type is 'trunk'

            expect(trunkSeg).toBeDefined()

            trunkX = trunkSeg.x1
            trunkY = trunkSeg.y1

            # Trunk must lie outside the solid region — with clearance of trunkRadius (1.2mm),
            # the trunk circle must not touch the solid edge at ±5mm.
            trunkClearance = nozzleDiameter * treeSupport.TRUNK_RADIUS_MULTIPLIER

            # Trunk centre must be at least (5 + clearance) away from the blocked centre.
            dist = Math.sqrt(trunkX * trunkX + trunkY * trunkY)

            expect(dist).toBeGreaterThanOrEqual(5 + trunkClearance - 0.1)

            # Trunk position must be accessible (not blocked at relevant layers).
            trunkTopZ = trunkSeg.z2
            expect(treeSupport.isTrunkAccessible(trunkX, trunkY, layerSolidRegions, trunkTopZ)).toBe(true)

        test 'upright arch: trunk centroid should NOT be relocated when only layers above trunkTopZ are solid', ->

            nozzleDiameter = 0.4
            layerHeight = 0.2

            # Overhang at Z=15 — centroid at (0,0).
            region = makeRegion(-5, 5, -5, 5, 15)

            # Hollow at low Z (trunk lives here); solid only above the overhang (arch cap).
            solidCapPath = makeSquarePath(0, 0, 5)
            layerSolidRegions = [
                { z: 0.2,  layerIndex: 0,  paths: [], pathIsHole: [] }
                { z: 0.4,  layerIndex: 1,  paths: [], pathIsHole: [] }
                { z: 16.2, layerIndex: 80, paths: [solidCapPath], pathIsHole: [false] }
                { z: 18.4, layerIndex: 91, paths: [solidCapPath], pathIsHole: [false] }
            ]

            slicer = makeSlicer()

            treeSupport.generateTreePattern(
                slicer, region, 14, 70,
                0, 0,
                nozzleDiameter, layerSolidRegions,
                'buildPlate', 0, layerHeight
            )

            trunkSeg = region._treeSegments.find (s) -> s.type is 'trunk'

            expect(trunkSeg).toBeDefined()

            # Trunk should remain at the centroid — arch cap layers are above trunkTopZ
            # and must NOT trigger relocation.
            expect(Math.abs(trunkSeg.x1)).toBeLessThan(1.5)
            expect(Math.abs(trunkSeg.y1)).toBeLessThan(1.5)

        test 'should generate support for branches in arch cavity even though lower layers were solid', ->

            nozzleDiameter = 0.4
            layerHeight = 0.2

            # Simulate a sideways arch scenario: the arch body is solid at low layers,
            # blocking the centroid.  At higher layers the arch cavity opens up so that
            # the cavity interior is no longer solid at those layer Z planes.
            # An accessible trunk (outside the arch body) can send branches into the cavity
            # at the layers where the cavity is open.  The relaxed current-layer check
            # (for branches in 'buildPlate' mode) must allow those branch cross-sections
            # through even though the same XY position was solid at lower layers.

            # Small overhang region centered at (0,0) at Z=10 — centroid will be (0,0).
            region = makeRegion(-0.5, 0.5, -0.5, 0.5, 10)

            # Low layers (indices 0-5, Z=0.2–1.2): solid block at (−5,−5)→(5,5).
            # This blocks the trunk centroid AND any branch path through the center.
            solidFull = makeSquarePath(0, 0, 5)
            layerSolidRegions = [0, 1, 2, 3, 4, 5].map (i) ->
                { z: (i + 1) * layerHeight, layerIndex: i, paths: [solidFull], pathIsHole: [false] }

            # High layers (>= index 6) have no solid — the arch cavity is fully open.

            slicer = makeSlicer()

            # Invoke at a layer deep in the branch zone (Z=7, layerIndex=35).
            # layerSolidRegions[35] is undefined, so the relaxed check returns true
            # and the branch cross-section inside the formerly-solid region is rendered.
            result = treeSupport.generateTreePattern(
                slicer, region, 7, 35,
                0, 0,
                nozzleDiameter, layerSolidRegions,
                'buildPlate', 0, layerHeight
            )

            # Support should be generated: the relocated trunk is accessible, and branches
            # can cross into the cavity region at this layer because the relaxed check
            # only evaluates the current layer (which has no solid geometry there).
            expect(result).toBe(true)
            expect(slicer.gcode.length).toBeGreaterThan(0)

        test 'without blocked centroid, behavior is identical to original (no regression)', ->

            nozzleDiameter = 0.4
            layerHeight = 0.2

            region1 = makeRegion(-10, 10, -10, 10, 20)
            region2 = makeRegion(-10, 10, -10, 10, 20)

            slicer1 = makeSlicer()
            slicer2 = makeSlicer()

            # No layerSolidRegions — centroid is accessible.
            treeSupport.generateTreePattern(
                slicer1, region1, 15, 75,
                0, 0,
                nozzleDiameter, [],
                'buildPlate', 0, layerHeight
            )

            # With fake layers where the trunk area is empty — should not trigger relocation.
            farSolid = makeSquarePath(100, 100, 2)
            farLayers = [
                { z: 0.2, layerIndex: 0, paths: [farSolid], pathIsHole: [false] }
            ]

            treeSupport.generateTreePattern(
                slicer2, region2, 15, 75,
                0, 0,
                nozzleDiameter, farLayers,
                'buildPlate', 0, layerHeight
            )

            # Both should produce equivalent trunk positions.
            trunk1 = region1._treeSegments.find (s) -> s.type is 'trunk'
            trunk2 = region2._treeSegments.find (s) -> s.type is 'trunk'

            expect(trunk1).toBeDefined()
            expect(trunk2).toBeDefined()
            expect(trunk2.x1).toBeCloseTo(trunk1.x1, 3)
            expect(trunk2.y1).toBeCloseTo(trunk1.y1, 3)
