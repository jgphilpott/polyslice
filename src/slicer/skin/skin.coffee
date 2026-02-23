# Skin generation module for Polyslice.

coders = require('../gcode/coders')
clipping = require('../utils/clipping')
paths = require('../utils/paths')
combing = require('../geometry/combing')

module.exports =

    # Generate G-code for skin (top/bottom solid infill).
    generateSkinGCode: (slicer, boundaryPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint = null, isHole = false, generateInfill = true, holeSkinWalls = [], holeOuterWalls = [], coveredAreaSkinWalls = [], isCoveredArea = false, generateWall = true) ->

        return if boundaryPath.length < 3

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()

        if verbose then slicer.gcode += "; TYPE: SKIN" + slicer.newline

        # Generate skin wall perimeter (unless disabled).
        skinWallPath = null

        if generateWall

            skinWallInset = nozzleDiameter
            offsetDirection = if isCoveredArea then false else isHole
            skinWallPath = paths.createInsetPath(boundaryPath, skinWallInset, offsetDirection)

            if skinWallPath.length >= 3

                # Find starting point closest to last position.
                if lastWallPoint?

                    minDistSq = Infinity
                    startIdx = 0

                    for point, idx in skinWallPath

                        distSq = (point.x - lastWallPoint.x) ** 2 + (point.y - lastWallPoint.y) ** 2

                        if distSq < minDistSq

                            minDistSq = distSq
                            startIdx = idx

                    skinWallPath = skinWallPath[startIdx...] .concat(skinWallPath[0...startIdx]) if startIdx > 0

                firstPoint = skinWallPath[0]
                targetPoint = { x: firstPoint.x, y: firstPoint.y, z: z }

                # Use combing if holes exist.
                if lastWallPoint? and holeOuterWalls.length > 0

                    combingPath = combing.findCombingPath(lastWallPoint, targetPoint, holeOuterWalls, boundaryPath, nozzleDiameter)

                    travelSpeedMmMin = slicer.getTravelSpeed() * 60

                    for i in [0...combingPath.length - 1]

                        waypoint = combingPath[i + 1]

                        offsetX = waypoint.x + centerOffsetX
                        offsetY = waypoint.y + centerOffsetY

                        if i is 0 and verbose
                            slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeedMmMin).replace(slicer.newline, "; Moving to skin wall" + slicer.newline)
                        else
                            slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeedMmMin)

                else

                    offsetX = firstPoint.x + centerOffsetX
                    offsetY = firstPoint.y + centerOffsetY

                    travelSpeedMmMin = slicer.getTravelSpeed() * 60

                    slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeedMmMin).replace(slicer.newline, (if verbose then "; Moving to skin wall" + slicer.newline else slicer.newline))

                perimeterSpeedMmMin = slicer.getPerimeterSpeed() * 60

                # Draw skin wall perimeter.
                for pointIndex in [1...skinWallPath.length]

                    point = skinWallPath[pointIndex]
                    prevPoint = skinWallPath[pointIndex - 1]

                    dx = point.x - prevPoint.x
                    dy = point.y - prevPoint.y

                    distance = Math.sqrt(dx * dx + dy * dy)

                    continue if distance < 0.001

                    extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
                    slicer.cumulativeE += extrusionDelta

                    offsetX = point.x + centerOffsetX
                    offsetY = point.y + centerOffsetY

                    slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, slicer.cumulativeE, perimeterSpeedMmMin)

                # Close loop.
                firstPoint = skinWallPath[0]
                lastPoint = skinWallPath[skinWallPath.length - 1]

                dx = firstPoint.x - lastPoint.x
                dy = firstPoint.y - lastPoint.y

                distance = Math.sqrt(dx * dx + dy * dy)

                if distance > 0.001

                    extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
                    slicer.cumulativeE += extrusionDelta

                    offsetX = firstPoint.x + centerOffsetX
                    offsetY = firstPoint.y + centerOffsetY

                    slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, slicer.cumulativeE, perimeterSpeedMmMin)

        # Generate diagonal skin infill.
        return unless generateInfill

        # Calculate infill boundary.
        # If wall was generated, use its offset; otherwise calculate from boundary.
        infillGap = nozzleDiameter / 2

        # Add small epsilon to ensure diagonal lines at boundary corners aren't excluded
        # due to floating-point precision issues in point-in-polygon tests.
        boundaryEpsilon = 0.05  # 0.05mm = 50 microns

        if generateWall

            skinWallInset = nozzleDiameter
            infillInset = skinWallInset + infillGap - boundaryEpsilon

        else

            # No wall generated, calculate infill boundary directly from boundaryPath.
            # Use the same offset as if wall had been generated.
            infillInset = nozzleDiameter + infillGap - boundaryEpsilon

        infillBoundary = paths.createInsetPath(boundaryPath, infillInset, isHole)

        return if infillBoundary.length < 3

        # Create hole exclusion zones with gap.
        holeSkinWallsWithGap = []

        for holeSkinWall in holeSkinWalls

            if holeSkinWall.length >= 3

                holeSkinWallWithGap = paths.createInsetPath(holeSkinWall, infillGap, true)

                if holeSkinWallWithGap.length >= 3

                    holeSkinWallsWithGap.push(holeSkinWallWithGap)

        # Use covered area boundaries as exclusion zones.
        coveredAreaSkinWallsWithGap = []

        for coveredAreaSkinWall in coveredAreaSkinWalls

            if coveredAreaSkinWall.length >= 3

                coveredAreaSkinWallsWithGap.push(coveredAreaSkinWall)

        # Calculate bounding box.
        minX = Infinity
        maxX = -Infinity
        minY = Infinity
        maxY = -Infinity

        for point in infillBoundary

            if point.x < minX then minX = point.x
            if point.x > maxX then maxX = point.x
            if point.y < minY then minY = point.y
            if point.y > maxY then maxY = point.y

        # Generate 45° diagonal infill, alternating direction per layer.
        lineSpacing = nozzleDiameter

        width = maxX - minX
        height = maxY - minY

        diagonalSpan = Math.sqrt(width * width + height * height)

        travelSpeedMmMin = slicer.getTravelSpeed() * 60
        infillSpeedMmMin = slicer.getInfillSpeed() * 60

        useNegativeSlope = (layerIndex % 2) is 1

        if useNegativeSlope

            offset = minY + minX - diagonalSpan
            maxOffset = maxY + maxX

        else

            offset = minY - maxX - diagonalSpan
            maxOffset = maxY - minX

        allSkinLines = []

        while offset < maxOffset

            intersections = []

            if useNegativeSlope

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

            else

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

                allExclusionWalls = holeSkinWallsWithGap.concat(coveredAreaSkinWallsWithGap)
                clippedSegments = clipping.clipLineWithHoles(intersections[0], intersections[1], infillBoundary, allExclusionWalls)

                for segment in clippedSegments

                    allSkinLines.push({
                        start: segment.start
                        end: segment.end
                    })

            offset += lineSpacing * Math.sqrt(2)

        # Render lines in nearest-neighbor order.
        # lastEndPoint: use skin wall if available, otherwise use lastWallPoint parameter.
        lastEndPoint = if skinWallPath and skinWallPath.length >= 3 then { x: skinWallPath[0].x, y: skinWallPath[0].y, z: z } else lastWallPoint

        while allSkinLines.length > 0

            minDistSq = Infinity
            bestLineIdx = 0
            bestFlipped = false

            if lastEndPoint?

                for line, idx in allSkinLines

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

            bestLine = allSkinLines[bestLineIdx]
            allSkinLines.splice(bestLineIdx, 1)

            if bestFlipped

                startPoint = bestLine.end
                endPoint = bestLine.start

            else

                startPoint = bestLine.start
                endPoint = bestLine.end

            # Only travel if the start point is not already the current position.
            isAlreadyAtStartPoint = lastEndPoint? and (startPoint.x - lastEndPoint.x) ** 2 + (startPoint.y - lastEndPoint.y) ** 2 < 0.001 ** 2

            if not isAlreadyAtStartPoint

                combingPath = combing.findCombingPath(lastEndPoint or startPoint, startPoint, holeOuterWalls, infillBoundary, nozzleDiameter)

                for i in [0...combingPath.length - 1]

                    waypoint = combingPath[i + 1]
                    offsetWaypointX = waypoint.x + centerOffsetX
                    offsetWaypointY = waypoint.y + centerOffsetY

                    slicer.gcode += coders.codeLinearMovement(slicer, offsetWaypointX, offsetWaypointY, z, null, travelSpeedMmMin).replace(slicer.newline, (if verbose then "; Moving to skin infill line" + slicer.newline else slicer.newline))

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

        if lastEndPoint?
            return lastEndPoint
        else if skinWallPath? and skinWallPath.length > 0
            return { x: skinWallPath[0].x, y: skinWallPath[0].y, z: z }
        else
            return null
