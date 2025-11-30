# Mesh preprocessing module for Polyslice.

LoopSubdivision = require('three-subdivide').LoopSubdivision

module.exports =

    # Preprocess mesh to improve triangle density in sparse regions.
    preprocessMesh: (mesh) ->

        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

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

        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

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

        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

        params = {
            split: true
            uvSmooth: false
            preserveEdges: false
            flatOnly: false
            maxTriangles: Infinity
        }

        return LoopSubdivision.modify(geometry, 1, params)

    # Extract mesh from scene object.
    extractMesh: (scene) ->

        return null if not scene

        if scene.isMesh then return scene

        if scene.children and scene.children.length > 0

            for child in scene.children

                if child.isMesh then return child

        if scene.mesh and scene.mesh.isMesh

            return scene.mesh

        return null
