# Concentric infill pattern implementation for Polyslice.

coders = require('../../gcode/coders')
clipping = require('../../utils/clipping')
paths = require('../../utils/paths')
combing = require('../../geometry/combing')

module.exports =

    # Generate concentric pattern infill (inward-spiraling contours).
    generateConcentricInfill: (slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, infillPatternCentering, lastWallPoint = null, holeInnerWalls = [], holeOuterWalls = []) ->

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()

        travelSpeedMmMin = slicer.getTravelSpeed() * 60
        infillSpeedMmMin = slicer.getInfillSpeed() * 60

        # Skip the outermost loop by insetting by lineSpacing.
        # This creates a density-dependent gap (e.g., 20% density = ~2mm gap).
        # The infillBoundary is already inset by nozzleDiameter/2 from the walls.
        currentPath = paths.createInsetPath(infillBoundary, lineSpacing, false)

        return if currentPath.length < 3

        # Generate concentric loops by repeatedly insetting the boundary.
        concentricLoops = []

        # Generate loops until the path becomes too small.
        while currentPath.length >= 3

            concentricLoops.push(currentPath)

            # Create next inset path.
            nextPath = paths.createInsetPath(currentPath, lineSpacing, false)

            # Stop if inset path is degenerate or too small.
            break if nextPath.length < 3

            currentPath = nextPath

        return if concentricLoops.length is 0

        # Render loops from outermost to innermost.
        lastEndPoint = lastWallPoint

        for loopIndex in [0...concentricLoops.length]

            currentLoop = concentricLoops[loopIndex]

            continue if currentLoop.length < 3

            if holeInnerWalls.length > 0

                # Clip each edge of the loop against hole walls to prevent
                # infill from being generated inside holes.
                validSegments = []

                for i in [0...currentLoop.length]

                    segStart = currentLoop[i]
                    segEnd = currentLoop[(i + 1) % currentLoop.length]

                    clippedSegs = clipping.clipLineWithHoles(segStart, segEnd, infillBoundary, holeInnerWalls)

                    for seg in clippedSegs

                        validSegments.push(seg)

                continue if validSegments.length is 0

                # Group consecutive segments into polylines to minimize travel moves.
                polylines = []
                currentPolyline = [validSegments[0].start, validSegments[0].end]

                for segIdx in [1...validSegments.length]

                    seg = validSegments[segIdx]
                    prevEnd = currentPolyline[currentPolyline.length - 1]

                    dx = seg.start.x - prevEnd.x
                    dy = seg.start.y - prevEnd.y

                    if dx * dx + dy * dy < 0.001 * 0.001

                        currentPolyline.push(seg.end)

                    else

                        polylines.push(currentPolyline)
                        currentPolyline = [seg.start, seg.end]

                polylines.push(currentPolyline)

                # Select and render polylines in nearest-neighbour order to minimize travel.
                remainingPolylines = polylines.slice()

                while remainingPolylines.length > 0

                    if lastEndPoint?

                        # Find the polyline start/end closest to the current position.
                        bestIdx = 0
                        bestFlipped = false
                        minDistSq = Infinity

                        for plIdx in [0...remainingPolylines.length]

                            pl = remainingPolylines[plIdx]
                            continue if pl.length < 2

                            startDistSq = (pl[0].x - lastEndPoint.x) ** 2 + (pl[0].y - lastEndPoint.y) ** 2
                            endDistSq = (pl[pl.length - 1].x - lastEndPoint.x) ** 2 + (pl[pl.length - 1].y - lastEndPoint.y) ** 2

                            if startDistSq < minDistSq

                                minDistSq = startDistSq
                                bestIdx = plIdx
                                bestFlipped = false

                            if endDistSq < minDistSq

                                minDistSq = endDistSq
                                bestIdx = plIdx
                                bestFlipped = true

                        polyline = remainingPolylines.splice(bestIdx, 1)[0]

                        if bestFlipped

                            polyline = polyline.slice().reverse()

                    else

                        polyline = remainingPolylines.shift()

                    continue if polyline.length < 2

                    startPoint = polyline[0]

                    combingPath = combing.findCombingPath(lastEndPoint or startPoint, startPoint, holeOuterWalls, infillBoundary, nozzleDiameter)

                    for i in [0...combingPath.length - 1]

                        waypoint = combingPath[i + 1]
                        offsetWaypointX = waypoint.x + centerOffsetX
                        offsetWaypointY = waypoint.y + centerOffsetY

                        slicer.gcode += coders.codeLinearMovement(slicer, offsetWaypointX, offsetWaypointY, z, null, travelSpeedMmMin).replace(slicer.newline, (if verbose then "; Moving to concentric loop" + slicer.newline else slicer.newline))

                    prevPoint = polyline[0]

                    for ptIdx in [1...polyline.length]

                        point = polyline[ptIdx]

                        dx = point.x - prevPoint.x
                        dy = point.y - prevPoint.y

                        distance = Math.sqrt(dx * dx + dy * dy)

                        if distance > 0.001

                            extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
                            slicer.cumulativeE += extrusionDelta

                            offsetX = point.x + centerOffsetX
                            offsetY = point.y + centerOffsetY

                            slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, slicer.cumulativeE, infillSpeedMmMin)

                        prevPoint = point

                    lastEndPoint = prevPoint

            else

                # No holes: use optimized full-loop rendering with start point selection.

                # Find optimal start point on this loop if we have a last position.
                startIndex = 0

                if lastEndPoint?

                    minDistSq = Infinity

                    for i in [0...currentLoop.length]

                        point = currentLoop[i]
                        distSq = (point.x - lastEndPoint.x) ** 2 + (point.y - lastEndPoint.y) ** 2

                        if distSq < minDistSq

                            minDistSq = distSq
                            startIndex = i

                # Travel to start point with combing.
                firstPoint = currentLoop[startIndex]

                combingPath = combing.findCombingPath(lastEndPoint or firstPoint, firstPoint, holeOuterWalls, infillBoundary, nozzleDiameter)

                for i in [0...combingPath.length - 1]

                    waypoint = combingPath[i + 1]
                    offsetWaypointX = waypoint.x + centerOffsetX
                    offsetWaypointY = waypoint.y + centerOffsetY

                    slicer.gcode += coders.codeLinearMovement(slicer, offsetWaypointX, offsetWaypointY, z, null, travelSpeedMmMin).replace(slicer.newline, (if verbose then "; Moving to concentric loop" + slicer.newline else slicer.newline))

                # Print the loop starting from startIndex.
                prevPoint = currentLoop[startIndex]

                for i in [1..currentLoop.length]

                    currentIndex = (startIndex + i) % currentLoop.length
                    point = currentLoop[currentIndex]

                    dx = point.x - prevPoint.x
                    dy = point.y - prevPoint.y

                    distance = Math.sqrt(dx * dx + dy * dy)

                    if distance > 0.001

                        extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
                        slicer.cumulativeE += extrusionDelta

                        offsetX = point.x + centerOffsetX
                        offsetY = point.y + centerOffsetY

                        slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, slicer.cumulativeE, infillSpeedMmMin)

                    prevPoint = point

                # Update last end point for next loop.
                lastEndPoint = prevPoint
