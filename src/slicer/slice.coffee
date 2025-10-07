# Main slicing method for Polyslice.

coders = require('./coders')

Polytree = require('@jgphilpott/polytree')

module.exports =

    # Main slicing method that generates G-code from a scene.
    slice: (slicer, scene = {}) ->

        # Reset G-code output.
        slicer.gcode = ""

        # Extract mesh from scene if provided.
        mesh = @extractMesh(scene)

        # If no mesh provided, just generate basic initialization sequence.
        if not mesh

            if slicer.getAutohome()

                slicer.gcode += coders.codeAutohome(slicer)

            return slicer.gcode

        # Initialize THREE.js if not already available.
        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

        # Generate pre-print sequence (metadata, heating, autohome, test strip if enabled).
        slicer.gcode += coders.codePrePrint(slicer)

        # Get mesh bounding box for slicing.
        boundingBox = new THREE.Box3().setFromObject(mesh)
        minZ = boundingBox.min.z
        maxZ = boundingBox.max.z
        layerHeight = slicer.getLayerHeight()

        # Use Polytree to slice the mesh into layers.
        allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ, maxZ)

        # Calculate center offset to position on build plate.
        buildPlateWidth = slicer.getBuildPlateWidth()
        buildPlateLength = slicer.getBuildPlateLength()
        centerOffsetX = buildPlateWidth / 2
        centerOffsetY = buildPlateLength / 2

        verbose = slicer.getVerbose()

        # Turn on fan if configured (after pre-print, before actual printing).
        fanSpeed = slicer.getFanSpeed()

        if fanSpeed > 0

            slicer.gcode += coders.codeFanSpeed(slicer, fanSpeed)
            if verbose
                slicer.gcode += "; Start Cooling Fan" + slicer.newline

        if verbose
            slicer.gcode += coders.codeMessage(slicer, "Printing #{allLayers.length} layers...")

        # Process each layer.
        for layerIndex in [0...allLayers.length]

            layerSegments = allLayers[layerIndex]
            currentZ = minZ + (layerIndex + 1) * layerHeight

            if verbose
                slicer.gcode += coders.codeMessage(slicer, "Layer #{layerIndex + 1}/#{allLayers.length}")

            # Convert Polytree line segments to closed paths.
            layerPaths = @connectSegmentsToPaths(layerSegments)

            # Generate G-code for this layer with center offset.
            @generateLayerGCode(slicer, layerPaths, currentZ, layerIndex, centerOffsetX, centerOffsetY)

        # Generate post-print sequence (retract, home, cool down, buzzer if enabled).
        slicer.gcode += coders.codePostPrint(slicer)

        return slicer.gcode

    # Extract mesh from scene object.
    extractMesh: (scene) ->

        return null if not scene

        # If scene is already a mesh, return it.
        if scene.isMesh

            return scene

        # If scene has children, find first mesh.
        if scene.children and scene.children.length > 0

            for child in scene.children

                if child.isMesh

                    return child

        # If scene has a mesh property.
        if scene.mesh and scene.mesh.isMesh

            return scene.mesh

        return null

    # Convert Polytree line segments (Line3 objects) to closed paths.
    connectSegmentsToPaths: (segments) ->

        return [] if not segments or segments.length is 0

        paths = []
        usedSegments = new Set()
        epsilon = 0.001 # Tolerance for point matching.

        # Convert segments to simple edge format for easier processing.
        edges = []

        for segment in segments

            edges.push({
                start: {x: segment.start.x, y: segment.start.y}
                end: {x: segment.end.x, y: segment.end.y}
            })

        # Simple greedy path connection.
        for startEdgeIndex in [0...edges.length]

            continue if usedSegments.has(startEdgeIndex)

            currentPath = []
            currentEdge = edges[startEdgeIndex]
            usedSegments.add(startEdgeIndex)

            currentPath.push(currentEdge.start)
            currentPath.push(currentEdge.end)

            # Try to extend the path.
            searching = true

            while searching

                searching = false
                lastPoint = currentPath[currentPath.length - 1]

                # Find next connecting edge.
                for nextEdgeIndex in [0...edges.length]

                    continue if usedSegments.has(nextEdgeIndex)

                    nextEdge = edges[nextEdgeIndex]

                    # Check if next edge connects to current path end.
                    if @pointsMatch(lastPoint, nextEdge.start, epsilon)

                        currentPath.push(nextEdge.end)
                        usedSegments.add(nextEdgeIndex)
                        searching = true
                        break

                    else if @pointsMatch(lastPoint, nextEdge.end, epsilon)

                        currentPath.push(nextEdge.start)
                        usedSegments.add(nextEdgeIndex)
                        searching = true
                        break

            # Only add paths with at least 3 points.
            if currentPath.length >= 3

                paths.push(currentPath)

        return paths

    # Check if two points are within epsilon distance.
    pointsMatch: (p1, p2, epsilon) ->

        dx = p1.x - p2.x
        dy = p1.y - p2.y
        distSq = dx * dx + dy * dy

        return distSq < epsilon * epsilon

    # Generate G-code for a single layer.
    generateLayerGCode: (slicer, paths, z, layerIndex, centerOffsetX = 0, centerOffsetY = 0) ->

        return if paths.length is 0

        verbose = slicer.getVerbose()

        # Process each closed path (perimeter).
        for path in paths

            # Move to start of path (travel move) with center offset.
            firstPoint = path[0]
            offsetX = firstPoint.x + centerOffsetX
            offsetY = firstPoint.y + centerOffsetY

            slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, slicer.getTravelSpeed())
            if verbose
                slicer.gcode += ";TYPE:WALL-OUTER" + slicer.newline

            # Print perimeter.
            for pointIndex in [1...path.length]

                point = path[pointIndex]
                prevPoint = path[pointIndex - 1]

                # Calculate distance for extrusion.
                dx = point.x - prevPoint.x
                dy = point.y - prevPoint.y
                distance = Math.sqrt(dx * dx + dy * dy)

                # Calculate extrusion amount.
                extrusion = slicer.calculateExtrusion(distance, slicer.getNozzleDiameter())

                # Apply center offset to coordinates.
                offsetX = point.x + centerOffsetX
                offsetY = point.y + centerOffsetY

                slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, extrusion, slicer.getPerimeterSpeed())

            # Close the path by returning to start.
            if path.length > 2

                firstPoint = path[0]
                lastPoint = path[path.length - 1]

                dx = firstPoint.x - lastPoint.x
                dy = firstPoint.y - lastPoint.y
                distance = Math.sqrt(dx * dx + dy * dy)

                if distance > 0.001

                    extrusion = slicer.calculateExtrusion(distance, slicer.getNozzleDiameter())
                    offsetX = firstPoint.x + centerOffsetX
                    offsetY = firstPoint.y + centerOffsetY
                    slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, extrusion, slicer.getPerimeterSpeed())
