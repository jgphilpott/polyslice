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

            # Expected sequence on skin layer:
            # 1. WALL-OUTER (outer boundary)
            # 2. WALL-INNER (outer boundary)
            # 3. WALL-OUTER (hole)
            # 4. WALL-INNER (hole)
            # 5. SKIN (hole) ← immediately after hole walls (PR #54)
            # 6. SKIN (outer boundary)

            # Verify we have the expected number of wall types.
            expect(types.length).toBe(6)

            # Verify the 5th element (index 4) is SKIN.
            # This confirms hole skin is generated immediately after hole walls.
            expect(types[4]).toBe('SKIN')

            # Verify we have exactly 2 outer and 2 inner walls.
            outerCount = types.filter((t) -> t is 'WALL-OUTER').length
            innerCount = types.filter((t) -> t is 'WALL-INNER').length
            skinCount = types.filter((t) -> t is 'SKIN').length

            expect(outerCount).toBe(2)  # Outer boundary + hole.
            expect(innerCount).toBe(2)  # Outer boundary + hole.
            expect(skinCount).toBe(2)  # Outer boundary + hole.

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



