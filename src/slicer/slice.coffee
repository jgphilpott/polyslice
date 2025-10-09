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

        # Reset cumulative extrusion counter (absolute mode starts at 0).
        slicer.cumulativeE = 0

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
            if verbose then slicer.gcode += "; Start Cooling Fan" + slicer.newline

        if verbose then slicer.gcode += coders.codeMessage(slicer, "Printing #{allLayers.length} layers...")

        # Process each layer.
        for layerIndex in [0...allLayers.length]

            layerSegments = allLayers[layerIndex]
            currentZ = minZ + layerIndex * layerHeight

            # Convert Polytree line segments to closed paths.
            layerPaths = @connectSegmentsToPaths(layerSegments)

            # Only output layer marker if layer has content.
            if verbose and layerPaths.length > 0
                slicer.gcode += coders.codeMessage(slicer, "LAYER:#{layerIndex}")

            # Generate G-code for this layer with center offset.
            @generateLayerGCode(slicer, layerPaths, currentZ, layerIndex, centerOffsetX, centerOffsetY)

        # Generate post-print sequence (retract, home, cool down, buzzer if enabled).
        slicer.gcode += coders.codePostPrint(slicer)

        return slicer.gcode

    # Extract mesh from scene object.
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
            maxIterations = edges.length * 2 # Prevent infinite loops.
            iterations = 0

            while searching and iterations < maxIterations

                iterations++

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

            # Only add paths with at least 3 points and remove duplicate last point if it matches first.
            if currentPath.length >= 3

                firstPoint = currentPath[0]
                lastPoint = currentPath[currentPath.length - 1]

                # Remove last point if it's the same as first (closed loop).
                if @pointsMatch(firstPoint, lastPoint, epsilon)

                    currentPath.pop()

                # Only add if still have at least 3 points.
                if currentPath.length >= 3 then paths.push(currentPath)

        return paths

    # Check if two points are within epsilon distance.
    pointsMatch: (p1, p2, epsilon) ->

        dx = p1.x - p2.x
        dy = p1.y - p2.y

        distSq = dx * dx + dy * dy

        return distSq < epsilon * epsilon

    # Create an inset path (shrink inward by specified distance).
    # Uses edge-normal based offsetting for accurate, uniform inset.
    createInsetPath: (path, insetDistance) ->

        return [] if path.length < 3

        insetPath = []
        n = path.length

        # Calculate signed area to determine winding order.
        # Using shoelace formula: sum of (x[i] * y[i+1] - x[i+1] * y[i]) / 2.
        signedArea = 0

        for i in [0...n]

            nextIdx = if i is n - 1 then 0 else i + 1
            signedArea += path[i].x * path[nextIdx].y - path[nextIdx].x * path[i].y

        # For inset (shrinking), we need to move perpendicular inward.
        # If signedArea > 0, path is CCW in standard math coordinates (Y up).
        # If signedArea < 0, path is CW in standard math coordinates.
        # We'll test and use the direction that gives us inward offset.
        isCCW = signedArea > 0

        # For each vertex, calculate the inset position based on adjacent edge normals.
        for i in [0...n]

            prevIdx = if i is 0 then n - 1 else i - 1
            nextIdx = if i is n - 1 then 0 else i + 1

            currentPoint = path[i]
            prevPoint = path[prevIdx]
            nextPoint = path[nextIdx]

            # Edge vector from previous to current point.
            edge1X = currentPoint.x - prevPoint.x
            edge1Y = currentPoint.y - prevPoint.y
            edge1Length = Math.sqrt(edge1X * edge1X + edge1Y * edge1Y)

            # Edge vector from current to next point.
            edge2X = nextPoint.x - currentPoint.x
            edge2Y = nextPoint.y - currentPoint.y
            edge2Length = Math.sqrt(edge2X * edge2X + edge2Y * edge2Y)

            # Skip degenerate edges.
            if edge1Length < 0.0001 or edge2Length < 0.0001

                insetPath.push({ x: currentPoint.x, y: currentPoint.y, z: currentPoint.z })

                continue

            # Normalize edges.
            edge1X /= edge1Length
            edge1Y /= edge1Length
            edge2X /= edge2Length
            edge2Y /= edge2Length

            # Calculate inward normals (perpendicular to edges).
            # For CCW winding, inward is left normal (rotate 90° counter-clockwise).
            # For CW winding, inward is right normal (rotate 90° clockwise).
            if isCCW
                # CCW - use left normals (rotate edge 90° counter-clockwise).
                normal1X = -edge1Y
                normal1Y = edge1X
                normal2X = -edge2Y
                normal2Y = edge2X
            else
                # CW - use right normals (rotate edge 90° clockwise).
                normal1X = edge1Y
                normal1Y = -edge1X
                normal2X = edge2Y
                normal2Y = -edge2X

            # Average the two normals to get the bisector direction.
            avgNormalX = (normal1X + normal2X) / 2
            avgNormalY = (normal1Y + normal2Y) / 2

            avgLength = Math.sqrt(avgNormalX * avgNormalX + avgNormalY * avgNormalY)

            # Skip if normals cancel out (180° angle).
            if avgLength < 0.0001

                insetPath.push({ x: currentPoint.x, y: currentPoint.y, z: currentPoint.z })

                continue

            # Normalize the average normal.
            avgNormalX /= avgLength
            avgNormalY /= avgLength

            # Calculate the angle between the two edges to adjust inset distance.
            # The inset distance needs to be scaled by 1/sin(angle/2) to maintain uniform offset.
            dotProduct = edge1X * edge2X + edge1Y * edge2Y
            angleBetween = Math.acos(Math.max(-1, Math.min(1, dotProduct)))
            halfAngle = angleBetween / 2

            # Avoid division by zero for straight edges.
            sinHalfAngle = Math.sin(halfAngle)

            if sinHalfAngle < 0.01
                scaledInset = insetDistance
            else
                scaledInset = insetDistance / sinHalfAngle

            # Clamp scaled inset to avoid excessive offsets at sharp angles.
            scaledInset = Math.min(scaledInset, insetDistance * 10)

            # Move point along the bisector normal by the scaled inset distance.
            insetX = currentPoint.x + avgNormalX * scaledInset
            insetY = currentPoint.y + avgNormalY * scaledInset

            insetPath.push({ x: insetX, y: insetY, z: currentPoint.z })

        return insetPath

    # Generate G-code for a single layer.
    generateLayerGCode: (slicer, paths, z, layerIndex, centerOffsetX = 0, centerOffsetY = 0) ->

        return if paths.length is 0

        verbose = slicer.getVerbose()

        # Initialize cumulative extrusion tracker if not exists.
        if not slicer.cumulativeE?
            slicer.cumulativeE = 0

        nozzleDiameter = slicer.getNozzleDiameter()
        shellWallThickness = slicer.getShellWallThickness()

        # Calculate number of walls based on shell wall thickness and nozzle diameter.
        # Each wall is approximately as wide as the nozzle diameter (it squishes to ~1x nozzle diameter).
        # Round down to get integer wall count.
        # Add small epsilon to handle floating point precision issues (e.g., 1.2/0.4 = 2.9999... should be 3).
        wallCount = Math.max(1, Math.floor((shellWallThickness / nozzleDiameter) + 0.0001))

        # Process each closed path (perimeter).
        for path in paths

            # Skip degenerate paths.
            continue if path.length < 3

            currentPath = path

            # Generate walls from outer to inner.
            for wallIndex in [0...wallCount]

                # Determine wall type for TYPE annotation.
                if wallIndex is 0
                    wallType = "WALL-OUTER"
                else if wallIndex is wallCount - 1
                    wallType = "WALL-INNER"
                else
                    wallType = "WALL-INNER"

                # Generate this wall.
                @generateWallGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, wallType)

                # Create inset path for next wall (if not last wall).
                if wallIndex < wallCount - 1

                    insetPath = @createInsetPath(currentPath, nozzleDiameter)

                    # Stop if inset path becomes degenerate.
                    break if insetPath.length < 3

                    currentPath = insetPath

    # Generate G-code for a single wall (outer or inner).
    generateWallGCode: (slicer, path, z, centerOffsetX, centerOffsetY, wallType) ->

        return if path.length < 3

        verbose = slicer.getVerbose()

        # Move to start of path (travel move) with center offset.
        firstPoint = path[0]

        offsetX = firstPoint.x + centerOffsetX
        offsetY = firstPoint.y + centerOffsetY

        # Convert speed from mm/s to mm/min for G-code.
        travelSpeedMmMin = slicer.getTravelSpeed() * 60

        slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeedMmMin)
        if verbose then slicer.gcode += ";TYPE:#{wallType}" + slicer.newline

        # Print perimeter.
        for pointIndex in [1...path.length]

            point = path[pointIndex]
            prevPoint = path[pointIndex - 1]

            # Calculate distance for extrusion.
            dx = point.x - prevPoint.x
            dy = point.y - prevPoint.y

            distance = Math.sqrt(dx * dx + dy * dy)

            # Skip negligible movements.
            continue if distance < 0.001

            # Calculate extrusion amount for this segment.
            extrusionDelta = slicer.calculateExtrusion(distance, slicer.getNozzleDiameter())

            # Add to cumulative extrusion (absolute mode).
            slicer.cumulativeE += extrusionDelta

            # Apply center offset to coordinates.
            offsetX = point.x + centerOffsetX
            offsetY = point.y + centerOffsetY

            # Convert speed from mm/s to mm/min for G-code.
            perimeterSpeedMmMin = slicer.getPerimeterSpeed() * 60

            slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, slicer.cumulativeE, perimeterSpeedMmMin)

        # Close the path by returning to start if needed.
        firstPoint = path[0]
        lastPoint = path[path.length - 1]

        dx = firstPoint.x - lastPoint.x
        dy = firstPoint.y - lastPoint.y

        distance = Math.sqrt(dx * dx + dy * dy)

        if distance > 0.001

            # Calculate extrusion amount for closing segment.
            extrusionDelta = slicer.calculateExtrusion(distance, slicer.getNozzleDiameter())

            # Add to cumulative extrusion (absolute mode).
            slicer.cumulativeE += extrusionDelta

            offsetX = firstPoint.x + centerOffsetX
            offsetY = firstPoint.y + centerOffsetY

            # Convert speed from mm/s to mm/min for G-code.
            perimeterSpeedMmMin = slicer.getPerimeterSpeed() * 60

            slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, slicer.cumulativeE, perimeterSpeedMmMin)
