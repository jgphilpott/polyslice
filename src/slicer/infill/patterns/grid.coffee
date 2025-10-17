# Grid infill pattern implementation for Polyslice.

coders = require('../../gcode/coders')
helpers = require('../../geometry/helpers')

module.exports =

    # Generate grid pattern infill (crosshatch at +45° and -45°).
    generateGridInfill: (slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint = null) ->

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

        # Collect all infill line segments first, then sort/render to minimize travel.
        allInfillLines = []

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

                # Clip the line segment to the actual infill boundary polygon.
                # This ensures infill stays within the boundary even for circular/irregular shapes.
                clippedSegments = helpers.clipLineToPolygon(intersections[0], intersections[1], infillBoundary)

                # Store each clipped segment for later rendering.
                for segment in clippedSegments

                    allInfillLines.push({
                        start: segment.start
                        end: segment.end
                    })

            # Move to next diagonal line.
            offset += lineSpacing * Math.sqrt(2) # Account for 45-degree angle.

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

                # Clip the line segment to the actual infill boundary polygon.
                # This ensures infill stays within the boundary even for circular/irregular shapes.
                clippedSegments = helpers.clipLineToPolygon(intersections[0], intersections[1], infillBoundary)

                # Store each clipped segment for later rendering.
                for segment in clippedSegments

                    allInfillLines.push({
                        start: segment.start
                        end: segment.end
                    })

            # Move to next diagonal line.
            offset += lineSpacing * Math.sqrt(2) # Account for 45-degree angle.

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
