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
            expect(result).toContain('LAYER: 1 of') # Layer marker.
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

        test 'should not modify original mesh position during slicing', ->

            # Create a cube positioned at specific coordinates.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            # Position mesh at (5, 10, 7).
            mesh.position.set(5, 10, 7)
            mesh.updateMatrixWorld()

            # Store original position.
            originalX = mesh.position.x
            originalY = mesh.position.y
            originalZ = mesh.position.z

            # Slice the mesh.
            slicer.setLayerHeight(0.2)
            result = slicer.slice(mesh)

            # Verify that original mesh position is unchanged.
            expect(mesh.position.x).toBe(originalX)
            expect(mesh.position.y).toBe(originalY)
            expect(mesh.position.z).toBe(originalZ)

            # Verify that slicing still worked.
            expect(result).toContain('Printing')

        test 'should not modify original mesh with negative Z position', ->

            # Create a cube with negative Z position (below build plate).
            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            # Position mesh below build plate.
            mesh.position.set(0, 0, -5)
            mesh.updateMatrixWorld()

            # Store original position.
            originalX = mesh.position.x
            originalY = mesh.position.y
            originalZ = mesh.position.z

            # Slice the mesh (should internally adjust Z but not modify original).
            slicer.setLayerHeight(0.2)
            result = slicer.slice(mesh)

            # Verify that original mesh position is unchanged.
            expect(mesh.position.x).toBe(originalX)
            expect(mesh.position.y).toBe(originalY)
            expect(mesh.position.z).toBe(originalZ)

            # Verify that slicing still worked.
            expect(result).toContain('Printing')

        test 'should not modify mesh rotation during slicing', ->

            # Create a rotated cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 5)
            mesh.rotation.set(Math.PI / 4, Math.PI / 6, Math.PI / 3)
            mesh.updateMatrixWorld()

            # Store original rotation.
            originalRotationX = mesh.rotation.x
            originalRotationY = mesh.rotation.y
            originalRotationZ = mesh.rotation.z

            # Slice the mesh.
            slicer.setLayerHeight(0.2)
            result = slicer.slice(mesh)

            # Verify that original mesh rotation is unchanged.
            expect(mesh.rotation.x).toBe(originalRotationX)
            expect(mesh.rotation.y).toBe(originalRotationY)
            expect(mesh.rotation.z).toBe(originalRotationZ)

            # Verify that slicing still worked.
            expect(result).toContain('Printing')

        test 'should not modify mesh scale during slicing', ->

            # Create a scaled cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 5)
            mesh.scale.set(1.5, 2.0, 0.8)
            mesh.updateMatrixWorld()

            # Store original scale.
            originalScaleX = mesh.scale.x
            originalScaleY = mesh.scale.y
            originalScaleZ = mesh.scale.z

            # Slice the mesh.
            slicer.setLayerHeight(0.2)
            result = slicer.slice(mesh)

            # Verify that original mesh scale is unchanged.
            expect(mesh.scale.x).toBe(originalScaleX)
            expect(mesh.scale.y).toBe(originalScaleY)
            expect(mesh.scale.z).toBe(originalScaleZ)

            # Verify that slicing still worked.
            expect(result).toContain('Printing')

        test 'should not modify original mesh geometry during slicing', ->

            # Create a mesh with geometry that has no bounding box computed.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            # Verify geometry has no bounding box computed initially.
            expect(geometry.boundingBox).toBeNull()

            # Store original geometry reference.
            originalGeometry = mesh.geometry

            # Slice the mesh.
            slicer.setLayerHeight(0.2)
            result = slicer.slice(mesh)

            # Verify that original mesh still has same geometry reference.
            expect(mesh.geometry).toBe(originalGeometry)

            # Verify that original geometry bounding box is still null (not computed).
            expect(originalGeometry.boundingBox).toBeNull()

            # Verify that slicing still worked.
            expect(result).toContain('Printing')

        test 'should center mesh on build plate regardless of world position', ->

            # Create a mesh at non-zero world position (like benchy at Y=500).
            geometry = new THREE.BoxGeometry(20, 10, 10)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            # Position mesh at arbitrary location.
            mesh.position.set(50, 200, 5)
            mesh.updateMatrixWorld()

            # Configure slicer with known build plate.
            slicer.setBuildPlateWidth(220)
            slicer.setBuildPlateLength(220)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(0)  # No infill for faster test.
            slicer.setVerbose(false)

            # Slice the mesh.
            result = slicer.slice(mesh)

            # Parse G-code to find actual print coordinates (only extrusion moves).
            lines = result.split('\n')
            minX = Infinity
            maxX = -Infinity
            minY = Infinity
            maxY = -Infinity

            for line in lines
                if (line.indexOf('G1 ') is 0 or line.indexOf('G0 ') is 0) and line.indexOf('E') > -1
                    xMatch = line.match(/X([-\d.]+)/)
                    yMatch = line.match(/Y([-\d.]+)/)
                    if xMatch
                        x = parseFloat(xMatch[1])
                        minX = Math.min(minX, x)
                        maxX = Math.max(maxX, x)
                    if yMatch
                        y = parseFloat(yMatch[1])
                        minY = Math.min(minY, y)
                        maxY = Math.max(maxY, y)

            # Calculate print center.
            printCenterX = (minX + maxX) / 2
            printCenterY = (minY + maxY) / 2

            # Build plate center should be (110, 110).
            expectedCenterX = 110
            expectedCenterY = 110

            # Verify print is centered on build plate (within 2mm tolerance).
            expect(Math.abs(printCenterX - expectedCenterX)).toBeLessThan(2)
            expect(Math.abs(printCenterY - expectedCenterY)).toBeLessThan(2)

    describe 'Torus Slicing with Holes', ->

        test 'should generate infill clipped by hole walls', ->

            # Create a torus mesh with a hole.
            geometry = new THREE.TorusGeometry(10, 3, 8, 16)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            # Position torus so bottom is at Z=0.
            mesh.position.set(0, 0, 3)
            mesh.updateMatrixWorld()

            # Configure slicer with infill.
            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(1.2)  # 3 walls.
            slicer.setShellSkinThickness(0.8)  # 4 skin layers.
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

            # Verify that skin is generated.
            expect(result).toContain('TYPE: SKIN')

            # The G-code should contain both wall and infill sections.
            # This confirms that the implementation is processing holes.
            expect(result.length).toBeGreaterThan(1000)

        test 'should generate skin infill clipped by hole skin walls', ->

            # Create a torus mesh with a hole.
            geometry = new THREE.TorusGeometry(10, 3, 8, 16)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            # Position torus so bottom is at Z=0.
            mesh.position.set(0, 0, 3)
            mesh.updateMatrixWorld()

            # Configure slicer with skin layers.
            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(1.2)  # 3 walls.
            slicer.setShellSkinThickness(0.8)  # 4 skin layers.
            slicer.setInfillDensity(0)  # No regular infill.
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            # Slice the mesh.
            result = slicer.slice(mesh)

            # Verify that skin is generated (top/bottom layers).
            expect(result).toContain('TYPE: SKIN')

            # Verify that walls are generated.
            expect(result).toContain('TYPE: WALL-OUTER')

            # Even with no regular infill, skin should be present on top/bottom.
            # The key test is that it completes without errors, and skin is clipped properly.
            expect(result.length).toBeGreaterThan(500)

        test 'should handle torus with multiple holes correctly', ->

            # Create a torus - it has both an outer boundary and an inner hole.
            geometry = new THREE.TorusGeometry(5, 2, 16, 32)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            # Position torus.
            mesh.position.set(0, 0, 2)
            mesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)  # 2 walls.
            slicer.setShellSkinThickness(0.6)  # 3 skin layers.
            slicer.setInfillDensity(30)
            slicer.setInfillPattern('triangles')
            slicer.setAutohome(false)

            # Slice the mesh.
            result = slicer.slice(mesh)

            # Should produce valid G-code without errors.
            expect(result).toBeDefined()
            expect(result.length).toBeGreaterThan(100)

            # Should not have any NaN or undefined coordinates.
            expect(result).not.toContain('NaN')
            expect(result).not.toContain('undefined')

    describe 'Torus Slicing Regression', ->

        test 'should correctly slice torus at center plane (issue fix)', ->

            # This test verifies the fix for the torus slicing bug where layer 10
            # (at the center plane Z=2.0mm) was only printing the inner hole instead
            # of both the outer ring and inner hole.
            #
            # Root cause: Polytree was slicing exactly at Z=2.0, which is a geometric
            # boundary for the torus, causing it to miss the outer ring.
            #
            # Fix: Added small epsilon offset to layer height to avoid hitting exact
            # geometric boundaries.

            # Create torus with same parameters as resources (radius=5mm, tube=2mm).
            geometry = new THREE.TorusGeometry(5, 2, 16, 32)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            # Position torus so bottom is at Z=0 (center at Z=2mm).
            mesh.position.set(0, 0, 2)
            mesh.updateMatrixWorld()

            # Configure slicer with same settings as resources.
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(50)
            slicer.setVerbose(true)

            # Slice the mesh.
            result = slicer.slice(mesh)

            # Find Layer 11 content (the problematic center layer at Z≈2.0mm, index 10).
            lines = result.split('\n')
            layer11Start = -1
            layer12Start = -1

            for line, i in lines
                if line.includes('LAYER: 11 of')
                    layer11Start = i
                if line.includes('LAYER: 12 of')
                    layer12Start = i
                    break

            # Verify Layer 11 was generated.
            expect(layer11Start).toBeGreaterThanOrEqual(0)
            expect(layer12Start).toBeGreaterThan(layer11Start)

            # Extract Layer 11 content.
            layer11Content = lines.slice(layer11Start, layer12Start).join('\n')

            # Count WALL-OUTER occurrences (should be 2: outer ring + inner hole).
            wallOuterCount = (layer11Content.match(/; TYPE: WALL-OUTER/g) or []).length

            # Verify we have 2 wall regions (not just 1).
            expect(wallOuterCount).toBeGreaterThanOrEqual(2)

            # Extract X coordinates to verify we're printing the full torus.
            xCoords = []
            for line in lines.slice(layer11Start, layer12Start)
                match = line.match(/G1 X([\d.]+) Y[\d.]+/)
                if match
                    xCoords.push(parseFloat(match[1]))

            # Calculate width of printed area.
            if xCoords.length > 0
                minX = Math.min(...xCoords)
                maxX = Math.max(...xCoords)
                width = maxX - minX

                # For a torus with radius=5mm and tube=2mm, the outer diameter should be
                # approximately 14mm (2 * (radius + tube) = 2 * 7 = 14mm).
                # At Z=2mm (center plane), we should be printing close to this width.
                # A width < 10mm would indicate only the hole is being printed.
                expect(width).toBeGreaterThan(10)

    describe 'Sphere Slicing at Equator', ->

        # Regression test for issue where slicing at the exact equator of a sphere
        # would result in only half the geometry being captured (semi-circle instead of full circle).
        # This occurred when slice planes aligned exactly with geometric boundaries where many
        # vertices exist at the same Z coordinate.
        test 'should generate full circle at sphere equator (not semi-circle)', ->

            # Test parameters.
            SPHERE_RADIUS = 5 # mm
            SPHERE_WIDTH_SEGMENTS = 32
            SPHERE_HEIGHT_SEGMENTS = 32
            MIN_EXPECTED_POINTS = 100 # Points at equator for full circle.
            MAX_SPAN_TOLERANCE = 0.15 # 15% tolerance for X/Y span difference.
            MIN_QUADRANT_BALANCE = 0.6 # Minimum balance ratio between quadrants.

            # Create a sphere with radius 5mm positioned so bottom is at Z=0.
            geometry = new THREE.SphereGeometry(SPHERE_RADIUS, SPHERE_WIDTH_SEGMENTS, SPHERE_HEIGHT_SEGMENTS)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            # Position sphere so bottom is at Z=0 (center at Z=SPHERE_RADIUS).
            mesh.position.set(0, 0, SPHERE_RADIUS)
            mesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8)
            slicer.setInfillDensity(30)
            slicer.setVerbose(true)

            # Slice the mesh.
            result = slicer.slice(mesh)

            # Extract layer 26 (index 25, which should be at the equator, Z ≈ 5mm).
            lines = result.split('\n')
            inLayer26 = false
            layer26Coords = []

            for line in lines

                if line.includes('M117 LAYER: 26 of')
                    inLayer26 = true

                else if inLayer26 and line.includes('M117 LAYER: 27 of')
                    break

                # Extract X,Y coordinates from extrusion moves.
                if inLayer26 and line.startsWith('G1') and line.includes('E')

                    xMatch = line.match(/X([\d.-]+)/)
                    yMatch = line.match(/Y([\d.-]+)/)

                    if xMatch and yMatch
                        layer26Coords.push({
                            x: parseFloat(xMatch[1])
                            y: parseFloat(yMatch[1])
                        })

            # Should have captured a significant number of points.
            expect(layer26Coords.length).toBeGreaterThan(MIN_EXPECTED_POINTS)

            # Calculate X and Y ranges.
            xVals = layer26Coords.map((c) -> c.x)
            yVals = layer26Coords.map((c) -> c.y)

            xMin = Math.min(...xVals)
            xMax = Math.max(...xVals)
            yMin = Math.min(...yVals)
            yMax = Math.max(...yVals)

            xSpan = xMax - xMin
            ySpan = yMax - yMin

            # For a full circle at the equator, X and Y spans should be similar.
            # A semi-circle would have significantly different spans (e.g., 5mm vs 9mm).
            spanDifference = Math.abs(xSpan - ySpan)
            averageSpan = (xSpan + ySpan) / 2
            tolerancePercent = spanDifference / averageSpan

            expect(tolerancePercent).toBeLessThan(MAX_SPAN_TOLERANCE)

            # Check quadrant balance to ensure we have geometry from all sides.
            centerX = (xMin + xMax) / 2
            centerY = (yMin + yMax) / 2

            quadrants = [0, 0, 0, 0] # Q1, Q2, Q3, Q4

            for coord in layer26Coords

                relX = coord.x - centerX
                relY = coord.y - centerY

                if relX >= 0 and relY >= 0
                    quadrants[0]++
                else if relX < 0 and relY >= 0
                    quadrants[1]++
                else if relX < 0 and relY < 0
                    quadrants[2]++
                else
                    quadrants[3]++

            # All quadrants should have reasonable representation.
            # Minimum quadrant should have at least MIN_QUADRANT_BALANCE of maximum quadrant.
            minQuadrant = Math.min(...quadrants)
            maxQuadrant = Math.max(...quadrants)
            balanceRatio = minQuadrant / maxQuadrant

            expect(balanceRatio).toBeGreaterThan(MIN_QUADRANT_BALANCE)

            return # Explicitly return undefined for Jest.

    describe 'Wall Print Order with Holes', ->

        test 'should print outer boundary walls before hole walls', ->

            # This test uses three-bvh-csg to create a sheet with holes.
            # Import CSG dependencies.
            { Brush, Evaluator, SUBTRACTION } = require('three-bvh-csg')

            # Suppress MeshBVH deprecation warnings from three-bvh-csg.
            originalWarn = console.warn
            console.warn = jest.fn()

            # Create a sheet with holes using CSG operations.
            sheetGeometry = new THREE.BoxGeometry(50, 50, 5)
            sheetBrush = new Brush(sheetGeometry)
            sheetBrush.updateMatrixWorld()

            csgEvaluator = new Evaluator()

            # Create 2x2 grid of holes.
            gridSize = 2
            spacing = 50 / (gridSize + 1)
            offsetX = -50 / 2 + spacing
            offsetY = -50 / 2 + spacing
            holeRadius = 3

            resultBrush = sheetBrush

            for row in [0...gridSize]

                for col in [0...gridSize]

                    # Calculate hole position.
                    holeX = offsetX + col * spacing
                    holeY = offsetY + row * spacing

                    # Create cylinder for hole.
                    holeGeometry = new THREE.CylinderGeometry(holeRadius, holeRadius, 10, 32)
                    holeMesh = new Brush(holeGeometry)

                    holeMesh.rotation.x = Math.PI / 2
                    holeMesh.position.set(holeX, holeY, 0)
                    holeMesh.updateMatrixWorld()

                    # Subtract hole from sheet.
                    resultBrush = csgEvaluator.evaluate(resultBrush, holeMesh, SUBTRACTION)

            # Restore console.warn.
            console.warn = originalWarn

            # Create final mesh.
            finalMesh = new THREE.Mesh(resultBrush.geometry, new THREE.MeshBasicMaterial())
            finalMesh.position.set(0, 0, 2.5)
            finalMesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)
            slicer.setShellWallThickness(0.8)

            # Slice the mesh.
            gcode = slicer.slice(finalMesh)

            # Find a layer with both outer and hole walls.
            # Extract lines for a middle layer (e.g., layer 6, index 5).
            lines = gcode.split('\n')

            layerStartIndex = -1
            layerEndIndex = -1

            for lineIndex in [0...lines.length]

                line = lines[lineIndex]

                if line.includes('LAYER: 6 of')
                    layerStartIndex = lineIndex
                else if layerStartIndex >= 0 and line.includes('LAYER: 7 of')
                    layerEndIndex = lineIndex
                    break

            # Default to end of file if no next layer found.
            if layerStartIndex >= 0 and layerEndIndex < 0
                layerEndIndex = lines.length

            # Extract layer lines.
            layerLines = lines.slice(layerStartIndex, layerEndIndex)

            # Extract wall type markers (WALL-OUTER, WALL-INNER).
            wallTypeIndices = []

            for lineIndex in [0...layerLines.length]

                line = layerLines[lineIndex]

                if line.includes('TYPE: WALL-OUTER') or line.includes('TYPE: WALL-INNER')
                    wallTypeIndices.push(lineIndex)

            # We expect at least 2 walls for outer boundary (OUTER + INNER).
            # And at least 2 walls per hole (OUTER + INNER) * 4 holes = 8.
            # Total: at least 10 wall type markers.
            expect(wallTypeIndices.length).toBeGreaterThanOrEqual(10)

            # Check that the first wall type markers are for outer boundary.
            # The outer boundary should be printed first, before any holes.
            # We can identify outer boundary walls by checking the order.
            # The first 2 wall types should be for the outer boundary (OUTER + INNER).
            # After that, we should see hole walls.

            # Extract coordinates from wall moves to identify outer vs hole walls.
            # Outer boundary walls will have coordinates near the edges (~85-135 range).
            # Hole walls will have coordinates clustered near hole centers.

            wallCoordinates = []

            for lineIndex in [0...layerLines.length]

                line = layerLines[lineIndex]

                if line.includes('TYPE: WALL-')

                    # Look at the next few lines to find actual G1 moves with coordinates.
                    for nextLineOffset in [1..5]

                        if lineIndex + nextLineOffset < layerLines.length

                            nextLine = layerLines[lineIndex + nextLineOffset]

                            if nextLine.match(/^G[01]\s/)

                                xMatch = nextLine.match(/X([-\d.]+)/)
                                yMatch = nextLine.match(/Y([-\d.]+)/)

                                if xMatch and yMatch

                                    wallCoordinates.push({
                                        x: parseFloat(xMatch[1])
                                        y: parseFloat(yMatch[1])
                                        type: if line.includes('WALL-OUTER') then 'OUTER' else 'INNER'
                                    })

                                    break

            # The first 2 walls should be outer boundary (near edges, far from center).
            # Derive build plate center from slicer configuration.
            centerX = slicer.getBuildPlateWidth() / 2
            centerY = slicer.getBuildPlateLength() / 2

            # Distance threshold to distinguish outer boundary from holes.
            # For a 50mm sheet centered on build plate:
            # - Outer boundary edges are ~25mm from center
            # - Hole centers are ~8-16mm from center (for 2x2 grid with 3mm radius holes)
            # Using 20mm as threshold provides good separation.
            OUTER_BOUNDARY_MIN_DISTANCE = 20

            expect(wallCoordinates.length).toBeGreaterThanOrEqual(10)

            # First wall should be outer boundary (far from any hole center).
            firstWall = wallCoordinates[0]
            secondWall = wallCoordinates[1]

            # Calculate distance from build plate center for first two walls.
            # Outer boundary walls should be farther from center than hole walls.
            firstDist = Math.sqrt((firstWall.x - centerX) ** 2 + (firstWall.y - centerY) ** 2)
            secondDist = Math.sqrt((secondWall.x - centerX) ** 2 + (secondWall.y - centerY) ** 2)

            # Both should be reasonably far from center (outer boundary).
            expect(firstDist).toBeGreaterThan(OUTER_BOUNDARY_MIN_DISTANCE)
            expect(secondDist).toBeGreaterThan(OUTER_BOUNDARY_MIN_DISTANCE)

            # Check that later walls (holes) are closer to center.
            laterWalls = wallCoordinates.slice(2)
            holeWallDistances = laterWalls.map((wall) ->
                Math.sqrt((wall.x - centerX) ** 2 + (wall.y - centerY) ** 2)
            )

            # At least some hole walls should be closer to center than outer walls.
            closeHoleWalls = holeWallDistances.filter((dist) -> dist < OUTER_BOUNDARY_MIN_DISTANCE)
            expect(closeHoleWalls.length).toBeGreaterThan(0)

            return # Explicitly return undefined for Jest.

        test 'should generate skin walls immediately after regular walls for holes on skin layers', ->

            # This test validates the skin wall integration feature.
            # Import CSG dependencies.
            { Brush, Evaluator, SUBTRACTION } = require('three-bvh-csg')

            # Suppress MeshBVH deprecation warnings from three-bvh-csg.
            originalWarn = console.warn
            console.warn = jest.fn()

            # Create a sheet with holes using CSG operations.
            sheetGeometry = new THREE.BoxGeometry(50, 50, 5)
            sheetBrush = new Brush(sheetGeometry)
            sheetBrush.updateMatrixWorld()

            csgEvaluator = new Evaluator()

            # Create 2x2 grid of holes.
            gridSize = 2
            spacing = 50 / (gridSize + 1)
            offsetX = -50 / 2 + spacing
            offsetY = -50 / 2 + spacing
            holeRadius = 3

            resultBrush = sheetBrush

            for row in [0...gridSize]

                for col in [0...gridSize]

                    # Calculate hole position.
                    holeX = offsetX + col * spacing
                    holeY = offsetY + row * spacing

                    # Create cylinder for hole.
                    holeGeometry = new THREE.CylinderGeometry(holeRadius, holeRadius, 10, 32)
                    holeMesh = new Brush(holeGeometry)

                    holeMesh.rotation.x = Math.PI / 2
                    holeMesh.position.set(holeX, holeY, 0)
                    holeMesh.updateMatrixWorld()

                    # Subtract hole from sheet.
                    resultBrush = csgEvaluator.evaluate(resultBrush, holeMesh, SUBTRACTION)

            # Restore console.warn.
            console.warn = originalWarn

            # Create final mesh.
            finalMesh = new THREE.Mesh(resultBrush.geometry, new THREE.MeshBasicMaterial())
            finalMesh.position.set(0, 0, 2.5)
            finalMesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8)  # Enable skin layers

            # Slice the mesh.
            gcode = slicer.slice(finalMesh)

            # Check layer 1 (bottom skin layer, index 0).
            lines = gcode.split('\n')

            layerStartIndex = -1
            layerEndIndex = -1

            for lineIndex in [0...lines.length]

                line = lines[lineIndex]

                if line.includes('LAYER: 1 of')
                    layerStartIndex = lineIndex
                else if layerStartIndex >= 0 and line.includes('LAYER: 2 of')
                    layerEndIndex = lineIndex
                    break

            # Default to end of file if no next layer found.
            if layerStartIndex >= 0 and layerEndIndex < 0
                layerEndIndex = lines.length

            # Extract layer lines.
            layerLines = lines.slice(layerStartIndex, layerEndIndex)

            # Extract wall and skin type markers in sequence.
            typeSequence = []

            for lineIndex in [0...layerLines.length]

                line = layerLines[lineIndex]

                if line.includes('TYPE: WALL-OUTER')
                    typeSequence.push('WALL-OUTER')
                else if line.includes('TYPE: WALL-INNER')
                    typeSequence.push('WALL-INNER')
                else if line.includes('TYPE: SKIN')
                    typeSequence.push('SKIN')

            # Validate the sequence pattern.
            # Updated pattern after spacing validation changes:
            # OUTER_BOUNDARY(OUTER,INNER) + HOLE1(OUTER,INNER) + HOLE2(OUTER,INNER) + ... + SKIN(for holes) + OUTER_BOUNDARY_SKIN + INFILL
            # We should see at least: 2 outer boundary walls + (2 walls * 4 holes) + skin = 14+ type markers

            expect(typeSequence.length).toBeGreaterThanOrEqual(14)

            # First two should be outer boundary walls (OUTER, INNER).
            expect(typeSequence[0]).toBe('WALL-OUTER')
            expect(typeSequence[1]).toBe('WALL-INNER')

            # Count hole walls (pairs of OUTER, INNER without immediate SKIN).
            holeWallPairCount = 0

            for i in [2...typeSequence.length - 1]

                if typeSequence[i] is 'WALL-OUTER' and
                   typeSequence[i + 1] is 'WALL-INNER'

                    holeWallPairCount++

            # We should have at least 4 hole wall pairs (one for each hole).
            expect(holeWallPairCount).toBeGreaterThanOrEqual(4)

            # Count total skin markers (should have some for holes with sufficient spacing).
            skinCount = typeSequence.filter((t) -> t is 'SKIN').length
            expect(skinCount).toBeGreaterThanOrEqual(1)

            return # Explicitly return undefined for Jest.

    describe 'Wall Spacing Validation', ->

        test 'should suppress inner and skin walls when spacing is insufficient', ->

            # Create a torus with narrow spacing on early layers.
            # Torus with radius=5mm, tube=2mm creates narrow gaps on first layers.
            geometry = new THREE.TorusGeometry(5, 2, 16, 32)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 2)
            mesh.updateMatrixWorld()

            # Configure slicer for spacing validation.
            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)  # 2 walls (outer + inner).
            slicer.setShellSkinThickness(0.8)  # Enable skin.
            slicer.setInfillDensity(10)
            slicer.setVerbose(true)

            # Slice the mesh.
            gcode = slicer.slice(mesh)

            # Parse gcode to analyze layers.
            lines = gcode.split('\n')

            # Helper to count markers in a layer (layerNum is 1-based display number).
            countMarkersInLayer = (layerNum, marker) ->

                layerStart = -1
                layerEnd = -1

                for i in [0...lines.length]

                    if lines[i].includes("LAYER: #{layerNum} of")
                        layerStart = i
                    else if layerStart >= 0 and lines[i].includes("LAYER: #{layerNum + 1} of")
                        layerEnd = i
                        break

                return 0 if layerStart < 0

                layerEnd = lines.length if layerEnd < 0

                count = 0

                for i in [layerStart...layerEnd]
                    count++ if lines[i].includes(marker)

                return count

            # Layer 1 (index 0): Should have only outer walls (no inner, skin, or infill).
            # Spacing between paths is ~0.3mm < 0.4mm nozzle diameter.
            layer1Outer = countMarkersInLayer(1, 'TYPE: WALL-OUTER')
            layer1Inner = countMarkersInLayer(1, 'TYPE: WALL-INNER')
            layer1Skin = countMarkersInLayer(1, 'TYPE: SKIN')
            layer1Fill = countMarkersInLayer(1, 'TYPE: FILL')

            expect(layer1Outer).toBeGreaterThan(0)  # Should have outer walls.
            expect(layer1Inner).toBe(0)  # No inner walls (insufficient spacing).
            expect(layer1Skin).toBe(0)  # No skin (insufficient spacing).
            expect(layer1Fill).toBe(0)  # No infill (suppressed with skin).

            # Layer 2 (index 1): Should have outer + inner walls, but no skin or infill.
            # Spacing between innermost walls is ~0.495mm < 0.8mm (2× nozzle diameter).
            layer2Outer = countMarkersInLayer(2, 'TYPE: WALL-OUTER')
            layer2Inner = countMarkersInLayer(2, 'TYPE: WALL-INNER')
            layer2Skin = countMarkersInLayer(2, 'TYPE: SKIN')
            layer2Fill = countMarkersInLayer(2, 'TYPE: FILL')

            expect(layer2Outer).toBeGreaterThan(0)  # Should have outer walls.
            expect(layer2Inner).toBeGreaterThan(0)  # Should have inner walls (sufficient spacing).
            expect(layer2Skin).toBe(0)  # No skin (innermost wall spacing < 0.8mm).
            expect(layer2Fill).toBe(0)  # No infill (suppressed with skin).

            # Layer 3+ (index 2+): Should have all features (sufficient spacing).
            layer3Outer = countMarkersInLayer(3, 'TYPE: WALL-OUTER')
            layer3Inner = countMarkersInLayer(3, 'TYPE: WALL-INNER')
            layer3Skin = countMarkersInLayer(3, 'TYPE: SKIN')

            expect(layer3Outer).toBeGreaterThan(0)  # Should have outer walls.
            expect(layer3Inner).toBeGreaterThan(0)  # Should have inner walls.
            expect(layer3Skin).toBeGreaterThan(0)  # Should have skin (sufficient spacing).

            return # Explicitly return undefined for Jest.

    describe 'Thin-Walled Geometry Support', ->

        test 'should generate inner walls with progressive fallback for thin walls', ->

            # Create a very thin box (25x25x0.6mm) where standard inset would fail.
            # With 0.4mm nozzle and 0.8mm wall thickness, we expect 2 walls.
            # But 0.6mm thickness means inner wall needs progressive fallback.
            geometry = new THREE.BoxGeometry(25, 25, 0.6)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 0.3)
            mesh.updateMatrixWorld()

            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)  # 2 walls expected
            slicer.setNozzleDiameter(0.4)
            slicer.setInfillDensity(20)
            slicer.setVerbose(true)

            gcode = slicer.slice(mesh)
            lines = gcode.split('\n')

            # Count wall types in middle layer
            outerCount = 0
            innerCount = 0
            inMiddleLayer = false

            for line in lines
                if line.includes('LAYER: 2 of')
                    inMiddleLayer = true
                else if inMiddleLayer and line.includes('LAYER: 3 of')
                    break
                else if inMiddleLayer
                    outerCount++ if line.includes('TYPE: WALL-OUTER')
                    innerCount++ if line.includes('TYPE: WALL-INNER')

            # Should have both outer and inner walls even for thin geometry
            expect(outerCount).toBeGreaterThan(0)
            expect(innerCount).toBeGreaterThan(0)

            return

        test 'should generate infill with boundary fallback for thin walls', ->

            # Create a thin cylindrical shell that challenges infill boundary creation
            geometry = new THREE.CylinderGeometry(5, 5, 2, 32)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 1)
            mesh.updateMatrixWorld()

            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setInfillDensity(30)
            slicer.setInfillPattern('grid')
            slicer.setVerbose(true)

            gcode = slicer.slice(mesh)
            lines = gcode.split('\n')

            # Count fill markers
            fillCount = 0
            for line in lines
                fillCount++ if line.includes('TYPE: FILL')

            # Should have infill despite thin walls
            expect(fillCount).toBeGreaterThan(0)

            return

        test 'should handle extremely thin walls with zero-offset fallback', ->

            # Create geometry thin enough that even minimal inset fails
            # This tests the zero-offset fallback (duplicate path)
            geometry = new THREE.BoxGeometry(20, 20, 0.4)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 0.2)
            mesh.updateMatrixWorld()

            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)  # 2 walls expected
            slicer.setNozzleDiameter(0.4)
            slicer.setInfillDensity(15)
            slicer.setVerbose(true)

            gcode = slicer.slice(mesh)

            # Should complete without errors
            expect(gcode).toBeDefined()
            expect(gcode.length).toBeGreaterThan(0)

            lines = gcode.split('\n')

            # Analyze the single layer (0.4mm height = 2 layers)
            layerStart = -1
            layerEnd = -1

            for i in [0...lines.length]
                if lines[i].includes('LAYER: 1 of')
                    layerStart = i
                else if layerStart >= 0 and lines[i].includes('LAYER: 2 of')
                    layerEnd = i
                    break

            return if layerStart < 0

            layerEnd = lines.length if layerEnd < 0

            # Count wall types and extrusion moves
            outerWallCount = 0
            innerWallCount = 0
            outerWallMoves = 0
            innerWallMoves = 0
            inOuterWall = false
            inInnerWall = false

            for i in [layerStart...layerEnd]
                line = lines[i]

                if line.includes('TYPE: WALL-OUTER')
                    outerWallCount++
                    inOuterWall = true
                    inInnerWall = false
                else if line.includes('TYPE: WALL-INNER')
                    innerWallCount++
                    inOuterWall = false
                    inInnerWall = true
                else if line.includes('TYPE:')
                    inOuterWall = false
                    inInnerWall = false

                # Count extrusion moves (G1 with E parameter)
                if line.match(/^G1.*E\d+/)
                    outerWallMoves++ if inOuterWall
                    innerWallMoves++ if inInnerWall

            # Verify both wall types are present
            expect(outerWallCount).toBeGreaterThan(0)
            expect(innerWallCount).toBeGreaterThan(0)

            # Verify both walls have extrusion moves
            expect(outerWallMoves).toBeGreaterThan(0)
            expect(innerWallMoves).toBeGreaterThan(0)

            # Note: When zero-offset fallback is used, inner and outer walls
            # will have similar move counts since they follow the same path.
            # This causes intentional over-extrusion for structural reinforcement
            # of extremely thin walls where no spatial separation is possible.
            # The move counts should be close but may differ slightly due to
            # starting point optimization.
            moveCountRatio = innerWallMoves / outerWallMoves
            expect(moveCountRatio).toBeGreaterThan(0.8)  # Similar move counts
            expect(moveCountRatio).toBeLessThan(1.2)     # Within 20% of each other

            return

        test 'should maintain infill when skin suppressed but boundary valid (sideways dome case)', ->

            # Create a rotated dome-like shape where some layers are thin
            # This tests that infill is generated when possible, even if skin is suppressed
            geometry = new THREE.SphereGeometry(6, 32, 32, 0, Math.PI * 2, 0, Math.PI / 2)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())

            # Rotate to create thin cross-sections
            mesh.rotation.y = Math.PI / 2
            mesh.position.set(0, 0, 6)
            mesh.updateMatrixWorld()

            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8)
            slicer.setInfillDensity(25)
            slicer.setInfillPattern('grid')
            slicer.setVerbose(true)
            slicer.setExposureDetection(false)

            gcode = slicer.slice(mesh)
            lines = gcode.split('\n')

            # Find a middle layer that would have thin walls
            testLayerNum = 15
            layerStart = -1
            layerEnd = -1

            for i in [0...lines.length]
                if lines[i].includes("LAYER: #{testLayerNum} of")
                    layerStart = i
                else if layerStart >= 0 and lines[i].includes("LAYER: #{testLayerNum + 1} of")
                    layerEnd = i
                    break

            return if layerStart < 0

            layerEnd = lines.length if layerEnd < 0

            hasOuter = false
            hasFill = false

            for i in [layerStart...layerEnd]
                hasOuter = true if lines[i].includes('TYPE: WALL-OUTER')
                hasFill = true if lines[i].includes('TYPE: FILL')

            # Should have both outer walls and fill for this geometry
            expect(hasOuter).toBe(true)
            expect(hasFill).toBe(true)

            return

        test 'should handle infill module boundary fallback correctly', ->

            # Test that the infill module's own fallback works
            # Create a box with enough size for infill
            geometry = new THREE.BoxGeometry(20, 20, 4)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 2)
            mesh.updateMatrixWorld()

            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.8)  # 4 skin layers top/bottom
            slicer.setInfillDensity(30)
            slicer.setInfillPattern('grid')
            slicer.setVerbose(true)

            gcode = slicer.slice(mesh)

            # Should complete without errors
            expect(gcode).toBeDefined()
            expect(gcode.length).toBeGreaterThan(0)

            # Count layers with fill (should have middle layers with infill)
            lines = gcode.split('\n')
            layersWithFill = 0
            currentLayerHasFill = false

            for line in lines
                if line.includes('M117 LAYER:')
                    layersWithFill++ if currentLayerHasFill
                    currentLayerHasFill = false
                else if line.includes('TYPE: FILL')
                    currentLayerHasFill = true

            # Last layer check
            layersWithFill++ if currentLayerHasFill

            # Should have infill in middle layers (not just top/bottom skin layers)
            # With 20 layers and 4 skin layers top/bottom, should have ~12 middle layers with infill
            expect(layersWithFill).toBeGreaterThan(5)

            return

    describe 'Single-Pass Skin Wall Generation (PR #54 + PR #55)', ->

        Polytree = null

        beforeAll ->

            { Polytree } = require('@jgphilpott/polytree')

        test 'should generate hole skin walls immediately after regular walls on skin layers', ->

            # This test verifies PR #54: skin walls for holes should be generated
            # immediately after their regular walls (single pass), not in a separate
            # pass after outer boundary skin.

            # Create a sheet with a hole using CSG.
            sheetGeometry = new THREE.BoxGeometry(50, 50, 5)
            sheetMesh = new THREE.Mesh(sheetGeometry, new THREE.MeshBasicMaterial())

            holeRadius = 3
            holeGeometry = new THREE.CylinderGeometry(holeRadius, holeRadius, 10, 32)
            holeMesh = new THREE.Mesh(holeGeometry, new THREE.MeshBasicMaterial())
            holeMesh.rotation.x = Math.PI / 2
            holeMesh.position.set(0, 0, 0)
            holeMesh.updateMatrixWorld()

            # Perform CSG subtraction.
            resultMesh = await Polytree.subtract(sheetMesh, holeMesh)
            finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material)
            finalMesh.position.set(0, 0, 2.5)
            finalMesh.updateMatrixWorld()

            # Configure slicer with skin layers.
            slicer.setShellSkinThickness(0.8)  # 4 skin layers.
            slicer.setShellWallThickness(0.8)  # 2 walls.
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            # Slice the mesh.
            result = slicer.slice(finalMesh)

            # Extract layer 1 (index 0, a skin layer).
            parts = result.split('LAYER: 1 of')
            expect(parts.length).toBeGreaterThan(1)
            layer1 = parts[1].split('LAYER: 2 of')[0]

            # Extract wall type sequence.
            typeMatches = layer1.match(/TYPE: (WALL-OUTER|WALL-INNER|SKIN)/g) || []
            types = typeMatches.map((m) -> m.replace('TYPE: ', ''))

            # Expected sequence on skin layer (with PR #96 structure skin walls):
            # 1. WALL-OUTER (outer boundary)
            # 2. WALL-INNER (outer boundary)
            # 3. SKIN (outer boundary structure skin wall) ← PR #96
            # 4. WALL-OUTER (hole)
            # 5. WALL-INNER (hole)
            # 6. SKIN (hole skin wall) ← immediately after hole walls (PR #54)
            # 7. SKIN (outer boundary skin infill)

            # Verify we have the expected number of wall types.
            expect(types.length).toBe(7)

            # Verify the 3rd element (index 2) is SKIN.
            # This confirms structure skin wall is generated after structure walls.
            expect(types[2]).toBe('SKIN')

            # Verify the 6th element (index 5) is SKIN.
            # This confirms hole skin is generated immediately after hole walls.
            expect(types[5]).toBe('SKIN')

            # Verify we have exactly 2 outer and 2 inner walls.
            outerCount = types.filter((t) -> t is 'WALL-OUTER').length
            innerCount = types.filter((t) -> t is 'WALL-INNER').length
            skinCount = types.filter((t) -> t is 'SKIN').length

            expect(outerCount).toBe(2)  # Outer boundary + hole.
            expect(innerCount).toBe(2)  # Outer boundary + hole.
            expect(skinCount).toBe(3)  # Structure skin wall + hole skin wall + structure skin infill.

            return # Explicitly return undefined for Jest.

        test 'should not generate skin walls on non-skin layers without holes', ->

            # Verify that skin walls are only generated on skin layers.
            # Middle layers without exposure should only have regular walls.
            # Note: This test uses a SOLID sheet (no holes) to verify baseline behavior.

            sheetGeometry = new THREE.BoxGeometry(50, 50, 5)
            sheetMesh = new THREE.Mesh(sheetGeometry, new THREE.MeshBasicMaterial())

            # Position the mesh so Z=0 is the build plate.
            sheetMesh.position.set(0, 0, 2.5)
            sheetMesh.updateMatrixWorld()

            slicer.setShellSkinThickness(0.8)  # 4 skin layers.
            slicer.setShellWallThickness(0.8)
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            result = slicer.slice(sheetMesh)

            # Check middle layer (layer 11 = index 10, not a skin layer).
            parts = result.split('LAYER: 11 of')
            expect(parts.length).toBeGreaterThan(1)
            layer11 = parts[1].split('LAYER: 12 of')[0]

            # Should not have any SKIN markers on middle layers of solid geometry.
            skinMatches = layer11.match(/TYPE: SKIN/g) || []
            expect(skinMatches.length).toBe(0)

            # But should have wall markers.
            wallMatches = layer11.match(/TYPE: WALL/g) || []
            expect(wallMatches.length).toBeGreaterThan(0)

            return # Explicitly return undefined for Jest.

        test 'should NOT generate skin walls for vertical holes on middle layers', ->

            # Verify that vertical holes (holes that go straight through) do NOT generate
            # skin walls on middle layers. Only top and bottom layers should have skin.
            # This fixes the issue where skin walls were incorrectly generated on every layer.

            sheetGeometry = new THREE.BoxGeometry(50, 50, 5)
            sheetMesh = new THREE.Mesh(sheetGeometry, new THREE.MeshBasicMaterial())

            holeRadius = 3
            holeGeometry = new THREE.CylinderGeometry(holeRadius, holeRadius, 10, 32)
            holeMesh = new THREE.Mesh(holeGeometry, new THREE.MeshBasicMaterial())
            holeMesh.rotation.x = Math.PI / 2
            holeMesh.position.set(0, 0, 0)
            holeMesh.updateMatrixWorld()

            resultMesh = await Polytree.subtract(sheetMesh, holeMesh)
            finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material)
            finalMesh.position.set(0, 0, 2.5)
            finalMesh.updateMatrixWorld()

            slicer.setShellSkinThickness(0.8)  # 4 skin layers.
            slicer.setShellWallThickness(0.8)
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)  # Ensure exposure detection is enabled.

            result = slicer.slice(finalMesh)

            # Check middle layer (layer 11 = index 10 at z=2.0mm).
            parts = result.split('LAYER: 11 of')
            expect(parts.length).toBeGreaterThan(1)
            layer11 = parts[1].split('LAYER: 12 of')[0]

            # Middle layers with VERTICAL holes should NOT have skin markers.
            # The hole goes straight through, so there's no exposure.
            skinMatches = layer11.match(/TYPE: SKIN/g) || []
            expect(skinMatches.length).toBe(0)

            # Should still have wall markers (outer and hole walls).
            wallMatches = layer11.match(/TYPE: WALL/g) || []
            expect(wallMatches.length).toBeGreaterThan(0)

            # Top layers should still have skin (layer 22-25 are top 4 layers, index 21-24).
            partsTop = result.split('LAYER: 23 of')
            expect(partsTop.length).toBeGreaterThan(1)
            layer23 = partsTop[1].split('LAYER: 24 of')[0]

            skinMatchesTop = layer23.match(/TYPE: SKIN/g) || []
            expect(skinMatchesTop.length).toBeGreaterThan(0)

            return # Explicitly return undefined for Jest.

        test 'should suppress inner and skin walls when spacing is insufficient (PR #55)', ->

            # This test verifies PR #55: spacing validation should prevent
            # inner and skin walls when paths are too close together.

            # Create a torus with tight spacing on early layers.
            geometry = new THREE.TorusGeometry(5, 2, 16, 32)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)
            mesh.position.set(0, 0, 2)
            mesh.updateMatrixWorld()

            # Configure slicer with standard settings.
            slicer.setShellSkinThickness(0.8)
            slicer.setShellWallThickness(0.8)
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            result = slicer.slice(mesh)

            # Layer 1 (index 0): Spacing is very tight, should only have outer walls.
            parts = result.split('LAYER: 1 of')
            expect(parts.length).toBeGreaterThan(1)
            layer1 = parts[1].split('LAYER: 2 of')[0]

            outerMatches = layer1.match(/TYPE: WALL-OUTER/g) || []
            innerMatches = layer1.match(/TYPE: WALL-INNER/g) || []
            skinMatches = layer1.match(/TYPE: SKIN/g) || []

            # Should have outer walls.
            expect(outerMatches.length).toBeGreaterThan(0)

            # Should NOT have inner or skin walls (insufficient spacing).
            expect(innerMatches.length).toBe(0)
            expect(skinMatches.length).toBe(0)

            return # Explicitly return undefined for Jest.

        test 'should allow inner walls when spacing increases on higher layers', ->

            # As we move up the torus, spacing increases and inner walls
            # should be allowed again.

            geometry = new THREE.TorusGeometry(5, 2, 16, 32)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)
            mesh.position.set(0, 0, 2)
            mesh.updateMatrixWorld()

            slicer.setShellSkinThickness(0.8)
            slicer.setShellWallThickness(0.8)
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            result = slicer.slice(mesh)

            # Layer 2 (index 1): Spacing should be sufficient for inner walls.
            parts = result.split('LAYER: 2 of')
            expect(parts.length).toBeGreaterThan(1)
            layer2 = parts[1].split('LAYER: 3 of')[0]

            outerMatches = layer2.match(/TYPE: WALL-OUTER/g) || []
            innerMatches = layer2.match(/TYPE: WALL-INNER/g) || []

            # Should have both outer and inner walls.
            expect(outerMatches.length).toBeGreaterThan(0)
            expect(innerMatches.length).toBeGreaterThan(0)

            return # Explicitly return undefined for Jest.

    describe 'Exposure Detection', ->

        test 'should generate skin only on top/bottom layers when exposure detection disabled', ->

            # Create a tall cylinder (has middle layers that should not get skin).
            geometry = new THREE.CylinderGeometry(5, 5, 10, 32)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8) # 4 layers of skin.
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(false) # Disabled.

            result = slicer.slice(mesh)

            # Verify we have layers.
            expect(result).toContain('LAYER:')

            # Count skin pattern occurrences (skin uses different pattern than infill).
            # With exposure detection disabled, skin should only appear in top/bottom layers.
            skinPatternMatches = result.match(/TYPE: SKIN/g) || []

            # We should have skin patterns (top and bottom layers).
            expect(skinPatternMatches.length).toBeGreaterThan(0)

            return # Explicitly return undefined for Jest.

        test 'should enable adaptive skin generation when exposure detection enabled', ->

            # Create the same tall cylinder.
            geometry = new THREE.CylinderGeometry(5, 5, 10, 32)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8) # 4 layers of skin.
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true) # Enabled.

            result = slicer.slice(mesh)

            # Verify we have layers.
            expect(result).toContain('LAYER:')

            # With exposure detection enabled, the algorithm should detect exposed surfaces.
            # For a simple cylinder, we may see some adaptive skin behavior, though the
            # exact behavior depends on the geometry coverage calculations.
            skinPatternMatches = result.match(/TYPE: SKIN/g) || []

            # We should still have skin patterns.
            expect(skinPatternMatches.length).toBeGreaterThan(0)

            return # Explicitly return undefined for Jest.

    describe 'Nested Hole/Structure Detection', ->

        Polytree = null

        beforeAll ->

            { Polytree } = require('@jgphilpott/polytree')

        # Helper function to create a hollow cylinder.
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

            # Subtract to create hollow cylinder.
            hollowMesh = await Polytree.subtract(outerMesh, innerMesh)
            finalMesh = new THREE.Mesh(hollowMesh.geometry, hollowMesh.material)

            return finalMesh

        test 'should classify single hollow cylinder correctly (level 0 outer, level 1 hole)', ->

            # Create a single hollow cylinder.
            # This tests the basic case: outer boundary (structure) and inner hole.

            outerRadius = 10
            innerRadius = 8
            height = 5

            # Create outer cylinder.
            outerGeometry = new THREE.CylinderGeometry(outerRadius, outerRadius, height, 32)
            outerMesh = new THREE.Mesh(outerGeometry, new THREE.MeshBasicMaterial())
            outerMesh.rotation.x = Math.PI / 2
            outerMesh.updateMatrixWorld()

            # Create inner cylinder (hole).
            innerGeometry = new THREE.CylinderGeometry(innerRadius, innerRadius, height * 1.2, 32)
            innerMesh = new THREE.Mesh(innerGeometry, new THREE.MeshBasicMaterial())
            innerMesh.rotation.x = Math.PI / 2
            innerMesh.updateMatrixWorld()

            # Subtract to create hollow cylinder.
            hollowMesh = await Polytree.subtract(outerMesh, innerMesh)
            finalMesh = new THREE.Mesh(hollowMesh.geometry, hollowMesh.material)
            finalMesh.position.set(0, 0, height / 2)
            finalMesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setInfillDensity(0)
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            # Slice the mesh.
            result = slicer.slice(finalMesh)

            # Extract first layer.
            lines = result.split('\n')
            layerStartIndex = -1
            layerEndIndex = -1

            for lineIndex in [0...lines.length]
                if lines[lineIndex].includes('LAYER: 1 of')
                    layerStartIndex = lineIndex
                else if layerStartIndex >= 0 and lines[lineIndex].includes('LAYER: 2 of')
                    layerEndIndex = lineIndex
                    break

            layerEndIndex = lines.length if layerEndIndex < 0

            layerLines = lines.slice(layerStartIndex, layerEndIndex)

            # Count wall types.
            outerWallCount = layerLines.filter((line) -> line.includes('TYPE: WALL-OUTER')).length
            innerWallCount = layerLines.filter((line) -> line.includes('TYPE: WALL-INNER')).length

            # Should have 2 outer walls (outer boundary + hole boundary).
            # Should have 2 inner walls (second pass for each).
            expect(outerWallCount).toBe(2)
            expect(innerWallCount).toBe(2)

            # Verify G-code structure is valid.
            expect(result).toContain('WALL-OUTER')
            expect(result).toContain('WALL-INNER')

            return # Explicitly return undefined for Jest.

        test 'should classify 2 nested hollow cylinders correctly (alternating hole/structure)', ->

            # Create 2 nested hollow cylinders.
            # Expected classification:
            # - Cylinder 1 outer: level 0 (structure)
            # - Cylinder 1 inner: level 1 (hole)
            # - Cylinder 2 outer: level 1 (hole, inside Cylinder 1)
            # - Cylinder 2 inner: level 2 (structure, inside hole)

            height = 5
            wallThickness = 1.6
            gap = 2

            # Create innermost cylinder (should be structure - level 2).
            inner = await createHollowCylinder(5 + wallThickness, 5, height)

            # Create middle cylinder (should be hole - level 1).
            middle = await createHollowCylinder(5 + wallThickness + gap + wallThickness, 5 + wallThickness + gap, height)

            # Combine cylinders.
            combined = await Polytree.unite(inner, middle)
            finalMesh = new THREE.Mesh(combined.geometry, combined.material)
            finalMesh.position.set(0, 0, height / 2)
            finalMesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setInfillDensity(0)
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            # Slice the mesh.
            result = slicer.slice(finalMesh)

            # Extract first layer.
            lines = result.split('\n')
            layerStartIndex = -1
            layerEndIndex = -1

            for lineIndex in [0...lines.length]
                if lines[lineIndex].includes('LAYER: 1 of')
                    layerStartIndex = lineIndex
                else if layerStartIndex >= 0 and lines[lineIndex].includes('LAYER: 2 of')
                    layerEndIndex = lineIndex
                    break

            layerEndIndex = lines.length if layerEndIndex < 0

            layerLines = lines.slice(layerStartIndex, layerEndIndex)

            # Count wall types.
            outerWallCount = layerLines.filter((line) -> line.includes('TYPE: WALL-OUTER')).length
            innerWallCount = layerLines.filter((line) -> line.includes('TYPE: WALL-INNER')).length

            # Should have 4 outer walls (2 cylinders × 2 boundaries each).
            # Should have 4 inner walls (second pass for each).
            expect(outerWallCount).toBe(4)
            expect(innerWallCount).toBe(4)

            # Verify G-code is valid.
            expect(result).not.toContain('NaN')
            expect(result).not.toContain('undefined')
            expect(result.length).toBeGreaterThan(1000)

            return # Explicitly return undefined for Jest.

        test 'should classify 3 nested hollow cylinders correctly', ->

            # Create 3 nested hollow cylinders.
            # This tests deeper nesting (up to level 3).

            height = 5
            wallThickness = 1.6
            gap = 2

            # Create innermost cylinder (level 2: structure).
            inner = await createHollowCylinder(5 + wallThickness, 5, height)

            # Create middle cylinder (level 1: hole).
            middle = await createHollowCylinder(5 + wallThickness + gap + wallThickness, 5 + wallThickness + gap, height)

            # Create outer cylinder (level 0: structure).
            outer = await createHollowCylinder(5 + wallThickness + gap + wallThickness + gap + wallThickness, 5 + wallThickness + gap + wallThickness + gap, height)

            # Combine all cylinders.
            combined = await Polytree.unite(inner, middle)
            combined = await Polytree.unite(combined, outer)
            finalMesh = new THREE.Mesh(combined.geometry, combined.material)
            finalMesh.position.set(0, 0, height / 2)
            finalMesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setInfillDensity(0)
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            # Slice the mesh.
            result = slicer.slice(finalMesh)

            # Extract first layer.
            lines = result.split('\n')
            layerStartIndex = -1
            layerEndIndex = -1

            for lineIndex in [0...lines.length]
                if lines[lineIndex].includes('LAYER: 1 of')
                    layerStartIndex = lineIndex
                else if layerStartIndex >= 0 and lines[lineIndex].includes('LAYER: 2 of')
                    layerEndIndex = lineIndex
                    break

            layerEndIndex = lines.length if layerEndIndex < 0

            layerLines = lines.slice(layerStartIndex, layerEndIndex)

            # Count wall types.
            outerWallCount = layerLines.filter((line) -> line.includes('TYPE: WALL-OUTER')).length
            innerWallCount = layerLines.filter((line) -> line.includes('TYPE: WALL-INNER')).length

            # Should have 6 outer walls (3 cylinders × 2 boundaries each).
            # Should have 6 inner walls (second pass for each).
            expect(outerWallCount).toBe(6)
            expect(innerWallCount).toBe(6)

            # Verify alternating pattern: walls should be processed correctly.
            # We can't easily verify exact offset directions from G-code,
            # but we can verify that slicing completes without errors.
            expect(result).not.toContain('NaN')
            expect(result).not.toContain('undefined')
            expect(result.length).toBeGreaterThan(2000)

            return # Explicitly return undefined for Jest.

        test 'should handle box with nested box structures correctly', ->

            # Create a box with a smaller box inside (simulating LEGO brick pattern).
            # Expected: outer box (level 0), inner hole (level 1), inner box (level 2).

            # Create outer box.
            outerGeometry = new THREE.BoxGeometry(20, 20, 5)
            outerMesh = new THREE.Mesh(outerGeometry, new THREE.MeshBasicMaterial())
            outerMesh.updateMatrixWorld()

            # Create hole (to subtract).
            holeGeometry = new THREE.BoxGeometry(16, 16, 6)
            holeMesh = new THREE.Mesh(holeGeometry, new THREE.MeshBasicMaterial())
            holeMesh.updateMatrixWorld()

            # Create inner structure.
            innerGeometry = new THREE.BoxGeometry(10, 10, 6)
            innerMesh = new THREE.Mesh(innerGeometry, new THREE.MeshBasicMaterial())
            innerMesh.updateMatrixWorld()

            # Perform CSG operations.
            hollowBox = await Polytree.subtract(outerMesh, holeMesh)
            finalMesh = await Polytree.unite(hollowBox, innerMesh)

            result = new THREE.Mesh(finalMesh.geometry, finalMesh.material)
            result.position.set(0, 0, 2.5)
            result.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setInfillDensity(0)
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            # Slice the mesh.
            gcode = slicer.slice(result)

            # Verify slicing completed successfully.
            expect(gcode).toBeDefined()
            expect(gcode.length).toBeGreaterThan(500)

            # Verify G-code has wall types.
            expect(gcode).toContain('WALL-OUTER')
            expect(gcode).toContain('WALL-INNER')

            # Verify no NaN or undefined coordinates.
            expect(gcode).not.toContain('NaN')
            expect(gcode).not.toContain('undefined')

            return # Explicitly return undefined for Jest.

        test 'should correctly calculate nesting levels for complex nested paths', ->

            # Create a test case with known nesting levels.
            # We'll use multiple nested cylinders and verify the behavior.

            height = 10
            wallThickness = 1.6
            gap = 2

            # Create 4 nested hollow cylinders.
            cylinders = []

            currentRadius = 5
            for i in [0...4]
                outerRadius = currentRadius + wallThickness
                cylinder = await createHollowCylinder(outerRadius, currentRadius, height)
                cylinders.push(cylinder)
                currentRadius = outerRadius + gap

            # Combine all cylinders.
            combined = cylinders[0]
            for i in [1...cylinders.length]
                combined = await Polytree.unite(combined, cylinders[i])

            finalMesh = new THREE.Mesh(combined.geometry, combined.material)
            finalMesh.position.set(0, 0, height / 2)
            finalMesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setInfillDensity(0)
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            # Slice the mesh.
            result = slicer.slice(finalMesh)

            # Extract first layer to analyze.
            lines = result.split('\n')
            layerStartIndex = -1
            layerEndIndex = -1

            for lineIndex in [0...lines.length]
                if lines[lineIndex].includes('LAYER: 1 of')
                    layerStartIndex = lineIndex
                else if layerStartIndex >= 0 and lines[lineIndex].includes('LAYER: 2 of')
                    layerEndIndex = lineIndex
                    break

            layerEndIndex = lines.length if layerEndIndex < 0

            layerLines = lines.slice(layerStartIndex, layerEndIndex)

            # Count wall types.
            outerWallCount = layerLines.filter((line) -> line.includes('TYPE: WALL-OUTER')).length
            innerWallCount = layerLines.filter((line) -> line.includes('TYPE: WALL-INNER')).length

            # Should have 8 outer walls (4 cylinders × 2 boundaries each).
            # Should have 8 inner walls (second pass for each).
            expect(outerWallCount).toBe(8)
            expect(innerWallCount).toBe(8)

            # Verify G-code is valid and substantial.
            expect(result).not.toContain('NaN')
            expect(result.length).toBeGreaterThan(3000)

            return # Explicitly return undefined for Jest.

        test 'should handle edge case with single path (no nesting)', ->

            # Test with a simple solid cylinder (no holes, level 0 only).

            geometry = new THREE.CylinderGeometry(5, 5, 5, 32)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 2.5)
            mesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellWallThickness(0.8)
            slicer.setInfillDensity(0)
            slicer.setVerbose(true)
            slicer.setAutohome(false)

            # Slice the mesh.
            result = slicer.slice(mesh)

            # Should complete successfully.
            expect(result).toBeDefined()
            expect(result.length).toBeGreaterThan(100)

            # Should have wall markers.
            expect(result).toContain('WALL-OUTER')
            expect(result).toContain('WALL-INNER')

            # No errors.
            expect(result).not.toContain('NaN')

            return # Explicitly return undefined for Jest.

    describe 'Nested Structures Infill Generation', ->

        Polytree = null

        beforeAll ->

            { Polytree } = require('@jgphilpott/polytree')

        # Helper to create a hollow cylinder using CSG.
        createHollowCylinder = (outerRadius, innerRadius, height, segments = 32) ->

            # Create outer cylinder.
            outerGeometry = new THREE.CylinderGeometry(outerRadius, outerRadius, height, segments)
            outerMesh = new THREE.Mesh(outerGeometry, new THREE.MeshBasicMaterial())
            outerMesh.rotation.x = Math.PI / 2
            outerMesh.updateMatrixWorld()

            # Create inner cylinder (hole).
            innerGeometry = new THREE.CylinderGeometry(innerRadius, innerRadius, height * 1.2, segments)
            innerMesh = new THREE.Mesh(innerGeometry, new THREE.MeshBasicMaterial())
            innerMesh.rotation.x = Math.PI / 2
            innerMesh.updateMatrixWorld()

            # Subtract inner from outer.
            hollowMesh = await Polytree.subtract(outerMesh, innerMesh)
            finalMesh = new THREE.Mesh(hollowMesh.geometry, hollowMesh.material)
            finalMesh.position.set(0, 0, height / 2)
            finalMesh.updateMatrixWorld()

            return finalMesh

        test 'should generate infill for single hollow cylinder', ->

            # Create a single hollow cylinder.
            mesh = await createHollowCylinder(10, 5, 1.2)

            # Configure slicer.
            slicer.setShellSkinThickness(0.4)  # 2 layers.
            slicer.setShellWallThickness(0.8)  # 2 walls.
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            result = slicer.slice(mesh)

            # Count infill sections (TYPE: FILL).
            infillMatches = result.match(/TYPE: FILL/g) || []

            # With 6 layers (1.2mm / 0.2mm) and 2 skin layers, expect 2 middle layers with infill.
            # 1 structure × 2 middle layers = 2 infill sections.
            expect(infillMatches.length).toBe(2)

            return # Explicitly return undefined for Jest.

        test 'should generate infill for nested hollow cylinders', ->

            # Create two nested hollow cylinders (matryoshka-style).
            innerCylinder = await createHollowCylinder(10, 5, 1.2)
            outerCylinder = await createHollowCylinder(23, 18, 1.2)

            # Combine using unite.
            combinedMesh = await Polytree.unite(innerCylinder, outerCylinder)
            finalMesh = new THREE.Mesh(combinedMesh.geometry, combinedMesh.material)
            finalMesh.position.set(0, 0, 0.6)
            finalMesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setShellSkinThickness(0.4)  # 2 layers.
            slicer.setShellWallThickness(0.8)  # 2 walls.
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            result = slicer.slice(finalMesh)

            # Count infill sections (TYPE: FILL).
            infillMatches = result.match(/TYPE: FILL/g) || []

            # With 6 layers and 2 skin layers, expect 2 middle layers with infill.
            # 2 structures × 2 middle layers = 4 infill sections.
            expect(infillMatches.length).toBe(4)

            # Verify both structures get infill by checking a middle layer.
            parts = result.split('LAYER: 3 of')
            expect(parts.length).toBeGreaterThan(1)
            layer3 = parts[1].split('LAYER: 4 of')[0]

            layer3InfillMatches = layer3.match(/TYPE: FILL/g) || []
            expect(layer3InfillMatches.length).toBe(2)  # Both structures should have infill.

            return # Explicitly return undefined for Jest.

        test 'should generate infill for three nested hollow cylinders', ->

            # Create three nested hollow cylinders.
            cylinder1 = await createHollowCylinder(10, 5, 1.2)
            cylinder2 = await createHollowCylinder(23, 18, 1.2)
            cylinder3 = await createHollowCylinder(36, 31, 1.2)

            # Combine all using unite.
            combined12 = await Polytree.unite(cylinder1, cylinder2)
            combined123 = await Polytree.unite(combined12, cylinder3)
            finalMesh = new THREE.Mesh(combined123.geometry, combined123.material)
            finalMesh.position.set(0, 0, 0.6)
            finalMesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setShellSkinThickness(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            result = slicer.slice(finalMesh)

            # Count infill sections.
            infillMatches = result.match(/TYPE: FILL/g) || []

            # 3 structures × 2 middle layers = 6 infill sections.
            expect(infillMatches.length).toBe(6)

            # Verify all three structures get infill on a middle layer.
            parts = result.split('LAYER: 3 of')
            expect(parts.length).toBeGreaterThan(1)
            layer3 = parts[1].split('LAYER: 4 of')[0]

            layer3InfillMatches = layer3.match(/TYPE: FILL/g) || []
            expect(layer3InfillMatches.length).toBe(3)  # All three structures should have infill.

            return # Explicitly return undefined for Jest.

        test 'should filter holes by nesting level', ->

            # This test verifies that holes are correctly filtered by nesting level
            # so that nested structures are not excluded by holes at higher levels.

            # Create two nested cylinders.
            innerCylinder = await createHollowCylinder(10, 5, 1.2)
            outerCylinder = await createHollowCylinder(23, 18, 1.2)

            combinedMesh = await Polytree.unite(innerCylinder, outerCylinder)
            finalMesh = new THREE.Mesh(combinedMesh.geometry, combinedMesh.material)
            finalMesh.position.set(0, 0, 0.6)
            finalMesh.updateMatrixWorld()

            slicer.setShellSkinThickness(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            result = slicer.slice(finalMesh)

            # On a middle layer, we should have:
            # - 2 outer structures (level 0 and level 2)
            # - 2 holes (level 1 and level 3)
            # Each structure should generate infill without being excluded by the other structure's hole.

            parts = result.split('LAYER: 3 of')
            expect(parts.length).toBeGreaterThan(1)
            layer3 = parts[1].split('LAYER: 4 of')[0]

            # Count outer walls (one per structure + one per hole).
            outerWallMatches = layer3.match(/TYPE: WALL-OUTER/g) || []
            expect(outerWallMatches.length).toBe(4)  # 2 structures + 2 holes.

            # Count infill (one per structure on middle layers).
            infillMatches = layer3.match(/TYPE: FILL/g) || []
            expect(infillMatches.length).toBe(2)  # Both structures should have infill.

            return # Explicitly return undefined for Jest.

    describe 'Infill/Skin Overlap Prevention with Nested Structures (PR #75 + PR #98 Reconciliation)', ->

        Polytree = null

        beforeAll ->

            { Polytree } = require('@jgphilpott/polytree')

        # Helper to create a hollow cylinder using CSG.
        createHollowCylinder = (outerRadius, innerRadius, height, segments = 32) ->

            # Create outer cylinder.
            outerGeometry = new THREE.CylinderGeometry(outerRadius, outerRadius, height, segments)
            outerMesh = new THREE.Mesh(outerGeometry, new THREE.MeshBasicMaterial())
            outerMesh.rotation.x = Math.PI / 2
            outerMesh.updateMatrixWorld()

            # Create inner cylinder (hole).
            innerGeometry = new THREE.CylinderGeometry(innerRadius, innerRadius, height * 1.2, segments)
            innerMesh = new THREE.Mesh(innerGeometry, new THREE.MeshBasicMaterial())
            innerMesh.rotation.x = Math.PI / 2
            innerMesh.updateMatrixWorld()

            # Subtract inner from outer.
            hollowMesh = await Polytree.subtract(outerMesh, innerMesh)
            finalMesh = new THREE.Mesh(hollowMesh.geometry, hollowMesh.material)
            finalMesh.position.set(0, 0, height / 2)
            finalMesh.updateMatrixWorld()

            return finalMesh

        test 'should prevent infill/skin overlap on absolute top/bottom layers', ->

            # Create a simple hollow cylinder (no nested structures).
            # Verify that on absolute top/bottom layers, both infill and skin are properly managed.
            cylinder = await createHollowCylinder(20, 15, 1.2)
            cylinder.position.set(0, 0, 0.6)
            cylinder.updateMatrixWorld()

            slicer.setShellSkinThickness(0.4)  # 2 layers.
            slicer.setShellWallThickness(0.8)  # 2 walls.
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            result = slicer.slice(cylinder)

            # Top layers should have skin only (no infill due to absolute top/bottom logic).
            # Middle layers should have infill only (no adaptive skin on simple cylinder).
            # This verifies the basic mechanism is working.

            # Check that the result contains both TYPE: FILL and TYPE: SKIN.
            expect(result).toContain('TYPE: FILL')
            expect(result).toContain('TYPE: SKIN')

            # Verify G-code structure is valid.
            expect(result).not.toContain('NaN')
            expect(result).not.toContain('undefined')

            return # Explicitly return undefined for Jest.

        test 'should allow nested structures to generate infill even with skin overlap prevention', ->

            # Create nested hollow cylinders.
            # Verify that nested structures get infill even when outer structure has adaptive skin.
            innerCylinder = await createHollowCylinder(10, 5, 1.2)
            outerCylinder = await createHollowCylinder(23, 18, 1.2)

            combinedMesh = await Polytree.unite(innerCylinder, outerCylinder)
            finalMesh = new THREE.Mesh(combinedMesh.geometry, combinedMesh.material)
            finalMesh.position.set(0, 0, 0.6)
            finalMesh.updateMatrixWorld()

            slicer.setShellSkinThickness(0.4)  # 2 layers.
            slicer.setShellWallThickness(0.8)  # 2 walls.
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            result = slicer.slice(finalMesh)

            # Extract a middle layer.
            parts = result.split('LAYER: 3 of')
            expect(parts.length).toBeGreaterThan(1)
            layer3 = parts[1].split('LAYER: 4 of')[0]

            # Count infill sections - should have one per structure.
            infillMatches = layer3.match(/TYPE: FILL/g) || []
            expect(infillMatches.length).toBe(2)  # Both structures should have infill.

            # Note: Skin generation on middle layers depends on exposure detection.
            # With nested cylinders, the outer cylinder may have exposed areas,
            # so we may or may not have skin depending on the geometry.
            # The key test is that BOTH structures get infill (reconciliation working).

            # Parse infill lines for each structure to verify both get infill.
            infillSections = layer3.split('TYPE: FILL')

            # Remove first element (before first TYPE: FILL).
            infillSections.shift()

            expect(infillSections.length).toBe(2)

            # Each infill section should have extrusion commands.
            for section in infillSections
                # Look for G1 commands with E parameter (extrusion).
                extrusionLines = section.match(/G1\s+X[\d.-]+\s+Y[\d.-]+.*E[\d.]+/g) || []
                expect(extrusionLines.length).toBeGreaterThan(0)

            return # Explicitly return undefined for Jest.

        test 'should verify skin areas are filtered before infill generation', ->

            # Create nested cylinders and verify that skin areas inside holes are filtered out.
            # This is the core mechanism of the reconciliation.
            innerCylinder = await createHollowCylinder(10, 5, 1.2)
            outerCylinder = await createHollowCylinder(23, 18, 1.2)

            combinedMesh = await Polytree.unite(innerCylinder, outerCylinder)
            finalMesh = new THREE.Mesh(combinedMesh.geometry, combinedMesh.material)
            finalMesh.position.set(0, 0, 0.6)
            finalMesh.updateMatrixWorld()

            slicer.setShellSkinThickness(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            result = slicer.slice(finalMesh)

            # Verify overall infill count across all layers.
            # With 6 layers total and 2 skin layers, we have 2 middle layers.
            # 2 structures × 2 middle layers = 4 infill sections expected.
            allInfillMatches = result.match(/TYPE: FILL/g) || []
            expect(allInfillMatches.length).toBe(4)

            # Verify that infill exists on middle layers for both structures.
            # This confirms that the filtering mechanism works correctly.
            for layerNum in [3, 4]  # Middle layers.
                layerParts = result.split("LAYER: #{layerNum} of")
                expect(layerParts.length).toBeGreaterThan(1)

                layer = layerParts[1].split("LAYER: #{layerNum + 1} of")[0]
                layerInfill = layer.match(/TYPE: FILL/g) || []

                # Each middle layer should have infill for both structures.
                expect(layerInfill.length).toBe(2)

            return # Explicitly return undefined for Jest.

        test 'should prevent overlap with three nested structures', ->

            # Test with three nested hollow cylinders to verify the mechanism
            # works with deeper nesting levels.
            cylinder1 = await createHollowCylinder(10, 5, 1.2)
            cylinder2 = await createHollowCylinder(23, 18, 1.2)
            cylinder3 = await createHollowCylinder(36, 31, 1.2)

            combined12 = await Polytree.unite(cylinder1, cylinder2)
            combined123 = await Polytree.unite(combined12, cylinder3)
            finalMesh = new THREE.Mesh(combined123.geometry, combined123.material)
            finalMesh.position.set(0, 0, 0.6)
            finalMesh.updateMatrixWorld()

            slicer.setShellSkinThickness(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            result = slicer.slice(finalMesh)

            # 3 structures × 2 middle layers = 6 infill sections.
            allInfillMatches = result.match(/TYPE: FILL/g) || []
            expect(allInfillMatches.length).toBe(6)

            # Verify a middle layer has all three structures with infill.
            parts = result.split('LAYER: 3 of')
            expect(parts.length).toBeGreaterThan(1)
            layer3 = parts[1].split('LAYER: 4 of')[0]

            layer3Infill = layer3.match(/TYPE: FILL/g) || []
            expect(layer3Infill.length).toBe(3)  # All three structures.

            # Verify the reconciliation is working: all structures get infill.
            # This confirms the fix allows nested structures to generate infill
            # even when overlap prevention is active.

            return # Explicitly return undefined for Jest.

    describe 'Travel Path Optimization for Independent Objects', ->

        # Helper to create a cylinder at a specific position.
        createCylinder = (x, y, z, radius, height) ->
            geometry = new THREE.CylinderGeometry(radius, radius, height, 32)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)
            mesh.position.set(x, y, z)
            mesh.rotation.x = Math.PI / 2  # Rotate to stand upright on Z axis.
            mesh.updateMatrixWorld()
            return mesh

        test 'should start from home position (0,0) on first layer', ->

            # Create two pillars at different positions with enough spacing.
            # Build plate is 220x220mm, centered at (110, 110).
            # We'll place pillars at positions that will result in different distances
            # from home (0, 0) after centering.
            # Pillar 1 at (-30, -30) from center → will be closer to (0, 0) after offset.
            # Pillar 2 at (30, 30) from center → will be farther from (0, 0) after offset.
            pillar1 = createCylinder(-30, -30, 3, 3, 6)
            pillar2 = createCylinder(30, 30, 3, 3, 6)

            group = new THREE.Group()
            group.add(pillar1)
            group.add(pillar2)

            slicer.setLayerHeight(0.2)
            slicer.setExposureDetection(false)  # For sequential completion.
            slicer.setVerbose(true)  # To see movement comments.

            result = slicer.slice(group)

            # Extract first layer (after homing and heating).
            lines = result.split('\n')
            firstLayerStarted = false
            firstWallMove = null

            for line in lines
                if line.includes('LAYER: 1 of')
                    firstLayerStarted = true
                else if firstLayerStarted and line.includes('Moving to wall outer')
                    firstWallMove = line
                    break

            expect(firstWallMove).toBeDefined()

            # Extract X and Y coordinates from the first wall move.
            xMatch = firstWallMove.match(/X([\d.]+)/)
            yMatch = firstWallMove.match(/Y([\d.]+)/)

            expect(xMatch).toBeDefined()
            expect(yMatch).toBeDefined()

            firstX = parseFloat(xMatch[1])
            firstY = parseFloat(yMatch[1])

            # The first position should be closer to the corner (0, 0)
            # than to the opposite corner (220, 220).
            distanceFromHome = Math.sqrt(firstX * firstX + firstY * firstY)
            distanceFromOppositeCorner = Math.sqrt((firstX - 220) * (firstX - 220) + (firstY - 220) * (firstY - 220))

            # Should start from the object closer to home position (0, 0).
            expect(distanceFromHome).toBeLessThan(distanceFromOppositeCorner)

        test 'should use nearest-neighbor sorting for independent objects', ->

            # Create 3 pillars with significant spacing to ensure they remain independent.
            # Use positions relative to center with 30mm+ spacing between them.
            pillarLeft = createCylinder(-40, -40, 3, 3, 6)
            pillarCenter = createCylinder(0, 0, 3, 3, 6)
            pillarRight = createCylinder(40, 40, 3, 3, 6)

            group = new THREE.Group()
            group.add(pillarLeft)
            group.add(pillarCenter)
            group.add(pillarRight)

            slicer.setLayerHeight(0.2)
            slicer.setExposureDetection(false)
            slicer.setVerbose(true)

            result = slicer.slice(group)

            # Count the number of independent outer boundaries in the result.
            # Each pillar should have its own WALL-OUTER.
            wallOuterCount = (result.match(/TYPE: WALL-OUTER/g) || []).length

            # Should have at least 1 WALL-OUTER marker per layer (merged or individual).
            # With 6 layers (6mm height / 0.2mm layer height), should have at least 6 total.
            expect(wallOuterCount).toBeGreaterThanOrEqual(6)

            # Extract first layer wall movements to verify nearest-neighbor logic exists.
            lines = result.split('\n')
            firstLayerStarted = false
            wallMoves = []

            for line in lines
                if line.includes('LAYER: 1 of')
                    firstLayerStarted = true
                else if firstLayerStarted and line.includes('LAYER: 2 of')
                    break
                else if firstLayerStarted and line.includes('Moving to wall outer')
                    xMatch = line.match(/X([\d.]+)/)
                    yMatch = line.match(/Y([\d.]+)/)
                    if xMatch and yMatch
                        wallMoves.push({ x: parseFloat(xMatch[1]), y: parseFloat(yMatch[1]) })

            # Should have at least 1 wall move.
            expect(wallMoves.length).toBeGreaterThanOrEqual(1)

            # If we have multiple wall moves, verify they're not just the same position repeated.
            if wallMoves.length > 1
                # Verify positions are distinct (not all the same pillar).
                for i in [0...wallMoves.length - 1]
                    current = wallMoves[i]
                    next = wallMoves[i + 1]

                    # Check if positions are different.
                    xDiff = Math.abs(next.x - current.x)
                    yDiff = Math.abs(next.y - current.y)

                    # At least one coordinate should differ by more than 1mm.
                    expect(xDiff + yDiff).toBeGreaterThan(1)

        test 'should complete each object before moving to next (sequential completion)', ->

            # Create 2 independent pillars with enough spacing.
            pillar1 = createCylinder(-30, -30, 3, 3, 6)
            pillar2 = createCylinder(30, 30, 3, 3, 6)

            group = new THREE.Group()
            group.add(pillar1)
            group.add(pillar2)

            slicer.setLayerHeight(0.2)
            slicer.setExposureDetection(false)  # Required for sequential completion.
            slicer.setVerbose(true)

            result = slicer.slice(group)

            # Extract first layer to verify object completion order.
            lines = result.split('\n')
            firstLayerStarted = false
            typeSequence = []

            for line in lines
                if line.includes('LAYER: 1 of')
                    firstLayerStarted = true
                else if firstLayerStarted and line.includes('LAYER: 2 of')
                    break
                else if firstLayerStarted
                    if line.includes('TYPE: WALL-OUTER')
                        typeSequence.push('WALL-OUTER')
                    else if line.includes('TYPE: WALL-INNER')
                        typeSequence.push('WALL-INNER')
                    else if line.includes('TYPE: SKIN')
                        typeSequence.push('SKIN')

            # Should have type markers.
            expect(typeSequence.length).toBeGreaterThan(0)

            # For sequential completion, the pattern should be:
            # Object 1: WALL-OUTER → WALL-INNER (optional) → SKIN
            # Object 2: WALL-OUTER → WALL-INNER (optional) → SKIN
            # Find the first SKIN marker (end of first object).
            firstSkinIndex = typeSequence.indexOf('SKIN')

            if firstSkinIndex >= 0
                # After the first SKIN, should have another WALL-OUTER (start of second object).
                secondWallIndex = -1
                for i in [firstSkinIndex + 1...typeSequence.length]
                    if typeSequence[i] is 'WALL-OUTER'
                        secondWallIndex = i
                        break

                # If we have a second object, it should start after the first object's SKIN.
                if secondWallIndex >= 0
                    expect(secondWallIndex).toBeGreaterThan(firstSkinIndex)

            # At minimum, verify we have both WALL and SKIN types present.
            hasWall = typeSequence.includes('WALL-OUTER') or typeSequence.includes('WALL-INNER')
            hasSkin = typeSequence.includes('SKIN')

            expect(hasWall).toBe(true)
            expect(hasSkin).toBe(true)

        test 'should defer to Phase 2 when exposure detection is enabled', ->

            # Create 2 independent pillars with exposure detection enabled.
            pillar1 = createCylinder(-30, -30, 3, 3, 6)
            pillar2 = createCylinder(30, 30, 3, 3, 6)

            group = new THREE.Group()
            group.add(pillar1)
            group.add(pillar2)

            slicer.setLayerHeight(0.2)
            slicer.setExposureDetection(true)  # Enable exposure detection.
            slicer.setVerbose(true)

            result = slicer.slice(group)

            # With exposure detection enabled, objects should still slice successfully.
            # The key is that the sequential completion optimization is bypassed,
            # and Phase 2 handles the skin/infill generation.
            expect(result).toContain('G28')  # Should complete successfully.
            expect(result).toContain('WALL')  # Should have walls.
            expect(result).toContain('SKIN')  # Should have skin.

            # Verify that slicing completes without errors.
            expect(result.length).toBeGreaterThan(1000)

            return # Explicitly return undefined for Jest.

        test 'should use sequential completion for top/bottom layers with exposure detection enabled', ->

            # Helper to create merged mesh from multiple cylinders.
            # This is an async test because we need to dynamically import BufferGeometryUtils.
            createMergedPillars = ->

                # Create two separate cylinders.
                geometry1 = new THREE.CylinderGeometry(3, 3, 1.2, 32)
                mesh1 = new THREE.Mesh(geometry1, new THREE.MeshBasicMaterial())
                mesh1.rotation.x = Math.PI / 2
                mesh1.position.set(-5, 0, 0.6)
                mesh1.updateMatrixWorld()
                geo1 = mesh1.geometry.clone()
                geo1.applyMatrix4(mesh1.matrixWorld)

                geometry2 = new THREE.CylinderGeometry(3, 3, 1.2, 32)
                mesh2 = new THREE.Mesh(geometry2, new THREE.MeshBasicMaterial())
                mesh2.rotation.x = Math.PI / 2
                mesh2.position.set(5, 0, 0.6)
                mesh2.updateMatrixWorld()
                geo2 = mesh2.geometry.clone()
                geo2.applyMatrix4(mesh2.matrixWorld)

                # Merge geometries using dynamic import.
                return import('three/examples/jsm/utils/BufferGeometryUtils.js').then (mod) ->

                    # Use the mergeGeometries function from the module.
                    # The module may export it directly or via BufferGeometryUtils namespace.
                    mergeFunc = mod.mergeGeometries or mod.BufferGeometryUtils?.mergeGeometries
                    mergedGeometry = mergeFunc([geo1, geo2], false)
                    mergedMesh = new THREE.Mesh(mergedGeometry, new THREE.MeshBasicMaterial())
                    mergedMesh.updateMatrixWorld()

                    return mergedMesh

            # Return promise for async test.
            return createMergedPillars().then (mergedMesh) ->

                # Configure slicer with exposure detection enabled.
                slicer.setLayerHeight(0.2)
                slicer.setShellSkinThickness(0.4)  # 2 layers top/bottom
                slicer.setExposureDetection(true)  # This is the key - exposure detection enabled!
                slicer.setVerbose(true)

                result = slicer.slice(mergedMesh)

                # Analyze the G-code pattern for last layer (top layer).
                lines = result.split('\n')
                lastLayerStart = -1

                for i in [0...lines.length]

                    if lines[i].includes('LAYER: 6 of')
                        lastLayerStart = i
                        break

                expect(lastLayerStart).toBeGreaterThan(-1)

                # Extract last layer content (from LAYER: 6 to end).
                lastLayerLines = lines[lastLayerStart...]
                lastLayerContent = lastLayerLines.join('\n')

                # For top/bottom layers with independent objects and exposure detection enabled,
                # we should see sequential completion: WALL-OUTER → WALL-INNER → SKIN (per pillar).
                # Count how many times we see WALL followed by SKIN (sequential completion pattern).
                wallToSkinTransitions = 0
                prevLineHadWall = false

                for line in lastLayerLines

                    if line.includes('TYPE: WALL')
                        prevLineHadWall = true
                    else if line.includes('TYPE: SKIN') and prevLineHadWall
                        wallToSkinTransitions++
                        prevLineHadWall = false
                    else if line.includes('TYPE:')
                        # Other type, reset
                        prevLineHadWall = false

                # With sequential completion, we expect at least 2 wall-to-skin transitions
                # (one for each pillar on this top layer).
                expect(wallToSkinTransitions).toBeGreaterThanOrEqual(2)

                # Verify the G-code contains expected elements.
                expect(result).toContain('WALL-OUTER')
                expect(result).toContain('SKIN')
                expect(result.length).toBeGreaterThan(1000)

                return # Explicitly return undefined for Jest.

        test 'should use sequential completion for infill layers even with exposure detection enabled', ->

            # Helper to create merged mesh from multiple cylinders.
            # This is an async test because we need to dynamically import BufferGeometryUtils.
            createMergedPillars = ->

                # Create two separate cylinders.
                geometry1 = new THREE.CylinderGeometry(3, 3, 6, 32)
                mesh1 = new THREE.Mesh(geometry1, new THREE.MeshBasicMaterial())
                mesh1.rotation.x = Math.PI / 2
                mesh1.position.set(-30, -30, 3)
                mesh1.updateMatrixWorld()
                geo1 = mesh1.geometry.clone()
                geo1.applyMatrix4(mesh1.matrixWorld)

                geometry2 = new THREE.CylinderGeometry(3, 3, 6, 32)
                mesh2 = new THREE.Mesh(geometry2, new THREE.MeshBasicMaterial())
                mesh2.rotation.x = Math.PI / 2
                mesh2.position.set(30, 30, 3)
                mesh2.updateMatrixWorld()
                geo2 = mesh2.geometry.clone()
                geo2.applyMatrix4(mesh2.matrixWorld)

                # Merge geometries using dynamic import.
                return import('three/examples/jsm/utils/BufferGeometryUtils.js').then (mod) ->

                    # Use the mergeGeometries function from the module.
                    mergeFunc = mod.mergeGeometries or mod.BufferGeometryUtils?.mergeGeometries
                    mergedGeometry = mergeFunc([geo1, geo2], false)
                    mergedMesh = new THREE.Mesh(mergedGeometry, new THREE.MeshBasicMaterial())
                    mergedMesh.updateMatrixWorld()

                    return mergedMesh

            # Return promise for async test.
            return createMergedPillars().then (mergedMesh) ->

                # Configure slicer with exposure detection enabled (default).
                # Sequential completion should work for independent objects regardless.
                slicer.setLayerHeight(0.2)
                slicer.setShellSkinThickness(0.4)  # 2 layers top/bottom
                slicer.setExposureDetection(true)  # Keep enabled (default)
                slicer.setInfillDensity(50)  # Enable infill
                slicer.setVerbose(true)

                result = slicer.slice(mergedMesh)

                # Analyze layer 4 (middle infill layer).
                # With 6mm height / 0.2mm layer height = 30 layers
                # Skin: layers 1-2 (bottom) and 29-30 (top)
                # Infill: layers 3-28
                lines = result.split('\n')
                layer4Start = -1
                layer5Start = -1

                for i in [0...lines.length]
                    if lines[i].includes('LAYER: 4 of')
                        layer4Start = i
                    else if layer4Start >= 0 and lines[i].includes('LAYER: 5 of')
                        layer5Start = i
                        break

                expect(layer4Start).toBeGreaterThan(-1)
                expect(layer5Start).toBeGreaterThan(-1)

                # Extract layer 4 content.
                layer4Lines = lines[layer4Start...layer5Start]
                typeSequence = []

                for line in layer4Lines
                    if line.includes('TYPE: WALL-OUTER')
                        typeSequence.push('WALL-OUTER')
                    else if line.includes('TYPE: WALL-INNER')
                        typeSequence.push('WALL-INNER')
                    else if line.includes('TYPE: FILL')
                        typeSequence.push('FILL')

                # Verify we have infill on this layer.
                hasFill = typeSequence.includes('FILL')
                expect(hasFill).toBe(true)

                # For sequential completion on infill layers, the pattern should be:
                # Pillar 1: WALL-OUTER → WALL-INNER → FILL
                # Pillar 2: WALL-OUTER → WALL-INNER → FILL
                # This is NOT:
                # All walls first: WALL-OUTER → WALL-INNER → WALL-OUTER → WALL-INNER
                # Then all fills: FILL → FILL

                # Count wall-to-fill transitions (sequential completion pattern).
                wallToFillTransitions = 0
                prevLineHadWall = false

                for type in typeSequence
                    if type is 'WALL-OUTER' or type is 'WALL-INNER'
                        prevLineHadWall = true
                    else if type is 'FILL' and prevLineHadWall
                        wallToFillTransitions++
                        prevLineHadWall = false
                    else
                        prevLineHadWall = false

                # With sequential completion, we expect at least 2 wall-to-fill transitions
                # (one for each pillar on this infill layer).
                # If the old two-pass behavior was happening, there would be only 1 transition.
                expect(wallToFillTransitions).toBeGreaterThanOrEqual(2)

                # Verify the G-code contains expected elements.
                expect(result).toContain('WALL-OUTER')
                expect(result).toContain('FILL')
                expect(result.length).toBeGreaterThan(1000)

                return # Explicitly return undefined for Jest.

    describe 'Mesh Complexity Warnings', ->

        # Suppress console.warn during tests to avoid cluttering test output
        originalWarn = null

        beforeEach ->
            originalWarn = console.warn
            console.warn = jest.fn()

        afterEach ->
            console.warn = originalWarn

        test 'should NOT warn for simple meshes', ->

            # Create a simple cube
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())

            result = slicer.slice(mesh)

            # Should not have called console.warn
            expect(console.warn).not.toHaveBeenCalled()
            expect(result.length).toBeGreaterThan(0)

        test 'should warn for medium complexity meshes', (done) ->

            # Create a medium complexity sphere (score > 1M)
            # Sphere(15, 64, 64) = 1.2M complexity score
            geometry = new THREE.SphereGeometry(15, 64, 64)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())

            # Configure for faster slicing
            slicer.setInfillDensity(0)  # No infill to speed up
            slicer.setExposureDetection(false)  # Disable exposure detection

            result = slicer.slice(mesh)

            # Should have warned about high complexity
            expect(console.warn).toHaveBeenCalled()
            expect(console.warn.mock.calls[0][0]).toContain('High mesh complexity detected')
            expect(result.length).toBeGreaterThan(0)
            done()

        , 30000  # 30 second timeout

        test 'should show critical warning for very complex meshes', (done) ->

            # Create a high complexity sphere (score > 5M)
            # Sphere(30, 96, 96) = 5.5M complexity score
            geometry = new THREE.SphereGeometry(30, 96, 96)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())

            # Configure for faster slicing
            slicer.setInfillDensity(0)  # No infill to speed up
            slicer.setExposureDetection(false)  # Disable exposure detection

            result = slicer.slice(mesh)

            # Should have warned about very high complexity
            expect(console.warn).toHaveBeenCalled()
            warningText = console.warn.mock.calls[0][0]
            expect(warningText).toContain('Very high mesh complexity detected')
            expect(result.length).toBeGreaterThan(0)
            done()

        , 90000  # 90 second timeout (this mesh takes ~20s to slice)
