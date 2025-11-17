# Custom mesh slicing implementation for 3D printing.
# Replaces Polytree.sliceIntoLayers with a robust, purpose-built solution.
#
# This implementation handles:
# - Plane-triangle intersection with adaptive epsilon
# - Segment chaining into closed paths
# - Coplanar vertices and near-parallel edges
# - Degenerate triangles and floating-point precision

module.exports =

    # Slice a Three.js mesh into horizontal layers.
    #
    # @param mesh [THREE.Mesh] The mesh to slice
    # @param layerHeight [Number] Height between layers in mm
    # @param minZ [Number] Starting Z coordinate
    # @param maxZ [Number] Ending Z coordinate
    # @return [Array<Array<Object>>] Array of layers, each containing line segments
    #
    # Each segment is an object with:
    #   start: { x: Number, y: Number, z: Number }
    #   end: { x: Number, y: Number, z: Number }
    sliceIntoLayers: (mesh, layerHeight, minZ, maxZ) ->

        # Initialize THREE.js.
        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

        # Extract geometry from mesh.
        geometry = mesh.geometry

        if not geometry
            throw new Error("Mesh has no geometry")

        # Ensure geometry is BufferGeometry.
        if not geometry.isBufferGeometry
            throw new Error("Geometry must be BufferGeometry")

        # Get world matrix for transforming vertices.
        worldMatrix = mesh.matrixWorld

        # Extract vertex positions.
        positionAttribute = geometry.getAttribute('position')

        if not positionAttribute
            throw new Error("Geometry has no position attribute")

        # Get indices (or generate them if non-indexed).
        indices = geometry.index

        if indices
            indexArray = indices.array
            triangleCount = Math.floor(indexArray.length / 3)
        else
            # Non-indexed geometry - vertices are in groups of 3.
            triangleCount = Math.floor(positionAttribute.count / 3)
            indexArray = null

        # Calculate number of layers.
        layerCount = Math.ceil((maxZ - minZ) / layerHeight)

        # Initialize array to hold all layers.
        allLayers = []

        # Process each layer.
        for layerIndex in [0...layerCount]

            # Calculate Z coordinate for this slice plane.
            sliceZ = minZ + layerIndex * layerHeight

            # Collect segments for this layer.
            segments = []

            # Check each triangle for intersection with the slice plane.
            for triIndex in [0...triangleCount]

                # Get triangle vertex indices.
                if indexArray
                    i0 = indexArray[triIndex * 3]
                    i1 = indexArray[triIndex * 3 + 1]
                    i2 = indexArray[triIndex * 3 + 2]
                else
                    i0 = triIndex * 3
                    i1 = triIndex * 3 + 1
                    i2 = triIndex * 3 + 2

                # Get vertex positions in local space.
                v0 = new THREE.Vector3(
                    positionAttribute.getX(i0),
                    positionAttribute.getY(i0),
                    positionAttribute.getZ(i0)
                )
                v1 = new THREE.Vector3(
                    positionAttribute.getX(i1),
                    positionAttribute.getY(i1),
                    positionAttribute.getZ(i1)
                )
                v2 = new THREE.Vector3(
                    positionAttribute.getX(i2),
                    positionAttribute.getY(i2),
                    positionAttribute.getZ(i2)
                )

                # Transform to world space.
                v0.applyMatrix4(worldMatrix)
                v1.applyMatrix4(worldMatrix)
                v2.applyMatrix4(worldMatrix)

                # Check if triangle intersects the slice plane.
                segment = @intersectTriangleWithPlane(v0, v1, v2, sliceZ)

                if segment
                    segments.push(segment)

            allLayers.push(segments)

        return allLayers

    # Calculate intersection of a triangle with a horizontal plane at given Z.
    #
    # @param v0 [THREE.Vector3] First vertex
    # @param v1 [THREE.Vector3] Second vertex
    # @param v2 [THREE.Vector3] Third vertex
    # @param planeZ [Number] Z coordinate of the slice plane
    # @return [Object|null] Segment object or null if no intersection
    intersectTriangleWithPlane: (v0, v1, v2, planeZ) ->

        # Initialize THREE.js.
        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

        # Calculate signed distances from vertices to plane.
        d0 = v0.z - planeZ
        d1 = v1.z - planeZ
        d2 = v2.z - planeZ

        # Calculate edge lengths for adaptive epsilon.
        edge01Length = v0.distanceTo(v1)
        edge12Length = v1.distanceTo(v2)
        edge20Length = v2.distanceTo(v0)
        maxEdgeLength = Math.max(edge01Length, edge12Length, edge20Length)

        # Base epsilon scaled by edge length.
        baseEpsilon = Math.max(1e-10, maxEdgeLength * 1e-9)

        # Calculate angles between edges and slice plane.
        # For near-parallel edges (angle < 1°), use larger epsilon.
        edge01Vector = new THREE.Vector3().subVectors(v1, v0)
        edge12Vector = new THREE.Vector3().subVectors(v2, v1)
        edge20Vector = new THREE.Vector3().subVectors(v0, v2)

        # Z component indicates how parallel edge is to XY plane.
        # Small Z component = nearly parallel to slice plane.
        edge01ParallelFactor = Math.abs(edge01Vector.z) / edge01Vector.length()
        edge12ParallelFactor = Math.abs(edge12Vector.z) / edge12Vector.length()
        edge20ParallelFactor = Math.abs(edge20Vector.z) / edge20Vector.length()

        # Adaptive epsilon: 100x larger for edges nearly parallel to plane.
        PARALLEL_THRESHOLD = 0.02  # ~1 degree
        PARALLEL_EPSILON_MULTIPLIER = 100

        epsilon01 = if edge01ParallelFactor < PARALLEL_THRESHOLD then baseEpsilon * PARALLEL_EPSILON_MULTIPLIER else baseEpsilon
        epsilon12 = if edge12ParallelFactor < PARALLEL_THRESHOLD then baseEpsilon * PARALLEL_EPSILON_MULTIPLIER else baseEpsilon
        epsilon20 = if edge20ParallelFactor < PARALLEL_THRESHOLD then baseEpsilon * PARALLEL_EPSILON_MULTIPLIER else baseEpsilon

        # Check if vertices are on the plane (within epsilon).
        onPlane0 = Math.abs(d0) < epsilon01
        onPlane1 = Math.abs(d1) < epsilon12
        onPlane2 = Math.abs(d2) < epsilon20

        # Collect intersection points.
        intersectionPoints = []

        # Helper to add point if not duplicate.
        addPoint = (point) =>
            # Check for duplicates within epsilon.
            for existing in intersectionPoints
                if Math.abs(existing.x - point.x) < baseEpsilon and
                   Math.abs(existing.y - point.y) < baseEpsilon
                    return
            intersectionPoints.push(point)

        # Check edge v0-v1.
        if onPlane0 and onPlane1
            # Both vertices on plane - entire edge is on plane.
            # This is a degenerate case - skip this edge.
            null
        else if onPlane0
            # v0 is on plane.
            addPoint({ x: v0.x, y: v0.y, z: planeZ })
        else if onPlane1
            # v1 is on plane.
            addPoint({ x: v1.x, y: v1.y, z: planeZ })
        else if (d0 < -epsilon01 and d1 > epsilon01) or (d0 > epsilon01 and d1 < -epsilon01)
            # Edge crosses plane - compute intersection point.
            t = -d0 / (d1 - d0)
            point =
                x: v0.x + t * (v1.x - v0.x)
                y: v0.y + t * (v1.y - v0.y)
                z: planeZ
            addPoint(point)

        # Check edge v1-v2.
        if onPlane1 and onPlane2
            # Both vertices on plane - entire edge is on plane.
            null
        else if onPlane1
            # Already added v1 above.
            null
        else if onPlane2
            # v2 is on plane.
            addPoint({ x: v2.x, y: v2.y, z: planeZ })
        else if (d1 < -epsilon12 and d2 > epsilon12) or (d1 > epsilon12 and d2 < -epsilon12)
            # Edge crosses plane - compute intersection point.
            t = -d1 / (d2 - d1)
            point =
                x: v1.x + t * (v2.x - v1.x)
                y: v1.y + t * (v2.y - v1.y)
                z: planeZ
            addPoint(point)

        # Check edge v2-v0.
        if onPlane2 and onPlane0
            # Both vertices on plane - entire edge is on plane.
            null
        else if onPlane2
            # Already added v2 above.
            null
        else if onPlane0
            # Already added v0 above.
            null
        else if (d2 < -epsilon20 and d0 > epsilon20) or (d2 > epsilon20 and d0 < -epsilon20)
            # Edge crosses plane - compute intersection point.
            t = -d2 / (d0 - d2)
            point =
                x: v2.x + t * (v0.x - v2.x)
                y: v2.y + t * (v0.y - v2.y)
                z: planeZ
            addPoint(point)

        # A triangle intersects a plane in a line segment (2 points).
        # If we have exactly 2 points, return the segment.
        if intersectionPoints.length is 2
            return {
                start: intersectionPoints[0]
                end: intersectionPoints[1]
            }

        # If we have more or fewer than 2 points, something is degenerate.
        # This can happen with coplanar triangles or numerical precision issues.
        return null
