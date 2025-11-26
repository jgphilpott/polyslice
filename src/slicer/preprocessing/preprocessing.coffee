# Mesh preprocessing module for Polyslice.
# Handles mesh analysis and subdivision for improving slicing quality.

LoopSubdivision = require('three-subdivide').LoopSubdivision

module.exports =

    # Preprocess mesh to improve triangle density in sparse regions.
    # This helps fill gaps that would otherwise cause missing segments during slicing.
    #
    # @param mesh [THREE.Mesh] The mesh to preprocess.
    # @return [THREE.Mesh] Preprocessed mesh with improved geometry.
    preprocessMesh: (mesh) ->

        # Initialize THREE.js if not already available.
        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

        # Get the geometry from the mesh.
        geometry = mesh.geometry

        return mesh if not geometry or not geometry.isBufferGeometry

        # Analyze geometry to determine if subdivision is needed.
        # Check triangle density distribution to identify sparse regions.
        needsSubdivision = @analyzeGeometryDensity(geometry)

        if needsSubdivision

            # Apply edge subdivision to increase triangle count in sparse regions.
            subdividedGeometry = @subdivideGeometry(geometry)

            # Create new mesh with subdivided geometry.
            subdividedMesh = new THREE.Mesh(subdividedGeometry, mesh.material)

            # Copy transform properties from original mesh.
            subdividedMesh.position.copy(mesh.position)
            subdividedMesh.rotation.copy(mesh.rotation)
            subdividedMesh.scale.copy(mesh.scale)
            subdividedMesh.updateMatrixWorld()

            return subdividedMesh

        return mesh

    # Analyze geometry to determine if it needs subdivision.
    # Returns true if geometry has regions with low triangle density.
    #
    # @param geometry [THREE.BufferGeometry] The geometry to analyze.
    # @return [Boolean] True if subdivision is recommended.
    analyzeGeometryDensity: (geometry) ->
        return false if not geometry

        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

        positionAttribute = geometry.getAttribute('position')
        return false if not positionAttribute

        # Get bounding box to calculate volume.
        geometry.computeBoundingBox()
        bbox = geometry.boundingBox

        return false if not bbox

        # Calculate bounding box volume.
        size = new THREE.Vector3()
        bbox.getSize(size)
        volume = size.x * size.y * size.z

        return false if volume <= 0

        # Count triangles.
        triangleCount = if geometry.index
            Math.floor(geometry.index.count / 3)
        else
            Math.floor(positionAttribute.count / 3)

        # Calculate triangle density (triangles per cubic unit).
        density = triangleCount / volume

        # Heuristic: If density is less than 5 triangles per cubic mm,
        # the mesh may benefit from subdivision.
        # This is an extremely conservative threshold that will only apply to
        # very sparse meshes like Benchy (which has ~5 triangles/mm³).
        # Most test geometries and properly designed models have much higher density
        # (e.g., simple test cubes have 100-1000+ triangles/mm³).
        DENSITY_THRESHOLD = 5

        return density < DENSITY_THRESHOLD

    # Subdivide geometry to increase triangle density.
    # Uses Loop subdivision algorithm via three-subdivide package.
    #
    # @param geometry [THREE.BufferGeometry] The geometry to subdivide.
    # @return [THREE.BufferGeometry] Subdivided geometry.
    subdivideGeometry: (geometry) ->

        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

        # Use Loop subdivision with 1 iteration (static method).
        # Loop subdivision is a smooth subdivision scheme that:
        # - Splits each triangle into 4 smaller triangles.
        # - Smooths the mesh by repositioning vertices.
        # - Maintains the overall shape while adding detail.
        #
        # iterations=1 provides a good balance:
        # - 4x triangle count (225k -> 900k for Benchy).
        # - Significant improvement in sparse regions.
        # - Reasonable computation time.
        #
        # Parameter rationale:
        # - split: true - ensures uniform subdivision across coplanar faces.
        # - uvSmooth: false - prevents UV coordinate averaging which causes texture tearing.
        # - preserveEdges: false - allows smooth subdivision (edge preservation makes sharper creases).
        # - flatOnly: false - subdivides all faces, not just flat ones.
        # - maxTriangles: Infinity - no limit, as we control subdivision via density threshold.
        params = {
            split: true           # Split coplanar faces for uniform subdivision.
            uvSmooth: false       # Don't average UVs (avoid tearing).
            preserveEdges: false  # Allow smooth subdivision.
            flatOnly: false       # Subdivide all faces.
            maxTriangles: Infinity # No triangle limit.
        }

        return LoopSubdivision.modify(geometry, 1, params)

    # Extract mesh from scene object.
    #
    # @param scene [Object] Scene or mesh object.
    # @return [THREE.Mesh|null] The extracted mesh or null.
    extractMesh: (scene) ->

        return null if not scene

        # If scene is already a mesh, return it.
        if scene.isMesh then return scene

        # If scene has children, find first mesh.
        if scene.children and scene.children.length > 0

            for child in scene.children

                if child.isMesh then return child

        # If scene has a mesh property.
        if scene.mesh and scene.mesh.isMesh

            return scene.mesh

        return null
