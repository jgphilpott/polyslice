# Triangles infill pattern implementation for Polyslice.

coders = require('../../gcode/coders')

module.exports =

    # Generate triangles pattern infill (tessellation at 0°, +60°, and -60°).
    generateTrianglesInfill: (slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint = null) ->

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()

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

        # Calculate span for pattern coverage.
        width = maxX - minX
        height = maxY - minY

        diagonalSpan = Math.sqrt(width * width + height * height)

        travelSpeedMmMin = slicer.getTravelSpeed() * 60
        infillSpeedMmMin = slicer.getInfillSpeed() * 60

        # Triangles pattern: generate lines at 0°, +60°, and -60° angles.
        # This creates a tessellation of equilateral triangles.
        # Unlike grid which uses +45° and -45°, triangles use horizontal and two 60° diagonals.
        # Center the pattern at origin (0, 0) in local coordinates.

        # Collect all infill line segments first, then sort/render to minimize travel.
        allInfillLines = []

        # Generate horizontal lines (0°, y = constant).
        # For horizontal lines, we iterate through Y values.
        centerOffset = 0

        # Calculate how many lines to generate in each direction from center.
        numLinesUp = Math.ceil(height / lineSpacing)

        # Start from center and generate lines in both directions.
        offset = centerOffset - numLinesUp * lineSpacing
        maxOffset = centerOffset + numLinesUp * lineSpacing

        while offset < maxOffset

            # Horizontal line at y = offset.
            # Check if line intersects the bounding box.
            y = offset

            if y >= minY and y <= maxY

                # Line extends from minX to maxX at this y.
                allInfillLines.push({
                    start: { x: minX, y: y }
                    end: { x: maxX, y: y }
                })

            # Move to next horizontal line.
            offset += lineSpacing

        # Generate +60° lines (slope = tan(60°) = sqrt(3) ≈ 1.732).
        # Line equation: y = sqrt(3) * x + offset.
        # For 60-degree lines, the perpendicular spacing between lines is lineSpacing * 2 / sqrt(3).
        # This accounts for the projection of the spacing onto the perpendicular direction.
        slope = Math.sqrt(3)
        diagonalLineSpacing = lineSpacing * 2 / Math.sqrt(3)
        centerOffset = 0

        # Calculate how many lines to generate.
        numLinesUp = Math.ceil(diagonalSpan / diagonalLineSpacing)

        # Start from center and generate lines in both directions.
        offset = centerOffset - numLinesUp * diagonalLineSpacing
        maxOffset = centerOffset + numLinesUp * diagonalLineSpacing

        while offset < maxOffset

            # Calculate intersection points with bounding box.
            intersections = []

            # Line equation: y = sqrt(3) * x + offset.

            # Check intersection with left edge (x = minX).
            y = slope * minX + offset
            if y >= minY and y <= maxY

                intersections.push({ x: minX, y: y })

            # Check intersection with right edge (x = maxX).
            y = slope * maxX + offset
            if y >= minY and y <= maxY

                intersections.push({ x: maxX, y: y })

            # Check intersection with bottom edge (y = minY).
            x = (minY - offset) / slope
            if x >= minX and x <= maxX

                intersections.push({ x: x, y: minY })

            # Check intersection with top edge (y = maxY).
            x = (maxY - offset) / slope
            if x >= minX and x <= maxX

                intersections.push({ x: x, y: maxY })

            # We should have exactly 2 intersection points.
            if intersections.length >= 2

                # Store this line segment for later rendering.
                allInfillLines.push({
                    start: intersections[0]
                    end: intersections[1]
                })

            # Move to next diagonal line.
            offset += diagonalLineSpacing

        # Generate -60° lines (slope = tan(-60°) = -sqrt(3)).
        # Line equation: y = -sqrt(3) * x + offset.
        slope = -Math.sqrt(3)
        centerOffset = 0

        # Start from center and generate lines in both directions.
        offset = centerOffset - numLinesUp * diagonalLineSpacing
        maxOffset = centerOffset + numLinesUp * diagonalLineSpacing

        while offset < maxOffset

            # Calculate intersection points with bounding box.
            intersections = []

            # Line equation: y = -sqrt(3) * x + offset.

            # Check intersection with left edge (x = minX).
            y = slope * minX + offset
            if y >= minY and y <= maxY

                intersections.push({ x: minX, y: y })

            # Check intersection with right edge (x = maxX).
            y = slope * maxX + offset
            if y >= minY and y <= maxY

                intersections.push({ x: maxX, y: y })

            # Check intersection with bottom edge (y = minY).
            x = (minY - offset) / slope
            if x >= minX and x <= maxX

                intersections.push({ x: x, y: minY })

            # Check intersection with top edge (y = maxY).
            x = (maxY - offset) / slope
            if x >= minX and x <= maxX

                intersections.push({ x: x, y: maxY })

            # We should have exactly 2 intersection points.
            if intersections.length >= 2

                # Store this line segment for later rendering.
                allInfillLines.push({
                    start: intersections[0]
                    end: intersections[1]
                })

            # Move to next diagonal line.
            offset += diagonalLineSpacing

        # Now render all collected lines in optimal order to minimize travel.
        # Start with the line closest to the last wall position.
        lastEndPoint = lastWallPoint

        while allInfillLines.length > 0

            # Find the line with an endpoint closest to current position.
            minDistSq = Infinity
            bestLineIdx = 0
            bestFlipped = false

            for line, idx in allInfillLines

                # Check distance to both endpoints of this line.
                if lastEndPoint?

                    distSq0 = (line.start.x - lastEndPoint.x) ** 2 + (line.start.y - lastEndPoint.y) ** 2
                    distSq1 = (line.end.x - lastEndPoint.x) ** 2 + (line.end.y - lastEndPoint.y) ** 2

                    if distSq0 < minDistSq

                        minDistSq = distSq0
                        bestLineIdx = idx
                        bestFlipped = false # Start from line.start

                    if distSq1 < minDistSq

                        minDistSq = distSq1
                        bestLineIdx = idx
                        bestFlipped = true # Start from line.end (flip the line)

                else

                    break # No last position, just use first line.

            # Get the best line and remove it from the list.
            bestLine = allInfillLines[bestLineIdx]
            allInfillLines.splice(bestLineIdx, 1)

            # Determine start and end based on whether we need to flip.
            if bestFlipped

                startPoint = bestLine.end
                endPoint = bestLine.start

            else

                startPoint = bestLine.start
                endPoint = bestLine.end

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
