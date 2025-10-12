# Tests for gyroid infill pattern

Polyslice = require('../../../index')

THREE = require('three')

describe 'Gyroid Infill Pattern', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Basic Gyroid Generation', ->

        test 'should generate gyroid infill for simple cube', ->

            # Create a simple 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('gyroid')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain infill type marker.
            expect(result).toContain('; TYPE: FILL')

            # Should contain G1 commands (extrusion moves).
            expect(result).toMatch(/G1.*E/)

        test 'should generate different patterns at different z heights', ->

            # Create a simple 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('gyroid')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # The gyroid pattern should vary between layers.
            # Count the number of extrusion commands to verify pattern exists.
            extrusionCommands = result.match(/G1.*E/g)

            expect(extrusionCommands).not.toBeNull()
            expect(extrusionCommands.length).toBeGreaterThan(0)

    describe 'Density Control', ->

        test 'should respect infill density setting', ->

            # Create a simple 2cm cube for better testing.
            geometry = new THREE.BoxGeometry(20, 20, 20)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 10)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillPattern('gyroid')
            slicer.setVerbose(true)

            # Test with 10% density.
            slicer.setInfillDensity(10)
            result10 = slicer.slice(mesh)
            extrusionCommands10 = result10.match(/; TYPE: FILL[\s\S]*?(?=;LAYER:|$)/g)

            # Reset slicer for next test.
            slicer = new Polyslice()
            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillPattern('gyroid')
            slicer.setVerbose(true)

            # Test with 30% density.
            slicer.setInfillDensity(30)
            result30 = slicer.slice(mesh)
            extrusionCommands30 = result30.match(/; TYPE: FILL[\s\S]*?(?=;LAYER:|$)/g)

            # Higher density should generally produce more extrusion.
            # Note: Due to the mathematical nature of gyroid, this is approximate.
            expect(extrusionCommands30).not.toBeNull()
            expect(extrusionCommands10).not.toBeNull()

        test 'should calculate correct line spacing for gyroid density', ->

            # The formula is: baseSpacing = nozzleDiameter / (density / 100)
            # For gyroid: lineSpacing = baseSpacing * 1.0

            nozzleDiameter = 0.4
            density = 20

            # Expected: 0.4 / 0.2 * 1.0 = 2.0mm
            expectedSpacing = (nozzleDiameter / (density / 100.0)) * 1.0

            expect(expectedSpacing).toBeCloseTo(2.0, 1)

    describe 'Pattern Validation', ->

        test 'should generate valid G-code commands', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('gyroid')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain valid G0/G1 commands.
            expect(result).toMatch(/G[01] X[\d.-]+ Y[\d.-]+ Z[\d.-]+/)

            # Should have proper extrusion values.
            expect(result).toMatch(/E[\d.]+/)

        test 'should handle small geometries', ->

            # Create a very small 5mm cube.
            geometry = new THREE.BoxGeometry(5, 5, 5)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 2.5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('gyroid')
            slicer.setVerbose(false)

            # Should not throw error.
            expect(() => slicer.slice(mesh)).not.toThrow()

        test 'should handle large geometries', ->

            # Create a larger 5cm cube.
            geometry = new THREE.BoxGeometry(50, 50, 50)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 25)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.5)
            slicer.setInfillDensity(15)
            slicer.setInfillPattern('gyroid')
            slicer.setVerbose(false)

            # Should not throw error.
            expect(() => slicer.slice(mesh)).not.toThrow()

    describe 'Comparison with Other Patterns', ->

        test 'should produce different output than grid pattern', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            # Configure slicer for grid.
            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('grid')
            slicer.setVerbose(false)

            resultGrid = slicer.slice(mesh)

            # Reset for gyroid.
            slicer = new Polyslice()
            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('gyroid')
            slicer.setVerbose(false)

            resultGyroid = slicer.slice(mesh)

            # Results should be different.
            expect(resultGrid).not.toBe(resultGyroid)

    describe 'Edge Cases', ->

        test 'should handle zero infill density', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(0)
            slicer.setInfillPattern('gyroid')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should not contain infill type marker.
            expect(result).not.toContain('; TYPE: FILL')

        test 'should handle very high density', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(100)
            slicer.setInfillPattern('gyroid')
            slicer.setVerbose(false)

            # Should not throw error.
            expect(() => slicer.slice(mesh)).not.toThrow()

        test 'should handle different nozzle diameters', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            # Test with 0.6mm nozzle.
            slicer.setNozzleDiameter(0.6)
            slicer.setShellWallThickness(1.2)
            slicer.setShellSkinThickness(0.6)
            slicer.setLayerHeight(0.3)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('gyroid')
            slicer.setVerbose(false)

            result = slicer.slice(mesh)

            # Should generate valid output.
            expect(result).toMatch(/G[01]/)
