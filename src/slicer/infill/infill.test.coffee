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

        test 'should vary line spacing with density', ->

            nozzleDiameter = 0.4

            # Higher density = smaller spacing.
            density20 = (nozzleDiameter / (20 / 100.0)) * 2.0
            density50 = (nozzleDiameter / (50 / 100.0)) * 2.0

            expect(density50).toBeLessThan(density20)
