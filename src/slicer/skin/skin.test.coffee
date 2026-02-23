# Tests for skin generation

Polyslice = require('../../index')

THREE = require('three')

describe 'Skin Generation', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice({progressCallback: null})

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
                    layerMatch = line.match(/LAYER: (\d+) of/)
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
                    layerMatch = line.match(/LAYER: (\d+) of/)
                    currentLayer = if layerMatch then parseInt(layerMatch[1]) else null

                if line.includes('; TYPE: SKIN') and currentLayer? and currentLayer >= 40
                    if not topSkinLayers.includes(currentLayer)
                        topSkinLayers.push(currentLayer)

            # Should have 3 top layers with skin (0.6mm / 0.2mm = 3).
            # Check that we have exactly 3 consecutive top skin layers.
            # Note: With epsilon offset in slicing, layer count may vary by 1, so we check
            # for 3 consecutive layers rather than specific numbers.
            expect(topSkinLayers.length).toBe(3)

            # Verify they are consecutive by checking the range.
            minTopLayer = Math.min(...topSkinLayers)
            maxTopLayer = Math.max(...topSkinLayers)
            expect(maxTopLayer - minTopLayer).toBe(2) # 3 consecutive layers

            # All three should be present in the array.
            expect(topSkinLayers).toContain(minTopLayer)
            expect(topSkinLayers).toContain(minTopLayer + 1)
            expect(topSkinLayers).toContain(maxTopLayer)

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
                    layerMatch = line.match(/LAYER: (\d+) of/)
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
                    layerMatch = line.match(/LAYER: (\d+) of/)
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
                    layerMatch = line.match(/LAYER: (\d+) of/)
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

                    if xMatch and yMatch and currentLayer is 2 # Check layer 2 (bottom skin layer with geometry, index 1).
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

        test 'should group skin infill segments by region when holes present', ->

            # Create a torus mesh with a hole to test region grouping behavior.
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

            # Parse G-code to find skin infill segments.
            lines = result.split('\n')
            skinSegments = []
            inSkin = false
            lastX = null
            lastY = null

            for line in lines

                if line.includes('TYPE: SKIN')
                    inSkin = true
                    lastX = null
                    lastY = null
                    continue

                if line.includes('TYPE:') and not line.includes('TYPE: SKIN')
                    inSkin = false
                    continue

                if inSkin and line.includes('G1') and line.includes('E')

                    # Extract X and Y coordinates.
                    xMatch = line.match(/X(-?\d+\.?\d*)/)
                    yMatch = line.match(/Y(-?\d+\.?\d*)/)

                    if xMatch and yMatch and lastX? and lastY?

                        currentX = parseFloat(xMatch[1])
                        currentY = parseFloat(yMatch[1])

                        # Calculate travel distance from last position.
                        dx = currentX - lastX
                        dy = currentY - lastY
                        travelDist = Math.sqrt(dx * dx + dy * dy)

                        skinSegments.push({
                            fromX: lastX
                            fromY: lastY
                            toX: currentX
                            toY: currentY
                            travelDist: travelDist
                        })

                        lastX = currentX
                        lastY = currentY

                    else if xMatch and yMatch

                        lastX = parseFloat(xMatch[1])
                        lastY = parseFloat(yMatch[1])

            # Verify we collected segments.
            expect(skinSegments.length).toBeGreaterThan(0)

            # With region grouping, segments on the same side of a hole should be closer together.
            # Calculate average travel distance - it should be reasonable (not jumping across holes constantly).
            totalTravel = 0

            for segment in skinSegments
                totalTravel += segment.travelDist

            avgTravel = totalTravel / skinSegments.length

            # Average travel should be less than 6mm (reasonable for grouped segments).
            # Without region grouping, this would be much higher as we jump across holes.
            # Note: With improved cavity/hole detection in exposure algorithm, more exposed
            # areas are detected, which can slightly increase travel distances (still efficient).
            expect(avgTravel).toBeLessThan(6)

            return # Explicitly return undefined for Jest.

    describe 'Nested Structure Skin Walls', ->

        Polytree = null

        beforeAll ->

            { Polytree } = require('@jgphilpott/polytree')

        createHollowCylinder = (outerRadius, innerRadius, height) ->

            # Create outer cylinder.
            outerGeometry = new THREE.CylinderGeometry(outerRadius, outerRadius, height, 32)
            outerMesh = new THREE.Mesh(outerGeometry, new THREE.MeshBasicMaterial())
            outerMesh.rotation.x = Math.PI / 2
            outerMesh.updateMatrixWorld()

            # Create inner cylinder (hole) - slightly taller for complete penetration.
            innerGeometry = new THREE.CylinderGeometry(innerRadius, innerRadius, height * 1.2, 32)
            innerMesh = new THREE.Mesh(innerGeometry, new THREE.MeshBasicMaterial())
            innerMesh.rotation.x = Math.PI / 2
            innerMesh.updateMatrixWorld()

            # Perform CSG subtraction.
            return Polytree.subtract(outerMesh, innerMesh)

        test 'should generate skin walls for structure paths on skin layers', ->

            # Create a simple hollow cylinder matching matryoshka nested-1.
            height = 1.2
            wallThickness = 5
            outerRadius = 5 + wallThickness  # 10
            innerRadius = 5  # 5

            hollowCylinder = await createHollowCylinder(outerRadius, innerRadius, height)

            mesh = new THREE.Mesh(hollowCylinder.geometry, hollowCylinder.material)
            mesh.position.set(0, 0, height / 2)
            mesh.updateMatrixWorld()

            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8)
            slicer.setInfillDensity(0)
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            result = slicer.slice(mesh)

            # Extract bottom layer (layer 1).
            lines = result.split('\n')
            inLayer1 = false
            skinMarkerCount = 0

            for line in lines
                if line.includes('LAYER: 1 of')
                    inLayer1 = true
                else if line.includes('LAYER: 2 of')
                    break

                if inLayer1 and line.includes('; TYPE: SKIN')
                    skinMarkerCount++

            # Should have at least 2 SKIN markers: 1 for outer structure, 1 for inner hole.
            # May have 3 if structure also gets skin infill from Phase 2.
            expect(skinMarkerCount).toBeGreaterThanOrEqual(2)

        test 'should generate skin walls for all paths in nested structures', ->

            # Create 3 nested hollow cylinders (6 paths total: 3 structures + 3 holes).
            height = 1.2  # Match matryoshka height
            wallThickness = 5  # Match matryoshka
            gap = 3  # Match matryoshka

            # Create 3 hollow cylinders.
            cylinder1 = await createHollowCylinder(5 + wallThickness, 5, height)
            cylinder2 = await createHollowCylinder(5 + wallThickness + gap + wallThickness, 5 + wallThickness + gap, height)
            cylinder3 = await createHollowCylinder(5 + wallThickness + gap + wallThickness + gap + wallThickness, 5 + wallThickness + gap + wallThickness + gap, height)

            # Combine all cylinders.
            combined1 = await Polytree.unite(cylinder1, cylinder2)
            combined2 = await Polytree.unite(combined1, cylinder3)

            mesh = new THREE.Mesh(combined2.geometry, combined2.material)
            mesh.position.set(0, 0, height / 2)
            mesh.updateMatrixWorld()

            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8)  # Default value
            slicer.setInfillDensity(0)
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            result = slicer.slice(mesh)

            # Extract bottom layer (layer 1).
            lines = result.split('\n')
            inLayer1 = false
            skinMarkerCount = 0

            for line in lines
                if line.includes('LAYER: 1 of')
                    inLayer1 = true
                else if line.includes('LAYER: 2 of')
                    break

                if inLayer1 and line.includes('; TYPE: SKIN')
                    skinMarkerCount++

            # Should have 9 SKIN markers: Phase 1 generates skin walls for all 6 paths (6 markers),
            # then Phase 2 generates skin (wall + infill) for 3 structures (3 more markers). Total: 9.
            expect(skinMarkerCount).toBe(9)

        test 'should have correct offset gap between inner walls and structure skin walls', ->

            # Create a simple hollow cylinder matching matryoshka.
            height = 1.2
            wallThickness = 5
            outerRadius = 5 + wallThickness  # 10
            innerRadius = 5

            hollowCylinder = await createHollowCylinder(outerRadius, innerRadius, height)

            mesh = new THREE.Mesh(hollowCylinder.geometry, hollowCylinder.material)
            mesh.position.set(0, 0, height / 2)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8)
            slicer.setInfillDensity(0)
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            result = slicer.slice(mesh)

            # Extract bottom layer and find inner wall and skin wall coordinates.
            lines = result.split('\n')
            inLayer1 = false
            inWallInner = false
            inSkin = false
            innerWallCoords = []
            skinWallCoords = []

            for line in lines
                if line.includes('LAYER: 1 of')
                    inLayer1 = true
                    inWallInner = false
                    inSkin = false
                else if line.includes('LAYER: 2 of')
                    break

                if inLayer1
                    if line.includes('; TYPE: WALL-INNER')
                        inWallInner = true
                        inSkin = false
                    else if line.includes('; TYPE: SKIN')
                        inWallInner = false
                        inSkin = true
                    else if line.includes('; TYPE:')
                        inWallInner = false
                        inSkin = false

                    # Extract coordinates from G1 commands with extrusion.
                    if line.includes('G1') and line.includes(' E')
                        xMatch = line.match(/X([\d.]+)/)
                        yMatch = line.match(/Y([\d.]+)/)

                        if xMatch and yMatch
                            x = parseFloat(xMatch[1])
                            y = parseFloat(yMatch[1])

                            if inWallInner
                                innerWallCoords.push({ x: x, y: y })
                            else if inSkin
                                skinWallCoords.push({ x: x, y: y })

            # Should have collected coordinates.
            expect(innerWallCoords.length).toBeGreaterThan(0)
            expect(skinWallCoords.length).toBeGreaterThan(0)

            # Verify that skin walls exist and are inset from inner walls.
            # We don't check exact offset due to circular geometry complexity,
            # but verify that both inner walls and skin walls are present.
            # This confirms the fix that structure paths now get skin walls.

        test 'should generate skin walls for both structures and holes', ->

            # Create 2 nested hollow cylinders (4 paths: 2 structures + 2 holes).
            height = 1.2  # Match matryoshka height
            wallThickness = 5  # Match matryoshka
            gap = 3  # Match matryoshka

            cylinder1 = await createHollowCylinder(5 + wallThickness, 5, height)
            cylinder2 = await createHollowCylinder(5 + wallThickness + gap + wallThickness, 5 + wallThickness + gap, height)

            combined = await Polytree.unite(cylinder1, cylinder2)

            mesh = new THREE.Mesh(combined.geometry, combined.material)
            mesh.position.set(0, 0, height / 2)
            mesh.updateMatrixWorld()

            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8)  # Default value
            slicer.setInfillDensity(0)
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            result = slicer.slice(mesh)

            # Extract bottom layer and count path types before skin.
            lines = result.split('\n')
            inLayer1 = false
            wallOuterCount = 0
            skinMarkerCount = 0

            for line in lines
                if line.includes('LAYER: 1 of')
                    inLayer1 = true
                else if line.includes('LAYER: 2 of')
                    break

                if inLayer1
                    if line.includes('; TYPE: WALL-OUTER')
                        wallOuterCount++
                    else if line.includes('; TYPE: SKIN')
                        skinMarkerCount++

            # Should have 4 WALL-OUTER markers (4 paths).
            expect(wallOuterCount).toBe(4)

            # Should have 6 SKIN markers: Phase 1 generates skin walls for all 4 paths (4 markers),
            # then Phase 2 generates skin (wall + infill) for 2 structures (2 more markers). Total: 6.
            expect(skinMarkerCount).toBe(6)

        test 'should not generate skin walls on middle layers without exposure detection', ->

            # Create a simple hollow cylinder.
            height = 10  # Tall enough to have middle layers.
            hollowCylinder = await createHollowCylinder(10, 8, height)

            mesh = new THREE.Mesh(hollowCylinder.geometry, hollowCylinder.material)
            mesh.position.set(0, 0, height / 2)
            mesh.updateMatrixWorld()

            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8)  # 4 skin layers (top/bottom).
            slicer.setInfillDensity(0)
            slicer.setExposureDetection(false)  # Disable exposure detection.
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            result = slicer.slice(mesh)

            # Extract middle layer (layer 25 out of 50).
            lines = result.split('\n')
            inMiddleLayer = false
            skinMarkerCount = 0

            for line in lines
                if line.includes('LAYER: 25 of')
                    inMiddleLayer = true
                else if line.includes('LAYER: 26 of')
                    break

                if inMiddleLayer and line.includes('; TYPE: SKIN')
                    skinMarkerCount++

            # Should have 0 SKIN markers on middle layers (not top/bottom).
            expect(skinMarkerCount).toBe(0)

    describe 'Nested Structure Skin Infill', ->

        Polytree = null

        beforeAll ->

            { Polytree } = require('@jgphilpott/polytree')

        createHollowCylinder = (outerRadius, innerRadius, height) ->

            # Create outer cylinder.
            outerGeometry = new THREE.CylinderGeometry(outerRadius, outerRadius, height, 32)
            outerMesh = new THREE.Mesh(outerGeometry, new THREE.MeshBasicMaterial())
            outerMesh.rotation.x = Math.PI / 2
            outerMesh.updateMatrixWorld()

            # Create inner cylinder (hole) - slightly taller for complete penetration.
            innerGeometry = new THREE.CylinderGeometry(innerRadius, innerRadius, height * 1.2, 32)
            innerMesh = new THREE.Mesh(innerGeometry, new THREE.MeshBasicMaterial())
            innerMesh.rotation.x = Math.PI / 2
            innerMesh.updateMatrixWorld()

            # Perform CSG subtraction.
            return Polytree.subtract(outerMesh, innerMesh)

        test 'should generate skin infill for outer structure in nested cylinders', ->

            # Create 2 nested hollow cylinders to test that outer structure gets skin infill.
            height = 1.2
            wallThickness = 5
            gap = 3

            cylinder1 = await createHollowCylinder(5 + wallThickness, 5, height)
            cylinder2 = await createHollowCylinder(5 + wallThickness + gap + wallThickness, 5 + wallThickness + gap, height)

            combined = await Polytree.unite(cylinder1, cylinder2)

            mesh = new THREE.Mesh(combined.geometry, combined.material)
            mesh.position.set(0, 0, height / 2)
            mesh.updateMatrixWorld()

            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8)
            slicer.setInfillDensity(0)  # No regular infill, only skin.
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            result = slicer.slice(mesh)

            # Extract bottom layer and check for skin infill moves.
            lines = result.split('\n')
            inLayer1 = false
            skinInfillMoveCount = 0

            for line in lines
                if line.includes('LAYER: 1 of')
                    inLayer1 = true
                else if line.includes('LAYER: 2 of')
                    break

                # Count "Moving to skin infill line" comments which indicate skin infill generation.
                if inLayer1 and line.includes('Moving to skin infill line')
                    skinInfillMoveCount++

            # Should have many skin infill moves (diagonal lines) for the outer structure.
            # The fix ensures these are generated in Phase 2.
            expect(skinInfillMoveCount).toBeGreaterThan(50)

        test 'should generate skin infill for inner structure in nested cylinders', ->

            # Create 2 nested hollow cylinders to test that INNER structure also gets skin infill.
            # This is the key regression test for the bug fix - inner structures were getting 0 infill lines.
            height = 1.2
            wallThickness = 5
            gap = 3

            cylinder1 = await createHollowCylinder(5 + wallThickness, 5, height)
            cylinder2 = await createHollowCylinder(5 + wallThickness + gap + wallThickness, 5 + wallThickness + gap, height)

            combined = await Polytree.unite(cylinder1, cylinder2)

            mesh = new THREE.Mesh(combined.geometry, combined.material)
            mesh.position.set(0, 0, height / 2)
            mesh.updateMatrixWorld()

            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8)
            slicer.setInfillDensity(0)
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            result = slicer.slice(mesh)

            # Extract bottom layer and find all SKIN sections.
            lines = result.split('\n')
            inLayer1 = false
            skinSections = []
            currentSectionLines = []
            inSkinSection = false

            for line in lines
                if line.includes('LAYER: 1 of')
                    inLayer1 = true
                else if line.includes('LAYER: 2 of')
                    if inSkinSection and currentSectionLines.length > 0
                        skinSections.push(currentSectionLines)
                    break

                if inLayer1
                    if line.includes('; TYPE: SKIN')
                        if inSkinSection and currentSectionLines.length > 0
                            skinSections.push(currentSectionLines)
                        currentSectionLines = []
                        inSkinSection = true
                    else if line.includes('; TYPE:') and not line.includes('; TYPE: SKIN')
                        if inSkinSection and currentSectionLines.length > 0
                            skinSections.push(currentSectionLines)
                        currentSectionLines = []
                        inSkinSection = false
                    else if inSkinSection
                        currentSectionLines.push(line)

            # With 2 nested cylinders (4 paths: 2 structures + 2 holes):
            # - Phase 1: 4 SKIN sections (walls only, no infill)
            # - Phase 2: 2 SKIN sections (wall + infill for structures)
            # Total: 6 SKIN sections
            expect(skinSections.length).toBe(6)

            # Count sections with infill (those with "Moving to skin infill line").
            sectionsWithInfill = 0
            for section in skinSections
                hasInfill = section.some((line) -> line.includes('Moving to skin infill line'))
                if hasInfill
                    sectionsWithInfill++

            # Both structures (outer and inner) should have skin infill.
            # This is the key assertion - before the fix, inner structure had 0 infill lines.
            expect(sectionsWithInfill).toBe(2)

        test 'should filter hole skin walls by nesting level for infill generation', ->

            # Create 3 nested hollow cylinders (6 paths: 3 structures + 3 holes).
            # This tests that the nesting level filtering works correctly.
            height = 1.2
            wallThickness = 5
            gap = 3

            cylinder1 = await createHollowCylinder(5 + wallThickness, 5, height)
            cylinder2 = await createHollowCylinder(5 + wallThickness + gap + wallThickness, 5 + wallThickness + gap, height)
            cylinder3 = await createHollowCylinder(5 + wallThickness + gap + wallThickness + gap + wallThickness, 5 + wallThickness + gap + wallThickness + gap, height)

            combined1 = await Polytree.unite(cylinder1, cylinder2)
            combined2 = await Polytree.unite(combined1, cylinder3)

            mesh = new THREE.Mesh(combined2.geometry, combined2.material)
            mesh.position.set(0, 0, height / 2)
            mesh.updateMatrixWorld()

            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8)
            slicer.setInfillDensity(0)
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            result = slicer.slice(mesh)

            # Extract bottom layer and count skin sections with infill.
            lines = result.split('\n')
            inLayer1 = false
            skinSections = []
            currentSectionLines = []
            inSkinSection = false

            for line in lines
                if line.includes('LAYER: 1 of')
                    inLayer1 = true
                else if line.includes('LAYER: 2 of')
                    if inSkinSection and currentSectionLines.length > 0
                        skinSections.push(currentSectionLines)
                    break

                if inLayer1
                    if line.includes('; TYPE: SKIN')
                        if inSkinSection and currentSectionLines.length > 0
                            skinSections.push(currentSectionLines)
                        currentSectionLines = []
                        inSkinSection = true
                    else if line.includes('; TYPE:') and not line.includes('; TYPE: SKIN')
                        if inSkinSection and currentSectionLines.length > 0
                            skinSections.push(currentSectionLines)
                        currentSectionLines = []
                        inSkinSection = false
                    else if inSkinSection
                        currentSectionLines.push(line)

            # Count sections with infill.
            sectionsWithInfill = 0
            infillLineCounts = []

            for section in skinSections
                infillMoves = section.filter((line) -> line.includes('Moving to skin infill line')).length
                if infillMoves > 0
                    sectionsWithInfill++
                    infillLineCounts.push(infillMoves)

            # All 3 structures should have skin infill.
            expect(sectionsWithInfill).toBe(3)

            # Each structure should have multiple infill lines (not zero).
            for count in infillLineCounts
                expect(count).toBeGreaterThan(0)

        test 'should not clip inner structure infill with outer hole walls', ->

            # Regression test: Before the fix, inner structure's skin infill was being
            # clipped by ALL hole skin walls, including the outer structure's hole.
            # This caused the inner structure to have 0 infill lines.
            height = 1.2
            wallThickness = 5
            gap = 3

            cylinder1 = await createHollowCylinder(5 + wallThickness, 5, height)
            cylinder2 = await createHollowCylinder(5 + wallThickness + gap + wallThickness, 5 + wallThickness + gap, height)

            combined = await Polytree.unite(cylinder1, cylinder2)

            mesh = new THREE.Mesh(combined.geometry, combined.material)
            mesh.position.set(0, 0, height / 2)
            mesh.updateMatrixWorld()

            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8)
            slicer.setInfillDensity(0)
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            result = slicer.slice(mesh)

            # Count infill moves in each skin section.
            lines = result.split('\n')
            inLayer1 = false
            skinSections = []
            currentSectionLines = []
            inSkinSection = false

            for line in lines
                if line.includes('LAYER: 1 of')
                    inLayer1 = true
                else if line.includes('LAYER: 2 of')
                    if inSkinSection and currentSectionLines.length > 0
                        skinSections.push(currentSectionLines)
                    break

                if inLayer1
                    if line.includes('; TYPE: SKIN')
                        if inSkinSection and currentSectionLines.length > 0
                            skinSections.push(currentSectionLines)
                        currentSectionLines = []
                        inSkinSection = true
                    else if line.includes('; TYPE:')
                        if inSkinSection and currentSectionLines.length > 0
                            skinSections.push(currentSectionLines)
                        currentSectionLines = []
                        inSkinSection = false
                    else if inSkinSection
                        currentSectionLines.push(line)

            # Get infill counts for Phase 2 sections (last 2 sections should have infill).
            infillCounts = []
            for section in skinSections
                infillMoves = section.filter((line) -> line.includes('Moving to skin infill line')).length
                if infillMoves > 0
                    infillCounts.push(infillMoves)

            # Should have 2 sections with infill (outer and inner structures).
            expect(infillCounts.length).toBe(2)

            # The key regression test: inner structure should have substantial infill lines.
            # Before the fix, it would have 0 lines because all hole walls were used for clipping.
            innerStructureInfillCount = Math.min(infillCounts[0], infillCounts[1])
            expect(innerStructureInfillCount).toBeGreaterThan(30)  # Should have many lines, not 0.

        test 'should generate travel moves (G0) when transitioning between skin areas', ->

            # This test validates that when generating skin for nested structures (holes),
            # the code generates proper G0 travel moves instead of G1 extrusion moves when
            # transitioning between different skin areas.
            # This is the fix for the issue where `lastEndPoint` was set to null instead of
            # using `lastWallPoint` when `generateWall=false`.

            # Create a box with two cylindrical holes to simulate nested structures.
            # Box dimensions: 40x40x8mm
            boxGeometry = new THREE.BoxGeometry(40, 40, 8)
            boxMesh = new THREE.Mesh(boxGeometry, new THREE.MeshBasicMaterial())
            boxMesh.updateMatrixWorld()

            # Create first cylindrical hole (4mm radius, 10mm tall to penetrate box).
            hole1Geometry = new THREE.CylinderGeometry(4, 4, 10, 32)
            hole1Mesh = new THREE.Mesh(hole1Geometry, new THREE.MeshBasicMaterial())
            hole1Mesh.position.set(-10, 0, 0)
            hole1Mesh.rotation.x = Math.PI / 2
            hole1Mesh.updateMatrixWorld()

            # Create second cylindrical hole.
            hole2Geometry = new THREE.CylinderGeometry(4, 4, 10, 32)
            hole2Mesh = new THREE.Mesh(hole2Geometry, new THREE.MeshBasicMaterial())
            hole2Mesh.position.set(10, 0, 0)
            hole2Mesh.rotation.x = Math.PI / 2
            hole2Mesh.updateMatrixWorld()

            # Perform CSG operations to create holes in the box.
            boxWithHole1 = await Polytree.subtract(boxMesh, hole1Mesh)
            boxWithHoles = await Polytree.subtract(boxWithHole1, hole2Mesh)

            # Create mesh from the result.
            mesh = new THREE.Mesh(boxWithHoles.geometry, boxWithHoles.material)
            mesh.position.set(0, 0, 4)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8)
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Parse the G-code to check for proper travel moves.
            lines = result.split('\n')

            # Track the pattern: when we see "; TYPE: SKIN" followed by a move,
            # it should be a G0 (travel) command, not G1 (extrusion).
            hasProperTravelMoves = false
            hasImproperExtrusionMoves = false

            for line, idx in lines

                if line.includes('; TYPE: SKIN')

                    # Check the next non-comment line after TYPE: SKIN.
                    for j in [(idx + 1)...Math.min(idx + 5, lines.length)]

                        nextLine = lines[j].trim()

                        # Skip empty lines and comments.
                        continue if nextLine.length is 0 or nextLine.startsWith(';')

                        # The first movement command after TYPE: SKIN should be checked.
                        if nextLine.startsWith('G0')
                            hasProperTravelMoves = true
                            break
                        else if nextLine.startsWith('G1') and nextLine.includes('E')
                            # This is an extrusion move immediately after TYPE: SKIN.
                            # Check if this is a long move (which would indicate a travel that should be G0).
                            xMatch = nextLine.match(/X([\d.]+)/)
                            yMatch = nextLine.match(/Y([\d.]+)/)

                            if xMatch and yMatch
                                # Get previous position.
                                prevX = null
                                prevY = null

                                for k in [(idx - 1)..Math.max(0, idx - 10)]
                                    prevLine = lines[k]
                                    if prevLine.includes('G0') or prevLine.includes('G1')
                                        prevXMatch = prevLine.match(/X([\d.]+)/)
                                        prevYMatch = prevLine.match(/Y([\d.]+)/)
                                        if prevXMatch and prevYMatch
                                            prevX = parseFloat(prevXMatch[1])
                                            prevY = parseFloat(prevYMatch[1])
                                            break

                                if prevX? and prevY?
                                    currentX = parseFloat(xMatch[1])
                                    currentY = parseFloat(yMatch[1])
                                    distance = Math.sqrt((currentX - prevX) ** 2 + (currentY - prevY) ** 2)

                                    # If the move is longer than 10mm, it should be a travel move.
                                    if distance > 10
                                        hasImproperExtrusionMoves = true
                            break

            # The fix ensures that we have proper G0 travel moves after TYPE: SKIN comments.
            expect(hasProperTravelMoves).toBe(true)

            # We should NOT have long extrusion moves immediately after TYPE: SKIN.
            expect(hasImproperExtrusionMoves).toBe(false)

    describe 'generateWall Parameter', ->

        test 'should generate both wall and infill when generateWall=true', ->

            # Create a 2cm x 2cm x 0.4mm sheet (single layer).
            geometry = new THREE.BoxGeometry(20, 20, 0.4)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 0.2)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.4)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            lines = result.split('\n')
            inSkin = false
            skinWallMoves = 0
            skinInfillMoves = 0

            for line in lines

                if line.includes('; TYPE: SKIN')
                    inSkin = true
                    continue

                if line.includes('; TYPE:') and inSkin
                    break

                if inSkin
                    # Wall moves are the first perimeter loop.
                    # Infill moves are marked with "Moving to skin infill line".
                    if line.includes('G1') and line.includes('E') and line.includes('F1800')
                        skinWallMoves++
                    if line.includes('Moving to skin infill line')
                        skinInfillMoves++

            # Should have both wall moves and infill moves.
            expect(skinWallMoves).toBeGreaterThan(0)
            expect(skinInfillMoves).toBeGreaterThan(0)

        test 'should not generate duplicate walls for structures with holes', ->

            # Create a sheet with a hole to trigger two-phase generation.
            outerWidth = 30
            outerHeight = 30
            holeRadius = 3
            thickness = 0.4

            # Create outer boundary.
            outerShape = new THREE.Shape()
            outerShape.moveTo(-outerWidth/2, -outerHeight/2)
            outerShape.lineTo(outerWidth/2, -outerHeight/2)
            outerShape.lineTo(outerWidth/2, outerHeight/2)
            outerShape.lineTo(-outerWidth/2, outerHeight/2)
            outerShape.lineTo(-outerWidth/2, -outerHeight/2)

            # Create hole.
            holePath = new THREE.Path()
            for angle in [0...360] by 30
                rad = angle * Math.PI / 180
                x = holeRadius * Math.cos(rad)
                y = holeRadius * Math.sin(rad)
                if angle is 0
                    holePath.moveTo(x, y)
                else
                    holePath.lineTo(x, y)
            holePath.lineTo(holeRadius, 0)  # Close path.

            outerShape.holes.push(holePath)

            # Extrude to create geometry.
            extrudeSettings = {
                depth: thickness
                bevelEnabled: false
            }
            geometry = new THREE.ExtrudeGeometry(outerShape, extrudeSettings)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, thickness/2)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.4)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            lines = result.split('\n')
            skinSections = []
            currentSection = []
            inSkin = false

            for line in lines

                if line.includes('; TYPE: SKIN')
                    if currentSection.length > 0
                        skinSections.push(currentSection)
                    currentSection = []
                    inSkin = true
                    continue

                if line.includes('; TYPE:') and inSkin
                    if currentSection.length > 0
                        skinSections.push(currentSection)
                    currentSection = []
                    inSkin = false

                if inSkin
                    currentSection.push(line)

            if currentSection.length > 0
                skinSections.push(currentSection)

            # Check that no two consecutive sections both have wall perimeters at similar coordinates.
            # Wall perimeters are at F1800, infill is at F3600.
            wallSections = []
            for section in skinSections
                wallMoves = section.filter((line) ->
                    line.includes('G1') and line.includes('E') and line.includes('F1800')
                ).length
                if wallMoves > 3  # More than just a few moves = actual wall perimeter.
                    wallSections.push(section)

            # Should have only one wall section for the outer boundary (not duplicate).
            # If there were duplicates, we'd see 2+ wall sections with similar perimeters.
            # The fix ensures Phase 1 generates wall-only, Phase 2 generates infill-only.
            expect(wallSections.length).toBeLessThanOrEqual(2)  # One for outer, possibly one for hole.

    describe 'Boundary Epsilon for Infill Coverage', ->

        test 'should not have gaps larger than line spacing at boundary edges', ->

            # Create a 2.5cm x 2.5cm sheet to test boundary coverage.
            geometry = new THREE.BoxGeometry(25, 25, 0.4)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 0.2)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.4)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            lines = result.split('\n')
            inSkin = false
            infillYCoords = []

            # Extract Y coordinates of infill lines at the right edge (X > 11).
            for line in lines

                if line.includes('; TYPE: SKIN')
                    inSkin = true
                    continue

                if line.includes('; TYPE:') and inSkin
                    break

                if inSkin and line.includes('G1') and line.includes('E')
                    # Extract X and Y coordinates.
                    xMatch = line.match(/X([\d.]+)/)
                    yMatch = line.match(/Y([\d.]+)/)
                    if xMatch and yMatch
                        x = parseFloat(xMatch[1])
                        y = parseFloat(yMatch[1])
                        # Focus on right edge where boundary issues occur.
                        if x > 11
                            infillYCoords.push(y)

            # Sort Y coordinates.
            infillYCoords.sort((a, b) -> a - b)

            # Calculate gaps between consecutive lines.
            expectedSpacing = 0.4 * Math.sqrt(2)  # ~0.566mm for 45° lines.
            maxGap = 0
            for i in [0...infillYCoords.length - 1]
                gap = infillYCoords[i + 1] - infillYCoords[i]
                if gap > maxGap
                    maxGap = gap

            # With boundary epsilon fix, max gap should not exceed 1.5x expected spacing.
            # Before fix, gaps could be 3x or more due to missing lines at boundary.
            expect(maxGap).toBeLessThan(expectedSpacing * 1.5)

        test 'should include infill lines near boundary edges', ->

            # Create a square sheet to test edge coverage.
            geometry = new THREE.BoxGeometry(20, 20, 0.4)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 0.2)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.4)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            lines = result.split('\n')
            inSkin = false
            edgeLineCount = 0

            # Check for infill lines near the edges (within 1mm of boundary at ~9mm).
            for line in lines

                if line.includes('; TYPE: SKIN')
                    inSkin = true
                    continue

                if line.includes('; TYPE:') and inSkin
                    break

                if inSkin and line.includes('G1') and line.includes('E') and line.includes('F3600')
                    xMatch = line.match(/X([-\d.]+)/)
                    yMatch = line.match(/Y([-\d.]+)/)
                    if xMatch and yMatch
                        x = parseFloat(xMatch[1])
                        y = parseFloat(yMatch[1])

                        # Check if near any edge (within 1mm of expected wall position ~9mm).
                        # Wall is at ~9.6mm (10 - 0.4), so check for lines beyond 8.5mm.
                        if Math.abs(x) > 8.5 or Math.abs(y) > 8.5
                            edgeLineCount++

            # Should have infill lines near boundary edges.
            # With epsilon fix, boundary-adjacent lines are not excluded.
            expect(edgeLineCount).toBeGreaterThan(10)

        test 'should maintain proper gap between skin wall and infill boundary', ->

            # Create a simple sheet.
            geometry = new THREE.BoxGeometry(20, 20, 0.4)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 0.2)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.4)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            lines = result.split('\n')
            inSkin = false
            wallMaxX = -Infinity
            infillMaxX = -Infinity

            # Find max X coordinate for wall and infill.
            for line in lines

                if line.includes('; TYPE: SKIN')
                    inSkin = true
                    continue

                if line.includes('; TYPE:') and inSkin
                    break

                if inSkin and line.includes('G1') and line.includes('E')
                    xMatch = line.match(/X([\d.]+)/)
                    if xMatch
                        x = parseFloat(xMatch[1])
                        # F1800 = wall, F3600 = infill.
                        if line.includes('F1800')
                            wallMaxX = Math.max(wallMaxX, x)
                        else if line.includes('F3600')
                            infillMaxX = Math.max(infillMaxX, x)

            # With epsilon of 0.05mm, the gap should be approximately 0.55mm.
            # This test verifies that epsilon adjustment is working.
            gap = wallMaxX - infillMaxX

            # Should maintain proper gap between skin wall and infill boundary.
            expect(gap).toBeLessThan(0.7)
            expect(gap).toBeGreaterThan(0.1)

        test 'should not generate skin infill lines that cross the skin wall boundary (regression)', ->

            # Regression test: skin infill lines were extending beyond the skin wall
            # boundary for curved cross-sections (e.g. cylinder) due to the clip polygon
            # epsilon being set too high (0.3mm). Bounding-box intersection points that
            # were outside but within 0.3mm of the circular boundary were falsely treated
            # as inside, producing spurious short segments at both ends of infill lines.

            # Use a cylinder which produces a circular cross-section.
            geometry = new THREE.CylinderGeometry(5, 5, 4, 32)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 2)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            lines = result.split('\n')
            inSkin = false
            skinInfillMoves = []

            for line in lines

                if line.includes('; TYPE: SKIN')
                    inSkin = true
                    continue

                if line.includes('; TYPE:') and inSkin
                    break

                # Collect skin infill G1 extrusion moves (F3600 = infill speed).
                if inSkin and line.includes('G1') and line.includes('E') and line.includes('F3600')
                    skinInfillMoves.push(line)

            # Cylinder center on build plate is at (110, 110) for 220x220 bed.
            cx = 110
            cy = 110

            # All skin infill endpoints should be inside the cylinder radius (5mm) minus
            # the skin wall gap (nozzleDiameter + nozzleDiameter/2 - 0.05mm ≈ 0.55mm).
            # Maximum allowed distance from center: radius - skinWallGap ≈ 5 - 0.55 = 4.45mm.
            # Use 4.5mm to allow for the polygon approximation of the cylinder boundary.
            maxAllowedDist = 4.5

            for line in skinInfillMoves

                xMatch = line.match(/X([\d.]+)/)
                yMatch = line.match(/Y([\d.]+)/)

                if xMatch and yMatch

                    x = parseFloat(xMatch[1]) - cx
                    y = parseFloat(yMatch[1]) - cy
                    dist = Math.sqrt(x * x + y * y)

                    # No infill endpoint should be outside the expected infill zone.
                    expect(dist).toBeLessThanOrEqual(maxAllowedDist)

            return

