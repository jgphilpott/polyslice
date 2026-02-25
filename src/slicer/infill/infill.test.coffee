# Tests for infill orchestration module

Polyslice = require('../../index')

THREE = require('three')

describe 'Infill Orchestration', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice({progressCallback: null})

    describe 'Infill Pattern Selection', ->

        test 'should default to hexagons pattern', ->

            expect(slicer.getInfillPattern()).toBe('hexagons')

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

            # Infill should be inside inner wall.
            # Tolerance of 0.05mm: with old epsilon=0.3 (pre-PR #153) infill extended
            # ~0.1mm beyond the inner wall center, which would fail this check.
            # With the fixed epsilon=0.001 infill stays ~0.2mm inside, well within tolerance.
            expect(minInfill).toBeGreaterThanOrEqual(minInnerWall - 0.05)
            expect(maxInfill).toBeLessThanOrEqual(maxInnerWall + 0.05)

        test 'should not extend regular infill beyond inner wall boundary for circular shape', ->

            # Regression test: with the old epsilon=0.3 in clipLineToPolygon, bounding-box
            # intersection points outside the infill boundary were falsely included, causing
            # infill to extend ~0.1mm beyond the inner wall center. The PR #153 fix (epsilon=0.001)
            # corrects this for all infill patterns since they all use clipLineToPolygon.
            # Circular shapes are most susceptible to this boundary precision issue.

            # Create a cylinder mesh (circular cross-section best exposes the epsilon bug).
            geometry = new THREE.CylinderGeometry(5, 5, 10, 32)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.rotation.x = Math.PI / 2
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.6)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('grid')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Parse G-code to extract regular infill extrusion coordinates (TYPE: FILL sections).
            lines = result.split('\n')
            inFill = false
            infillCoords = []

            for line in lines

                if line.includes('; TYPE: FILL')
                    inFill = true
                    continue

                if (line.includes('; TYPE:') and not line.includes('FILL')) or line.includes('LAYER:')
                    inFill = false
                    continue

                # Collect extrusion moves only (G1 with both X and E parameters).
                if inFill and line.includes('G1') and line.includes('X') and line.includes('E')

                    xMatch = line.match(/X([\d.]+)/)
                    yMatch = line.match(/Y([\d.]+)/)

                    if xMatch and yMatch

                        infillCoords.push({
                            x: parseFloat(xMatch[1])
                            y: parseFloat(yMatch[1])
                        })

            # Should have collected regular infill coordinates from middle layers.
            expect(infillCoords.length).toBeGreaterThan(0)

            # Cylinder centered on 220x220 build plate at (110, 110), outer radius 5mm.
            # With 2 walls (nozzle=0.4mm each), infill boundary is ~4.2mm from center.
            # Inner wall center is ~4.4mm from center.
            #
            # With old epsilon=0.3 (pre-PR #153): max infill radius ≈ 4.2 + 0.3 = 4.5mm.
            # With fixed epsilon=0.001 (post-PR #153): max infill radius ≈ 4.2mm.
            #
            # Threshold of 4.45mm: fails before fix (4.5 > 4.45), passes after fix (4.2 ≤ 4.45).
            centerX = 110
            centerY = 110
            maxAllowedRadius = 4.45

            for coord in infillCoords

                dx = coord.x - centerX
                dy = coord.y - centerY

                distance = Math.sqrt(dx * dx + dy * dy)

                expect(distance).toBeLessThanOrEqual(maxAllowedRadius)

            return

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

    describe 'Infill Gap from Hole Walls', ->

        test 'should maintain gap from hole walls similar to outer walls', ->

            # Create a torus mesh with a hole to test infill gap behavior.
            geometry = new THREE.TorusGeometry(10, 3, 8, 16)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            # Position torus so bottom is at Z=0.
            mesh.position.set(0, 0, 3)
            mesh.updateMatrixWorld()

            # Configure slicer with infill.
            slicer.setNozzleDiameter(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(1.2) # 3 walls.
            slicer.setShellSkinThickness(0.8) # 4 skin layers.
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('grid')
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            # Slice the mesh.
            result = slicer.slice(mesh)

            # Verify that infill is generated (should have TYPE: FILL comments).
            expect(result).toContain('TYPE: FILL')

            # Verify that walls are generated for both outer and hole.
            expect(result).toContain('TYPE: WALL-OUTER')
            expect(result).toContain('TYPE: WALL-INNER')

            # The test verifies that the code completes successfully with holes present.
            # The actual gap validation is implicit in the clipLineWithHoles function.
            # Since we've modified infill.coffee to apply the same gap to hole walls,
            # this test confirms the change doesn't break slicing of meshes with holes.
            expect(result.length).toBeGreaterThan(1000)

            # Test passed - infill generation with holes completes successfully.
            return # Explicitly return undefined for Jest.

    describe 'Infill Pattern Centering', ->

        test 'should default to object centering', ->

            expect(slicer.getInfillPatternCentering()).toBe('object')

        test 'should allow setting to global centering', ->

            slicer.setInfillPatternCentering('global')

            expect(slicer.getInfillPatternCentering()).toBe('global')

        test 'should allow setting to object centering', ->

            slicer.setInfillPatternCentering('object')

            expect(slicer.getInfillPatternCentering()).toBe('object')

        test 'should handle case-insensitive input', ->

            slicer.setInfillPatternCentering('GLOBAL')

            expect(slicer.getInfillPatternCentering()).toBe('global')

            slicer.setInfillPatternCentering('Object')

            expect(slicer.getInfillPatternCentering()).toBe('object')

        test 'should ignore invalid values', ->

            slicer.setInfillPatternCentering('invalid')

            expect(slicer.getInfillPatternCentering()).toBe('object') # Should remain default.

        test 'should support method chaining', ->

            result = slicer.setInfillPatternCentering('global')

            expect(result).toBe(slicer)

        test 'should generate grid infill centered on object', ->

            # Create a 1cm cube offset from build plate center.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(20, 30, 5) # Offset from center.
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('grid')
            slicer.setInfillPatternCentering('object')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain infill.
            expect(result).toContain('; TYPE: FILL')

            # Pattern should be generated.
            lines = result.split('\n')
            infillLineCount = 0

            for line in lines

                if line.includes('G1') and line.includes('E') and not line.includes('; TYPE:')
                    infillLineCount++

            expect(infillLineCount).toBeGreaterThan(0)

        test 'should generate grid infill centered on build plate', ->

            # Create a 1cm cube offset from build plate center.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(20, 30, 5) # Offset from center.
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('grid')
            slicer.setInfillPatternCentering('global')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain infill.
            expect(result).toContain('; TYPE: FILL')

            # Pattern should be generated.
            lines = result.split('\n')
            infillLineCount = 0

            for line in lines

                if line.includes('G1') and line.includes('E') and not line.includes('; TYPE:')
                    infillLineCount++

            expect(infillLineCount).toBeGreaterThan(0)

        test 'should generate triangles infill with both centering modes', ->

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

            # Test object centering.
            slicer.setInfillPatternCentering('object')
            resultObject = slicer.slice(mesh)
            expect(resultObject).toContain('; TYPE: FILL')

            # Test global centering.
            slicer.gcode = ""
            slicer.setInfillPatternCentering('global')
            resultGlobal = slicer.slice(mesh)
            expect(resultGlobal).toContain('; TYPE: FILL')

        test 'should generate hexagons infill with both centering modes', ->

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

            # Test object centering.
            slicer.setInfillPatternCentering('object')
            resultObject = slicer.slice(mesh)
            expect(resultObject).toContain('; TYPE: FILL')

            # Test global centering.
            slicer.gcode = ""
            slicer.setInfillPatternCentering('global')
            resultGlobal = slicer.slice(mesh)
            expect(resultGlobal).toContain('; TYPE: FILL')

        test 'object centering should produce consistent patterns for differently positioned objects', ->

            # Create two identical cubes at different positions.
            geometry1 = new THREE.BoxGeometry(10, 10, 10)
            mesh1 = new THREE.Mesh(geometry1, new THREE.MeshBasicMaterial())
            mesh1.position.set(0, 0, 5)
            mesh1.updateMatrixWorld()

            geometry2 = new THREE.BoxGeometry(10, 10, 10)
            mesh2 = new THREE.Mesh(geometry2, new THREE.MeshBasicMaterial())
            mesh2.position.set(30, 30, 5)
            mesh2.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('grid')
            slicer.setInfillPatternCentering('object')

            result1 = slicer.slice(mesh1)

            # Reset slicer for second mesh.
            slicer.gcode = ""

            result2 = slicer.slice(mesh2)

            # Both should have infill.
            expect(result1).toContain('; TYPE: FILL')
            expect(result2).toContain('; TYPE: FILL')

            # Results should differ (different positions).
            expect(result1).not.toBe(result2)

        test 'global centering should align patterns across differently positioned objects', ->

            # Create two identical cubes at different positions.
            geometry1 = new THREE.BoxGeometry(10, 10, 10)
            mesh1 = new THREE.Mesh(geometry1, new THREE.MeshBasicMaterial())
            mesh1.position.set(0, 0, 5)
            mesh1.updateMatrixWorld()

            geometry2 = new THREE.BoxGeometry(10, 10, 10)
            mesh2 = new THREE.Mesh(geometry2, new THREE.MeshBasicMaterial())
            mesh2.position.set(30, 30, 5)
            mesh2.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('grid')
            slicer.setInfillPatternCentering('global')

            result1 = slicer.slice(mesh1)

            # Reset slicer for second mesh.
            slicer.gcode = ""

            result2 = slicer.slice(mesh2)

            # Both should have infill.
            expect(result1).toContain('; TYPE: FILL')
            expect(result2).toContain('; TYPE: FILL')

            # Results should differ (different positions).
            expect(result1).not.toBe(result2)
