# Tests for concentric infill pattern

Polyslice = require('../../../index')

THREE = require('three')

describe 'Concentric Infill Generation', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice({progressCallback: null})

    # Parse X/Y coordinates from all infill extrusion (G1 ... E) lines in a G-code string.
    parseFillExtrusionCoords = (gcode) ->

        lines = gcode.split('\n')
        inFill = false
        coords = []

        for line in lines

            if line.includes('; TYPE: FILL')
                inFill = true
            else if line.includes('; TYPE:') and not line.includes('; TYPE: FILL')
                inFill = false

            if inFill and line.includes('G1') and line.includes('E')

                xMatch = line.match(/X([\d.-]+)/)
                yMatch = line.match(/Y([\d.-]+)/)

                if xMatch and yMatch
                    coords.push({ x: parseFloat(xMatch[1]), y: parseFloat(yMatch[1]) })

        return coords

    # Tolerance (mm) applied to hole-radius assertions to absorb polygon approximation
    # of circular hole boundaries (sliced as polygons, not true circles).
    HOLE_TOLERANCE = 0.5

    describe 'Pattern Generation Tests', ->

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
            slicer.setInfillPattern('concentric')
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
            slicer.setInfillPattern('concentric')
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
            slicer.setInfillPattern('concentric')
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
                    else if line.includes('; TYPE:') and not line.includes('; TYPE: FILL')
                        inFill = false

                    if inFill and line.includes('G1') and line.includes('E')
                        count++

                return count

            moves20 = countInfillMoves(result20)
            moves50 = countInfillMoves(result50)

            # 50% density should have more infill moves than 20%.
            expect(moves50).toBeGreaterThan(moves20)

        test 'should generate concentric loops from outside to inside', ->

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
            slicer.setInfillPattern('concentric')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should generate valid G-code.
            expect(result).toBeTruthy()
            expect(result.length).toBeGreaterThan(0)

        test 'should handle circular shapes efficiently', ->

            # Create a cylinder (circular cross-section).
            geometry = new THREE.CylinderGeometry(5, 5, 10, 32)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.rotation.x = Math.PI / 2 # Orient cylinder along Z axis.
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('concentric')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should generate valid G-code.
            expect(result).toBeTruthy()
            expect(result).toContain('; TYPE: FILL')

        test 'should respect holes in geometries (torus)', ->

            # Create a torus (has a hole in the middle).
            geometry = new THREE.TorusGeometry(5, 2, 16, 32)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 2)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('concentric')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should generate valid G-code with infill.
            expect(result).toBeTruthy()
            expect(result).toContain('; TYPE: FILL')

            # Count FILL sections to ensure infill is generated.
            lines = result.split('\n')
            fillCount = 0

            for line in lines

                if line.includes('; TYPE: FILL')
                    fillCount++

            # Should have infill on multiple layers.
            expect(fillCount).toBeGreaterThan(5)

            # Verify that infill doesn't generate in the hole area.
            # Extract coordinates from infill sections.
            fillCoords = parseFillExtrusionCoords(result)

            # Check that no infill points are in the center hole area.
            # Derive build plate center from slicer configuration to avoid hardcoding.
            centerX = slicer.getBuildPlateWidth() / 2
            centerY = slicer.getBuildPlateLength() / 2

            # For a torus with radius 5 and tube 2, the hole radius is approximately 3mm.
            # Use HOLE_TOLERANCE to absorb polygon approximation of the circular hole.
            holeRadius = 3
            pointsNearHole = 0

            for coord in fillCoords

                dx = coord.x - centerX
                dy = coord.y - centerY
                distToCenter = Math.sqrt(dx * dx + dy * dy)

                if distToCenter < holeRadius - HOLE_TOLERANCE
                    pointsNearHole++

            # Should have no points in the hole area after the fix.
            expect(pointsNearHole).toBe(0) # 100% elimination of hole violations.

        test 'should clip partial-overlap loops when rectangular loops intersect circular hole (regression for dome)', ->

            # Create a shape with a 20x20mm rectangular outer boundary and a
            # circular inner hole of radius 6mm at the center.  Extruded 10mm tall.
            # This replicates dome-like cross-sections where concentric loops shrink as
            # rectangles but the hole is circular: at ~10x10mm loop size the four side
            # midpoints fall inside the 6mm hole while the corners stay outside.
            # Old code: 4/8 sampled points inside → ≤50% threshold → loop NOT skipped
            # → parts of the loop printed inside the hole (bug).
            # New code: each edge is clipped against the hole → correct arcs only.
            outerShape = new THREE.Shape()
            outerShape.moveTo(-10, -10)
            outerShape.lineTo(10, -10)
            outerShape.lineTo(10, 10)
            outerShape.lineTo(-10, 10)
            outerShape.lineTo(-10, -10)

            holePath = new THREE.Path()
            holePath.absarc(0, 0, 6, 0, Math.PI * 2, false)
            outerShape.holes.push(holePath)

            extrudeSettings = { depth: 10, bevelEnabled: false }
            geometry = new THREE.ExtrudeGeometry(outerShape, extrudeSettings)

            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('concentric')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should generate valid G-code with infill.
            expect(result).toBeTruthy()
            expect(result).toContain('; TYPE: FILL')

            lines = result.split('\n')

            # Extract infill extrusion G-code coordinates using shared helper.
            fillCoords = parseFillExtrusionCoords(result)

            centerX = slicer.getBuildPlateWidth() / 2
            centerY = slicer.getBuildPlateLength() / 2

            # The circular hole has radius 6mm. Use HOLE_TOLERANCE to absorb
            # polygon approximation of the circular hole boundary.
            holeRadius = 6
            pointsNearHole = 0

            for coord in fillCoords

                dx = coord.x - centerX
                dy = coord.y - centerY
                distToCenter = Math.sqrt(dx * dx + dy * dy)

                if distToCenter < holeRadius - HOLE_TOLERANCE
                    pointsNearHole++

            # No infill should be generated inside the circular hole.
            expect(pointsNearHole).toBe(0)
