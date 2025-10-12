# Gyroid infill pattern implementation for Polyslice.

coders = require('../../gcode/coders')

module.exports =

    # Generate gyroid pattern infill (triply periodic minimal surface).
    generateGyroidInfill: (slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint = null) ->

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

        travelSpeedMmMin = slicer.getTravelSpeed() * 60
        infillSpeedMmMin = slicer.getInfillSpeed() * 60

        # Gyroid pattern: a triply periodic minimal surface.
        # The gyroid is defined by: sin(x)cos(y) + sin(y)cos(z) + sin(z)cos(x) = 0
        # For 2D slicing at a given z-height, we fix z and solve for the contours in the x-y plane.
        # The pattern naturally varies between layers, creating strong 3D structure.

        # The lineSpacing parameter controls the scale/frequency of the gyroid pattern.
        # Smaller lineSpacing = denser pattern = higher frequency oscillations.
        scale = lineSpacing

        # Generate gyroid contours by marching through the x-y plane.
        # We'll use a grid-based approach to trace contour lines where the gyroid function crosses zero.
        # Resolution determines how finely we sample the gyroid function.
        resolution = nozzleDiameter / 2.0

        # Collect all infill line segments first, then sort/render to minimize travel.
        allInfillLines = []

        # For each row, scan for zero-crossings of the gyroid function.
        currentY = minY

        while currentY <= maxY

            # Track points where gyroid crosses zero along this scan line.
            crossingPoints = []

            currentX = minX
            prevValue = null

            while currentX <= maxX

                # Evaluate gyroid function at this point.
                # Scale coordinates to control pattern frequency.
                scaledX = currentX / scale
                scaledY = currentY / scale
                scaledZ = z / scale

                # Gyroid equation: sin(x)cos(y) + sin(y)cos(z) + sin(z)cos(x)
                gyroidValue = Math.sin(scaledX) * Math.cos(scaledY) + 
                              Math.sin(scaledY) * Math.cos(scaledZ) + 
                              Math.sin(scaledZ) * Math.cos(scaledX)

                # Check for zero crossing (sign change).
                if prevValue?

                    if (prevValue < 0 and gyroidValue >= 0) or (prevValue >= 0 and gyroidValue < 0)

                        # Linear interpolation to find more accurate crossing point.
                        t = -prevValue / (gyroidValue - prevValue)
                        crossingX = (currentX - resolution) + t * resolution

                        crossingPoints.push({ x: crossingX, y: currentY })

                prevValue = gyroidValue
                currentX += resolution

            # Connect consecutive crossing points to form line segments.
            i = 0

            while i < crossingPoints.length - 1

                allInfillLines.push({
                    start: crossingPoints[i]
                    end: crossingPoints[i + 1]
                })

                i += 2 # Skip to next pair (gyroid creates paired crossings)

            currentY += resolution

        # Also scan vertically for better coverage and to catch vertical portions.
        currentX = minX

        while currentX <= maxX

            # Track points where gyroid crosses zero along this scan line.
            crossingPoints = []

            currentY = minY
            prevValue = null

            while currentY <= maxY

                # Evaluate gyroid function at this point.
                scaledX = currentX / scale
                scaledY = currentY / scale
                scaledZ = z / scale

                # Gyroid equation.
                gyroidValue = Math.sin(scaledX) * Math.cos(scaledY) + 
                              Math.sin(scaledY) * Math.cos(scaledZ) + 
                              Math.sin(scaledZ) * Math.cos(scaledX)

                # Check for zero crossing.
                if prevValue?

                    if (prevValue < 0 and gyroidValue >= 0) or (prevValue >= 0 and gyroidValue < 0)

                        # Linear interpolation to find crossing point.
                        t = -prevValue / (gyroidValue - prevValue)
                        crossingY = (currentY - resolution) + t * resolution

                        crossingPoints.push({ x: currentX, y: crossingY })

                prevValue = gyroidValue
                currentY += resolution

            # Connect consecutive crossing points.
            i = 0

            while i < crossingPoints.length - 1

                allInfillLines.push({
                    start: crossingPoints[i]
                    end: crossingPoints[i + 1]
                })

                i += 2

            currentX += resolution

        # Filter out lines that are outside the infill boundary or too short.
        filteredLines = []

        for line in allInfillLines

            # Check if both endpoints are reasonably within bounds.
            if line.start.x >= minX and line.start.x <= maxX and
               line.start.y >= minY and line.start.y <= maxY and
               line.end.x >= minX and line.end.x <= maxX and
               line.end.y >= minY and line.end.y <= maxY

                # Calculate line length.
                dx = line.end.x - line.start.x
                dy = line.end.y - line.start.y
                length = Math.sqrt(dx * dx + dy * dy)

                # Only include lines longer than minimum threshold.
                if length > nozzleDiameter / 4.0

                    filteredLines.push(line)

        allInfillLines = filteredLines

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

            # Draw the line.
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
