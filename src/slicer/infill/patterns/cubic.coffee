# Cubic infill pattern implementation for Polyslice.

coders = require('../../gcode/coders')

module.exports =

    # Generate cubic pattern infill (3D cubic lattice structure).
    # Cubic infill creates a TRUE 3D lattice where lines shift across layers to form cube edges.
    # The pattern creates tilted cubes in 3D space, with lines connecting across multiple Z layers.
    generateCubicInfill: (slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint = null, layerIndex = 0) ->

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()
        layerHeight = slicer.getLayerHeight()

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

        # TRUE Cubic pattern: Creates a 3D cubic lattice by shifting diagonal lines across layers.
        # The key difference from grid: lines shift their XY position as Z increases, 
        # creating a 3D interlocking structure rather than flat 2D layers.
        #
        # Pattern concept:
        # - Use diagonal lines at +45° and -45° (like grid)
        # - BUT shift the line positions progressively on each layer
        # - The shift creates a helical/spiral effect when viewed in 3D
        # - Lines from different layers connect diagonally in Z, forming 3D cube edges
        #
        # The pattern repeats every 4 layers (not 3) for proper cubic geometry:
        # - Layer 0: Lines at positions [0, spacing, 2*spacing, ...]
        # - Layer 1: Lines shift by spacing/4 in one direction
        # - Layer 2: Lines shift by spacing/2 (half period)
        # - Layer 3: Lines shift by 3*spacing/4
        # - Layer 4: Back to layer 0 pattern (completes the cycle)

        # Collect all infill line segments first, then sort/render to minimize travel.
        allInfillLines = []

        # Calculate the phase shift for this layer to create the 3D effect.
        # This shift moves the line pattern progressively on each layer.
        # The pattern repeats every 4 layers for proper cubic geometry.
        cycleLength = 4
        cyclePhase = layerIndex % cycleLength
        phaseShift = (cyclePhase * lineSpacing / cycleLength)

        # Calculate how many lines we need.
        numLines = Math.ceil(diagonalSpan / (lineSpacing * Math.sqrt(2)))

        # Generate +45° diagonal lines with phase shift.
        offset = -numLines * lineSpacing * Math.sqrt(2) + phaseShift
        maxOffset = numLines * lineSpacing * Math.sqrt(2) + phaseShift

        while offset < maxOffset

            intersections = []

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

        # Generate -45° diagonal lines with phase shift in opposite direction.
        # This creates the interlocking 3D structure.
        offset = -numLines * lineSpacing * Math.sqrt(2) - phaseShift
        maxOffset = numLines * lineSpacing * Math.sqrt(2) - phaseShift

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
