# Grid infill pattern implementation for Polyslice.

coders = require('../../gcode/coders')
primitives = require('../../utils/primitives')
clipping = require('../../utils/clipping')
combing = require('../../geometry/combing')

module.exports =

    # Generate grid pattern infill (crosshatch at ±45°).
    generateGridInfill: (slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint = null, holeInnerWalls = [], holeOuterWalls = []) ->

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

        diagonalSpan = Math.sqrt(width * width + height * height)

        travelSpeedMmMin = slicer.getTravelSpeed() * 60
        infillSpeedMmMin = slicer.getInfillSpeed() * 60

        # Grid: both +45° and -45° lines on every layer, centered on the infill boundary.
        allInfillLines = []

        # Calculate center of the infill boundary for proper line centering.
        centerX = (minX + maxX) / 2
        centerY = (minY + maxY) / 2

        # For +45° lines (y = x + offset), center offset is y - x at center point.
        centerOffset = centerY - centerX

        numLinesUp = Math.ceil(diagonalSpan / (lineSpacing * Math.sqrt(2)))

        offset = centerOffset - numLinesUp * lineSpacing * Math.sqrt(2)
        maxOffset = centerOffset + numLinesUp * lineSpacing * Math.sqrt(2)

        while offset < maxOffset

            intersections = []

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

                uniqueIntersections = primitives.deduplicateIntersections(intersections)

                if uniqueIntersections.length is 2

                    clippedSegments = clipping.clipLineWithHoles(uniqueIntersections[0], uniqueIntersections[1], infillBoundary, holeInnerWalls)

                    for segment in clippedSegments

                        allInfillLines.push({
                            start: segment.start
                            end: segment.end
                        })

            offset += lineSpacing * Math.sqrt(2)

        # Generate -45° lines.
        # For -45° lines (y = -x + offset), center offset is y + x at center point.
        centerOffset = centerY + centerX

        offset = centerOffset - numLinesUp * lineSpacing * Math.sqrt(2)
        maxOffset = centerOffset + numLinesUp * lineSpacing * Math.sqrt(2)

        while offset < maxOffset

            intersections = []

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

                uniqueIntersections = primitives.deduplicateIntersections(intersections)

                if uniqueIntersections.length is 2

                    clippedSegments = clipping.clipLineWithHoles(uniqueIntersections[0], uniqueIntersections[1], infillBoundary, holeInnerWalls)

                    for segment in clippedSegments

                        allInfillLines.push({
                            start: segment.start
                            end: segment.end
                        })

            offset += lineSpacing * Math.sqrt(2)

        # Render lines in nearest-neighbor order.
        lastEndPoint = lastWallPoint

        while allInfillLines.length > 0

            minDistSq = Infinity
            bestLineIdx = 0
            bestFlipped = false

            for line, idx in allInfillLines

                if lastEndPoint?

                    distSq0 = (line.start.x - lastEndPoint.x) ** 2 + (line.start.y - lastEndPoint.y) ** 2
                    distSq1 = (line.end.x - lastEndPoint.x) ** 2 + (line.end.y - lastEndPoint.y) ** 2

                    if distSq0 < minDistSq

                        minDistSq = distSq0
                        bestLineIdx = idx
                        bestFlipped = false

                    if distSq1 < minDistSq

                        minDistSq = distSq1
                        bestLineIdx = idx
                        bestFlipped = true

                else

                    break

            bestLine = allInfillLines[bestLineIdx]
            allInfillLines.splice(bestLineIdx, 1)

            if bestFlipped

                startPoint = bestLine.end
                endPoint = bestLine.start

            else

                startPoint = bestLine.start
                endPoint = bestLine.end

            combingPath = combing.findCombingPath(lastEndPoint or startPoint, startPoint, holeOuterWalls, infillBoundary, nozzleDiameter)

            for i in [0...combingPath.length - 1]

                waypoint = combingPath[i + 1]
                offsetWaypointX = waypoint.x + centerOffsetX
                offsetWaypointY = waypoint.y + centerOffsetY

                slicer.gcode += coders.codeLinearMovement(slicer, offsetWaypointX, offsetWaypointY, z, null, travelSpeedMmMin).replace(slicer.newline, (if verbose then "; Moving to infill line" + slicer.newline else slicer.newline))

            dx = endPoint.x - startPoint.x
            dy = endPoint.y - startPoint.y

            distance = Math.sqrt(dx * dx + dy * dy)

            if distance > 0.001

                extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
                slicer.cumulativeE += extrusionDelta

                offsetEndX = endPoint.x + centerOffsetX
                offsetEndY = endPoint.y + centerOffsetY

                slicer.gcode += coders.codeLinearMovement(slicer, offsetEndX, offsetEndY, z, slicer.cumulativeE, infillSpeedMmMin)
                lastEndPoint = endPoint
