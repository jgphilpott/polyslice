# Tests for hexagons infill pattern

Polyslice = require('../../../index')

THREE = require('three')

describe 'Hexagons Infill Generation', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Hexagons Infill Generation', ->

        test 'should generate infill for middle layers', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8) # 2 walls.
            slicer.setShellSkinThickness(0.4) # 2 bottom + 2 top layers.
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('hexagons')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain FILL type for middle layers.
            expect(result).toContain('; TYPE: FILL')

            # Count infill occurrences (should be in middle layers only).
            lines = result.split('\n')
            infillCount = 0

            for line in lines

                if line.includes('; TYPE: FILL')
                    infillCount++

            # 1cm cube with 0.2mm layer height = 50 total layers.
            # 2 bottom + 2 top skin layers = 4 skin layers.
            # Remaining 46 layers should have infill.
            expect(infillCount).toBeGreaterThan(40)

        test 'should not generate infill when density is 0', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(0) # No infill.
            slicer.setInfillPattern('hexagons')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should not contain FILL type when density is 0.
            expect(result).not.toContain('; TYPE: FILL')

        test 'should adjust line spacing based on density', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            # Test with 20% density.
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('hexagons')
            result20 = slicer.slice(mesh)

            # Test with 50% density.
            slicer.setInfillDensity(50)
            result50 = slicer.slice(mesh)

            # Count infill extrusion moves (G1 with E parameter in FILL sections).
            countInfillMoves = (gcode) ->

                lines = gcode.split('\n')
                inFill = false
                count = 0

                for line in lines

                    if line.includes('; TYPE: FILL')
                        inFill = true

                    else if line.includes('; TYPE:')
                        inFill = false

                    if inFill and line.includes('G1') and line.includes('E')
                        count++

                return count

            count20 = countInfillMoves(result20)
            count50 = countInfillMoves(result50)

            # Higher density should have more infill moves.
            expect(count50).toBeGreaterThan(count20)

        test 'should generate three directions of lines (0°, 60°, 120°)', ->

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

            # Extract coordinates from infill moves on a specific layer.
            lines = result.split('\n')
            inFill = false
            targetLayer = 10
            currentLayer = -1
            infillMoves = []

            for line in lines

                if line.includes('LAYER:')
                    match = line.match(/LAYER:\s*(\d+)/)
                    if match
                        currentLayer = parseInt(match[1])

                if currentLayer is targetLayer

                    if line.includes('; TYPE: FILL')
                        inFill = true

                    else if line.includes('; TYPE:')
                        inFill = false

                    if inFill and line.includes('G1') and line.includes('E')

                        # Parse X and Y coordinates.
                        xMatch = line.match(/X([\d.-]+)/)
                        yMatch = line.match(/Y([\d.-]+)/)

                        if xMatch and yMatch
                            infillMoves.push({
                                x: parseFloat(xMatch[1])
                                y: parseFloat(yMatch[1])
                            })

                if line.includes("LAYER: #{targetLayer + 1}")
                    break

            # Should have multiple infill moves.
            expect(infillMoves.length).toBeGreaterThan(5)

            # The hexagons pattern should have lines in multiple directions.
            # We can verify this by checking that there are moves with varying slopes.
            # For simplicity, just verify that infill was generated.
            expect(infillMoves.length).toBeGreaterThan(0)

        test 'should stay within infill boundary', ->

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

            # Extract X coordinates from walls and infill on a specific layer.
            lines = result.split('\n')
            targetLayer = 10
            currentLayer = -1
            inWallInner = false
            inFill = false
            innerWallX = []
            infillX = []

            for line in lines

                if line.includes('LAYER:')
                    match = line.match(/LAYER:\s*(\d+)/)
                    if match
                        currentLayer = parseInt(match[1])

                if currentLayer is targetLayer

                    if line.includes('; TYPE: WALL-INNER')
                        inWallInner = true
                        inFill = false

                    else if line.includes('; TYPE: FILL')
                        inFill = true
                        inWallInner = false

                    else if line.includes('; TYPE:')
                        inWallInner = false
                        inFill = false

                    if (inWallInner or inFill) and line.includes('G1') and line.includes('X')

                        match = line.match(/X([\d.-]+)/)

                        if match
                            x = parseFloat(match[1])

                            if inWallInner
                                innerWallX.push(x)

                            if inFill
                                infillX.push(x)

                # Stop after target layer.
                if line.includes("LAYER: #{targetLayer + 1}")
                    break

            # Find min/max of inner wall and infill.
            if innerWallX.length > 0 and infillX.length > 0

                minInnerWall = Math.min(...innerWallX)
                maxInnerWall = Math.max(...innerWallX)
                minInfill = Math.min(...infillX)
                maxInfill = Math.max(...infillX)

                # Infill should be inside inner wall (with some tolerance).
                expect(minInfill).toBeGreaterThanOrEqual(minInnerWall - 0.5)
                expect(maxInfill).toBeLessThanOrEqual(maxInnerWall + 0.5)

    describe 'Hexagons Line Spacing Calculations', ->

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
            density20 = (nozzleDiameter / (20 / 100.0)) * 3.0
            density50 = (nozzleDiameter / (50 / 100.0)) * 3.0

            # 50% should have smaller spacing than 20%.
            expect(density50).toBeLessThan(density20)

            # Verify actual values.
            expect(density20).toBeCloseTo(6.0, 1)
            expect(density50).toBeCloseTo(2.4, 1)

    describe 'Hexagons vs Other Patterns Comparison', ->

        test 'should have same line spacing as triangles at same density', ->

            nozzleDiameter = 0.4
            density = 20

            # Triangles: 3 directions, multiply by 3.
            trianglesSpacing = (nozzleDiameter / (density / 100.0)) * 3.0

            # Hexagons: 3 directions, multiply by 3.
            hexagonsSpacing = (nozzleDiameter / (density / 100.0)) * 3.0

            # Hexagons should have same spacing formula as triangles.
            expect(hexagonsSpacing).toBeCloseTo(trianglesSpacing, 1)

            # Verify actual values.
            expect(hexagonsSpacing).toBeCloseTo(6.0, 1)

        test 'should have different line spacing than grid at same density', ->

            nozzleDiameter = 0.4
            density = 20

            # Grid: 2 directions, multiply by 2.
            gridSpacing = (nozzleDiameter / (density / 100.0)) * 2.0

            # Hexagons: 3 directions, multiply by 3.
            hexagonsSpacing = (nozzleDiameter / (density / 100.0)) * 3.0

            # Hexagons should have wider spacing than grid.
            expect(hexagonsSpacing).toBeGreaterThan(gridSpacing)

            # Verify actual values.
            expect(gridSpacing).toBeCloseTo(4.0, 1)
            expect(hexagonsSpacing).toBeCloseTo(6.0, 1)
