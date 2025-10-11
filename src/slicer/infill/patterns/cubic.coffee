# Cubic infill pattern implementation for Polyslice.

coders = require('../../gcode/coders')

module.exports =

    # Generate cubic pattern infill (3D cubic lattice structure).
    # Cubic infill creates a 3D lattice by rotating diagonal lines across layers.
    # Pattern repeats every 3 layers with different orientations to form cube diagonals.
    generateCubicInfill: (slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint = null, layerIndex = 0) ->

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

        # For diagonal lines, calculate the span.
        width = maxX - minX
        height = maxY - minY

        diagonalSpan = Math.sqrt(width * width + height * height)

        travelSpeedMmMin = slicer.getTravelSpeed() * 60
        infillSpeedMmMin = slicer.getInfillSpeed() * 60

        # Cubic pattern: rotate diagonal lines every layer to form 3D cubic structure.
        # Use layer index modulo 3 to determine which orientation to use.
        # Layer 0: +45° and -45° (like grid).
        # Layer 1: +45° rotated 60° (creates different diagonal).
        # Layer 2: +45° rotated 120° (creates third diagonal).
        # This creates a repeating 3-layer pattern that forms cubic cells in 3D.

        orientation = layerIndex % 3

        # Collect all infill line segments first, then sort/render to minimize travel.
        allInfillLines = []

        # Center the pattern at origin (0, 0) in local coordinates.
        centerOffset = 0

        # Calculate how many lines to generate in each direction from center.
        # For cubic pattern, we use wider spacing since we're building a 3D structure.
        # The spacing is already calculated in the parent to account for density.
        numLines = Math.ceil(diagonalSpan / (lineSpacing * Math.sqrt(2)))

        # Generate diagonal lines based on current layer orientation.
        if orientation is 0

            # Layer 0: Standard +45° and -45° lines (same as grid pattern).
            # Generate +45° lines (y = x + offset).
            offset = centerOffset - numLines * lineSpacing * Math.sqrt(2)
            maxOffset = centerOffset + numLines * lineSpacing * Math.sqrt(2)

            while offset < maxOffset

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

                # Store line segment if we have exactly 2 intersection points.
                if intersections.length >= 2

                    allInfillLines.push({
                        start: intersections[0]
                        end: intersections[1]
                    })

                offset += lineSpacing * Math.sqrt(2)

            # Generate -45° lines (y = -x + offset).
            offset = centerOffset - numLines * lineSpacing * Math.sqrt(2)
            maxOffset = centerOffset + numLines * lineSpacing * Math.sqrt(2)

            while offset < maxOffset

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

                # Store line segment if we have exactly 2 intersection points.
                if intersections.length >= 2

                    allInfillLines.push({
                        start: intersections[0]
                        end: intersections[1]
                    })

                offset += lineSpacing * Math.sqrt(2)

        else if orientation is 1

            # Layer 1: Lines at different angles to form cubic structure.
            # Use only one set of parallel lines rotated from the base orientation.
            # This creates the second diagonal direction of the cube.
            offset = centerOffset - numLines * lineSpacing * Math.sqrt(2)
            maxOffset = centerOffset + numLines * lineSpacing * Math.sqrt(2)

            while offset < maxOffset

                intersections = []

                # For cubic infill, use +45° lines only on odd layers in the cycle.
                # Line equation: y = x + offset (slope = +1).
                y = minX + offset
                if y >= minY and y <= maxY

                    intersections.push({ x: minX, y: y })

                y = maxX + offset
                if y >= minY and y <= maxY

                    intersections.push({ x: maxX, y: y })

                x = minY - offset
                if x >= minX and x <= maxX

                    intersections.push({ x: x, y: minY })

                x = maxY - offset
                if x >= minX and x <= maxX

                    intersections.push({ x: x, y: maxY })

                if intersections.length >= 2

                    allInfillLines.push({
                        start: intersections[0]
                        end: intersections[1]
                    })

                offset += lineSpacing * Math.sqrt(2)

        else if orientation is 2

            # Layer 2: Lines at third angle to complete cubic structure.
            # Use -45° lines only on this layer in the cycle.
            offset = centerOffset - numLines * lineSpacing * Math.sqrt(2)
            maxOffset = centerOffset + numLines * lineSpacing * Math.sqrt(2)

            while offset < maxOffset

                intersections = []

                # Line equation: y = -x + offset (slope = -1).
                y = offset - minX
                if y >= minY and y <= maxY

                    intersections.push({ x: minX, y: y })

                y = offset - maxX
                if y >= minY and y <= maxY

                    intersections.push({ x: maxX, y: y })

                x = offset - minY
                if x >= minX and x <= maxX

                    intersections.push({ x: x, y: minY })

                x = offset - maxY
                if x >= minX and x <= maxX

                    intersections.push({ x: x, y: maxY })

                if intersections.length >= 2

                    allInfillLines.push({
                        start: intersections[0]
                        end: intersections[1]
                    })

                offset += lineSpacing * Math.sqrt(2)

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
