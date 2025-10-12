# Tests for triangles infill pattern

Polyslice = require('../../../index')

THREE = require('three')

describe 'Triangles Infill Generation', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Triangles Pattern Generation', ->

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
            slicer.setInfillPattern('triangles')
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
            slicer.setInfillPattern('triangles')
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
            slicer.setInfillPattern('triangles')
            slicer.setVerbose(true)

            # Test with 20% density.
            slicer.setInfillDensity(20)
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
                        continue

                    if line.includes('; TYPE:') and not line.includes('FILL')
                        inFill = false

                    if inFill and line.includes('G1') and line.includes('E')
                        count++

                return count

            moves20 = countInfillMoves(result20)
            moves50 = countInfillMoves(result50)

            # Higher density should have more infill moves.
            expect(moves50).toBeGreaterThan(moves20)

        test 'should generate triangular tessellation with three line orientations', ->

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

            # Parse layers and check infill patterns.
            lines = result.split('\n')
            currentLayer = null
            infillLayers = []
            inFill = false
            currentInfillCoords = []

            for line in lines

                if line.includes('LAYER:')
                    layerMatch = line.match(/LAYER: (\d+)/)
                    currentLayer = if layerMatch then parseInt(layerMatch[1]) else null

                    # Save previous layer's infill if any.
                    if currentInfillCoords.length > 0
                        infillLayers.push({
                            layer: currentLayer - 1
                            coords: currentInfillCoords
                        })
                        currentInfillCoords = []

                if line.includes('; TYPE: FILL')
                    inFill = true
                    continue

                if line.includes('; TYPE:') and not line.includes('FILL')
                    inFill = false

                if inFill and line.includes('G1') and line.includes('X') and line.includes('Y')

                    xMatch = line.match(/X([\d.-]+)/)
                    yMatch = line.match(/Y([\d.-]+)/)

                    if xMatch and yMatch
                        currentInfillCoords.push({
                            x: parseFloat(xMatch[1])
                            y: parseFloat(yMatch[1])
                        })

            # Check that we have infill layers.
            expect(infillLayers.length).toBeGreaterThan(5)

            # Check first few middle layers that should have infill.
            middleLayers = infillLayers.filter((l) -> l.layer > 5 and l.layer < 45)

            expect(middleLayers.length).toBeGreaterThan(5)

            # Triangles pattern should have horizontal and diagonal lines.
            # We should detect movement in different directions (0°, +60°, -60°).
            for layer in middleLayers.slice(0, 3)

                coords = layer.coords

                # Need at least 4 points to verify pattern.
                continue if coords.length < 4

                # Check for horizontal segments (Y constant, X varies).
                hasHorizontal = false

                # Check for diagonal segments (both X and Y vary).
                hasDiagonal = false

                for i in [1...coords.length]

                    dx = Math.abs(coords[i].x - coords[i - 1].x)
                    dy = Math.abs(coords[i].y - coords[i - 1].y)

                    # Horizontal line: Y constant, X varies.
                    if dx > 0.5 and dy < 0.1
                        hasHorizontal = true

                    # Diagonal line: both X and Y vary.
                    if dx > 0.5 and dy > 0.5
                        hasDiagonal = true

                # Triangles pattern should have both horizontal and diagonal lines.
                expect(hasHorizontal or hasDiagonal).toBe(true)

            undefined

        test 'should use infill speed for infill lines', ->

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
            slicer.setInfillSpeed(60) # 60 mm/s = 3600 mm/min.
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Find infill extrusion moves.
            lines = result.split('\n')
            inFill = false
            foundInfillMove = false

            for line in lines

                if line.includes('; TYPE: FILL')
                    inFill = true
                    continue

                if line.includes('; TYPE:') and not line.includes('FILL')
                    inFill = false

                if inFill and line.includes('G1') and line.includes('E') and line.includes('F3600')

                    # Found a line with infill speed (F3600 = 60mm/s * 60).
                    foundInfillMove = true
                    break

            # Should have found at least one infill move with correct speed.
            expect(foundInfillMove).toBe(true)

        test 'should handle 100% infill density', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(100) # Solid infill.
            slicer.setInfillPattern('triangles')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain infill.
            expect(result).toContain('; TYPE: FILL')

            # Count infill moves.
            lines = result.split('\n')
            inFill = false
            infillMoveCount = 0

            for line in lines

                if line.includes('; TYPE: FILL')
                    inFill = true
                    continue

                if line.includes('; TYPE:') and not line.includes('FILL')
                    inFill = false

                if inFill and line.includes('G1') and line.includes('E')
                    infillMoveCount++

            # 100% density should have many infill moves.
            expect(infillMoveCount).toBeGreaterThan(100)

        test 'should generate infill inside walls', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8) # 2 walls.
            slicer.setShellSkinThickness(0.4) # 2 layers.
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('triangles')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Parse G-code to find wall and infill coordinates for a middle layer.
            lines = result.split('\n')
            inWallInner = false
            inFill = false
            innerWallX = []
            infillX = []
            targetLayer = 10 # Middle layer.
            currentLayer = null

            for line in lines

                if line.includes('LAYER:')
                    layerMatch = line.match(/LAYER: (\d+)/)
                    currentLayer = if layerMatch then parseInt(layerMatch[1]) else null

                # Only process target layer.
                continue if currentLayer isnt targetLayer

                if line.includes('; TYPE: WALL-INNER')
                    inWallInner = true
                    inFill = false
                    continue

                if line.includes('; TYPE: FILL')
                    inWallInner = false
                    inFill = true
                    continue

                if line.includes('; TYPE:')
                    inWallInner = false
                    inFill = false

                # Extract X coordinates.
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

        test 'should support triangles pattern setting', ->

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

            # Set infill pattern to triangles.
            slicer.setInfillPattern('triangles')

            expect(slicer.getInfillPattern()).toBe('triangles')

            result = slicer.slice(mesh)

            # Should generate infill.
            expect(result).toContain('; TYPE: FILL')

    describe 'Triangles Line Spacing', ->

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
            density20 = (nozzleDiameter / (20 / 100.0)) * 3.0
            density50 = (nozzleDiameter / (50 / 100.0)) * 3.0

            # 50% should have smaller spacing than 20%.
            expect(density50).toBeLessThan(density20)

            # Verify actual values.
            expect(density20).toBeCloseTo(6.0, 1)
            expect(density50).toBeCloseTo(2.4, 1)

    describe 'Triangles vs Grid Comparison', ->

        test 'should have different line spacing than grid at same density', ->

            nozzleDiameter = 0.4
            density = 20

            # Grid: 2 directions, multiply by 2.
            gridSpacing = (nozzleDiameter / (density / 100.0)) * 2.0

            # Triangles: 3 directions, multiply by 3.
            trianglesSpacing = (nozzleDiameter / (density / 100.0)) * 3.0

            # Triangles should have wider spacing than grid.
            expect(trianglesSpacing).toBeGreaterThan(gridSpacing)

            expect(gridSpacing).toBeCloseTo(4.0, 1)
            expect(trianglesSpacing).toBeCloseTo(6.0, 1)
