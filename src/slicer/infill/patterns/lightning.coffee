# Lightning infill pattern implementation for Polyslice.

coders = require('../../gcode/coders')
primitives = require('../../utils/primitives')
clipping = require('../../utils/clipping')
combing = require('../../geometry/combing')

# Add a zig-zagged line by routing via a kink point for lightning-like sharpness.
addKinkedLine = (lines, startPt, endPt, kinkT, kinkOffset, boundary, holeInnerWalls) ->

    dx = endPt.x - startPt.x
    dy = endPt.y - startPt.y
    len = Math.sqrt(dx * dx + dy * dy)

    return if len < 0.001

    perpX = -dy / len
    perpY = dx / len

    kinkPt = { x: startPt.x + dx * kinkT + perpX * kinkOffset, y: startPt.y + dy * kinkT + perpY * kinkOffset }

    for seg in clipping.clipLineWithHoles(startPt, kinkPt, boundary, holeInnerWalls)
        lines.push({ start: seg.start, end: seg.end })

    for seg in clipping.clipLineWithHoles(kinkPt, endPt, boundary, holeInnerWalls)
        lines.push({ start: seg.start, end: seg.end })

module.exports =

    # Generate lightning pattern infill (tree-like branching structure).
    generateLightningInfill: (slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, infillPatternCentering, lastWallPoint = null, holeInnerWalls = [], holeOuterWalls = []) ->

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

        # Lightning pattern: tree-like branches from boundary inward.
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

        # Generate branches along the boundary perimeter.
        branchSpacing = lineSpacing * 2.5 # Spacing between branch starting points.
        branchLength = Math.min(width, height) * 0.8 # Maximum branch length.
        branchAngleVariation = Math.PI / 4 # 45 degrees variation.

        # Calculate total perimeter length and number of branches.
        totalPerimeter = 0
        for i in [0...infillBoundary.length]
            p1 = infillBoundary[i]
            p2 = infillBoundary[(i + 1) % infillBoundary.length]
            dx = p2.x - p1.x
            dy = p2.y - p1.y
            totalPerimeter += Math.sqrt(dx * dx + dy * dy)

        numBranches = Math.max(3, Math.floor(totalPerimeter / branchSpacing))
        branchStepSize = totalPerimeter / numBranches

        # Generate branches from boundary points.
        currentDistance = 0
        targetDistance = 0
        branchIndex = 0

        for i in [0...infillBoundary.length]
            p1 = infillBoundary[i]
            p2 = infillBoundary[(i + 1) % infillBoundary.length]
            segmentDx = p2.x - p1.x
            segmentDy = p2.y - p1.y
            segmentLength = Math.sqrt(segmentDx * segmentDx + segmentDy * segmentDy)

            # Skip degenerate segments (duplicate points).
            if segmentLength < 0.001
                continue

            # Check if this segment contains branch starting points.
            while targetDistance <= currentDistance + segmentLength and targetDistance < totalPerimeter

                # Interpolate starting point on this segment.
                t = (targetDistance - currentDistance) / segmentLength
                startX = p1.x + segmentDx * t
                startY = p1.y + segmentDy * t

                # Calculate direction toward center with some randomness.
                dirX = centerX - startX
                dirY = centerY - startY
                dirLength = Math.sqrt(dirX * dirX + dirY * dirY)

                if dirLength > 0.001

                    dirX /= dirLength
                    dirY /= dirLength

                    # Add slight angle variation based on position for natural look.
                    angleOffset = Math.sin(targetDistance / totalPerimeter * Math.PI * 4) * branchAngleVariation
                    cosAngle = Math.cos(angleOffset)
                    sinAngle = Math.sin(angleOffset)
                    rotatedDirX = dirX * cosAngle - dirY * sinAngle
                    rotatedDirY = dirX * sinAngle + dirY * cosAngle

                    # Create main branch toward center.
                    endX = startX + rotatedDirX * branchLength
                    endY = startY + rotatedDirY * branchLength

                    # Clip the branch line to the boundary (clipper handles out-of-bounds endpoints).
                    startPoint = { x: startX, y: startY }
                    endPoint = { x: endX, y: endY }
                    clippedSegments = clipping.clipLineWithHoles(startPoint, endPoint, infillBoundary, holeInnerWalls)

                    for segment in clippedSegments

                        # Add zig-zag kink to main branch for lightning-like appearance.
                        mainKinkT = 0.4 + 0.15 * Math.sin(branchIndex * 2.3)
                        mainKinkSide = if branchIndex % 2 is 0 then 1 else -1
                        addKinkedLine(allInfillLines, segment.start, segment.end, mainKinkT, branchLength * 0.2 * mainKinkSide, infillBoundary, holeInnerWalls)

                        # Generate sub-branches forking at different positions for each side.
                        branchSegDx = segment.end.x - segment.start.x
                        branchSegDy = segment.end.y - segment.start.y
                        subBranchLength = branchLength * 0.4
                        perpDirX = -rotatedDirY
                        perpDirY = rotatedDirX

                        # Left fork at ~35-45%, right fork at ~55-65% for asymmetric look.
                        leftForkT = 0.3 + 0.15 * (Math.sin(targetDistance * 7.3) * 0.5 + 0.5)
                        rightForkT = 0.55 + 0.15 * (Math.cos(targetDistance * 5.7) * 0.5 + 0.5)

                        for sideIdx in [0...2]

                            side = if sideIdx is 0 then -1 else 1
                            forkT = if sideIdx is 0 then leftForkT else rightForkT

                            forkX = segment.start.x + branchSegDx * forkT
                            forkY = segment.start.y + branchSegDy * forkT

                            # Use perpendicular blend to achieve 45° fork angle.
                            subBranchDirX = (rotatedDirX + perpDirX * side)
                            subBranchDirY = (rotatedDirY + perpDirY * side)
                            subBranchDirLength = Math.sqrt(subBranchDirX * subBranchDirX + subBranchDirY * subBranchDirY)

                            if subBranchDirLength > 0.001

                                subBranchDirX /= subBranchDirLength
                                subBranchDirY /= subBranchDirLength

                                subEndX = forkX + subBranchDirX * subBranchLength
                                subEndY = forkY + subBranchDirY * subBranchLength

                                # Clip sub-branch (clipper handles out-of-bounds endpoints).
                                subStartPoint = { x: forkX, y: forkY }
                                subEndPoint = { x: subEndX, y: subEndY }
                                subClippedSegments = clipping.clipLineWithHoles(subStartPoint, subEndPoint, infillBoundary, holeInnerWalls)

                                for subSegment in subClippedSegments

                                    # Add zig-zag kink to sub-branch.
                                    addKinkedLine(allInfillLines, subSegment.start, subSegment.end, 0.5, subBranchLength * 0.2 * side, infillBoundary, holeInnerWalls)

                    branchIndex++

                targetDistance += branchStepSize

            currentDistance += segmentLength

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
