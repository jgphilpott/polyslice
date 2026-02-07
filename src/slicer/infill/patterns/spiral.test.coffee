# Tests for spiral infill pattern

Polyslice = require('../../../index')

THREE = require('three')

describe 'Spiral Infill Generation', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice({progressCallback: null})

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
            slicer.setInfillPattern('spiral')
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

        test 'should respect infillDensity setting', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillPattern('spiral')
            slicer.setVerbose(true)

            # Test with 0% infill.
            slicer.setInfillDensity(0)
            result0 = slicer.slice(mesh)
            expect(result0).not.toContain('; TYPE: FILL')

            # Test with 50% infill.
            slicer.setInfillDensity(50)
            result50 = slicer.slice(mesh)
            expect(result50).toContain('; TYPE: FILL')

        test 'should support object centering mode', ->

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
            slicer.setInfillPattern('spiral')
            slicer.setInfillPatternCentering('object')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain FILL type.
            expect(result).toContain('; TYPE: FILL')

        test 'should support global centering mode', ->

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
            slicer.setInfillPattern('spiral')
            slicer.setInfillPatternCentering('global')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain FILL type.
            expect(result).toContain('; TYPE: FILL')

        test 'should handle circular parts', ->

            # Create a cylinder (circular cross-section).
            geometry = new THREE.CylinderGeometry(5, 5, 10, 32)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.rotation.x = Math.PI / 2
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('spiral')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain FILL type.
            expect(result).toContain('; TYPE: FILL')

            # Should have multiple G1 commands (extrusion).
            lines = result.split('\n')
            g1Count = 0

            for line in lines

                if line.trim().startsWith('G1') and line.includes('E')
                    g1Count++

            expect(g1Count).toBeGreaterThan(10)
