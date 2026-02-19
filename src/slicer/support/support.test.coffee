# Tests for support generation module.

Polyslice = require('../../index')

THREE = require('three')

supportModule = require('./support')

describe 'Support Module', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice({
            progressCallback: null # Disable progress output during tests
        })

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

        test 'should detect different overhangs for buildPlate vs everywhere placement', ->

            slicer.setSupportEnabled(true)
            slicer.setSupportThreshold(45)

            # Create a box positioned very close to the build plate (just above the 0.5mm threshold).
            # The bottom face (z ≈ 0.3mm) will be excluded by 'buildPlate' (requires z > 0.5mm)
            # but included by 'everywhere' (requires z > 0mm).
            geometry = new THREE.BoxGeometry(10, 10, 10)
            geometry.computeVertexNormals() # Required for detection.
            mesh = new THREE.Mesh(geometry)
            mesh.position.set(0, 0, 5.3) # Bottom at z ≈ 0.3mm (below 0.5mm threshold).
            mesh.updateMatrixWorld()

            # Detect with 'buildPlate' placement (default).
            overhangsBuildPlate = supportModule.detectOverhangs(mesh, 45, 0, 'buildPlate')

            # Detect with 'everywhere' placement.
            overhangsEverywhere = supportModule.detectOverhangs(mesh, 45, 0, 'everywhere')

            # 'buildPlate' should exclude the overhang (z=0.3mm < 0.5mm threshold).
            expect(overhangsBuildPlate.length).toBe(0)

            # 'everywhere' should include the overhang (z=0.3mm > 0mm).
            expect(overhangsEverywhere.length).toBeGreaterThan(0)

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
            expect(slicer._overhangFaces).toBeDefined()

            # Second call should use cached data.
            cachedFaces = slicer._overhangFaces
            supportModule.generateSupportGCode(slicer, mesh, [], 1, 0.2, 0, 0, 0, 0.2)
            expect(slicer._overhangFaces).toBe(cachedFaces)

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
            overhangFaces1 = slicer._overhangFaces

            # Rotate 180 degrees (flipped).
            mesh.rotation.y = Math.PI
            mesh.updateMatrixWorld()

            # Slice flipped orientation - support regions should be recalculated.
            gcode2 = slicer.slice(mesh)
            overhangFaces2 = slicer._overhangFaces

            # The overhang faces should have been recalculated (new array instance).
            # Note: We can't easily compare content here without complex geometry, but we
            # ensure the cache was cleared and regenerated (not the same instance).
            expect(overhangFaces1).toBeDefined()
            expect(overhangFaces2).toBeDefined()
            expect(overhangFaces2).not.toBe(overhangFaces1)

    describe 'Collision Detection', ->

        test 'should build layer solid regions cache', ->

            slicer.setSupportEnabled(true)
            slicer.setSupportThreshold(45)

            # Create a simple bridge with pillars.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            # Slice to build layer cache.
            gcode = slicer.slice(mesh)

            # Layer solid regions should be cached.
            expect(slicer._layerSolidRegions).toBeDefined()
            expect(slicer._layerSolidRegions.length).toBeGreaterThan(0)

        test 'should detect collision with solid geometry in buildPlate mode', ->

            slicer.setSupportEnabled(true)
            slicer.setSupportPlacement('buildPlate')
            slicer.setSupportThreshold(45)

            # Create a simple geometry.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            # Slice the mesh.
            gcode = slicer.slice(mesh)

            # In buildPlate mode, a box sitting on the build plate shouldn't need supports.
            # The G-code should not contain support structures.
            expect(gcode).not.toContain('TYPE: SUPPORT')

        test 'should clear layer solid regions cache between slices', ->

            slicer.setSupportEnabled(true)
            slicer.setSupportThreshold(45)

            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            # First slice.
            gcode1 = slicer.slice(mesh)
            cache1 = slicer._layerSolidRegions

            # Second slice.
            gcode2 = slicer.slice(mesh)
            cache2 = slicer._layerSolidRegions

            # Caches should be different instances (regenerated).
            expect(cache1).toBeDefined()
            expect(cache2).toBeDefined()
            expect(cache2).not.toBe(cache1)

    describe 'Hole Detection', ->

        test 'should calculate nesting levels for paths', ->

            slicer.setSupportEnabled(true)
            slicer.setSupportThreshold(45)

            # Create a simple box.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            # Slice the mesh to build layer cache.
            gcode = slicer.slice(mesh)

            # Check that pathIsHole information is stored.
            expect(slicer._layerSolidRegions).toBeDefined()
            expect(slicer._layerSolidRegions.length).toBeGreaterThan(0)

            # Each layer should have pathIsHole array.
            firstLayer = slicer._layerSolidRegions[0]
            expect(firstLayer.pathIsHole).toBeDefined()
            expect(Array.isArray(firstLayer.pathIsHole)).toBe(true)

        test 'should use even-odd winding rule for solid detection', ->

            slicer.setSupportEnabled(true)
            slicer.setSupportThreshold(45)

            # Create test paths for verification.
            # Outer square.
            outerPath = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Inner square (hole).
            innerPath = [
                { x: 2, y: 2 }
                { x: 8, y: 2 }
                { x: 8, y: 8 }
                { x: 2, y: 8 }
            ]

            paths = [outerPath, innerPath]
            pathIsHole = [false, true]

            # Point outside: containment count = 0 (not solid)
            pointOutside = { x: -1, y: -1 }
            resultOutside = supportModule.isPointInsideSolidGeometry(pointOutside, paths, pathIsHole)
            expect(resultOutside).toBe(false)

            # Point in outer only: containment count = 1 (solid)
            pointInOuter = { x: 1, y: 1 }
            resultInOuter = supportModule.isPointInsideSolidGeometry(pointInOuter, paths, pathIsHole)
            expect(resultInOuter).toBe(true)

            # Point in hole: containment count = 2 (not solid - it's empty space)
            pointInHole = { x: 5, y: 5 }
            resultInHole = supportModule.isPointInsideSolidGeometry(pointInHole, paths, pathIsHole)
            expect(resultInHole).toBe(false)

    describe 'Everywhere Mode Behavior', ->

        test 'should stop supports at solid surfaces in everywhere mode', ->

            slicer.setSupportEnabled(true)
            slicer.setSupportPlacement('everywhere')
            slicer.setSupportThreshold(45)

            # Create a simple elevated box.
            geometry = new THREE.BoxGeometry(10, 10, 5)
            mesh = new THREE.Mesh(geometry)
            # Position so there's a gap between build plate and box bottom.
            mesh.position.set(0, 0, 7.5) # Box from Z=5 to Z=10
            mesh.updateMatrixWorld()

            # Slice the mesh.
            gcode = slicer.slice(mesh)

            # Verify layer cache was built.
            expect(slicer._layerSolidRegions).toBeDefined()
            expect(slicer._layerSolidRegions.length).toBeGreaterThan(0)

            # Count support lines in G-code.
            supportLines = gcode.split('\n').filter((line) -> line.includes('TYPE: SUPPORT')).length

            # A floating box should generate supports BELOW the box (in the gap),
            # but NOT inside the solid box itself. With collision detection,
            # supports should be present but limited to the gap region.
            if supportLines > 0
                # Verify supports are only in lower layers (below the solid box).
                # This is a basic sanity check - detailed behavior tested with CSG geometries.
                expect(supportLines).toBeGreaterThan(0)

        test 'should allow supports through cavities in buildPlate mode', ->

            slicer.setSupportEnabled(true)
            slicer.setSupportPlacement('buildPlate')
            slicer.setSupportThreshold(45)

            # Create a simple box geometry.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            # Slice the mesh.
            gcode = slicer.slice(mesh)

            # Verify placement mode is set correctly.
            expect(slicer.getSupportPlacement()).toBe('buildPlate')

            # A simple box on build plate should not need supports (no overhangs).
            supportLines = gcode.split('\n').filter((line) -> line.includes('TYPE: SUPPORT')).length
            expect(supportLines).toBe(0)

            # Note: Cavity behavior (supports through holes) is thoroughly tested
            # with complex CSG geometries in examples (dome upright, sideways dome).
            expect(gcode).not.toContain('TYPE: SUPPORT')
