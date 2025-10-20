# Hexagons infill pattern implementation for Polyslice.

coders = require('../../gcode/coders')
helpers = require('../../geometry/helpers')

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

        # Honeycomb pattern: create actual hexagon cells that tessellate with shared edges.
        # Hexagons are drawn in flat-top orientation (flat sides horizontal).
        # Vertices start at 30° and increment by 60°: 30°, 90°, 150°, 210°, 270°, 330°
        # For a regular hexagon with side length 's':
        # - Width (point-to-point horizontally): 2 * s (but edges are at s*sqrt(3))
        # - Height (flat-to-flat vertically): sqrt(3) * s
        # - Horizontal spacing between centers: s * sqrt(3) (for edge sharing)
        # - Vertical spacing between rows: 1.5 * s
        # - Every other row offset by: s * sqrt(3) / 2 (half of horizontal spacing)

        # Adjust lineSpacing to create appropriate hexagon size.
        # The lineSpacing parameter represents the desired spacing between hexagon centers.
        hexagonSide = lineSpacing / Math.sqrt(3)
        horizontalSpacing = hexagonSide * Math.sqrt(3)
        verticalSpacing = 1.5 * hexagonSide

        # Collect unique hexagon edge segments (avoid drawing shared edges twice).
        uniqueEdges = {}

        # Helper to create edge key (ensures consistent ordering).
        createEdgeKey = (x1, y1, x2, y2) ->

            # Use precise rounding to 0.01mm precision (10 microns).
            rx1 = Math.round(x1 * 100) / 100
            ry1 = Math.round(y1 * 100) / 100
            rx2 = Math.round(x2 * 100) / 100
            ry2 = Math.round(y2 * 100) / 100

            # Order points to ensure edge direction doesn't matter.
            if rx1 < rx2 or (rx1 is rx2 and ry1 < ry2)

                return "#{rx1},#{ry1}-#{rx2},#{ry2}"

            else

                return "#{rx2},#{ry2}-#{rx1},#{ry1}"

        # Calculate pattern center (build plate center, not origin).
        # The build plate center is at centerOffsetX, centerOffsetY.
        patternCenterX = 0
        patternCenterY = 0

        # Determine how many rows and columns we need to cover the area.
        numRows = Math.ceil(height / verticalSpacing) + 2
        numCols = Math.ceil(width / horizontalSpacing) + 2

        # Generate hexagons in a honeycomb pattern centered at pattern center.
        for row in [-numRows..numRows]

            for col in [-numCols..numCols]

                # Calculate hexagon center position relative to pattern center.
                # In honeycomb, every other row is offset by half horizontal spacing.
                centerX = patternCenterX + col * horizontalSpacing

                if row % 2 != 0

                    centerX += horizontalSpacing / 2

                centerY = patternCenterY + row * verticalSpacing

                # Generate the 6 vertices of this hexagon (flat-top orientation).
                # Vertices start at 30° and go clockwise: 30°, 90°, 150°, 210°, 270°, 330°
                vertices = []

                for i in [0...6]

                    angle = (30 + i * 60) * Math.PI / 180

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

                        # Clip edge to the actual infill boundary polygon.
                        # This ensures infill stays within the boundary even for circular/irregular shapes.
                        clippedSegments = helpers.clipLineToPolygon(v1, v2, infillBoundary)

                        # Process each clipped segment (usually just one for convex shapes).
                        for clippedSegment in clippedSegments

                            # Create edge key AFTER clipping (using clipped coordinates).
                            edgeKey = createEdgeKey(
                                clippedSegment.start.x, clippedSegment.start.y,
                                clippedSegment.end.x, clippedSegment.end.y
                            )

                            # Only add edge if we haven't seen it before.
                            if not uniqueEdges[edgeKey]

                                # Store clipped edge segment.
                                uniqueEdges[edgeKey] = {
                                    start: { x: clippedSegment.start.x, y: clippedSegment.start.y }
                                    end: { x: clippedSegment.end.x, y: clippedSegment.end.y }
                                }

        # Convert unique edges map to array.
        allInfillLines = []

        for key, edge of uniqueEdges

            if edge? # Only add edges that were successfully clipped and stored.

                allInfillLines.push(edge)

        # Build a connectivity graph to find connected edge chains.
        # This allows drawing multiple connected edges in one continuous path.
        # Use a helper function to create consistent point keys.
        createPointKey = (x, y) ->

            # Round to 0.01mm precision (10 microns).
            rx = Math.round(x * 100) / 100
            ry = Math.round(y * 100) / 100

            return "#{rx},#{ry}"

        pointToEdges = {}  # Map from point key to list of edge indices.

        for edge, idx in allInfillLines

            # Create point keys for start and end.
            startKey = createPointKey(edge.start.x, edge.start.y)
            endKey = createPointKey(edge.end.x, edge.end.y)

            if not pointToEdges[startKey]

                pointToEdges[startKey] = []

            if not pointToEdges[endKey]

                pointToEdges[endKey] = []

            pointToEdges[startKey].push({ idx: idx, endpoint: 'start' })
            pointToEdges[endKey].push({ idx: idx, endpoint: 'end' })

        # Track which edges have been drawn.
        drawnEdges = {}
        lastEndPoint = lastWallPoint

        while Object.keys(drawnEdges).length < allInfillLines.length

            # Find the nearest undrawn edge to current position.
            minDistSq = Infinity
            bestIdx = -1
            bestFlipped = false

            for edge, idx in allInfillLines

                if drawnEdges[idx]

                    continue

                if lastEndPoint?

                    distSq0 = (edge.start.x - lastEndPoint.x) ** 2 + (edge.start.y - lastEndPoint.y) ** 2
                    distSq1 = (edge.end.x - lastEndPoint.x) ** 2 + (edge.end.y - lastEndPoint.y) ** 2

                    if distSq0 < minDistSq

                        minDistSq = distSq0
                        bestIdx = idx
                        bestFlipped = false

                    if distSq1 < minDistSq

                        minDistSq = distSq1
                        bestIdx = idx
                        bestFlipped = true

                else

                    bestIdx = idx
                    bestFlipped = false

                    break

            if bestIdx is -1

                break  # No more edges to draw.

            # Build a chain of connected edges starting from bestIdx.
            chain = []
            currentIdx = bestIdx
            currentFlipped = bestFlipped

            while currentIdx isnt -1 and not drawnEdges[currentIdx]

                edge = allInfillLines[currentIdx]
                drawnEdges[currentIdx] = true

                if currentFlipped

                    chain.push({ start: edge.end, end: edge.start })
                    currentPoint = edge.start

                else

                    chain.push({ start: edge.start, end: edge.end })
                    currentPoint = edge.end

                # Look for a connected edge at currentPoint.
                pointKey = createPointKey(currentPoint.x, currentPoint.y)
                nextIdx = -1

                if pointToEdges[pointKey]

                    for connection in pointToEdges[pointKey]

                        if not drawnEdges[connection.idx]

                            nextIdx = connection.idx
                            currentFlipped = (connection.endpoint is 'end')

                            break

                currentIdx = nextIdx

            # Draw the chain.
            for segment, segIdx in chain

                if segIdx is 0

                    # First segment: travel move to start.
                    offsetStartX = segment.start.x + centerOffsetX
                    offsetStartY = segment.start.y + centerOffsetY

                    slicer.gcode += coders.codeLinearMovement(slicer, offsetStartX, offsetStartY, z, null, travelSpeedMmMin).replace(slicer.newline, (if verbose then "; Moving to infill line" + slicer.newline else slicer.newline))

                # Draw extrusion move.
                dx = segment.end.x - segment.start.x
                dy = segment.end.y - segment.start.y

                distance = Math.sqrt(dx * dx + dy * dy)

                if distance > 0.001

                    extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
                    slicer.cumulativeE += extrusionDelta

                    offsetEndX = segment.end.x + centerOffsetX
                    offsetEndY = segment.end.y + centerOffsetY

                    slicer.gcode += coders.codeLinearMovement(slicer, offsetEndX, offsetEndY, z, slicer.cumulativeE, infillSpeedMmMin)

                    lastEndPoint = segment.end
