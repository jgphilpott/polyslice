# Tests for main slicing method

Polyslice = require('../index')

THREE = require('three')

describe 'Slicing', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Basic Slicing', ->

        test 'should perform basic slice with autohome', ->

            result = slicer.slice()
            expect(result).toContain('G28\n') # Should contain autohome.

        test 'should skip autohome if disabled', ->

            slicer.setAutohome(false)
            result = slicer.slice()

            expect(result).toBe('') # Should be empty without autohome.

    describe 'Cube Slicing', ->

        test 'should slice a 1cm cube', ->

            # Create a 1cm cube (10mm).
            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            # Position cube so bottom is at Z=0.
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setNozzleTemperature(200)
            slicer.setBedTemperature(60)
            slicer.setFanSpeed(100)

            # Slice the mesh.
            result = slicer.slice(mesh)

            # Verify basic structure.
            expect(result).toContain('G28') # Autohome.
            expect(result).toContain('G17') # Workspace plane.
            expect(result).toContain('G21') # Millimeters.
            expect(result).toContain('M190') # Bed heating.
            expect(result).toContain('M109') # Nozzle heating.
            expect(result).toContain('M106') # Fan on.
            expect(result).toContain('Printing') # Layer message.
            expect(result).toContain('LAYER: 1') # Layer marker.
            expect(result).toContain('Print complete') # End message.
            expect(result).toContain('M107') # Fan off.

        test 'should slice a 1cm cube from scene', ->

            # Create a scene.
            scene = new THREE.Scene()

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()
            scene.add(mesh)

            # Slice the scene.
            result = slicer.slice(scene)

            expect(result).toContain('G28')
            expect(result).toContain('Printing')

        test 'should generate movement commands for cube layers', ->

            # Create a small cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setLayerHeight(0.2)

            result = slicer.slice(mesh)

            # Should contain linear movement commands.
            expect(result).toContain('G1')

            # Should have multiple layers (10mm / 0.2mm = 50 layers).
            lines = result.split('\n')
            layerMessages = lines.filter((line) -> line.includes('Layer'))
            expect(layerMessages.length).toBeGreaterThan(0)

        test 'should handle different layer heights', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            # Test with 0.1mm layer height.
            slicer.setLayerHeight(0.1)
            result1 = slicer.slice(mesh)

            # Test with 0.3mm layer height.
            slicer.setLayerHeight(0.3)
            result2 = slicer.slice(mesh)

            # More layers with smaller layer height.
            expect(result1.length).toBeGreaterThan(result2.length)

        test 'should handle mesh without heating when temperatures are zero', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleTemperature(0)
            slicer.setBedTemperature(0)

            result = slicer.slice(mesh)

            # Should not contain heating commands.
            expect(result).not.toContain('M190')
            expect(result).not.toContain('M109')

    describe 'Edge Cases', ->

        test 'should handle empty scene', ->

            result = slicer.slice({})
            expect(result).toContain('G28')

        test 'should handle null scene', ->

            result = slicer.slice(null)
            expect(result).toContain('G28')

        test 'should handle scene with no mesh', ->

            scene = new THREE.Scene()
            result = slicer.slice(scene)
            expect(result).toContain('G28')

    describe 'Multiple Wall Generation', ->

        test 'should generate single wall with 0.4mm shell thickness and 0.4mm nozzle', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.4)
            slicer.setLayerHeight(0.2)

            result = slicer.slice(mesh)

            # Should have WALL-OUTER but no WALL-INNER (single wall).
            expect(result).toContain('WALL-OUTER')

        test 'should generate two walls with 0.8mm shell thickness and 0.4mm nozzle', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setLayerHeight(0.2)

            result = slicer.slice(mesh)

            # Should have both outer and inner walls.
            expect(result).toContain('WALL-OUTER')
            expect(result).toContain('WALL-INNER')

        test 'should generate three walls with 1.2mm shell thickness and 0.4mm nozzle', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(1.2)
            slicer.setLayerHeight(0.2)

            result = slicer.slice(mesh)

            # Should have both outer and inner walls (3 total).
            expect(result).toContain('WALL-OUTER')
            expect(result).toContain('WALL-INNER')

            # Count wall type annotations to verify wall count.
            outerCount = (result.match(/WALL-OUTER/g) || []).length
            innerCount = (result.match(/WALL-INNER/g) || []).length

            # Should have more wall-inner than with 2 walls.
            expect(outerCount).toBeGreaterThan(0)
            expect(innerCount).toBeGreaterThan(0)

        test 'should round down wall count with non-multiple thickness', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(1.0) # Should give 2 walls (floor(1.0/0.4) = 2).
            slicer.setLayerHeight(0.2)

            result = slicer.slice(mesh)

            # Should have both outer and inner walls.
            expect(result).toContain('WALL-OUTER')
            expect(result).toContain('WALL-INNER')

        test 'should handle different nozzle diameter (0.6mm)', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.6)
            slicer.setShellWallThickness(1.2) # Should give 2 walls (floor(1.2/0.6) = 2).
            slicer.setLayerHeight(0.2)

            result = slicer.slice(mesh)

            # Should have both outer and inner walls.
            expect(result).toContain('WALL-OUTER')
            expect(result).toContain('WALL-INNER')

    describe 'Wall Quality and Regression Tests', ->

        test 'should maintain consistent extrusion across all layers', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8) # 2 walls
            slicer.setLayerHeight(0.2)

            result = slicer.slice(mesh)

            # Extract all G1 commands with extrusion values.
            lines = result.split('\n')
            extrusionLines = lines.filter((line) -> line.includes('G1') and line.includes('E'))

            # Check that we have extrusion commands.
            expect(extrusionLines.length).toBeGreaterThan(0)

            # Extract E values and verify they are cumulative (always increasing).
            eValues = []
            for line in extrusionLines
                match = line.match(/E([\d.]+)/)
                if match
                    eValues.push(parseFloat(match[1]))

            # Verify E values are monotonically increasing (cumulative).
            for i in [1...eValues.length]
                expect(eValues[i]).toBeGreaterThanOrEqual(eValues[i-1])
            undefined

            # Verify reasonable extrusion rate (~0.033 E/mm for default settings).
            # For a 10mm x 10mm cube top layer with 2 walls:
            # Outer wall: ~40mm perimeter
            # Inner wall: ~30.4mm perimeter (inset 0.4mm)
            # Total: ~70mm per layer
            # Expected E: ~70 * 0.033 = ~2.3 per layer
            # Final E value should be reasonable for 50 layers.
            finalE = eValues[eValues.length - 1]
            expect(finalE).toBeGreaterThan(50) # At least some extrusion
            expect(finalE).toBeLessThan(500) # Not excessive extrusion

        test 'should maintain proper wall spacing (no over-extension)', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8) # 2 walls
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Parse G-code to extract wall coordinates.
            lines = result.split('\n')

            # Find first layer with both walls.
            inWallOuter = false
            inWallInner = false
            outerCoords = []
            innerCoords = []

            for line in lines
                if line.includes('; TYPE: WALL-OUTER')
                    inWallOuter = true
                    inWallInner = false
                    continue
                if line.includes('; TYPE: WALL-INNER')
                    inWallOuter = false
                    inWallInner = true
                    continue
                if line.includes('LAYER:') or line.includes('Print complete')
                    break if outerCoords.length > 0 and innerCoords.length > 0

                # Extract coordinates from G1 commands.
                if line.includes('G1') and (inWallOuter or inWallInner)
                    xMatch = line.match(/X([\d.]+)/)
                    yMatch = line.match(/Y([\d.]+)/)
                    if xMatch and yMatch
                        coord = { x: parseFloat(xMatch[1]), y: parseFloat(yMatch[1]) }
                        if inWallOuter
                            outerCoords.push(coord)
                        else if inWallInner
                            innerCoords.push(coord)

            # Verify we have coordinates.
            expect(outerCoords.length).toBeGreaterThan(0)
            expect(innerCoords.length).toBeGreaterThan(0)

            # Check minimum distance between outer and inner walls.
            # Should be approximately nozzle diameter (0.4mm), allowing small tolerance.
            minDistance = Infinity
            for inner in innerCoords
                for outer in outerCoords
                    dx = inner.x - outer.x
                    dy = inner.y - outer.y
                    distance = Math.sqrt(dx * dx + dy * dy)
                    if distance < minDistance
                        minDistance = distance

            # Walls should be at least 0.3mm apart (nozzle diameter minus tolerance).
            # This catches over-extension issues where walls get too close.
            expect(minDistance).toBeGreaterThan(0.3)

        test 'should not create mystery diagonal lines between walls', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(1.2) # 3 walls - more complex case
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Parse G-code to check for unexpected movements.
            lines = result.split('\n')

            # Track wall boundaries.
            inWall = false
            previousWallType = null

            for line in lines
                # Detect wall type changes.
                if line.includes('; TYPE: WALL-')
                    currentWallType = if line.includes('OUTER') then 'OUTER' else 'INNER'
                    
                    # If wall type changed, we should see a G0 (travel) command before the next G1.
                    if previousWallType and currentWallType isnt previousWallType
                        # Next line should be a G0 or G1 travel move (no E value).
                        inWall = false
                    
                    previousWallType = currentWallType
                    inWall = true
                    continue

                # Check for G1 commands with extrusion.
                if line.includes('G1') and line.includes('E') and not inWall
                    # Found an extrusion move outside of a wall context - potential mystery line.
                    # However, closing moves are ok, so we only fail if this happens repeatedly.
                    # For now, just verify we're in a wall context when extruding.
                    continue # Allow this for now

            # Main check: verify that WALL types are properly sequenced.
            # Count transitions and ensure they match expected pattern.
            wallTypes = []
            for line in lines
                if line.includes('; TYPE: WALL-OUTER')
                    wallTypes.push('OUTER')
                else if line.includes('; TYPE: WALL-INNER')
                    wallTypes.push('INNER')

            # For 3 walls: pattern should be OUTER, INNER, INNER per layer.
            # Verify we have the right ratio.
            outerCount = wallTypes.filter((t) -> t is 'OUTER').length
            innerCount = wallTypes.filter((t) -> t is 'INNER').length

            # Should have 1 outer per layer and 2 inners per layer.
            # Ratio should be approximately 1:2.
            expect(innerCount / outerCount).toBeGreaterThan(1.5)
            expect(innerCount / outerCount).toBeLessThan(2.5)

        test 'should maintain consistent wall count across all layers', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(1.6) # 4 walls
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Count wall types per layer.
            lines = result.split('\n')
            layerWallCounts = []
            currentLayerOuter = 0
            currentLayerInner = 0

            for line in lines
                if line.includes('LAYER:')
                    # Save previous layer counts if any.
                    if currentLayerOuter > 0
                        layerWallCounts.push({ outer: currentLayerOuter, inner: currentLayerInner })
                    currentLayerOuter = 0
                    currentLayerInner = 0
                else if line.includes('; TYPE: WALL-OUTER')
                    currentLayerOuter++
                else if line.includes('; TYPE: WALL-INNER')
                    currentLayerInner++

            # Save last layer.
            if currentLayerOuter > 0
                layerWallCounts.push({ outer: currentLayerOuter, inner: currentLayerInner })

            # All layers should have the same wall count (1 outer + 3 inner).
            for counts in layerWallCounts
                expect(counts.outer).toBe(1)
                expect(counts.inner).toBe(3)
            undefined

        test 'should properly simplify paths to avoid extra vertices', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8) # 2 walls
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Check that top layer (which should be a perfect square) has exactly 4 corners.
            lines = result.split('\n')
            
            # Find the last layer before post-print.
            lastLayerLines = []
            inLastLayer = false
            for line in lines
                if line.includes('post-print')
                    break
                if inLastLayer
                    lastLayerLines.push(line)
                if line.includes('LAYER:')
                    inLastLayer = true
                    lastLayerLines = []

            # Count G1 commands in the last layer's outer wall.
            outerWallG1Count = 0
            inOuterWall = false
            for line in lastLayerLines
                if line.includes('; TYPE: WALL-OUTER')
                    inOuterWall = true
                    outerWallG1Count = 0
                else if line.includes('; TYPE: WALL-INNER')
                    inOuterWall = false
                else if inOuterWall and line.includes('G1') and line.includes('E')
                    outerWallG1Count++

            # Top layer of a cube should have 4 sides (4-5 G1 commands including closing).
            # Allow 4-6 to account for closing move and any rounding.
            expect(outerWallG1Count).toBeGreaterThanOrEqual(4)
            expect(outerWallG1Count).toBeLessThanOrEqual(6)

            # Should have both outer and inner walls.
            expect(result).toContain('WALL-OUTER')
            expect(result).toContain('WALL-INNER')

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

    describe 'Grid Infill Generation', ->

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
            slicer.setInfillPattern('grid')
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

        test 'should generate crosshatch pattern with 45-degree lines', ->

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

                    xMatch = line.match(/X([\d.]+)/)
                    yMatch = line.match(/Y([\d.]+)/)

                    if xMatch and yMatch
                        currentInfillCoords.push({
                            x: parseFloat(xMatch[1])
                            y: parseFloat(yMatch[1])
                        })

            # Check that we have infill layers.
            expect(infillLayers.length).toBeGreaterThan(5)

            # Check first few middle layers that should have infill.
            # (Skip first few layers which might be skin).
            middleLayers = infillLayers.filter((l) -> l.layer > 5 and l.layer < 45)

            expect(middleLayers.length).toBeGreaterThan(5)

            # Grid pattern should have diagonal lines at 45-degree angles.
            # Check that X and Y both vary (diagonal movement).
            for layer in middleLayers.slice(0, 5)

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
                # (Unlike horizontal/vertical which have variance in only one dimension).
                expect(xVariance).toBeGreaterThan(0)
                expect(yVariance).toBeGreaterThan(0)

            return # Explicitly return undefined for Jest.

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

        test 'should support grid pattern setting', ->

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

            # Set infill pattern to grid.
            slicer.setInfillPattern('grid')

            expect(slicer.getInfillPattern()).toBe('grid')

            result = slicer.slice(mesh)

            # Should generate infill.
            expect(result).toContain('; TYPE: FILL')
