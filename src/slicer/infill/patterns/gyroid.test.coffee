# Tests for gyroid infill pattern

Polyslice = require('../../../index')

THREE = require('three')

describe 'Gyroid Infill Generation', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice({progressCallback: null})

    describe 'Gyroid Infill Generation', ->

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
            slicer.setInfillPattern('gyroid')
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
            material = new THREE.MeshBasicMaterial()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillPattern('gyroid')
            slicer.setVerbose(true)

            # Test different densities.
            densities = [10, 20, 40, 80]
            gcodeResults = []

            # Generate G-code for each density.
            gcodeResults = densities.map (density) ->
                # Create a fresh mesh for each density.
                mesh = new THREE.Mesh(geometry, material)
                mesh.position.set(0, 0, 5)
                mesh.updateMatrixWorld()

                slicer.setInfillDensity(density)
                return slicer.slice(mesh)

            # Higher density should result in more G-code (more infill lines).
            # Compare consecutive densities.
            for i in [0...gcodeResults.length - 1]

                currentLength = gcodeResults[i].length
                nextLength = gcodeResults[i + 1].length

                # Higher density should produce longer G-code.
                expect(nextLength).toBeGreaterThan(currentLength)

            # Return undefined to satisfy Jest.
            return undefined

        test 'should respect infillPatternCentering setting', ->

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
            slicer.setInfillPattern('gyroid')
            slicer.setVerbose(true)

            # Test object centering (default).
            slicer.setInfillPatternCentering('object')
            resultObject = slicer.slice(mesh)

            # Test global centering.
            slicer.setInfillPatternCentering('global')
            resultGlobal = slicer.slice(mesh)

            # Both should generate infill.
            expect(resultObject).toContain('; TYPE: FILL')
            expect(resultGlobal).toContain('; TYPE: FILL')

            # Results should differ due to centering mode.
            expect(resultObject).not.toBe(resultGlobal)

        test 'should generate wavy pattern with alternating layers', ->

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
            slicer.setInfillPattern('gyroid')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Gyroid should generate G1 commands (extrusion) for infill.
            lines = result.split('\n')
            g1Count = 0
            inFillSection = false

            for line in lines

                if line.includes('; TYPE: FILL')
                    inFillSection = true
                else if line.includes('; TYPE:') and not line.includes('FILL')
                    inFillSection = false

                if inFillSection and line.startsWith('G1') and line.includes('E')
                    g1Count++

            # Should have substantial number of extrusion commands in infill.
            expect(g1Count).toBeGreaterThan(100)

        test 'should work with different nozzle sizes', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setShellWallThickness(1.2)
            slicer.setShellSkinThickness(0.6)
            slicer.setLayerHeight(0.3)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('gyroid')
            slicer.setVerbose(true)

            # Test with 0.4mm nozzle.
            slicer.setNozzleDiameter(0.4)
            result1 = slicer.slice(mesh)

            # Test with 0.6mm nozzle.
            slicer.setNozzleDiameter(0.6)
            result2 = slicer.slice(mesh)

            # Both should generate infill.
            expect(result1).toContain('; TYPE: FILL')
            expect(result2).toContain('; TYPE: FILL')

            # Different nozzle sizes should produce different results.
            expect(result1).not.toBe(result2)
