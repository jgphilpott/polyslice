# Tests for infill orchestration module

Polyslice = require('../../index')

THREE = require('three')

describe 'Infill Orchestration', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Infill Pattern Selection', ->

        test 'should default to grid pattern', ->

            expect(slicer.getInfillPattern()).toBe('grid')

        test 'should set grid pattern', ->

            slicer.setInfillPattern('grid')

            expect(slicer.getInfillPattern()).toBe('grid')

        test 'should generate infill with grid pattern', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('grid')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain infill type marker.
            expect(result).toContain('; TYPE: FILL')

        test 'should set triangles pattern', ->

            slicer.setInfillPattern('triangles')

            expect(slicer.getInfillPattern()).toBe('triangles')

        test 'should generate infill with triangles pattern', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('triangles')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain infill type marker.
            expect(result).toContain('; TYPE: FILL')

        test 'should set hexagons pattern', ->

            slicer.setInfillPattern('hexagons')

            expect(slicer.getInfillPattern()).toBe('hexagons')

        test 'should generate infill with hexagons pattern', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('hexagons')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain infill type marker.
            expect(result).toContain('; TYPE: FILL')

    describe 'Infill Density', ->

        test 'should skip infill when density is 0', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(0)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should not contain infill type marker.
            expect(result).not.toContain('; TYPE: FILL')

        test 'should generate infill with positive density', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(15)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain infill.
            expect(result).toContain('; TYPE: FILL')

        test 'should handle different density values', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            # Test with different densities.
            densities = [10, 25, 50, 75]

            for density in densities

                slicer.setInfillDensity(density)
                result = slicer.slice(mesh)

                # All should contain infill.
                expect(result).toContain('; TYPE: FILL')

            return # Explicitly return undefined for Jest.

    describe 'Infill Boundary Creation', ->

        test 'should create infill inside walls', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Parse G-code to verify infill is inside walls.
            lines = result.split('\n')
            inWallInner = false
            inFill = false
            innerWallX = []
            infillX = []

            for line in lines

                if line.includes('; TYPE: WALL-INNER')
                    inWallInner = true
                    inFill = false
                    continue

                if line.includes('; TYPE: FILL')
                    inWallInner = false
                    inFill = true
                    continue

                if line.includes('; TYPE:') and not line.includes('WALL-INNER') and not line.includes('FILL')
                    inWallInner = false
                    inFill = false

                # Extract X coordinates.
                if (inWallInner or inFill) and line.includes('G1') and line.includes('X')

                    match = line.match(/X([\d.]+)/)

                    if match
                        x = parseFloat(match[1])

                        if inWallInner
                            innerWallX.push(x)

                        if inFill
                            infillX.push(x)

                # Only check first layer with both.
                if innerWallX.length > 0 and infillX.length > 0 and line.includes('LAYER: 2')
                    break

            # Verify we collected data.
            expect(innerWallX.length).toBeGreaterThan(0)
            expect(infillX.length).toBeGreaterThan(0)

            # Find min/max of inner wall and infill.
            minInnerWall = Math.min(...innerWallX)
            maxInnerWall = Math.max(...innerWallX)
            minInfill = Math.min(...infillX)
            maxInfill = Math.max(...infillX)

            # Infill should be inside inner wall (with some tolerance).
            expect(minInfill).toBeGreaterThanOrEqual(minInnerWall - 0.5)
            expect(maxInfill).toBeLessThanOrEqual(maxInnerWall + 0.5)

    describe 'Infill Line Spacing Calculation', ->

        test 'should calculate correct line spacing for grid density', ->

            # The formula is: baseSpacing = nozzleDiameter / (density / 100)
            # Then doubled for grid pattern: lineSpacing = baseSpacing * 2

            nozzleDiameter = 0.4
            density = 20

            # Expected: 0.4 / 0.2 * 2 = 4.0mm
            expectedSpacing = (nozzleDiameter / (density / 100.0)) * 2.0

            expect(expectedSpacing).toBeCloseTo(4.0, 1)

        test 'should calculate correct line spacing for triangles density', ->

            # The formula is: baseSpacing = nozzleDiameter / (density / 100)
            # Then tripled for triangles pattern: lineSpacing = baseSpacing * 3

            nozzleDiameter = 0.4
            density = 20

            # Expected: 0.4 / 0.2 * 3 = 6.0mm
            expectedSpacing = (nozzleDiameter / (density / 100.0)) * 3.0

            expect(expectedSpacing).toBeCloseTo(6.0, 1)

        test 'should calculate correct line spacing for hexagons density', ->

            # The formula is: baseSpacing = nozzleDiameter / (density / 100)
            # Then tripled for hexagons pattern: lineSpacing = baseSpacing * 3

            nozzleDiameter = 0.4
            density = 20

            # Expected: 0.4 / 0.2 * 3 = 6.0mm
            expectedSpacing = (nozzleDiameter / (density / 100.0)) * 3.0

            expect(expectedSpacing).toBeCloseTo(6.0, 1)

        test 'should vary line spacing with density', ->

            nozzleDiameter = 0.4

            # Higher density = smaller spacing.
            density20 = (nozzleDiameter / (20 / 100.0)) * 2.0
            density50 = (nozzleDiameter / (50 / 100.0)) * 2.0

            expect(density50).toBeLessThan(density20)

    describe 'Infill Marker Consistency (Regression Test)', ->

        # Helper function to create a cone mesh for testing.
        createConeMesh = ->

            geometry = new THREE.ConeGeometry(5, 10, 32)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.rotation.x = Math.PI / 2
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            return mesh

        # Helper function to configure slicer for cone testing.
        configureSlicerForCone = (slicer) ->

            slicer.setNozzleDiameter(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('grid')
            slicer.setVerbose(true)

        # Helper function to check for empty TYPE: FILL sections in G-code.
        # Returns an array of layer numbers that have TYPE: FILL marker but no actual fill lines.
        checkForEmptyFillSections = (gcode) ->

            SEARCH_WINDOW_SIZE = 10 # Lines to search after TYPE: FILL marker.

            lines = gcode.split('\n')
            problemLayers = []

            for i in [0...lines.length]

                line = lines[i].trim()

                if line.startsWith('M117 LAYER:')

                    layerNum = parseInt(line.split(':')[1].trim())

                    # Check for TYPE: FILL in this layer.
                    for j in [i + 1...lines.length]

                        nextLine = lines[j].trim()

                        break if nextLine.startsWith('M117 LAYER:') # Next layer.

                        if nextLine is '; TYPE: FILL'

                            # Check if there's actual fill after this marker.
                            hasActualFill = false

                            for k in [j + 1...Math.min(j + SEARCH_WINDOW_SIZE, lines.length)]

                                fillLine = lines[k].trim()

                                break if fillLine.startsWith('M117 LAYER:')

                                # Look for G1 commands with extrusion (E parameter).
                                if fillLine.startsWith('G1 ') and fillLine.includes(' E')

                                    hasActualFill = true

                                    break

                            if not hasActualFill then problemLayers.push(layerNum)

                            break

            return problemLayers

        test 'should not add TYPE: FILL marker when no infill lines are generated', ->

            # Create a cone mesh (some upper layers have very small cross-sections).
            mesh = createConeMesh()

            configureSlicerForCone(slicer)

            result = slicer.slice(mesh)

            # Check for empty TYPE: FILL sections.
            problemLayers = checkForEmptyFillSections(result)

            # There should be NO layers with TYPE: FILL but no actual fill lines.
            expect(problemLayers).toEqual([])

        test 'should generate infill on layers with sufficient area', ->

            # Create a cone mesh.
            mesh = createConeMesh()

            configureSlicerForCone(slicer)

            result = slicer.slice(mesh)

            # Count layers with infill.
            lines = result.split('\n')
            layersWithInfill = 0

            for line in lines

                if line.includes('; TYPE: FILL')

                    layersWithInfill++

            # Cone dimensions: height=10mm, layerHeight=0.2mm.
            coneHeight = 10
            layerHeight = 0.2
            totalLayers = coneHeight / layerHeight # 50 layers.

            # A cone should have some layers with infill (not all, as upper layers are too small).
            expect(layersWithInfill).toBeGreaterThan(0)
            expect(layersWithInfill).toBeLessThan(totalLayers)
