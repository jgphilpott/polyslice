# Tests for cubic infill pattern

Polyslice = require('../../../index')

THREE = require('three')

describe 'Cubic Infill Generation', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Basic Cubic Infill Generation', ->

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
            slicer.setInfillPattern('cubic')
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
            slicer.setInfillPattern('cubic')
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
            slicer.setInfillPattern('cubic')
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

    describe 'Layer Pattern Rotation', ->

        test 'should rotate pattern across 3-layer cycle', ->

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
            slicer.setInfillPattern('cubic')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Parse layers and count infill moves per layer.
            lines = result.split('\n')
            currentLayer = null
            infillLayers = []
            inFill = false
            currentInfillMoveCount = 0

            for line in lines

                if line.includes('LAYER:')
                    layerMatch = line.match(/LAYER: (\d+)/)
                    newLayer = if layerMatch then parseInt(layerMatch[1]) else null

                    # Save previous layer's data if any.
                    if currentLayer? and currentInfillMoveCount > 0
                        infillLayers.push({
                            layer: currentLayer
                            moveCount: currentInfillMoveCount
                        })
                        currentInfillMoveCount = 0

                    currentLayer = newLayer
                    inFill = false

                if line.includes('; TYPE: FILL')
                    inFill = true
                    continue

                if line.includes('; TYPE:') and not line.includes('FILL')
                    inFill = false

                if inFill and line.includes('G1') and line.includes('E')
                    currentInfillMoveCount++

            # Check that we have infill layers.
            expect(infillLayers.length).toBeGreaterThan(10)

            # For cubic pattern, layer 0 in the cycle should have more moves
            # than layers 1 and 2 (because it has both +45° and -45° lines).
            middleLayers = infillLayers.filter((l) -> l.layer > 5 and l.layer < 45)

            expect(middleLayers.length).toBeGreaterThan(10)

            # Group by layer modulo 3.
            layer0Moves = []
            layer1Moves = []
            layer2Moves = []

            for layerData in middleLayers

                mod = layerData.layer % 3

                if mod is 0
                    layer0Moves.push(layerData.moveCount)
                else if mod is 1
                    layer1Moves.push(layerData.moveCount)
                else if mod is 2
                    layer2Moves.push(layerData.moveCount)

            # Calculate average moves for each orientation.
            avgLayer0 = layer0Moves.reduce((a, b) -> a + b) / layer0Moves.length if layer0Moves.length > 0
            avgLayer1 = layer1Moves.reduce((a, b) -> a + b) / layer1Moves.length if layer1Moves.length > 0
            avgLayer2 = layer2Moves.reduce((a, b) -> a + b) / layer2Moves.length if layer2Moves.length > 0

            # Layer 0 should have roughly double the moves of layers 1 and 2.
            # (because it has both diagonal directions).
            expect(avgLayer0).toBeGreaterThan(avgLayer1 * 1.5)
            expect(avgLayer0).toBeGreaterThan(avgLayer2 * 1.5)

            return # Explicitly return undefined for Jest.

        test 'should generate diagonal lines on all layer orientations', ->

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
            slicer.setInfillPattern('cubic')
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
                    newLayer = if layerMatch then parseInt(layerMatch[1]) else null

                    # Save previous layer's infill if any.
                    if currentLayer? and currentInfillCoords.length > 0
                        infillLayers.push({
                            layer: currentLayer
                            coords: currentInfillCoords
                        })
                        currentInfillCoords = []

                    currentLayer = newLayer
                    inFill = false

                if line.includes('; TYPE: FILL')
                    inFill = true
                    continue

                if line.includes('; TYPE:') and not line.includes('FILL')
                    inFill = false

                if inFill and line.includes('G1') and line.includes('X') and line.includes('Y')

                    xMatch = line.match(/X([\d.]+)/)
                    yMatch = line.match(/Y([\d.]+)/)

                    if xMatch and yMatch
                        currentInfillCoords.push({
                            x: parseFloat(xMatch[1])
                            y: parseFloat(yMatch[1])
                        })

            # Check that we have infill layers.
            expect(infillLayers.length).toBeGreaterThan(5)

            # Check middle layers that should have infill.
            middleLayers = infillLayers.filter((l) -> l.layer > 5 and l.layer < 45)

            expect(middleLayers.length).toBeGreaterThan(5)

            # Cubic pattern should have diagonal lines (both X and Y should vary).
            for layer in middleLayers.slice(0, 9) # Check first 9 layers (3 full cycles).

                coords = layer.coords

                # Need at least 4 points to verify diagonal pattern.
                continue if coords.length < 4

                # For diagonal lines, both X and Y should change.
                xVariance = 0
                yVariance = 0

                for i in [1...coords.length]
                    xVariance += Math.abs(coords[i].x - coords[i - 1].x)
                    yVariance += Math.abs(coords[i].y - coords[i - 1].y)

                # Both X and Y should have significant variance for diagonal lines.
                expect(xVariance).toBeGreaterThan(0)
                expect(yVariance).toBeGreaterThan(0)

            return # Explicitly return undefined for Jest.

    describe 'Speed and Performance', ->

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
            slicer.setInfillPattern('cubic')
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
            slicer.setInfillPattern('cubic')
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

    describe 'Boundary Handling', ->

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
            slicer.setInfillPattern('cubic')
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

                    match = line.match(/X([\d.]+)/)

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

        test 'should support cubic pattern setting', ->

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

            # Set infill pattern to cubic.
            slicer.setInfillPattern('cubic')

            expect(slicer.getInfillPattern()).toBe('cubic')

            result = slicer.slice(mesh)

            # Should generate infill.
            expect(result).toContain('; TYPE: FILL')

    describe 'Comparison with Grid Pattern', ->

        test 'should use less material than grid pattern at same density', ->

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
            slicer.setVerbose(true)

            # Test with grid pattern.
            slicer.setInfillPattern('grid')
            resultGrid = slicer.slice(mesh)

            # Test with cubic pattern.
            slicer.setInfillPattern('cubic')
            resultCubic = slicer.slice(mesh)

            # Count infill extrusion moves.
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

            movesGrid = countInfillMoves(resultGrid)
            movesCubic = countInfillMoves(resultCubic)

            # Cubic should use fewer moves than grid (more efficient 3D structure).
            # At 20% density, cubic typically uses about 30-40% less material.
            expect(movesCubic).toBeLessThan(movesGrid)
            expect(movesCubic).toBeGreaterThan(movesGrid * 0.5) # But not dramatically less.

            return # Explicitly return undefined for Jest.
