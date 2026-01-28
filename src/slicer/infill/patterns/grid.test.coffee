# Tests for grid infill pattern

Polyslice = require('../../../index')

THREE = require('three')

describe 'Grid Infill Generation', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice({progressCallback: null})

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

    describe 'Grid Infill Clipping to Polygon Boundaries', ->

        test 'should clip infill to circular boundary instead of bounding box', ->

            # Create a cylinder (circular cross-section).
            geometry = new THREE.CylinderGeometry(5, 5, 10, 32)
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

            # Parse G-code to find infill coordinates for a middle layer.
            lines = result.split('\n')
            inFill = false
            infillCoords = []
            targetLayer = 10
            currentLayer = null

            for line in lines

                if line.includes('LAYER:')
                    layerMatch = line.match(/LAYER: (\d+)/)
                    currentLayer = if layerMatch then parseInt(layerMatch[1]) else null

                continue if currentLayer isnt targetLayer

                if line.includes('; TYPE: FILL')
                    inFill = true
                    continue

                if line.includes('; TYPE:') and not line.includes('FILL')
                    inFill = false

                if inFill and line.includes('G1') and line.includes('X') and line.includes('Y')

                    xMatch = line.match(/X([\d.]+)/)
                    yMatch = line.match(/Y([\d.]+)/)

                    if xMatch and yMatch
                        infillCoords.push({
                            x: parseFloat(xMatch[1])
                            y: parseFloat(yMatch[1])
                        })

                if line.includes("LAYER: #{targetLayer + 1}")
                    break

            # Verify we have infill coordinates.
            expect(infillCoords.length).toBeGreaterThan(0)

            # For a cylinder with radius 5mm, all infill points should be within
            # the circular boundary (radius ~5mm).
            # First calculate the actual center from the coordinates.
            xs = infillCoords.map((c) -> c.x)
            ys = infillCoords.map((c) -> c.y)
            centerX = (Math.min(...xs) + Math.max(...xs)) / 2
            centerY = (Math.min(...ys) + Math.max(...ys)) / 2

            # Allow tolerance for numerical precision, nozzle width, and wall inset.
            radius = 5
            tolerance = 1.0

            for coord in infillCoords

                # Calculate distance from actual center.
                dx = coord.x - centerX
                dy = coord.y - centerY
                distance = Math.sqrt(dx * dx + dy * dy)

                # Distance should be less than radius + tolerance.
                # This ensures infill doesn't extend to rectangular bounding box corners.
                expect(distance).toBeLessThan(radius + tolerance)

            return

        test 'should generate infill for cylinder at all densities', ->

            # Create a cylinder.
            geometry = new THREE.CylinderGeometry(5, 5, 10, 32)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillPattern('grid')
            slicer.setVerbose(true)

            # Test multiple densities.
            densities = [10, 20, 50, 100]

            for density in densities

                slicer.setInfillDensity(density)
                result = slicer.slice(mesh)

                # All densities should generate infill.
                expect(result).toContain('; TYPE: FILL')

            return

        test 'should handle cone with varying circular cross-sections', ->

            # Create a cone (circular cross-sections of different sizes).
            geometry = new THREE.ConeGeometry(5, 10, 32)
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

            # Should generate infill.
            expect(result).toContain('; TYPE: FILL')

            # Parse G-code and verify infill coordinates stay within boundaries.
            # For a cone, the radius decreases as we go up, so check a middle layer.
            lines = result.split('\n')
            inFill = false
            layerInfillCoords = {}
            currentLayer = null

            for line in lines

                if line.includes('LAYER:')
                    layerMatch = line.match(/LAYER: (\d+)/)
                    currentLayer = if layerMatch then parseInt(layerMatch[1]) else null

                    if currentLayer and not layerInfillCoords[currentLayer]
                        layerInfillCoords[currentLayer] = []

                if line.includes('; TYPE: FILL')
                    inFill = true
                    continue

                if line.includes('; TYPE:') and not line.includes('FILL')
                    inFill = false

                if inFill and currentLayer and line.includes('G1') and line.includes('X') and line.includes('Y')

                    xMatch = line.match(/X([\d.]+)/)
                    yMatch = line.match(/Y([\d.]+)/)

                    if xMatch and yMatch
                        layerInfillCoords[currentLayer].push({
                            x: parseFloat(xMatch[1])
                            y: parseFloat(yMatch[1])
                        })

            # Verify we have infill on multiple layers (should decrease as cone narrows).
            layersWithInfill = Object.keys(layerInfillCoords).filter((k) -> layerInfillCoords[k].length > 0)

            expect(layersWithInfill.length).toBeGreaterThan(5)

            # For cone, higher layers should have smaller or no infill area as radius decreases.
            # Just verify the pattern is reasonable - not checking exact radius constraints.
            return

    describe 'Grid Infill for Multi-Object Arrays', ->

        test 'should generate infill for all pillars in 3x3 array', ->

            # Import BufferGeometryUtils for merging geometries.
            BufferGeometryUtils = null

            try
                mod = require('three/examples/jsm/utils/BufferGeometryUtils.js')
                BufferGeometryUtils = mod
            catch error
                # Skip test if module not available.
                return

            # Create a 3x3 array of cylinders (pillars).
            pillarRadius = 3
            pillarHeight = 1.2
            spacing = 10 # mm between centers

            geometries = []

            for row in [0...3]
                for col in [0...3]
                    x = -spacing + col * spacing
                    y = -spacing + row * spacing

                    cylinder = new THREE.CylinderGeometry(pillarRadius, pillarRadius, pillarHeight, 32)
                    mesh = new THREE.Mesh(cylinder)
                    mesh.rotation.x = Math.PI / 2
                    mesh.position.set(x, y, pillarHeight / 2)
                    mesh.updateMatrixWorld()

                    geom = mesh.geometry.clone()
                    geom.applyMatrix4(mesh.matrixWorld)
                    geometries.push(geom)

            # Merge all geometries into one mesh.
            mergedGeometry = BufferGeometryUtils.mergeGeometries(geometries, false)
            mergedMesh = new THREE.Mesh(mergedGeometry)

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8) # 2 walls
            slicer.setShellSkinThickness(0.4) # 2 skin layers (bottom + top)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(50)
            slicer.setInfillPattern('grid')
            slicer.setVerbose(true)

            result = slicer.slice(mergedMesh)

            # Split by layers to analyze layer 3 (middle layer with infill).
            # Layer 1-2 are bottom skin, Layer 5-6 are top skin.
            layers = result.split('M117 LAYER:')

            expect(layers.length).toBeGreaterThan(3)

            layer3 = layers[3]

            # Count infill sections.
            infillSections = layer3.split('; TYPE: FILL')

            # Should have 9 infill sections (one per pillar).
            expect(infillSections.length - 1).toBe(9)

            # Count extrusion moves per infill section.
            emptyCount = 0
            totalExtrusions = 0

            for i in [1...infillSections.length]
                section = infillSections[i]

                # Count G1 moves with E parameter (extrusion).
                extrusions = section.match(/G1\s+X[\d.]+\s+Y[\d.]+.*?E[\d.]+/g)
                lineCount = if extrusions then extrusions.length else 0
                totalExtrusions += lineCount

                if lineCount is 0
                    emptyCount++

            # All 9 pillars should have infill (no empty sections).
            expect(emptyCount).toBe(0)

            # Each pillar should have multiple extrusion lines.
            # With 50% density and grid pattern, expect ~6 lines per pillar (3 per direction).
            expect(totalExtrusions).toBeGreaterThan(50)

            return

        test 'should generate infill for edge and corner pillars equally', ->

            # Import BufferGeometryUtils for merging geometries.
            BufferGeometryUtils = null

            try
                mod = require('three/examples/jsm/utils/BufferGeometryUtils.js')
                BufferGeometryUtils = mod
            catch error
                # Skip test if module not available.
                return

            # Create a 3x3 array to test edge vs corner pillars.
            pillarRadius = 3
            pillarHeight = 1.2
            spacing = 10

            geometries = []
            pillarPositions = []

            for row in [0...3]
                for col in [0...3]
                    x = -spacing + col * spacing
                    y = -spacing + row * spacing
                    pillarPositions.push({ x, y, row, col })

                    cylinder = new THREE.CylinderGeometry(pillarRadius, pillarRadius, pillarHeight, 32)
                    mesh = new THREE.Mesh(cylinder)
                    mesh.rotation.x = Math.PI / 2
                    mesh.position.set(x, y, pillarHeight / 2)
                    mesh.updateMatrixWorld()

                    geom = mesh.geometry.clone()
                    geom.applyMatrix4(mesh.matrixWorld)
                    geometries.push(geom)

            mergedGeometry = BufferGeometryUtils.mergeGeometries(geometries, false)
            mergedMesh = new THREE.Mesh(mergedGeometry)

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(50)
            slicer.setInfillPattern('grid')
            slicer.setVerbose(true)

            result = slicer.slice(mergedMesh)

            # Analyze layer 3.
            layers = result.split('M117 LAYER:')
            layer3 = layers[3]

            # Split by TYPE markers to get each infill section.
            parts = layer3.split(/; TYPE: (WALL-OUTER|WALL-INNER|FILL)/)

            # Count lines per infill section.
            infillLineCounts = []

            for i in [0...parts.length]
                if parts[i] is 'FILL' and i + 1 < parts.length
                    section = parts[i + 1]
                    extrusions = section.match(/G1\s+X[\d.]+\s+Y[\d.]+.*?E[\d.]+/g)
                    lineCount = if extrusions then extrusions.length else 0
                    infillLineCounts.push(lineCount)

            # All 9 sections should have infill.
            expect(infillLineCounts.length).toBe(9)

            # All sections should have roughly equal infill (within tolerance).
            # For grid pattern with 50% density, expect ~6 lines each.
            minLines = Math.min(...infillLineCounts)
            maxLines = Math.max(...infillLineCounts)

            # All pillars should have at least some infill.
            expect(minLines).toBeGreaterThan(0)

            # Variance should be reasonable (all pillars similar).
            # Allow for edge effects, but all should be within 50% of each other.
            expect(maxLines).toBeLessThan(minLines * 2)

            return

        test 'should handle 2x2, 4x4, and 5x5 pillar arrays', ->

            # Import BufferGeometryUtils for merging geometries.
            BufferGeometryUtils = null

            try
                mod = require('three/examples/jsm/utils/BufferGeometryUtils.js')
                BufferGeometryUtils = mod
            catch error
                # Skip test if module not available.
                return

            pillarRadius = 3
            pillarHeight = 1.2
            spacing = 10

            # Test different grid sizes.
            gridSizes = [2, 4, 5]

            for gridSize in gridSizes

                geometries = []

                for row in [0...gridSize]
                    for col in [0...gridSize]
                        x = -(gridSize - 1) * spacing / 2 + col * spacing
                        y = -(gridSize - 1) * spacing / 2 + row * spacing

                        cylinder = new THREE.CylinderGeometry(pillarRadius, pillarRadius, pillarHeight, 32)
                        mesh = new THREE.Mesh(cylinder)
                        mesh.rotation.x = Math.PI / 2
                        mesh.position.set(x, y, pillarHeight / 2)
                        mesh.updateMatrixWorld()

                        geom = mesh.geometry.clone()
                        geom.applyMatrix4(mesh.matrixWorld)
                        geometries.push(geom)

                mergedGeometry = BufferGeometryUtils.mergeGeometries(geometries, false)
                mergedMesh = new THREE.Mesh(mergedGeometry)

                slicer.setNozzleDiameter(0.4)
                slicer.setShellWallThickness(0.8)
                slicer.setShellSkinThickness(0.4)
                slicer.setLayerHeight(0.2)
                slicer.setInfillDensity(50)
                slicer.setInfillPattern('grid')
                slicer.setVerbose(true)

                result = slicer.slice(mergedMesh)

                # Analyze layer 3.
                layers = result.split('M117 LAYER:')
                layer3 = layers[3]

                # Count infill sections.
                infillSections = layer3.split('; TYPE: FILL').length - 1

                expectedPillars = gridSize * gridSize

                # Should have one infill section per pillar.
                expect(infillSections).toBe(expectedPillars)

                # Count empty sections.
                parts = layer3.split('; TYPE: FILL')
                emptyCount = 0

                for i in [1...parts.length]
                    extrusions = parts[i].match(/G1\s+X[\d.]+\s+Y[\d.]+.*?E[\d.]+/g)
                    if not extrusions or extrusions.length is 0
                        emptyCount++

                # No pillar should be missing infill.
                expect(emptyCount).toBe(0)

            return

        test 'should center infill on boundary not global origin', ->

            # This test verifies the fix: infill is centered on each boundary's center
            # rather than the global origin (0, 0).

            # Create a single pillar offset from origin.
            pillarRadius = 3
            pillarHeight = 1.2
            offsetX = 20 # Offset from origin
            offsetY = 15

            cylinder = new THREE.CylinderGeometry(pillarRadius, pillarRadius, pillarHeight, 32)
            mesh = new THREE.Mesh(cylinder)
            mesh.rotation.x = Math.PI / 2
            mesh.position.set(offsetX, offsetY, pillarHeight / 2)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(50)
            slicer.setInfillPattern('grid')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Analyze layer 3.
            layers = result.split('M117 LAYER:')
            layer3 = layers[3]

            # Should have infill.
            expect(layer3).toContain('; TYPE: FILL')

            # Count extrusion moves in infill.
            fillSection = layer3.split('; TYPE: FILL')[1]

            if fillSection
                extrusions = fillSection.match(/G1\s+X[\d.]+\s+Y[\d.]+.*?E[\d.]+/g)

                # Should have infill lines even though pillar is offset from origin.
                expect(extrusions).toBeTruthy()
                expect(extrusions.length).toBeGreaterThan(0)

            return
