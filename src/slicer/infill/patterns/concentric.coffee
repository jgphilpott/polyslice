# Concentric infill pattern implementation for Polyslice.

coders = require('../../gcode/coders')
paths = require('../../utils/paths')
combing = require('../../geometry/combing')
primitives = require('../../utils/primitives')

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

            # Check if this loop should be skipped because it's inside a hole.
            # Sample multiple points on the loop to ensure accurate detection.
            skipLoop = false

            if holeInnerWalls.length > 0

                # Sample points evenly distributed around the loop.
                sampleCount = Math.min(8, currentLoop.length)

                pointsInHoles = 0

                for sampleIdx in [0...sampleCount]

                    # Distribute samples evenly across the loop's length.
                    pointIdx = Math.floor(sampleIdx * currentLoop.length / sampleCount)
                    testPoint = currentLoop[pointIdx]

                    # Check if this point is inside any hole.
                    for holeWall in holeInnerWalls

                        if holeWall.length >= 3 and primitives.pointInPolygon(testPoint, holeWall)

                            pointsInHoles++
                            break

                # Skip loop only if majority of sampled points are inside holes.
                # This prevents skipping loops that merely pass near holes.
                if pointsInHoles > sampleCount / 2

                    skipLoop = true

            continue if skipLoop

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
