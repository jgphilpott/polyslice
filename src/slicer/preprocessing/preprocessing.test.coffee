# Tests for mesh preprocessing module

Polyslice = require('../../index')

preprocessing = require('./preprocessing')

THREE = require('three')

describe 'Mesh Preprocessing', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice({progressCallback: null})

    describe 'Configuration', ->

        test 'should have meshPreprocessing disabled by default', ->

            expect(slicer.getMeshPreprocessing()).toBe(false)

            return # Explicitly return undefined for Jest.

        test 'should allow enabling meshPreprocessing', ->

            slicer.setMeshPreprocessing(true)
            expect(slicer.getMeshPreprocessing()).toBe(true)

            return # Explicitly return undefined for Jest.

        test 'should allow disabling meshPreprocessing', ->

            slicer.setMeshPreprocessing(true)
            slicer.setMeshPreprocessing(false)
            expect(slicer.getMeshPreprocessing()).toBe(false)

            return # Explicitly return undefined for Jest.

        test 'should accept meshPreprocessing in constructor', ->

            slicerWithPreprocessing = new Polyslice({ meshPreprocessing: true })
            expect(slicerWithPreprocessing.getMeshPreprocessing()).toBe(true)

            return # Explicitly return undefined for Jest.

    describe 'Slicing with Preprocessing', ->

        test 'should slice mesh successfully with preprocessing enabled', ->

            # Create a simple cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            # Enable preprocessing.
            slicer.setMeshPreprocessing(true)
            slicer.setLayerHeight(0.2)
            slicer.setAutohome(false)

            # Slice should complete without errors.
            result = slicer.slice(mesh)
            expect(result).toContain('LAYER:')

            return # Explicitly return undefined for Jest.

        test 'should handle preprocessing without errors on sparse geometry', ->

            # Create a very sparse, large sphere that should trigger subdivision.
            geometry = new THREE.SphereGeometry(50, 4, 3) # Very sparse
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 50)
            mesh.updateMatrixWorld()

            # Configure slicer with preprocessing enabled.
            slicer.setMeshPreprocessing(true)
            slicer.setLayerHeight(1) # Larger layer height for faster test
            slicer.setAutohome(false)
            slicer.setVerbose(false)

            # Should not throw an error.
            expect(() -> slicer.slice(mesh)).not.toThrow()

            return # Explicitly return undefined for Jest.

    describe 'Module Functions', ->

        describe 'extractMesh', ->

            test 'should return null for null input', ->

                expect(preprocessing.extractMesh(null)).toBeNull()

                return # Explicitly return undefined for Jest.

            test 'should return null for empty object', ->

                expect(preprocessing.extractMesh({})).toBeNull()

                return # Explicitly return undefined for Jest.

            test 'should return mesh when given a mesh directly', ->

                geometry = new THREE.BoxGeometry(1, 1, 1)
                mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())

                result = preprocessing.extractMesh(mesh)
                expect(result).toBe(mesh)

                return # Explicitly return undefined for Jest.

            test 'should extract mesh from scene with children', ->

                scene = new THREE.Scene()
                geometry = new THREE.BoxGeometry(1, 1, 1)
                mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
                scene.add(mesh)

                result = preprocessing.extractMesh(scene)
                expect(result).toBe(mesh)

                return # Explicitly return undefined for Jest.

            test 'should return first mesh from scene with multiple children', ->

                scene = new THREE.Scene()
                geometry1 = new THREE.BoxGeometry(1, 1, 1)
                mesh1 = new THREE.Mesh(geometry1, new THREE.MeshBasicMaterial())
                geometry2 = new THREE.BoxGeometry(2, 2, 2)
                mesh2 = new THREE.Mesh(geometry2, new THREE.MeshBasicMaterial())

                scene.add(mesh1)
                scene.add(mesh2)

                result = preprocessing.extractMesh(scene)
                expect(result).toBe(mesh1)

                return # Explicitly return undefined for Jest.

        describe 'analyzeGeometryDensity', ->

            test 'should return false for null geometry', ->

                expect(preprocessing.analyzeGeometryDensity(null)).toBe(false)

                return # Explicitly return undefined for Jest.

            test 'should return false for geometry without position attribute', ->

                geometry = new THREE.BufferGeometry()
                expect(preprocessing.analyzeGeometryDensity(geometry)).toBe(false)

                return # Explicitly return undefined for Jest.

            test 'should return false for dense geometry (small high-resolution sphere)', ->

                # A small, high-resolution sphere has high triangle density and should not need subdivision.
                # SphereGeometry(1, 32, 32) ≈ 2000 triangles / ~4mm³ ≈ 500 triangles/mm³ >> 5 threshold
                geometry = new THREE.SphereGeometry(1, 32, 32)
                expect(preprocessing.analyzeGeometryDensity(geometry)).toBe(false)

                return # Explicitly return undefined for Jest.

            test 'should return true for sparse geometry (large sphere with few segments)', ->

                # A large sparse geometry should need subdivision.
                geometry = new THREE.SphereGeometry(100, 4, 3)
                expect(preprocessing.analyzeGeometryDensity(geometry)).toBe(true)

                return # Explicitly return undefined for Jest.

        describe 'preprocessMesh', ->

            test 'should return original mesh if geometry is dense enough', ->

                # Create a small, high-segment sphere - dense geometry that won't need subdivision.
                # For a small volume with many triangles, density is high.
                # SphereGeometry(1, 32, 32) = ~2000 triangles / ~4mm³ = ~500 triangles/mm³
                geometry = new THREE.SphereGeometry(1, 32, 32)
                material = new THREE.MeshBasicMaterial()
                mesh = new THREE.Mesh(geometry, material)
                mesh.updateMatrixWorld()

                result = preprocessing.preprocessMesh(mesh)

                # Should return original mesh since it's already dense.
                expect(result).toBe(mesh)

                return # Explicitly return undefined for Jest.

            test 'should return new mesh with subdivided geometry for sparse geometry', ->

                # Create a very sparse, large sphere.
                geometry = new THREE.SphereGeometry(100, 4, 3)
                material = new THREE.MeshBasicMaterial()
                mesh = new THREE.Mesh(geometry, material)
                mesh.position.set(0, 0, 100)
                mesh.updateMatrixWorld()

                result = preprocessing.preprocessMesh(mesh)

                # Should return a new mesh with more triangles.
                expect(result).not.toBe(mesh)
                expect(result.geometry.getAttribute('position').count).toBeGreaterThan(
                    mesh.geometry.getAttribute('position').count
                )

                return # Explicitly return undefined for Jest.

            test 'should copy transform properties to subdivided mesh', ->

                geometry = new THREE.SphereGeometry(100, 4, 3)
                material = new THREE.MeshBasicMaterial()
                mesh = new THREE.Mesh(geometry, material)
                mesh.position.set(10, 20, 30)
                mesh.rotation.set(0.1, 0.2, 0.3)
                mesh.scale.set(1.5, 1.5, 1.5)
                mesh.updateMatrixWorld()

                result = preprocessing.preprocessMesh(mesh)

                # Should copy position, rotation, and scale.
                expect(result.position.x).toBe(10)
                expect(result.position.y).toBe(20)
                expect(result.position.z).toBe(30)
                expect(result.rotation.x).toBeCloseTo(0.1, 5)
                expect(result.rotation.y).toBeCloseTo(0.2, 5)
                expect(result.rotation.z).toBeCloseTo(0.3, 5)
                expect(result.scale.x).toBe(1.5)
                expect(result.scale.y).toBe(1.5)
                expect(result.scale.z).toBe(1.5)

                return # Explicitly return undefined for Jest.
