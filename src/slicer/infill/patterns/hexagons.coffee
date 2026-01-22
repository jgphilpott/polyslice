# Hexagons infill pattern implementation for Polyslice.

coders = require('../../gcode/coders')
clipping = require('../../utils/clipping')
combing = require('../../geometry/combing')

module.exports =

    # Generate hexagons pattern infill (honeycomb tessellation).
    generateHexagonsInfill: (slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint = null, holeInnerWalls = [], holeOuterWalls = []) ->

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()

        minX = Infinity
        maxX = -Infinity
        minY = Infinity
        maxY = -Infinity

        for point in infillBoundary

            if point.x < minX then minX = point.x
            if point.x > maxX then maxX = point.x
            if point.y < minY then minY = point.y
            if point.y > maxY then maxY = point.y

        width = maxX - minX
        height = maxY - minY

        travelSpeedMmMin = slicer.getTravelSpeed() * 60
        infillSpeedMmMin = slicer.getInfillSpeed() * 60

        # Honeycomb: flat-top hexagons with shared edges.
        hexagonSide = lineSpacing / Math.sqrt(3)
        horizontalSpacing = hexagonSide * Math.sqrt(3)
        verticalSpacing = 1.5 * hexagonSide

        uniqueEdges = {}

        createEdgeKey = (x1, y1, x2, y2) ->

            rx1 = Math.round(x1 * 100) / 100
            ry1 = Math.round(y1 * 100) / 100
            rx2 = Math.round(x2 * 100) / 100
            ry2 = Math.round(y2 * 100) / 100

            if rx1 < rx2 or (rx1 is rx2 and ry1 < ry2)

                return "#{rx1},#{ry1}-#{rx2},#{ry2}"

            else

                return "#{rx2},#{ry2}-#{rx1},#{ry1}"

        # Center the hexagon pattern on the infill boundary center.
        patternCenterX = (minX + maxX) / 2
        patternCenterY = (minY + maxY) / 2

        numRows = Math.ceil(height / verticalSpacing) + 2
        numCols = Math.ceil(width / horizontalSpacing) + 2

        for row in [-numRows..numRows]

            for col in [-numCols..numCols]

                centerX = patternCenterX + col * horizontalSpacing

                if row % 2 != 0

                    centerX += horizontalSpacing / 2

                centerY = patternCenterY + row * verticalSpacing

                vertices = []

                for i in [0...6]

                    angle = (30 + i * 60) * Math.PI / 180

                    vx = centerX + hexagonSide * Math.cos(angle)
                    vy = centerY + hexagonSide * Math.sin(angle)

                    vertices.push({ x: vx, y: vy })

                expandedMargin = hexagonSide * 2
                hexagonInBounds = false

                for v in vertices

                    if v.x >= minX - expandedMargin and v.x <= maxX + expandedMargin and
                       v.y >= minY - expandedMargin and v.y <= maxY + expandedMargin

                        hexagonInBounds = true

                        break

                if hexagonInBounds

                    for i in [0...6]

                        v1 = vertices[i]
                        v2 = vertices[(i + 1) % 6]

                        clippedSegments = clipping.clipLineWithHoles(v1, v2, infillBoundary, holeInnerWalls)

                        for clippedSegment in clippedSegments

                            edgeKey = createEdgeKey(
                                clippedSegment.start.x, clippedSegment.start.y,
                                clippedSegment.end.x, clippedSegment.end.y
                            )

                            if not uniqueEdges[edgeKey]

                                uniqueEdges[edgeKey] = {
                                    start: { x: clippedSegment.start.x, y: clippedSegment.start.y }
                                    end: { x: clippedSegment.end.x, y: clippedSegment.end.y }
                                }

        allInfillLines = []

        for key, edge of uniqueEdges

            if edge?

                allInfillLines.push(edge)

        # Build connectivity graph for chaining edges.
        createPointKey = (x, y) ->

            rx = Math.round(x * 100) / 100
            ry = Math.round(y * 100) / 100

            return "#{rx},#{ry}"

        pointToEdges = {}

        for edge, idx in allInfillLines

            startKey = createPointKey(edge.start.x, edge.start.y)
            endKey = createPointKey(edge.end.x, edge.end.y)

            if not pointToEdges[startKey]

                pointToEdges[startKey] = []

            if not pointToEdges[endKey]

                pointToEdges[endKey] = []

            pointToEdges[startKey].push({ idx: idx, endpoint: 'start' })
            pointToEdges[endKey].push({ idx: idx, endpoint: 'end' })

        drawnEdges = {}
        lastEndPoint = lastWallPoint

        while Object.keys(drawnEdges).length < allInfillLines.length

            minDistSq = Infinity
            bestIdx = -1
            bestFlipped = false
            bestCrossesHole = true

            for edge, idx in allInfillLines

                if drawnEdges[idx]

                    continue

                if lastEndPoint?

                    distSq0 = (edge.start.x - lastEndPoint.x) ** 2 + (edge.start.y - lastEndPoint.y) ** 2
                    distSq1 = (edge.end.x - lastEndPoint.x) ** 2 + (edge.end.y - lastEndPoint.y) ** 2

                    crossesHole0 = combing.travelPathCrossesHoles(lastEndPoint, edge.start, holeOuterWalls)
                    crossesHole1 = combing.travelPathCrossesHoles(lastEndPoint, edge.end, holeOuterWalls)

                    if distSq0 < minDistSq

                        if not bestCrossesHole and crossesHole0

                            continue

                        else if bestCrossesHole and not crossesHole0

                            minDistSq = distSq0
                            bestIdx = idx
                            bestFlipped = false
                            bestCrossesHole = crossesHole0

                        else

                            minDistSq = distSq0
                            bestIdx = idx
                            bestFlipped = false
                            bestCrossesHole = crossesHole0

                    if distSq1 < minDistSq

                        if not bestCrossesHole and crossesHole1

                            continue

                        else if bestCrossesHole and not crossesHole1

                            minDistSq = distSq1
                            bestIdx = idx
                            bestFlipped = true
                            bestCrossesHole = crossesHole1

                        else

                            minDistSq = distSq1
                            bestIdx = idx
                            bestFlipped = true
                            bestCrossesHole = crossesHole1

                else

                    bestIdx = idx
                    bestFlipped = false

                    break

            if bestIdx is -1

                break

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

                pointKey = createPointKey(currentPoint.x, currentPoint.y)
                nextIdx = -1

                if pointToEdges[pointKey]

                    for connection in pointToEdges[pointKey]

                        if not drawnEdges[connection.idx]

                            nextIdx = connection.idx
                            currentFlipped = (connection.endpoint is 'end')

                            break

                currentIdx = nextIdx

            for segment, segIdx in chain

                if segIdx is 0

                    combingPath = combing.findCombingPath(lastEndPoint or segment.start, segment.start, holeOuterWalls, infillBoundary, nozzleDiameter)

                    for i in [0...combingPath.length - 1]

                        waypoint = combingPath[i + 1]
                        offsetWaypointX = waypoint.x + centerOffsetX
                        offsetWaypointY = waypoint.y + centerOffsetY

                        slicer.gcode += coders.codeLinearMovement(slicer, offsetWaypointX, offsetWaypointY, z, null, travelSpeedMmMin).replace(slicer.newline, (if verbose then "; Moving to infill line" + slicer.newline else slicer.newline))

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
