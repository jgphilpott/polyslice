# Gyroid infill pattern implementation for Polyslice.

coders = require('../../gcode/coders')
clipping = require('../../utils/clipping')
combing = require('../../geometry/combing')

module.exports =

    # Generate gyroid pattern infill (wavy TPMS structure).
    generateGyroidInfill: (slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, infillPatternCentering, lastWallPoint = null, holeInnerWalls = [], holeOuterWalls = []) ->

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()
        layerHeight = slicer.getLayerHeight()

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

        # Gyroid: wavy lines with gradual direction transition across layers.
        allInfillLines = []

        # Determine pattern center based on infillPatternCentering setting.
        if infillPatternCentering is 'global'
            # Global centering: use build plate center (0, 0 in local coordinates).
            centerX = 0
            centerY = 0
        else
            # Object centering: use infill boundary center (current/default behavior).
            centerX = (minX + maxX) / 2
            centerY = (minY + maxY) / 2

        # Calculate the phase offset for the gyroid based on Z height.
        # This creates the characteristic 3D gyroid structure across layers.
        zPhase = (z / lineSpacing) * 2 * Math.PI

        # Gyroid has a natural frequency - use lineSpacing as the fundamental period.
        frequency = (2 * Math.PI) / lineSpacing

        # Calculate gradual direction transition over 8 layers.
        # This creates smoother layer-to-layer transitions compared to alternating.
        transitionLayerCount = 8
        currentLayer = Math.floor(z / layerHeight)
        layerInCycle = currentLayer % transitionLayerCount
        blendRatio = layerInCycle / transitionLayerCount  # 0 to ~0.875

        # Generate X-direction lines (horizontal wavy lines) when blend ratio < 1.
        if blendRatio < 1.0

            # Determine the range for line generation based on centering mode.
            if infillPatternCentering is 'global'
                # Global centering: lines are positioned relative to pattern center.
                numLines = Math.ceil(height / lineSpacing) + 2
                lineStart = centerY - (numLines / 2) * lineSpacing
            else
                # Object centering: lines span from minY to maxY.
                numLines = Math.ceil(height / lineSpacing) + 2
                lineStart = minY - lineSpacing

            for i in [0...numLines]

                yBase = lineStart + i * lineSpacing

                # Skip if line is completely outside bounds.
                if yBase < minY - lineSpacing or yBase > maxY + lineSpacing
                    continue

                # Generate points along this wavy line.
                # Guard against division by zero when width is 0 or very small.
                segments = Math.max(1, Math.ceil(width / (lineSpacing / 4)))
                points = []

                for j in [0..segments]

                    xPos = minX + (j / segments) * width

                    # Gyroid equation: sin(x)cos(y) + sin(y)cos(z) + sin(z)cos(x) = 0
                    # For 2D slice at height z, we approximate with:
                    # y_offset = amplitude * sin(frequency * x + z_phase)
                    amplitude = lineSpacing * 0.4

                    yOffset = amplitude * Math.sin(frequency * (xPos - centerX) + zPhase)

                    yPos = yBase + yOffset

                    # Check if point is roughly within bounds.
                    if yPos >= minY - lineSpacing and yPos <= maxY + lineSpacing

                        points.push({ x: xPos, y: yPos })

                # Create line segments from consecutive points.
                for k in [0...points.length - 1]

                    startPt = points[k]
                    endPt = points[k + 1]

                    # Clip each segment against the boundary and holes.
                    clippedSegments = clipping.clipLineWithHoles(startPt, endPt, infillBoundary, holeInnerWalls)

                    for segment in clippedSegments

                        allInfillLines.push({
                            start: segment.start
                            end: segment.end
                        })

        # Generate Y-direction lines (vertical wavy lines) when blend ratio > 0.
        if blendRatio > 0.0

            # Determine the range for line generation based on centering mode.
            if infillPatternCentering is 'global'
                # Global centering: lines are positioned relative to pattern center.
                numLines = Math.ceil(width / lineSpacing) + 2
                lineStart = centerX - (numLines / 2) * lineSpacing
            else
                # Object centering: lines span from minX to maxX.
                numLines = Math.ceil(width / lineSpacing) + 2
                lineStart = minX - lineSpacing

            for i in [0...numLines]

                xBase = lineStart + i * lineSpacing

                # Skip if line is completely outside bounds.
                if xBase < minX - lineSpacing or xBase > maxX + lineSpacing
                    continue

                # Generate points along this wavy line.
                # Guard against division by zero when height is 0 or very small.
                segments = Math.max(1, Math.ceil(height / (lineSpacing / 4)))
                points = []

                for j in [0..segments]

                    yPos = minY + (j / segments) * height

                    # Gyroid equation with phase shift for orthogonal direction.
                    # x_offset = amplitude * cos(frequency * y + z_phase + pi/2)
                    amplitude = lineSpacing * 0.4

                    xOffset = amplitude * Math.cos(frequency * (yPos - centerY) + zPhase + Math.PI / 2)

                    xPos = xBase + xOffset

                    # Check if point is roughly within bounds.
                    if xPos >= minX - lineSpacing and xPos <= maxX + lineSpacing

                        points.push({ x: xPos, y: yPos })

                # Create line segments from consecutive points.
                for k in [0...points.length - 1]

                    startPt = points[k]
                    endPt = points[k + 1]

                    # Clip each segment against the boundary and holes.
                    clippedSegments = clipping.clipLineWithHoles(startPt, endPt, infillBoundary, holeInnerWalls)

                    for segment in clippedSegments

                        allInfillLines.push({
                            start: segment.start
                            end: segment.end
                        })

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
