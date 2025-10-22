# Skin generation module for Polyslice.

coders = require('../gcode/coders')
helpers = require('../geometry/helpers')

module.exports =

    # Generate G-code for skin (top/bottom solid infill).
    # If generateInfill is false, only skin walls are generated (useful for holes).
    # holeSkinWalls: Array of hole skin wall paths to exclude from skin infill.
    generateSkinGCode: (slicer, boundaryPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint = null, isHole = false, generateInfill = true, holeSkinWalls = []) ->

        return if boundaryPath.length < 3

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()

        if verbose then slicer.gcode += "; TYPE: SKIN" + slicer.newline

        # Step 1: Generate skin wall (perimeter pass around skin boundary).
        # Create an inset of full nozzle diameter from the boundary path.
        # Pass isHole parameter to ensure correct inset direction for holes.
        skinWallInset = nozzleDiameter
        skinWallPath = helpers.createInsetPath(boundaryPath, skinWallInset, isHole)

        if skinWallPath.length >= 3

            # Choose starting point closest to last wall position to minimize travel.
            if lastWallPoint?

                # Find the point in skinWallPath closest to lastWallPoint.
                minDistSq = Infinity
                startIdx = 0

                for point, idx in skinWallPath

                    distSq = (point.x - lastWallPoint.x) ** 2 + (point.y - lastWallPoint.y) ** 2

                    if distSq < minDistSq

                        minDistSq = distSq
                        startIdx = idx

                # Rotate the path to start from the closest point.
                skinWallPath = skinWallPath[startIdx...] .concat(skinWallPath[0...startIdx]) if startIdx > 0

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
        # Skip infill generation if requested (e.g., for holes where we only want walls).
        return unless generateInfill

        # Calculate bounding box with additional inset for gap from skin wall.
        infillGap = nozzleDiameter / 2  # Gap between skin wall and infill.
        infillInset = skinWallInset + infillGap  # Total: 1.5 * nozzleDiameter from boundary.

        # Create inset boundary for infill area.
        # Pass isHole parameter to ensure correct inset direction for holes.
        infillBoundary = helpers.createInsetPath(boundaryPath, infillInset, isHole)

        return if infillBoundary.length < 3

        # Create inset versions of hole skin walls to maintain the same gap.
        # For holes, we want to shrink them (outset from the hole's perspective) by the same infill gap.
        # This ensures skin infill maintains a consistent gap from all walls, including hole skin walls.
        holeSkinWallsWithGap = []

        for holeSkinWall in holeSkinWalls

            if holeSkinWall.length >= 3

                # Create outset path for the hole (isHole=true means it will shrink the hole).
                holeSkinWallWithGap = helpers.createInsetPath(holeSkinWall, infillGap, true)

                if holeSkinWallWithGap.length >= 3

                    holeSkinWallsWithGap.push(holeSkinWallWithGap)

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

                # Clip the line segment to the actual infill boundary polygon.
                # Also exclude hole areas by clipping against hole skin walls with gap.
                # This ensures skin infill stays within the boundary and outside holes with proper clearance.
                clippedSegments = helpers.clipLineWithHoles(intersections[0], intersections[1], infillBoundary, holeSkinWallsWithGap)

                # Process each clipped segment (usually just one for convex shapes).
                for segment in clippedSegments

                    startPoint = segment.start
                    endPoint = segment.end

                    # For zig-zag pattern, choose start/end to minimize travel distance.
                    # If this is not the first line, pick the point closest to the last end point.
                    if lastEndPoint?

                        # Calculate distances from last end point to both endpoints.
                        dist0 = Math.sqrt((startPoint.x - lastEndPoint.x) ** 2 + (startPoint.y - lastEndPoint.y) ** 2)
                        dist1 = Math.sqrt((endPoint.x - lastEndPoint.x) ** 2 + (endPoint.y - lastEndPoint.y) ** 2)

                        # Swap if starting from end is closer.
                        if dist1 < dist0

                            temp = startPoint
                            startPoint = endPoint
                            endPoint = temp

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
