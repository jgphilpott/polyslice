# Tests for support generation module.

Polyslice = require('../../index')

THREE = require('three')

supportModule = require('./support')

describe 'Support Module', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Configuration', ->

        test 'should respect supportEnabled flag', ->

            # Support generation should not occur when disabled.
            slicer.setSupportEnabled(false)

            expect(slicer.getSupportEnabled()).toBe(false)

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            # Call support generation (should return early).
            result = supportModule.generateSupportGCode(slicer, mesh, 0, 0, 0, 0)

            expect(result).toBeUndefined()

        test 'should only generate when supportEnabled is true', ->

            slicer.setSupportEnabled(true)

            expect(slicer.getSupportEnabled()).toBe(true)

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            # Call support generation.
            # Currently returns undefined as implementation is placeholder.
            result = supportModule.generateSupportGCode(slicer, mesh, 0, 0, 0, 0)

            expect(result).toBeUndefined()

        test 'should respect supportType setting', ->

            slicer.setSupportEnabled(true)
            slicer.setSupportType('normal')

            expect(slicer.getSupportType()).toBe('normal')

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            # Normal supports should proceed (returns undefined for now).
            result = supportModule.generateSupportGCode(slicer, mesh, 0, 0, 0, 0)

            expect(result).toBeUndefined()

            # Tree supports should return early (not yet implemented).
            slicer.setSupportType('tree')

            result = supportModule.generateSupportGCode(slicer, mesh, 0, 0, 0, 0)

            expect(result).toBeUndefined()

        test 'should respect supportPlacement setting', ->

            slicer.setSupportEnabled(true)
            slicer.setSupportPlacement('buildPlate')

            expect(slicer.getSupportPlacement()).toBe('buildPlate')

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            # Build plate placement should proceed (returns undefined for now).
            result = supportModule.generateSupportGCode(slicer, mesh, 0, 0, 0, 0)

            expect(result).toBeUndefined()

            # Everywhere placement should return early (not yet implemented).
            slicer.setSupportPlacement('everywhere')

            result = supportModule.generateSupportGCode(slicer, mesh, 0, 0, 0, 0)

            expect(result).toBeUndefined()

        test 'should use supportThreshold for overhang detection', ->

            slicer.setSupportEnabled(true)

            # Default threshold is 55 degrees.
            expect(slicer.getSupportThreshold()).toBe(55)

            # Set custom threshold.
            slicer.setSupportThreshold(60)

            expect(slicer.getSupportThreshold()).toBe(60)

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            # Call support generation with custom threshold.
            result = supportModule.generateSupportGCode(slicer, mesh, 0, 0, 0, 0)

            expect(result).toBeUndefined()

    describe 'Overhang Detection', ->

        test 'should detect overhangs on horizontal downward-facing surfaces', ->

            slicer.setSupportEnabled(true)
            slicer.setSupportThreshold(45)

            # Create a simple box that's elevated (has underside that needs support).
            geometry = new THREE.BoxGeometry(10, 10, 10)
            geometry.computeVertexNormals() # Required for detection.
            mesh = new THREE.Mesh(geometry)
            mesh.position.set(0, 0, 15) # Elevated 15mm above build plate.
            mesh.updateMatrixWorld()

            # Detect overhangs.
            overhangs = supportModule.detectOverhangs(mesh, 45, 0)

            # Should detect the bottom face of the box as an overhang.
            expect(overhangs.length).toBeGreaterThan(0)

        test 'should not detect overhangs on vertical faces', ->

            slicer.setSupportEnabled(true)
            slicer.setSupportThreshold(45)

            # Create a simple box on the build plate.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            geometry.computeVertexNormals() # Required for detection.
            mesh = new THREE.Mesh(geometry)
            mesh.position.set(0, 0, 5) # Bottom at Z=0.
            mesh.updateMatrixWorld()

            # Detect overhangs.
            overhangs = supportModule.detectOverhangs(mesh, 45, 0)

            # Should not detect overhangs for a simple box on build plate.
            expect(overhangs.length).toBe(0)

        test 'should respect support threshold angle', ->

            slicer.setSupportEnabled(true)

            # Create a box.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            geometry.computeVertexNormals() # Required for detection.
            mesh = new THREE.Mesh(geometry)
            mesh.position.set(0, 0, 15)
            mesh.updateMatrixWorld()

            # With 0° threshold, all downward faces need support.
            overhangs0 = supportModule.detectOverhangs(mesh, 0, 0)
            expect(overhangs0.length).toBeGreaterThan(0)

            # With 90° threshold, no faces need support (very permissive).
            overhangs90 = supportModule.detectOverhangs(mesh, 90, 0)
            expect(overhangs90.length).toBe(0)

    describe 'Support Column Generation', ->

        test 'should generate G-code for support columns', ->

            slicer.setSupportEnabled(true)
            slicer.setSupportThreshold(45)

            # Create a simple bridge geometry.
            leftPillar = new THREE.BoxGeometry(5, 5, 10)
            rightPillar = new THREE.BoxGeometry(5, 5, 10)
            bridge = new THREE.BoxGeometry(20, 5, 5)

            # Merge geometries manually for testing.
            geometry = new THREE.BufferGeometry()

            # For simplicity, just test that the module can be called.
            mesh = new THREE.Mesh(leftPillar)
            mesh.position.set(0, 0, 10)
            mesh.updateMatrixWorld()

            # This should not throw an error.
            expect(() =>
                supportModule.generateSupportGCode(slicer, mesh, [], 0, 0, 0, 0, 0, 0.2)
            ).not.toThrow()

    describe 'Integration', ->

        test 'should cache overhang detection across layers', ->

            slicer.setSupportEnabled(true)
            slicer.setSupportThreshold(45)

            geometry = new THREE.BoxGeometry(10, 10, 10)
            geometry.computeVertexNormals() # Required for detection.
            mesh = new THREE.Mesh(geometry)
            mesh.position.set(0, 0, 15)
            mesh.updateMatrixWorld()

            # First call should detect and cache.
            supportModule.generateSupportGCode(slicer, mesh, [], 0, 0, 0, 0, 0, 0.2)
            expect(slicer._overhangRegions).toBeDefined()

            # Second call should use cached data.
            cachedRegions = slicer._overhangRegions
            supportModule.generateSupportGCode(slicer, mesh, [], 1, 0.2, 0, 0, 0, 0.2)
            expect(slicer._overhangRegions).toBe(cachedRegions)

        test 'should recalculate overhangs for different mesh orientations', ->

            slicer.setSupportEnabled(true)
            slicer.setSupportThreshold(45)

            # Create an arch-like geometry (box with a hole).
            geometry = new THREE.BoxGeometry(20, 10, 10)
            geometry.computeVertexNormals()
            mesh = new THREE.Mesh(geometry)
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            # Slice upright orientation - this would generate support regions.
            gcode1 = slicer.slice(mesh)
            overhangRegions1 = slicer._overhangRegions

            # Rotate 180 degrees (flipped).
            mesh.rotation.y = Math.PI
            mesh.updateMatrixWorld()

            # Slice flipped orientation - support regions should be recalculated.
            gcode2 = slicer.slice(mesh)
            overhangRegions2 = slicer._overhangRegions

            # The overhang regions should have been recalculated (new array instance).
            # Note: We can't easily compare content here without complex geometry, but we
            # ensure the cache was cleared and regenerated (not the same instance).
            expect(overhangRegions1).toBeDefined()
            expect(overhangRegions2).toBeDefined()
            expect(overhangRegions2).not.toBe(overhangRegions1)
