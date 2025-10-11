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
        slicer.gcode += slicer.newline

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

            if verbose
                slicer.gcode += coders.codeFanSpeed(slicer, fanSpeed).replace(slicer.newline, "; Start Cooling Fan" + slicer.newline)
            else
                slicer.gcode += coders.codeFanSpeed(slicer, fanSpeed)

        if verbose then slicer.gcode += coders.codeMessage(slicer, "Printing #{allLayers.length} layers...")

        # Process each layer.
        totalLayers = allLayers.length

        for layerIndex in [0...totalLayers]

            layerSegments = allLayers[layerIndex]
            currentZ = minZ + layerIndex * layerHeight

            # Convert Polytree line segments to closed paths.
            layerPaths = @connectSegmentsToPaths(layerSegments)

            # Only output layer marker if layer has content.
            if verbose and layerPaths.length > 0

                slicer.gcode += coders.codeMessage(slicer, "LAYER: #{layerIndex}")

            # Generate G-code for this layer with center offset.
            @generateLayerGCode(slicer, layerPaths, currentZ, layerIndex, centerOffsetX, centerOffsetY, totalLayers)

        slicer.gcode += slicer.newline # Add blank line before post-print for readability.
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
    # First simplifies path by merging near-collinear edges, then applies perpendicular offset.
    createInsetPath: (path, insetDistance) ->

        return [] if path.length < 3

        # Step 1: Simplify the path by detecting significant corners only.
        # A significant corner is one where the direction changes by more than a threshold.
        simplifiedPath = []
        angleThreshold = 0.05 # ~2.9 degrees in radians

        n = path.length

        for i in [0...n]

            prevIdx = if i is 0 then n - 1 else i - 1
            nextIdx = if i is n - 1 then 0 else i + 1

            p1 = path[prevIdx]
            p2 = path[i]
            p3 = path[nextIdx]

            # Calculate vectors for the two edges.
            v1x = p2.x - p1.x
            v1y = p2.y - p1.y
            v2x = p3.x - p2.x
            v2y = p3.y - p2.y

            len1 = Math.sqrt(v1x * v1x + v1y * v1y)
            len2 = Math.sqrt(v2x * v2x + v2y * v2y)

            # Skip if either edge is degenerate.
            if len1 < 0.0001 or len2 < 0.0001 then continue

            # Normalize vectors.
            v1x /= len1
            v1y /= len1
            v2x /= len2
            v2y /= len2

            # Calculate cross product to detect direction change.
            cross = v1x * v2y - v1y * v2x

            # If direction changes significantly, this is a real corner.
            if Math.abs(cross) > angleThreshold then simplifiedPath.push(p2)

        # If simplification resulted in < 4 points for rectangular shapes, use original path.
        # We want at least 4 corners for proper rectangular insets.
        if simplifiedPath.length < 4 then simplifiedPath = path

        # Step 2: Create inset using the simplified path.
        insetPath = []
        n = simplifiedPath.length

        # Calculate signed area to determine winding order.
        signedArea = 0

        for i in [0...n]

            nextIdx = if i is n - 1 then 0 else i + 1
            signedArea += simplifiedPath[i].x * simplifiedPath[nextIdx].y - simplifiedPath[nextIdx].x * simplifiedPath[i].y

        isCCW = signedArea > 0

        # Create offset lines for each edge.
        offsetLines = []

        for i in [0...n]

            nextIdx = if i is n - 1 then 0 else i + 1

            p1 = simplifiedPath[i]
            p2 = simplifiedPath[nextIdx]

            # Edge vector.
            edgeX = p2.x - p1.x
            edgeY = p2.y - p1.y

            edgeLength = Math.sqrt(edgeX * edgeX + edgeY * edgeY)

            if edgeLength < 0.0001 then continue

            # Normalize.
            edgeX /= edgeLength
            edgeY /= edgeLength

            if isCCW # Perpendicular inward normal.

                normalX = -edgeY
                normalY = edgeX

            else

                normalX = edgeY
                normalY = -edgeX

            # Offset the edge.
            offset1X = p1.x + normalX * insetDistance
            offset1Y = p1.y + normalY * insetDistance
            offset2X = p2.x + normalX * insetDistance
            offset2Y = p2.y + normalY * insetDistance

            offsetLines.push({
                p1: { x: offset1X, y: offset1Y }
                p2: { x: offset2X, y: offset2Y }
                originalIdx: i
            })

        # Find intersections of adjacent offset lines.
        for i in [0...offsetLines.length]

            prevIdx = if i is 0 then offsetLines.length - 1 else i - 1

            line1 = offsetLines[prevIdx]
            line2 = offsetLines[i]

            intersection = @lineIntersection(line1.p1, line1.p2, line2.p1, line2.p2)

            origVertex = simplifiedPath[line2.originalIdx]

            if intersection

                insetPath.push({ x: intersection.x, y: intersection.y, z: origVertex.z })

            else

                # Parallel lines - use midpoint of offset segment.
                insetPath.push({
                    x: line2.p1.x
                    y: line2.p1.y
                    z: origVertex.z
                })

        return insetPath

    # Calculate intersection point of two line segments.
    lineIntersection: (p1, p2, p3, p4) ->

        x1 = p1.x
        y1 = p1.y

        x2 = p2.x
        y2 = p2.y

        x3 = p3.x
        y3 = p3.y

        x4 = p4.x
        y4 = p4.y

        denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)

        # Lines are parallel or coincident.
        if Math.abs(denom) < 0.0001 then return null

        t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom

        # Calculate intersection point.
        x = x1 + t * (x2 - x1)
        y = y1 + t * (y2 - y1)

        return { x: x, y: y }

    # Generate G-code for a single layer.
    generateLayerGCode: (slicer, paths, z, layerIndex, centerOffsetX = 0, centerOffsetY = 0, totalLayers = 0) ->

        return if paths.length is 0

        verbose = slicer.getVerbose()

        # Initialize cumulative extrusion tracker if not exists.
        if not slicer.cumulativeE? then slicer.cumulativeE = 0

        layerHeight = slicer.getLayerHeight()
        nozzleDiameter = slicer.getNozzleDiameter()
        shellWallThickness = slicer.getShellWallThickness()
        shellSkinThickness = slicer.getShellSkinThickness()

        # Calculate number of walls based on shell wall thickness and nozzle diameter.
        # Each wall is approximately as wide as the nozzle diameter (it squishes to ~1x nozzle diameter).
        # Round down to get integer wall count.
        # Add small epsilon to handle floating point precision issues (e.g., 1.2/0.4 = 2.9999... should be 3).
        wallCount = Math.max(1, Math.floor((shellWallThickness / nozzleDiameter) + 0.0001))

        # Calculate number of skin layers (top and bottom solid layers).
        skinLayerCount = Math.max(1, Math.floor((shellSkinThickness / layerHeight) + 0.0001))

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

            # After walls, generate skin if this is a bottom or top layer.
            # Bottom layers: layerIndex <= skinLayerCount
            # Top layers: layerIndex >= (totalLayers - skinLayerCount)
            # Use <= for bottom because layer 0 is typically empty (on bed).
            isBottomLayer = layerIndex <= skinLayerCount
            isTopLayer = totalLayers > 0 and layerIndex >= (totalLayers - skinLayerCount)

            if isBottomLayer or isTopLayer

                # Generate skin for this layer.
                # currentPath now holds the innermost wall boundary.
                @generateSkinGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex)

            else

                # Generate infill for middle layers (not top/bottom).
                # Only generate if density > 0.
                infillDensity = slicer.getInfillDensity()

                if infillDensity > 0

                    # currentPath now holds the innermost wall boundary.
                    @generateInfillGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex)

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

        # Add descriptive comment for travel move if verbose.
        comment = "; Moving to #{wallType.toLowerCase().replace('-', ' ')}"
        slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeedMmMin).replace(slicer.newline, (if verbose then comment + slicer.newline else slicer.newline))

        if verbose then slicer.gcode += "; TYPE: #{wallType}" + slicer.newline

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

    # Generate G-code for skin (top/bottom solid infill).
    generateSkinGCode: (slicer, boundaryPath, z, centerOffsetX, centerOffsetY, layerIndex) ->

        return if boundaryPath.length < 3

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()

        if verbose then slicer.gcode += "; TYPE: SKIN" + slicer.newline

        # Step 1: Generate skin wall (perimeter pass around skin boundary).
        # Create an inset of full nozzle diameter from the boundary path.
        skinWallInset = nozzleDiameter
        skinWallPath = @createInsetPath(boundaryPath, skinWallInset)

        if skinWallPath.length >= 3

            # Move to start of skin wall.
            firstPoint = skinWallPath[0]
            offsetX = firstPoint.x + centerOffsetX
            offsetY = firstPoint.y + centerOffsetY

            travelSpeedMmMin = slicer.getTravelSpeed() * 60
            perimeterSpeedMmMin = slicer.getPerimeterSpeed() * 60

            slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeedMmMin).replace(slicer.newline, (if verbose then "; Moving to skin wall" + slicer.newline else slicer.newline))

            # Draw skin wall perimeter.
            for pointIndex in [1...skinWallPath.length]

                point = skinWallPath[pointIndex]
                prevPoint = skinWallPath[pointIndex - 1]

                dx = point.x - prevPoint.x
                dy = point.y - prevPoint.y

                distance = Math.sqrt(dx * dx + dy * dy)

                continue if distance < 0.001

                extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
                slicer.cumulativeE += extrusionDelta

                offsetX = point.x + centerOffsetX
                offsetY = point.y + centerOffsetY

                slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, slicer.cumulativeE, perimeterSpeedMmMin)

            # Close the skin wall loop.
            firstPoint = skinWallPath[0]
            lastPoint = skinWallPath[skinWallPath.length - 1]

            dx = firstPoint.x - lastPoint.x
            dy = firstPoint.y - lastPoint.y

            distance = Math.sqrt(dx * dx + dy * dy)

            if distance > 0.001

                extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
                slicer.cumulativeE += extrusionDelta

                offsetX = firstPoint.x + centerOffsetX
                offsetY = firstPoint.y + centerOffsetY

                slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, slicer.cumulativeE, perimeterSpeedMmMin)

        # Step 2: Generate diagonal skin infill at 45-degree angle.
        # Calculate bounding box with additional inset for gap from skin wall.
        infillGap = nozzleDiameter / 2  # Gap between skin wall and infill.
        infillInset = skinWallInset + infillGap  # Total: 1.5 * nozzleDiameter from boundary.

        # Create inset boundary for infill area.
        infillBoundary = @createInsetPath(boundaryPath, infillInset)

        return if infillBoundary.length < 3

        # Calculate bounding box of infill area.
        minX = Infinity
        maxX = -Infinity
        minY = Infinity
        maxY = -Infinity

        for point in infillBoundary

            if point.x < minX then minX = point.x
            if point.x > maxX then maxX = point.x
            if point.y < minY then minY = point.y
            if point.y > maxY then maxY = point.y

        # Generate diagonal infill lines at 45-degree angle.
        # Alternate direction per layer: odd layers at -45°, even layers at +45°.
        # Line spacing equal to nozzle diameter for solid infill.
        lineSpacing = nozzleDiameter

        # For 45-degree lines, we'll iterate along a diagonal axis.
        # Calculate the diagonal span.
        width = maxX - minX
        height = maxY - minY

        diagonalSpan = Math.sqrt(width * width + height * height)

        travelSpeedMmMin = slicer.getTravelSpeed() * 60
        infillSpeedMmMin = slicer.getInfillSpeed() * 60

        # Determine infill angle based on layer index.
        # Odd layers: -45° (y = -x + offset), Even layers: +45° (y = x + offset).
        useNegativeSlope = (layerIndex % 2) is 1

        # Start from appropriate diagonal position.
        if useNegativeSlope

            # For -45° (y = -x + offset): offset ranges from minY + minX to maxY + maxX.
            offset = minY + minX - diagonalSpan
            maxOffset = maxY + maxX

        else

            # For +45° (y = x + offset): offset ranges from minY - maxX to maxY - minX.
            offset = minY - maxX - diagonalSpan
            maxOffset = maxY - minX

        # Track last position for efficient zig-zag (minimize travel distance).
        lastEndPoint = null

        while offset < maxOffset

            # Calculate intersection points with bounding box.
            intersections = []

            if useNegativeSlope

                # Line equation: y = -x + offset (slope = -1).

                # Check intersection with left edge (x = minX).
                y = offset - minX
                if y >= minY and y <= maxY

                    intersections.push({ x: minX, y: y })

                # Check intersection with right edge (x = maxX).
                y = offset - maxX
                if y >= minY and y <= maxY

                    intersections.push({ x: maxX, y: y })

                # Check intersection with bottom edge (y = minY).
                x = offset - minY
                if x >= minX and x <= maxX

                    intersections.push({ x: x, y: minY })

                # Check intersection with top edge (y = maxY).
                x = offset - maxY
                if x >= minX and x <= maxX

                    intersections.push({ x: x, y: maxY })

            else

                # Line equation: y = x + offset (slope = +1).

                # Check intersection with left edge (x = minX).
                y = minX + offset
                if y >= minY and y <= maxY

                    intersections.push({ x: minX, y: y })

                # Check intersection with right edge (x = maxX).
                y = maxX + offset
                if y >= minY and y <= maxY

                    intersections.push({ x: maxX, y: y })

                # Check intersection with bottom edge (y = minY).
                x = minY - offset
                if x >= minX and x <= maxX

                    intersections.push({ x: x, y: minY })

                # Check intersection with top edge (y = maxY).
                x = maxY - offset
                if x >= minX and x <= maxX

                    intersections.push({ x: x, y: maxY })

            # We should have exactly 2 intersection points.
            if intersections.length >= 2

                # For zig-zag pattern, choose start/end to minimize travel distance.
                # If this is not the first line, pick the point closest to the last end point.
                if lastEndPoint?

                    # Calculate distances from last end point to both intersections.
                    dist0 = Math.sqrt((intersections[0].x - lastEndPoint.x) ** 2 + (intersections[0].y - lastEndPoint.y) ** 2)
                    dist1 = Math.sqrt((intersections[1].x - lastEndPoint.x) ** 2 + (intersections[1].y - lastEndPoint.y) ** 2)

                    # Start from the closer point.
                    if dist0 < dist1

                        startPoint = intersections[0]
                        endPoint = intersections[1]

                    else

                        startPoint = intersections[1]
                        endPoint = intersections[0]

                else

                    # First line: use consistent ordering.
                    startPoint = intersections[0]
                    endPoint = intersections[1]

                # Move to start of line (travel move).
                offsetStartX = startPoint.x + centerOffsetX
                offsetStartY = startPoint.y + centerOffsetY

                slicer.gcode += coders.codeLinearMovement(slicer, offsetStartX, offsetStartY, z, null, travelSpeedMmMin).replace(slicer.newline, (if verbose then "; Moving to skin infill line" + slicer.newline else slicer.newline))

                # Draw the diagonal line.
                dx = endPoint.x - startPoint.x
                dy = endPoint.y - startPoint.y

                distance = Math.sqrt(dx * dx + dy * dy)

                if distance > 0.001

                    extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
                    slicer.cumulativeE += extrusionDelta

                    offsetEndX = endPoint.x + centerOffsetX
                    offsetEndY = endPoint.y + centerOffsetY

                    slicer.gcode += coders.codeLinearMovement(slicer, offsetEndX, offsetEndY, z, slicer.cumulativeE, infillSpeedMmMin)

                    # Track where this line ended for next iteration.
                    lastEndPoint = endPoint

            # Move to next diagonal line.
            offset += lineSpacing * Math.sqrt(2)  # Account for 45-degree angle.

    # Generate G-code for infill (interior fill with variable density).
    generateInfillGCode: (slicer, boundaryPath, z, centerOffsetX, centerOffsetY, layerIndex) ->

        return if boundaryPath.length < 3

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()
        infillDensity = slicer.getInfillDensity()
        infillPattern = slicer.getInfillPattern()

        # Skip if no infill density configured.
        return if infillDensity <= 0

        # Only process grid pattern for now.
        # Other patterns (lines, triangles, cubic, gyroid, honeycomb) not yet implemented.
        return if infillPattern isnt 'grid'

        if verbose then slicer.gcode += "; TYPE: FILL" + slicer.newline

        # Create inset boundary for infill area (half nozzle diameter gap from innermost wall).
        infillGap = nozzleDiameter / 2
        infillBoundary = @createInsetPath(boundaryPath, infillGap)

        return if infillBoundary.length < 3

        # Calculate bounding box of infill area.
        minX = Infinity
        maxX = -Infinity
        minY = Infinity
        maxY = -Infinity

        for point in infillBoundary

            if point.x < minX then minX = point.x
            if point.x > maxX then maxX = point.x
            if point.y < minY then minY = point.y
            if point.y > maxY then maxY = point.y

        # Calculate line spacing based on infill density.
        # Since we generate BOTH +45° and -45° lines (crosshatch), we need to double
        # the spacing to achieve the target density. Each direction contributes half.
        # Formula: spacing = (nozzleDiameter / (density / 100)) * 2
        # For example: 20% density → spacing = (0.4 / 0.2) * 2 = 4.0mm per direction
        # This gives 10% in each direction, totaling 20% combined.
        baseSpacing = nozzleDiameter / (infillDensity / 100.0)
        lineSpacing = baseSpacing * 2.0  # Double for grid pattern (both directions).

        # For 45-degree lines, calculate the diagonal span.
        width = maxX - minX
        height = maxY - minY

        diagonalSpan = Math.sqrt(width * width + height * height)

        travelSpeedMmMin = slicer.getTravelSpeed() * 60
        infillSpeedMmMin = slicer.getInfillSpeed() * 60

        # Grid pattern: generate both +45° and -45° lines on EVERY layer (not alternating).
        # This creates a crosshatch pattern where lines intersect.
        # Unlike skin, infill uses the same pattern on all layers.
        # Center the grid at origin (0, 0) in local coordinates, which corresponds to
        # the build plate center after centerOffsetX/Y are applied.

        # Track last position for efficient zig-zag pattern.
        lastEndPoint = null

        # Generate +45° lines (y = x + offset), centered at origin (0, 0).
        # For a line passing through origin: y = x + 0, so centerOffset = 0.
        centerOffset = 0
        
        # Calculate how many lines to generate in each direction from center.
        numLinesUp = Math.ceil(diagonalSpan / (lineSpacing * Math.sqrt(2)))
        
        # Start from center and generate lines in both directions.
        offset = centerOffset - numLinesUp * lineSpacing * Math.sqrt(2)
        maxOffset = centerOffset + numLinesUp * lineSpacing * Math.sqrt(2)

        while offset < maxOffset

            # Calculate intersection points with bounding box.
            intersections = []

            # Line equation: y = x + offset (slope = +1).

            # Check intersection with left edge (x = minX).
            y = minX + offset
            if y >= minY and y <= maxY

                intersections.push({ x: minX, y: y })

            # Check intersection with right edge (x = maxX).
            y = maxX + offset
            if y >= minY and y <= maxY

                intersections.push({ x: maxX, y: y })

            # Check intersection with bottom edge (y = minY).
            x = minY - offset
            if x >= minX and x <= maxX

                intersections.push({ x: x, y: minY })

            # Check intersection with top edge (y = maxY).
            x = maxY - offset
            if x >= minX and x <= maxX

                intersections.push({ x: x, y: maxY })

            # We should have exactly 2 intersection points.
            if intersections.length >= 2

                # For zig-zag pattern, choose start/end to minimize travel distance.
                if lastEndPoint?

                    # Use squared distances for comparison (more efficient, no sqrt needed).
                    distSq0 = (intersections[0].x - lastEndPoint.x) ** 2 + (intersections[0].y - lastEndPoint.y) ** 2
                    distSq1 = (intersections[1].x - lastEndPoint.x) ** 2 + (intersections[1].y - lastEndPoint.y) ** 2

                    # Start from the closer point.
                    if distSq0 < distSq1

                        startPoint = intersections[0]
                        endPoint = intersections[1]

                    else

                        startPoint = intersections[1]
                        endPoint = intersections[0]

                else

                    # First line: use consistent ordering.
                    startPoint = intersections[0]
                    endPoint = intersections[1]

                # Move to start of line (travel move).
                offsetStartX = startPoint.x + centerOffsetX
                offsetStartY = startPoint.y + centerOffsetY

                slicer.gcode += coders.codeLinearMovement(slicer, offsetStartX, offsetStartY, z, null, travelSpeedMmMin).replace(slicer.newline, (if verbose then "; Moving to infill line" + slicer.newline else slicer.newline))

                # Draw the diagonal line.
                dx = endPoint.x - startPoint.x
                dy = endPoint.y - startPoint.y

                distance = Math.sqrt(dx * dx + dy * dy)

                if distance > 0.001

                    extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
                    slicer.cumulativeE += extrusionDelta

                    offsetEndX = endPoint.x + centerOffsetX
                    offsetEndY = endPoint.y + centerOffsetY

                    slicer.gcode += coders.codeLinearMovement(slicer, offsetEndX, offsetEndY, z, slicer.cumulativeE, infillSpeedMmMin)

                    # Track where this line ended for next iteration.
                    lastEndPoint = endPoint

            # Move to next diagonal line.
            offset += lineSpacing * Math.sqrt(2)  # Account for 45-degree angle.

        # Generate -45° lines (y = -x + offset), centered at origin (0, 0).
        # For a line passing through origin: y = -x + 0, so centerOffset = 0.
        centerOffset = 0
        
        # Start from center and generate lines in both directions.
        offset = centerOffset - numLinesUp * lineSpacing * Math.sqrt(2)
        maxOffset = centerOffset + numLinesUp * lineSpacing * Math.sqrt(2)

        while offset < maxOffset

            # Calculate intersection points with bounding box.
            intersections = []

            # Line equation: y = -x + offset (slope = -1).

            # Check intersection with left edge (x = minX).
            y = offset - minX
            if y >= minY and y <= maxY

                intersections.push({ x: minX, y: y })

            # Check intersection with right edge (x = maxX).
            y = offset - maxX
            if y >= minY and y <= maxY

                intersections.push({ x: maxX, y: y })

            # Check intersection with bottom edge (y = minY).
            x = offset - minY
            if x >= minX and x <= maxX

                intersections.push({ x: x, y: minY })

            # Check intersection with top edge (y = maxY).
            x = offset - maxY
            if x >= minX and x <= maxX

                intersections.push({ x: x, y: maxY })

            # We should have exactly 2 intersection points.
            if intersections.length >= 2

                # For zig-zag pattern, choose start/end to minimize travel distance.
                if lastEndPoint?

                    # Use squared distances for comparison (more efficient, no sqrt needed).
                    distSq0 = (intersections[0].x - lastEndPoint.x) ** 2 + (intersections[0].y - lastEndPoint.y) ** 2
                    distSq1 = (intersections[1].x - lastEndPoint.x) ** 2 + (intersections[1].y - lastEndPoint.y) ** 2

                    # Start from the closer point.
                    if distSq0 < distSq1

                        startPoint = intersections[0]
                        endPoint = intersections[1]

                    else

                        startPoint = intersections[1]
                        endPoint = intersections[0]

                else

                    # First line: use consistent ordering.
                    startPoint = intersections[0]
                    endPoint = intersections[1]

                # Move to start of line (travel move).
                offsetStartX = startPoint.x + centerOffsetX
                offsetStartY = startPoint.y + centerOffsetY

                slicer.gcode += coders.codeLinearMovement(slicer, offsetStartX, offsetStartY, z, null, travelSpeedMmMin).replace(slicer.newline, (if verbose then "; Moving to infill line" + slicer.newline else slicer.newline))

                # Draw the diagonal line.
                dx = endPoint.x - startPoint.x
                dy = endPoint.y - startPoint.y

                distance = Math.sqrt(dx * dx + dy * dy)

                if distance > 0.001

                    extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
                    slicer.cumulativeE += extrusionDelta

                    offsetEndX = endPoint.x + centerOffsetX
                    offsetEndY = endPoint.y + centerOffsetY

                    slicer.gcode += coders.codeLinearMovement(slicer, offsetEndX, offsetEndY, z, slicer.cumulativeE, infillSpeedMmMin)

                    # Track where this line ended for next iteration.
                    lastEndPoint = endPoint

            # Move to next diagonal line.
            offset += lineSpacing * Math.sqrt(2)  # Account for 45-degree angle.
