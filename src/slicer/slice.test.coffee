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

            # Find Layer 10 content (the problematic center layer at Z≈2.0mm).
            lines = result.split('\n')
            layer10Start = -1
            layer11Start = -1

            for line, i in lines
                if line.includes('LAYER: 10')
                    layer10Start = i
                if line.includes('LAYER: 11')
                    layer11Start = i
                    break

            # Verify Layer 10 was generated.
            expect(layer10Start).toBeGreaterThanOrEqual(0)
            expect(layer11Start).toBeGreaterThan(layer10Start)

            # Extract Layer 10 content.
            layer10Content = lines.slice(layer10Start, layer11Start).join('\n')

            # Count WALL-OUTER occurrences (should be 2: outer ring + inner hole).
            wallOuterCount = (layer10Content.match(/; TYPE: WALL-OUTER/g) or []).length

            # Verify we have 2 wall regions (not just 1).
            expect(wallOuterCount).toBeGreaterThanOrEqual(2)

            # Extract X coordinates to verify we're printing the full torus.
            xCoords = []
            for line in lines.slice(layer10Start, layer11Start)
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

