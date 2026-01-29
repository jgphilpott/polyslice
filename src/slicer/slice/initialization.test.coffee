# Tests for slice initialization module

initialization = require('./initialization')
THREE = require('three')

describe 'Slice Initialization', ->

    describe 'initializeMesh', ->

        test 'should extract and clone mesh from scene', ->

            # Create a simple mesh
            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            result = initialization.initializeMesh(mesh)

            expect(result).toBeDefined()
            expect(result.mesh).toBeDefined()
            expect(result.THREE).toBeDefined()
            expect(result.mesh.geometry).toBeDefined()

        test 'should return null for empty scene', ->

            result = initialization.initializeMesh(null)

            expect(result).toBeNull()

        test 'should clone mesh to preserve original', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial()
            originalMesh = new THREE.Mesh(geometry, material)
            originalMesh.position.set(5, 10, 15)

            result = initialization.initializeMesh(originalMesh)

            expect(result.mesh).not.toBe(originalMesh)
            expect(result.mesh.geometry).not.toBe(originalMesh.geometry)

    describe 'prepareMeshForSlicing', ->

        test 'should calculate bounding box', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            result = initialization.prepareMeshForSlicing(mesh, THREE)

            expect(result.boundingBox).toBeDefined()
            expect(result.minZ).toBeDefined()
            expect(result.maxZ).toBeDefined()
            expect(result.minZ).toBeCloseTo(0, 1)
            expect(result.maxZ).toBeCloseTo(10, 1)

        test 'should adjust mesh with negative Z to build plate', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)
            mesh.position.set(0, 0, 0) # Mesh extends from -5 to 5
            mesh.updateMatrixWorld()

            result = initialization.prepareMeshForSlicing(mesh, THREE)

            # After adjustment, minZ should be 0
            expect(result.minZ).toBeGreaterThanOrEqual(0)

    describe 'calculateCenterOffsets', ->

        test 'should calculate offsets to center mesh on build plate', ->

            boundingBox = {
                min: { x: -5, y: -5, z: 0 }
                max: { x: 5, y: 5, z: 10 }
            }
            buildPlateWidth = 220
            buildPlateLength = 220

            result = initialization.calculateCenterOffsets(boundingBox, buildPlateWidth, buildPlateLength)

            expect(result.centerOffsetX).toBe(110) # (220/2) - 0
            expect(result.centerOffsetY).toBe(110) # (220/2) - 0

    describe 'storeMeshBounds', ->

        test 'should store mesh bounds in slicer object', ->

            slicer = {}
            boundingBox = {
                min: { x: -5, y: -5, z: 0 }
                max: { x: 5, y: 5, z: 10 }
            }
            centerOffsetX = 110
            centerOffsetY = 110

            initialization.storeMeshBounds(slicer, boundingBox, centerOffsetX, centerOffsetY)

            expect(slicer.meshBounds).toBeDefined()
            expect(slicer.meshBounds.minX).toBe(105) # -5 + 110
            expect(slicer.meshBounds.maxX).toBe(115) # 5 + 110
            expect(slicer.meshBounds.minY).toBe(105)
            expect(slicer.meshBounds.maxY).toBe(115)
            expect(slicer.meshBounds.minZ).toBe(0)
            expect(slicer.meshBounds.maxZ).toBe(10)
