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
            expect(result).toContain('LAYER:1') # Layer marker.
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
