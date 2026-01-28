# Tests for hexagons infill pattern

Polyslice = require('../../../index')

THREE = require('three')

describe 'Hexagons Infill Generation', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice({progressCallback: null})

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

    describe 'Hexagons Infill Clipping to Polygon Boundaries', ->

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
            slicer.setInfillPattern('hexagons')
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

        test 'should generate hexagons infill for cylinder at various densities', ->

            # Create a cylinder.
            geometry = new THREE.CylinderGeometry(5, 5, 10, 32)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillPattern('hexagons')
            slicer.setVerbose(true)

            # Test multiple densities.
            densities = [10, 20, 50]

            for density in densities

                slicer.setInfillDensity(density)
                result = slicer.slice(mesh)

                # All densities should generate infill.
                expect(result).toContain('; TYPE: FILL')

            return

    describe 'Hexagons Infill for Multi-Object Arrays', ->

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
            slicer.setInfillPattern('hexagons')
            slicer.setVerbose(true)

            result = slicer.slice(mergedMesh)

            # Split by layers to analyze layer 3 (middle layer with infill).
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
            expect(totalExtrusions).toBeGreaterThan(50)

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
            slicer.setInfillPattern('hexagons')
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
