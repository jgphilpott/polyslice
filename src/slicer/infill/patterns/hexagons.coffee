# Hexagons infill pattern implementation for Polyslice.

coders = require('../../gcode/coders')

module.exports =

    # Generate hexagons pattern infill (tessellation at 0°, 60°, and 120°).
    generateHexagonsInfill: (slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint = null) ->

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

        # Hexagons pattern: generate lines at 0° (horizontal), 60°, and 120° (-60°).
        # This creates a tessellation of regular hexagons.
        # All three line sets must use the same perpendicular spacing.
        # We use lineSpacing as the base perpendicular distance between parallel lines in each set.

        # Collect all infill line segments first, then sort/render to minimize travel.
        allInfillLines = []

        # Generate horizontal lines at 0° (y = offset).
        # For horizontal lines, perpendicular spacing equals y-spacing directly.
        centerOffset = 0

        # Calculate how many lines to generate in each direction from center.
        numLinesUp = Math.ceil(height / lineSpacing)

        # Start from center and generate lines in both directions.
        offset = centerOffset - numLinesUp * lineSpacing
        maxOffset = centerOffset + numLinesUp * lineSpacing

        while offset < maxOffset

            # For horizontal line: y = offset.
            # Check if this y value intersects the bounding box.
            if offset >= minY and offset <= maxY

                # Line spans from minX to maxX at y = offset.
                allInfillLines.push({
                    start: { x: minX, y: offset }
                    end: { x: maxX, y: offset }
                })

            # Move to next horizontal line.
            offset += lineSpacing

        # Generate lines at 60°.
        # Slope = tan(60°) = sqrt(3) ≈ 1.732.
        # Line equation: y = sqrt(3) * x + offset.
        slope = Math.sqrt(3)

        # For lines at 60° angle, calculate offset step for same perpendicular spacing.
        # The perpendicular distance between lines is lineSpacing.
        # For angle 60°, offsetStep = lineSpacing / |cos(60°)| = lineSpacing / 0.5 = lineSpacing * 2
        angle60 = 60 * Math.PI / 180
        offsetStep60 = lineSpacing / Math.abs(Math.cos(angle60))
        centerOffset = 0

        # Calculate how many lines to generate.
        numLinesUp = Math.ceil(diagonalSpan / offsetStep60)

        # Start from center and generate lines in both directions.
        offset = centerOffset - numLinesUp * offsetStep60
        maxOffset = centerOffset + numLinesUp * offsetStep60

        while offset < maxOffset

            # Calculate intersection points with bounding box.
            intersections = []

            # Line equation: y = slope * x + offset.

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
            offset += offsetStep60

        # Generate lines at 120° (equivalent to -60°).
        # Slope = tan(120°) = -sqrt(3) ≈ -1.732.
        # Line equation: y = -sqrt(3) * x + offset.
        slope = -Math.sqrt(3)

        # For lines at 120° angle, calculate offset step for same perpendicular spacing.
        # For angle 120° (or -60°), offsetStep = lineSpacing / |cos(120°)| = lineSpacing / 0.5 = lineSpacing * 2
        angle120 = 120 * Math.PI / 180
        offsetStep120 = lineSpacing / Math.abs(Math.cos(angle120))
        centerOffset = 0

        # Calculate how many lines to generate.
        numLinesUp = Math.ceil(diagonalSpan / offsetStep120)

        # Start from center and generate lines in both directions.
        offset = centerOffset - numLinesUp * offsetStep120
        maxOffset = centerOffset + numLinesUp * offsetStep120

        while offset < maxOffset

            # Calculate intersection points with bounding box.
            intersections = []

            # Line equation: y = slope * x + offset.

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
            offset += offsetStep120

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
