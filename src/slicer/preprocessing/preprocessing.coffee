# Mesh preprocessing module for Polyslice.

{ Polytree } = require('@jgphilpott/polytree')

LoopSubdivision = require('three-subdivide').LoopSubdivision

getTHREE = ->

    return if typeof window isnt 'undefined' then window.THREE else require('three')

pushUniqueMesh = (meshes, mesh) ->

    return if not mesh or not mesh.isMesh

    if not meshes.includes(mesh)

        meshes.push(mesh)

cloneMeshWithWorldTransform = (mesh) ->

    THREE = getTHREE()

    clonedMesh = mesh.clone(true)

    if mesh.geometry and mesh.geometry.clone

        clonedMesh.geometry = mesh.geometry.clone()

    worldPosition = new THREE.Vector3()
    worldQuaternion = new THREE.Quaternion()
    worldScale = new THREE.Vector3()

    mesh.matrixWorld.decompose(worldPosition, worldQuaternion, worldScale)

    clonedMesh.position.copy(worldPosition)
    clonedMesh.quaternion.copy(worldQuaternion)
    clonedMesh.scale.copy(worldScale)
    clonedMesh.updateMatrixWorld(true)

    return clonedMesh

module.exports =

    # Preprocess mesh to improve triangle density in sparse regions.
    preprocessMesh: (mesh) ->

        THREE = getTHREE()

        geometry = mesh.geometry

        return mesh if not geometry or not geometry.isBufferGeometry

        needsSubdivision = @analyzeGeometryDensity(geometry)

        if needsSubdivision

            subdividedGeometry = @subdivideGeometry(geometry)

            subdividedMesh = new THREE.Mesh(subdividedGeometry, mesh.material)

            subdividedMesh.position.copy(mesh.position)
            subdividedMesh.rotation.copy(mesh.rotation)
            subdividedMesh.scale.copy(mesh.scale)
            subdividedMesh.updateMatrixWorld()

            return subdividedMesh

        return mesh

    # Analyze geometry to determine if it needs subdivision.
    analyzeGeometryDensity: (geometry) ->

        return false if not geometry

        THREE = getTHREE()

        positionAttribute = geometry.getAttribute('position')
        return false if not positionAttribute

        geometry.computeBoundingBox()
        bbox = geometry.boundingBox

        return false if not bbox

        size = new THREE.Vector3()
        bbox.getSize(size)
        volume = size.x * size.y * size.z

        return false if volume <= 0

        triangleCount = if geometry.index
            Math.floor(geometry.index.count / 3)
        else
            Math.floor(positionAttribute.count / 3)

        density = triangleCount / volume

        # Density < 5 triangles/mm³ indicates sparse mesh needing subdivision.
        DENSITY_THRESHOLD = 5

        return density < DENSITY_THRESHOLD

    # Subdivide geometry using Loop subdivision algorithm.
    subdivideGeometry: (geometry) ->

        params = {
            split: true
            uvSmooth: false
            preserveEdges: false
            flatOnly: false
            maxTriangles: Infinity
        }

        return LoopSubdivision.modify(geometry, 1, params)

    # Extract all meshes from scene object.
    extractMeshes: (scene) ->

        return [] if not scene

        meshes = []

        traverseNode = (node) ->

            return if not node

            pushUniqueMesh(meshes, node)
            pushUniqueMesh(meshes, node.mesh)

            if node.children and node.children.length > 0

                for child in node.children

                    traverseNode(child)

        traverseNode(scene)

        return meshes

    # Extract first mesh from scene object.
    extractMesh: (scene) ->

        meshes = @extractMeshes(scene)

        return meshes[0] if meshes.length > 0

        return null

    # Check if any meshes overlap by world-space bounding boxes.
    hasOverlappingMeshes: (meshes = []) ->

        return false if not Array.isArray(meshes) or meshes.length < 2

        THREE = getTHREE()

        worldBounds = []

        for mesh in meshes

            worldBounds.push(new THREE.Box3().setFromObject(mesh))

        for firstMeshIndex in [0...worldBounds.length]

            for secondMeshIndex in [firstMeshIndex + 1...worldBounds.length]

                if worldBounds[firstMeshIndex].intersectsBox(worldBounds[secondMeshIndex])

                    return true

        return false

    # Auto-join overlapping meshes into a single mesh.
    autoJoinOverlappingMeshes: (meshes = []) ->

        return null if not Array.isArray(meshes) or meshes.length is 0

        return meshes[0] if meshes.length is 1

        return meshes[0] if not @hasOverlappingMeshes(meshes)

        try

            meshesForJoin = []

            for mesh in meshes

                meshesForJoin.push(cloneMeshWithWorldTransform(mesh))

            joinedMesh = meshesForJoin[0]

            for meshIndex in [1...meshesForJoin.length]

                # Use sync Polytree unite in the current synchronous slicing pipeline.
                joinedMesh = Polytree.unite(joinedMesh, meshesForJoin[meshIndex], false)

                if not joinedMesh or not joinedMesh.isMesh

                    return meshes[0]

            joinedMesh.updateMatrixWorld(true)

            return joinedMesh

        catch error

            return meshes[0]
