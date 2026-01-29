# Mesh initialization and preprocessing for slicing.

Polytree = require('@jgphilpott/polytree')
preprocessingModule = require('../preprocessing/preprocessing')

module.exports =

    # Initialize and prepare mesh for slicing.
    initializeMesh: (scene) ->

        # Extract mesh from scene if provided.
        originalMesh = preprocessingModule.extractMesh(scene)

        # If no mesh provided, return null.
        return null if not originalMesh

        # Initialize THREE.js if not already available.
        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

        # Clone mesh to avoid modifying the original object.
        # This preserves the original mesh's position, rotation, and scale in the scene.
        # We use clone(true) for recursive cloning, then manually clone geometry to prevent
        # any shared state modifications (e.g., from computeBoundingBox calls).
        mesh = originalMesh.clone(true)
        mesh.geometry = originalMesh.geometry.clone()
        mesh.updateMatrixWorld()

        return { mesh, THREE }

    # Calculate mesh bounding box and adjust position if needed.
    prepareMeshForSlicing: (mesh, THREE) ->

        # Get mesh bounding box for slicing.
        boundingBox = new THREE.Box3().setFromObject(mesh)

        minZ = boundingBox.min.z
        maxZ = boundingBox.max.z

        # Ensure the mesh is positioned above the build plate (no negative Z).
        # If minZ < 0, raise the entire mesh so it sits on the build plate.
        if minZ < 0

            zOffset = -minZ
            mesh.position.z += zOffset
            mesh.updateMatrixWorld()

            # Recalculate bounding box after adjustment.
            boundingBox = new THREE.Box3().setFromObject(mesh)

            minZ = boundingBox.min.z
            maxZ = boundingBox.max.z

        return { boundingBox, minZ, maxZ }

    # Check mesh complexity and warn about potential performance issues.
    checkMeshComplexity: (mesh, minZ, maxZ, layerHeight) ->

        geometry = mesh.geometry
        return if not geometry or not geometry.attributes or not geometry.attributes.position

        positionCount = geometry.attributes.position.count
        triangleCount = if geometry.index then Math.floor(geometry.index.count / 3) else Math.floor(positionCount / 3)
        estimatedLayers = Math.ceil((maxZ - minZ) / layerHeight)

        # Complexity metric: triangles * layers (approximation)
        # Based on testing:
        # - Under 500k: Fast (< 10s)
        # - 500k - 1M: Moderate (10s - 30s)
        # - 1M - 5M: Slow (30s - 2min)
        # - Over 5M: Very slow or may appear to hang (>2min)
        complexityScore = triangleCount * estimatedLayers

        COMPLEXITY_WARNING_THRESHOLD = 1000000  # 1M
        COMPLEXITY_CRITICAL_THRESHOLD = 5000000  # 5M

        if complexityScore > COMPLEXITY_CRITICAL_THRESHOLD

            console.warn("    WARNING: Very high mesh complexity detected!")
            console.warn("    Triangles: #{triangleCount}, Estimated layers: #{estimatedLayers}")
            console.warn("    Complexity score: #{Math.floor(complexityScore / 1000)}k")
            console.warn("    Slicing may take several minutes or appear to hang.")
            console.warn("    Consider reducing mesh detail or increasing layer height.")
            console.warn("    See: https://github.com/jgphilpott/polyslice/blob/main/docs/slicer/MESH_COMPLEXITY.md\n")

        else if complexityScore > COMPLEXITY_WARNING_THRESHOLD

            console.warn("    High mesh complexity detected. Slicing may take 30-60 seconds.")
            console.warn("    Triangles: #{triangleCount}, Layers: #{estimatedLayers}, Score: #{Math.floor(complexityScore / 1000)}k\n")

    # Apply preprocessing to mesh if enabled.
    preprocessMesh: (slicer, mesh) ->

        if slicer.getMeshPreprocessing and slicer.getMeshPreprocessing()

            return preprocessingModule.preprocessMesh(mesh)

        return mesh

    # Slice mesh into layers using Polytree.
    sliceMeshIntoLayers: (mesh, layerHeight, minZ, maxZ) ->

        # Small epsilon offset avoids slicing at exact geometric boundaries.
        SLICE_EPSILON = 0.001
        adjustedMinZ = minZ + SLICE_EPSILON

        # Use Polytree to slice the mesh into layers with adjusted starting position.
        allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, adjustedMinZ, maxZ)

        return { allLayers, adjustedMinZ }

    # Calculate center offsets to position mesh on build plate center.
    calculateCenterOffsets: (boundingBox, buildPlateWidth, buildPlateLength) ->

        # Calculate the mesh's bounding box center in XY plane.
        meshCenterX = (boundingBox.min.x + boundingBox.max.x) / 2
        meshCenterY = (boundingBox.min.y + boundingBox.max.y) / 2

        # Calculate offsets to center the mesh on the build plate.
        # The offset should map the mesh center to the build plate center.
        centerOffsetX = (buildPlateWidth / 2) - meshCenterX
        centerOffsetY = (buildPlateLength / 2) - meshCenterY

        return { centerOffsetX, centerOffsetY }

    # Store mesh bounds for metadata (convert to build plate coordinates).
    storeMeshBounds: (slicer, boundingBox, centerOffsetX, centerOffsetY) ->

        slicer.meshBounds = {
            minX: boundingBox.min.x + centerOffsetX
            maxX: boundingBox.max.x + centerOffsetX
            minY: boundingBox.min.y + centerOffsetY
            maxY: boundingBox.max.y + centerOffsetY
            minZ: boundingBox.min.z
            maxZ: boundingBox.max.z
        }
