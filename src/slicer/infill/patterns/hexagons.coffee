# Hexagons infill pattern implementation for Polyslice.

coders = require('../../gcode/coders')

# Helper function to clip a line segment to a rectangular bounding box.
# Uses Cohen-Sutherland line clipping algorithm.
clipLineToBounds = (p1, p2, minX, maxX, minY, maxY) ->

    # Compute outcodes for both endpoints.
    INSIDE = 0  # 0000
    LEFT = 1    # 0001
    RIGHT = 2   # 0010
    BOTTOM = 4  # 0100
    TOP = 8     # 1000

    computeOutcode = (x, y) ->
        code = INSIDE
        if x < minX then code |= LEFT
        else if x > maxX then code |= RIGHT
        if y < minY then code |= BOTTOM
        else if y > maxY then code |= TOP
        return code

    x1 = p1.x
    y1 = p1.y
    x2 = p2.x
    y2 = p2.y

    outcode1 = computeOutcode(x1, y1)
    outcode2 = computeOutcode(x2, y2)

    while true

        # Both endpoints inside - accept.
        if (outcode1 | outcode2) is 0
            return { p1: { x: x1, y: y1 }, p2: { x: x2, y: y2 } }

        # Both endpoints outside same region - reject.
        if (outcode1 & outcode2) != 0
            return null

        # At least one endpoint is outside - find intersection.
        outcodeOut = if outcode1 != 0 then outcode1 else outcode2

        # Find intersection point.
        if (outcodeOut & TOP) != 0
            x = x1 + (x2 - x1) * (maxY - y1) / (y2 - y1)
            y = maxY
        else if (outcodeOut & BOTTOM) != 0
            x = x1 + (x2 - x1) * (minY - y1) / (y2 - y1)
            y = minY
        else if (outcodeOut & RIGHT) != 0
            y = y1 + (y2 - y1) * (maxX - x1) / (x2 - x1)
            x = maxX
        else if (outcodeOut & LEFT) != 0
            y = y1 + (y2 - y1) * (minX - x1) / (x2 - x1)
            x = minX

        # Replace point outside with intersection point.
        if outcodeOut is outcode1
            x1 = x
            y1 = y
            outcode1 = computeOutcode(x1, y1)
        else
            x2 = x
            y2 = y
            outcode2 = computeOutcode(x2, y2)

module.exports =

    # Generate hexagons pattern infill (honeycomb tessellation).
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

        travelSpeedMmMin = slicer.getTravelSpeed() * 60
        infillSpeedMmMin = slicer.getInfillSpeed() * 60

        # Honeycomb pattern: create actual hexagon cells that tessellate.
        # For a regular hexagon with center-to-center distance based on lineSpacing:
        # - Hexagon side length: s = lineSpacing / sqrt(3)
        # - Horizontal spacing between hexagon centers: 1.5 * s
        # - Vertical spacing between hexagon rows: sqrt(3) * s
        
        # Adjust lineSpacing to create appropriate hexagon size.
        # The lineSpacing parameter represents the desired spacing between hexagon centers.
        hexagonSide = lineSpacing / Math.sqrt(3)
        horizontalSpacing = 1.5 * hexagonSide
        verticalSpacing = Math.sqrt(3) * hexagonSide

        # Collect all hexagon edge segments.
        allInfillLines = []

        # Calculate hexagon grid starting from center (0, 0).
        # Determine how many rows and columns we need to cover the area.
        numRows = Math.ceil(height / verticalSpacing) + 2
        numCols = Math.ceil(width / horizontalSpacing) + 2

        # Generate hexagons in a honeycomb pattern centered at origin.
        for row in [-numRows..numRows]

            for col in [-numCols..numCols]

                # Calculate hexagon center position.
                # In honeycomb, every other row is offset by half horizontal spacing.
                centerX = col * 2 * horizontalSpacing
                
                if row % 2 != 0
                    centerX += horizontalSpacing

                centerY = row * verticalSpacing

                # Generate the 6 vertices of this hexagon.
                vertices = []
                
                for i in [0...6]
                
                    angle = (i * 60) * Math.PI / 180
                    vx = centerX + hexagonSide * Math.cos(angle)
                    vy = centerY + hexagonSide * Math.sin(angle)
                    vertices.push({ x: vx, y: vy })

                # Check if any part of this hexagon is within the bounding box.
                # Simple check: if any vertex is within an expanded boundary.
                expandedMargin = hexagonSide * 2
                hexagonInBounds = false
                
                for v in vertices
                
                    if v.x >= minX - expandedMargin and v.x <= maxX + expandedMargin and
                       v.y >= minY - expandedMargin and v.y <= maxY + expandedMargin
                        hexagonInBounds = true
                        break

                # If hexagon is potentially visible, add its edges.
                if hexagonInBounds
                
                    for i in [0...6]
                    
                        v1 = vertices[i]
                        v2 = vertices[(i + 1) % 6]

                        # Clip edge to bounding box.
                        clippedSegment = clipLineToBounds(v1, v2, minX, maxX, minY, maxY)

                        if clippedSegment?
                        
                            # Store clipped edge segment.
                            allInfillLines.push({
                                start: { x: clippedSegment.p1.x, y: clippedSegment.p1.y }
                                end: { x: clippedSegment.p2.x, y: clippedSegment.p2.y }
                            })

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
