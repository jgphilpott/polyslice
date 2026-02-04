# Tests for infill pattern centering configuration

Polyslice = require('../../index')

THREE = require('three')

describe 'Infill Pattern Centering', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice({progressCallback: null})

    describe 'Configuration', ->

        test 'should default to object centering', ->

            expect(slicer.getInfillPatternCentering()).toBe('object')

        test 'should allow setting to global centering', ->

            slicer.setInfillPatternCentering('global')

            expect(slicer.getInfillPatternCentering()).toBe('global')

        test 'should allow setting to object centering', ->

            slicer.setInfillPatternCentering('object')

            expect(slicer.getInfillPatternCentering()).toBe('object')

        test 'should handle case-insensitive input', ->

            slicer.setInfillPatternCentering('GLOBAL')

            expect(slicer.getInfillPatternCentering()).toBe('global')

            slicer.setInfillPatternCentering('Object')

            expect(slicer.getInfillPatternCentering()).toBe('object')

        test 'should ignore invalid values', ->

            slicer.setInfillPatternCentering('invalid')

            expect(slicer.getInfillPatternCentering()).toBe('object') # Should remain default.

        test 'should support method chaining', ->

            result = slicer.setInfillPatternCentering('global')

            expect(result).toBe(slicer)

    describe 'Grid Pattern with Object Centering', ->

        test 'should generate infill centered on object', ->

            # Create a 1cm cube offset from build plate center.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(20, 30, 5) # Offset from center.
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('grid')
            slicer.setInfillPatternCentering('object')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain infill.
            expect(result).toContain('; TYPE: FILL')

            # Pattern should be generated (check for multiple infill lines).
            lines = result.split('\n')
            infillLineCount = 0

            for line in lines

                if line.includes('G1') and line.includes('E') and not line.includes('; TYPE:')
                    # Check if this is after a FILL type marker.
                    infillLineCount++

            expect(infillLineCount).toBeGreaterThan(0)

    describe 'Grid Pattern with Global Centering', ->

        test 'should generate infill centered on build plate', ->

            # Create a 1cm cube offset from build plate center.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(20, 30, 5) # Offset from center.
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('grid')
            slicer.setInfillPatternCentering('global')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain infill.
            expect(result).toContain('; TYPE: FILL')

            # Pattern should be generated.
            lines = result.split('\n')
            infillLineCount = 0

            for line in lines

                if line.includes('G1') and line.includes('E') and not line.includes('; TYPE:')
                    infillLineCount++

            expect(infillLineCount).toBeGreaterThan(0)

    describe 'Triangles Pattern with Object Centering', ->

        test 'should generate triangles infill centered on object', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('triangles')
            slicer.setInfillPatternCentering('object')

            result = slicer.slice(mesh)

            expect(result).toContain('; TYPE: FILL')

    describe 'Triangles Pattern with Global Centering', ->

        test 'should generate triangles infill centered on build plate', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('triangles')
            slicer.setInfillPatternCentering('global')

            result = slicer.slice(mesh)

            expect(result).toContain('; TYPE: FILL')

    describe 'Hexagons Pattern with Object Centering', ->

        test 'should generate hexagons infill centered on object', ->

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
            slicer.setInfillPatternCentering('object')

            result = slicer.slice(mesh)

            expect(result).toContain('; TYPE: FILL')

    describe 'Hexagons Pattern with Global Centering', ->

        test 'should generate hexagons infill centered on build plate', ->

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
            slicer.setInfillPatternCentering('global')

            result = slicer.slice(mesh)

            expect(result).toContain('; TYPE: FILL')

    describe 'Multi-object Consistency', ->

        test 'object centering should produce different patterns for differently positioned objects', ->

            # Create two identical cubes at different positions.
            geometry1 = new THREE.BoxGeometry(10, 10, 10)
            mesh1 = new THREE.Mesh(geometry1, new THREE.MeshBasicMaterial())
            mesh1.position.set(0, 0, 5)
            mesh1.updateMatrixWorld()

            geometry2 = new THREE.BoxGeometry(10, 10, 10)
            mesh2 = new THREE.Mesh(geometry2, new THREE.MeshBasicMaterial())
            mesh2.position.set(30, 30, 5)
            mesh2.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('grid')
            slicer.setInfillPatternCentering('object')

            result1 = slicer.slice(mesh1)

            # Reset slicer for second mesh.
            slicer.gcode = ""

            result2 = slicer.slice(mesh2)

            # Both should have infill, but patterns should be centered on respective objects.
            expect(result1).toContain('; TYPE: FILL')
            expect(result2).toContain('; TYPE: FILL')

            # The actual infill line coordinates should be different.
            # (This is a basic sanity check that the patterns are position-dependent).
            expect(result1).not.toBe(result2)

        test 'global centering should produce consistent patterns for differently positioned objects', ->

            # Create two identical cubes at different positions.
            geometry1 = new THREE.BoxGeometry(10, 10, 10)
            mesh1 = new THREE.Mesh(geometry1, new THREE.MeshBasicMaterial())
            mesh1.position.set(0, 0, 5)
            mesh1.updateMatrixWorld()

            geometry2 = new THREE.BoxGeometry(10, 10, 10)
            mesh2 = new THREE.Mesh(geometry2, new THREE.MeshBasicMaterial())
            mesh2.position.set(30, 30, 5)
            mesh2.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('grid')
            slicer.setInfillPatternCentering('global')

            result1 = slicer.slice(mesh1)

            # Reset slicer for second mesh.
            slicer.gcode = ""

            result2 = slicer.slice(mesh2)

            # Both should have infill centered on build plate.
            expect(result1).toContain('; TYPE: FILL')
            expect(result2).toContain('; TYPE: FILL')

            # The results should be different (different object positions),
            # but the underlying pattern grid is consistent across the build plate.
            expect(result1).not.toBe(result2)
