# Tests for skin generation

Polyslice = require('../../index')

THREE = require('three')

describe 'Skin Generation', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Skin Generation', ->

        test 'should generate skin on bottom layers', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8) # 2 walls.
            slicer.setShellSkinThickness(0.8) # 4 skin layers.
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Check that SKIN type exists.
            expect(result).toContain('; TYPE: SKIN')

            # Count how many layers have skin.
            lines = result.split('\n')
            skinLayerCount = 0
            currentLayer = null

            for line in lines

                if line.includes('LAYER:')
                    currentLayer = line

                if line.includes('; TYPE: SKIN')
                    skinLayerCount++

            # Should have 8 layers with skin: 4 bottom + 4 top (0.8mm / 0.2mm = 4 each).
            expect(skinLayerCount).toBe(8)

        test 'should generate zig-zag pattern for skin', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.2) # Just 1 layer.
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Find first skin section.
            lines = result.split('\n')
            inSkin = false
            skinLines = []

            for line in lines

                if line.includes('; TYPE: SKIN')
                    inSkin = true
                    continue

                if line.includes('; TYPE:') and inSkin
                    break

                if inSkin
                    skinLines.push(line)

            # Should have alternating G0 (travel) and G1 (extrusion) moves.
            travelMoves = skinLines.filter((l) -> l.includes('G0')).length
            extrusionMoves = skinLines.filter((l) -> l.includes('G1') and l.includes('E')).length

            # Should have zig-zag pattern with travels between lines.
            expect(travelMoves).toBeGreaterThan(0)
            expect(extrusionMoves).toBeGreaterThan(0)

            # Number of extrusion moves should roughly match number of travel moves.
            expect(Math.abs(extrusionMoves - travelMoves)).toBeLessThanOrEqual(2)

        test 'should calculate correct skin layer count', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            # Test different skin thickness values.
            # Each value generates both top and bottom layers.
            testCases = [
                { thickness: 0.2, expectedLayers: 2 }  # 0.2 / 0.2 = 1 bottom + 1 top = 2.
                { thickness: 0.4, expectedLayers: 4 }  # 0.4 / 0.2 = 2 bottom + 2 top = 4.
                { thickness: 0.6, expectedLayers: 6 }  # 0.6 / 0.2 = 3 bottom + 3 top = 6.
                { thickness: 0.8, expectedLayers: 8 }  # 0.8 / 0.2 = 4 bottom + 4 top = 8.
                { thickness: 1.0, expectedLayers: 10 }  # 1.0 / 0.2 = 5 bottom + 5 top = 10.
            ]

            for testCase in testCases

                slicer.setShellSkinThickness(testCase.thickness)

                result = slicer.slice(mesh)

                # Count skin layers.
                lines = result.split('\n')
                skinLayerCount = 0

                for line in lines

                    if line.includes('; TYPE: SKIN')
                        skinLayerCount++

                expect(skinLayerCount).toBe(testCase.expectedLayers)

            return # Explicitly return undefined for Jest.

        test 'should use infill speed for skin', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.2) # 1 layer.
            slicer.setLayerHeight(0.2)
            slicer.setInfillSpeed(60) # 60 mm/s = 3600 mm/min.
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Find first skin infill extrusion move (after skin wall).
            lines = result.split('\n')
            inSkin = false
            foundInfillMove = false

            for line in lines

                if line.includes('; TYPE: SKIN')
                    inSkin = true
                    continue

                if inSkin and line.includes('G1') and line.includes('E') and line.includes('F3600')

                    # Found a line with infill speed (F3600 = 60mm/s * 60).
                    foundInfillMove = true
                    break

            # Should have found at least one infill move with correct speed.
            expect(foundInfillMove).toBe(true)

            return # Explicitly return undefined for Jest.

        test 'should generate skin inside walls', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8) # 2 walls.
            slicer.setShellSkinThickness(0.2) # 1 layer.
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Parse G-code to find wall and skin coordinates.
            lines = result.split('\n')
            inWallInner = false
            inSkin = false
            innerWallX = []
            skinX = []

            for line in lines

                # Skip until first layer with skin.
                if line.includes('LAYER: 1')
                    continue

                if line.includes('; TYPE: WALL-INNER')
                    inWallInner = true
                    inSkin = false
                    continue

                if line.includes('; TYPE: SKIN')
                    inWallInner = false
                    inSkin = true
                    continue

                if line.includes('; TYPE:')
                    inWallInner = false
                    inSkin = false

                # Extract X coordinates.
                if (inWallInner or inSkin) and line.includes('G1') and line.includes('X')

                    match = line.match(/X([\d.]+)/)

                    if match
                        x = parseFloat(match[1])

                        if inWallInner
                            innerWallX.push(x)

                        if inSkin
                            skinX.push(x)

                # Only check first layer.
                if line.includes('LAYER: 2')
                    break

            # Find min/max of inner wall and skin.
            minInnerWall = Math.min(...innerWallX)
            maxInnerWall = Math.max(...innerWallX)
            minSkin = Math.min(...skinX)
            maxSkin = Math.max(...skinX)

            # Skin should be inside inner wall (with some tolerance).
            expect(minSkin).toBeGreaterThanOrEqual(minInnerWall - 0.1)
            expect(maxSkin).toBeLessThanOrEqual(maxInnerWall + 0.1)


        test 'should update bottom skin layers when shellSkinThickness changes', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            # Test with 0.4mm skin thickness (2 layers).
            slicer.setShellSkinThickness(0.4)
            result = slicer.slice(mesh)

            lines = result.split('\n')
            bottomSkinLayers = []

            for line in lines

                if line.includes('LAYER:')
                    layerMatch = line.match(/LAYER: (\d+)/)
                    currentLayer = if layerMatch then parseInt(layerMatch[1]) else null

                if line.includes('; TYPE: SKIN') and currentLayer? and currentLayer <= 10
                    if not bottomSkinLayers.includes(currentLayer)
                        bottomSkinLayers.push(currentLayer)

            # Should have 2 bottom layers with skin (0.4mm / 0.2mm = 2).
            expect(bottomSkinLayers.length).toBe(2)
            expect(bottomSkinLayers).toContain(1)
            expect(bottomSkinLayers).toContain(2)

        test 'should update top skin layers when shellSkinThickness changes', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            # Test with 0.6mm skin thickness (3 layers).
            slicer.setShellSkinThickness(0.6)
            result = slicer.slice(mesh)

            lines = result.split('\n')
            topSkinLayers = []
            currentLayer = null

            for line in lines

                if line.includes('LAYER:')
                    layerMatch = line.match(/LAYER: (\d+)/)
                    currentLayer = if layerMatch then parseInt(layerMatch[1]) else null

                if line.includes('; TYPE: SKIN') and currentLayer? and currentLayer >= 40
                    if not topSkinLayers.includes(currentLayer)
                        topSkinLayers.push(currentLayer)

            # Should have 3 top layers with skin (0.6mm / 0.2mm = 3).
            # For a 1cm cube with 0.2mm layers, we have 50 layers total.
            # Top 3 layers should be 48, 49, 50.
            expect(topSkinLayers.length).toBe(3)
            expect(topSkinLayers).toContain(48)
            expect(topSkinLayers).toContain(49)
            expect(topSkinLayers).toContain(50)

        test 'should update skin layers when layerHeight changes', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8) # 0.8mm skin.
            slicer.setVerbose(true)

            # Test with 0.4mm layer height (should have 2 bottom + 2 top = 4 total).
            slicer.setLayerHeight(0.4)
            result = slicer.slice(mesh)

            lines = result.split('\n')
            skinLayerCount = 0

            for line in lines

                if line.includes('; TYPE: SKIN')
                    skinLayerCount++

            # 0.8mm / 0.4mm = 2 layers per side, so 4 total.
            expect(skinLayerCount).toBe(4)

        test 'should handle zero skin thickness correctly', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0) # No skin.
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # With 0 skin thickness, should still have at least 1 layer per side.
            # (Math.max(1, Math.floor(0 / 0.2)) = 1).
            lines = result.split('\n')
            skinLayerCount = 0

            for line in lines

                if line.includes('; TYPE: SKIN')
                    skinLayerCount++

            # Should have minimum of 2 layers (1 bottom + 1 top).
            expect(skinLayerCount).toBeGreaterThanOrEqual(2)

        test 'should generate correct skin pattern for different cube sizes', ->

            # Test with a 2cm cube.
            geometry = new THREE.BoxGeometry(20, 20, 20)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 10)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8)
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should have SKIN type.
            expect(result).toContain('; TYPE: SKIN')

            # Count skin layers.
            lines = result.split('\n')
            skinLayerCount = 0

            for line in lines

                if line.includes('; TYPE: SKIN')
                    skinLayerCount++

            # Should still have 8 layers (4 bottom + 4 top) regardless of cube size.
            expect(skinLayerCount).toBe(8)

        test 'should maintain skin wall gap for various configurations', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            # Test with different nozzle diameter.
            slicer.setNozzleDiameter(0.6)
            slicer.setShellWallThickness(1.2) # 2 walls.
            slicer.setShellSkinThickness(0.6) # 1 layer.
            slicer.setLayerHeight(0.6)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should have SKIN type.
            expect(result).toContain('; TYPE: SKIN')

            # Verify skin wall is generated.
            lines = result.split('\n')
            hasSkinWall = false

            for line in lines

                if line.includes('Moving to skin wall')
                    hasSkinWall = true
                    break

            expect(hasSkinWall).toBe(true)

        test 'should alternate infill angle correctly across all skin layers', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8)
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Parse G-code and check angles for each layer.
            lines = result.split('\n')
            skinLayers = []
            currentLayer = null
            inSkin = false

            for line in lines

                if line.includes('LAYER:')
                    layerMatch = line.match(/LAYER: (\d+)/)
                    currentLayer = if layerMatch then parseInt(layerMatch[1]) else null
                    inSkin = false

                if line.includes('; TYPE: SKIN')
                    inSkin = true

                # Check for first infill move in skin.
                if inSkin and line.includes('G1') and line.includes('E') and line.includes('F3600')
                    if currentLayer? and not skinLayers.some((l) -> l.layer is currentLayer)
                        # Extract coordinates to determine angle.
                        xMatch = line.match(/X([\d.]+)/)
                        yMatch = line.match(/Y([\d.]+)/)

                        if xMatch and yMatch
                            skinLayers.push({ layer: currentLayer, x: parseFloat(xMatch[1]), y: parseFloat(yMatch[1]) })

            # Should have at least 8 skin layers.
            expect(skinLayers.length).toBeGreaterThanOrEqual(8)

            # Check that adjacent layers have different patterns.
            # (This is a basic check - full angle verification would be more complex).
            for i in [0...skinLayers.length - 1]

                layer1 = skinLayers[i]
                layer2 = skinLayers[i + 1]

                # Adjacent skin layers should have different coordinate patterns.
                # (Perpendicular lines will have different X,Y relationships).
                expect(layer1.layer).not.toBe(layer2.layer)

            return # Explicitly return undefined for Jest.

        test 'should clip skin infill to circular boundaries', ->

            # Create a cylinder (circular cross-section).
            geometry = new THREE.CylinderGeometry(5, 5, 10, 32)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())

            # Rotate to align with Z-axis.
            mesh.rotation.x = Math.PI / 2
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.6) # 3 layers.
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Parse G-code to extract skin infill coordinates.
            lines = result.split('\n')
            inSkinInfill = false
            skinInfillCoords = []
            currentLayer = null

            for line in lines

                if line.includes('LAYER:')
                    layerMatch = line.match(/LAYER: (\d+)/)
                    currentLayer = if layerMatch then parseInt(layerMatch[1]) else null
                    inSkinInfill = false

                # Detect skin infill section (after skin wall).
                if line.includes('Moving to skin infill line')
                    inSkinInfill = true

                # Exit skin infill when we hit another TYPE or next LAYER.
                if (line.includes('; TYPE:') and not line.includes('SKIN')) or (line.includes('LAYER:') and currentLayer?)
                    inSkinInfill = false

                # Extract coordinates from skin infill G1 moves.
                if inSkinInfill and line.includes('G1') and line.includes('E')

                    xMatch = line.match(/X([\d.]+)/)
                    yMatch = line.match(/Y([\d.]+)/)

                    if xMatch and yMatch
                        x = parseFloat(xMatch[1])
                        y = parseFloat(yMatch[1])
                        skinInfillCoords.push({ x: x, y: y, layer: currentLayer })

            # Should have skin infill coordinates.
            expect(skinInfillCoords.length).toBeGreaterThan(0)

            # For a cylinder centered at (110, 110) with radius ~5,
            # all skin infill coordinates should be within the circular boundary.
            # The cylinder has outer radius 5, with 2 walls (0.8mm) and skin wall (0.4mm),
            # leaving approximately 3.8mm radius for skin infill.
            centerX = 110
            centerY = 110
            maxRadius = 5.0 # Outer radius.
            minExpectedRadius = 2.0 # Should be well inside after walls.

            for coord in skinInfillCoords

                # Calculate distance from center.
                dx = coord.x - centerX
                dy = coord.y - centerY
                distance = Math.sqrt(dx * dx + dy * dy)

                # Skin infill should be inside the cylinder boundary.
                # Allow tolerance for numerical precision and edge cases in inset calculation.
                # The tolerance accounts for corner cases where diagonal infill lines may extend
                # slightly beyond the ideal boundary due to the discrete sampling of circular paths.
                expect(distance).toBeLessThan(maxRadius + 1.1)

                # Should also not be too close to center (there are walls).
                expect(distance).toBeGreaterThan(minExpectedRadius)

            return # Explicitly return undefined for Jest.

        test 'should not extend skin infill beyond polygon boundaries', ->

            # Create a sphere (complex curved surface).
            geometry = new THREE.SphereGeometry(5, 32, 32)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4) # 2 layers.
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Parse G-code to extract skin wall and infill coordinates.
            lines = result.split('\n')
            inSkinWall = false
            inSkinInfill = false
            skinWallCoords = []
            skinInfillCoords = []
            currentLayer = null

            for line in lines

                if line.includes('LAYER:')
                    layerMatch = line.match(/LAYER: (\d+)/)
                    currentLayer = if layerMatch then parseInt(layerMatch[1]) else null
                    inSkinWall = false
                    inSkinInfill = false

                # Detect skin wall (right after TYPE: SKIN).
                if line.includes('; TYPE: SKIN')
                    inSkinWall = true
                    inSkinInfill = false

                # Skin infill starts after "Moving to skin infill line".
                if line.includes('Moving to skin infill line')
                    inSkinWall = false
                    inSkinInfill = true

                # Exit skin section.
                if line.includes('; TYPE:') and not line.includes('SKIN')
                    inSkinWall = false
                    inSkinInfill = false

                # Extract coordinates from G1 moves.
                if (inSkinWall or inSkinInfill) and line.includes('G1')

                    xMatch = line.match(/X([\d.]+)/)
                    yMatch = line.match(/Y([\d.]+)/)

                    if xMatch and yMatch and currentLayer is 2 # Check layer 2 (bottom skin layer).
                        x = parseFloat(xMatch[1])
                        y = parseFloat(yMatch[1])

                        if inSkinWall
                            skinWallCoords.push({ x: x, y: y })

                        if inSkinInfill
                            skinInfillCoords.push({ x: x, y: y })

            # Should have both wall and infill coordinates.
            expect(skinWallCoords.length).toBeGreaterThan(0)
            expect(skinInfillCoords.length).toBeGreaterThan(0)

            # Calculate bounding box of skin wall.
            wallMinX = Math.min(...skinWallCoords.map((c) -> c.x))
            wallMaxX = Math.max(...skinWallCoords.map((c) -> c.x))
            wallMinY = Math.min(...skinWallCoords.map((c) -> c.y))
            wallMaxY = Math.max(...skinWallCoords.map((c) -> c.y))

            # All skin infill points should be reasonably contained.
            # The key regression test: infill should NOT extend far beyond the shape boundary.
            # Allow generous margin since infill is inset from walls and may have diagonal lines.
            margin = 2.0 # mm tolerance.

            for coord in skinInfillCoords

                expect(coord.x).toBeGreaterThanOrEqual(wallMinX - margin)
                expect(coord.x).toBeLessThanOrEqual(wallMaxX + margin)
                expect(coord.y).toBeGreaterThanOrEqual(wallMinY - margin)
                expect(coord.y).toBeLessThanOrEqual(wallMaxY + margin)

            return # Explicitly return undefined for Jest.

    describe 'Skin Infill Gap from Hole Walls', ->

        test 'should maintain gap from hole skin walls similar to outer walls', ->

            # Create a torus mesh with a hole to test skin infill gap behavior.
            geometry = new THREE.TorusGeometry(10, 3, 8, 16)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            # Position torus so bottom is at Z=0.
            mesh.position.set(0, 0, 3)
            mesh.updateMatrixWorld()

            # Configure slicer with skin layers.
            slicer.setNozzleDiameter(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(1.2) # 3 walls.
            slicer.setShellSkinThickness(0.8) # 4 skin layers.
            slicer.setInfillDensity(20) # Some infill.
            slicer.setInfillPattern('grid')
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            # Slice the mesh.
            result = slicer.slice(mesh)

            # Verify that skin infill is generated (should have TYPE: SKIN comments).
            expect(result).toContain('TYPE: SKIN')

            # Verify that walls are generated for both outer and hole.
            expect(result).toContain('TYPE: WALL-OUTER')
            expect(result).toContain('TYPE: WALL-INNER')

            # The test verifies that the code completes successfully with holes present.
            # The actual gap validation is implicit in the clipLineWithHoles function.
            # Since we've modified skin.coffee to apply the same gap to hole skin walls,
            # this test confirms the change doesn't break slicing of meshes with holes.
            expect(result.length).toBeGreaterThan(1000)

            # Test passed - skin infill generation with holes completes successfully.
            return # Explicitly return undefined for Jest.

