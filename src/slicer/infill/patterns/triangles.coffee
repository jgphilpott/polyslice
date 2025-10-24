# Triangles infill pattern implementation for Polyslice.

coders = require('../../gcode/coders')
helpers = require('../../geometry/helpers')

module.exports =

    # Generate triangles pattern infill (tessellation at 0°, +60°, and -60°).
    # holeInnerWalls: Array of hole inner wall paths to exclude from infill.
    generateTrianglesInfill: (slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint = null, holeInnerWalls = []) ->

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

        diagonalSpan = Math.sqrt(width * width + height * height)

        travelSpeedMmMin = slicer.getTravelSpeed() * 60
        infillSpeedMmMin = slicer.getInfillSpeed() * 60

        # Triangles pattern: generate lines at 45° (baseline), +60° from baseline (105°), and -60° from baseline (-15°).
        # This creates a tessellation of equilateral triangles.
        # The baseline extends diagonally at 45° from origin (like grid pattern).
        # The other two lines are at ±60° relative to the baseline.
        # Center the pattern at origin (0, 0) in local coordinates.

        # For proper equilateral triangle tessellation, all three line sets must use
        # the same perpendicular spacing. We use lineSpacing as the base perpendicular
        # distance between parallel lines in each set.

        # Collect all infill line segments first, then sort/render to minimize travel.
        allInfillLines = []

        # Calculate center of bounding box to properly center the pattern.
        centerX = (minX + maxX) / 2
        centerY = (minY + maxY) / 2

        # Generate baseline at 45° (y = x + offset).
        # This is the primary diagonal line, same as grid's +45° line.
        # For a 45° line (slope = 1), moving perpendicular by distance lineSpacing
        # requires changing the y-intercept by lineSpacing * sqrt(2).
        # The center line should pass through (centerX, centerY), so: centerY = centerX + centerOffset
        centerOffset = centerY - centerX

        # For 45-degree lines, account for diagonal spacing.
        # Perpendicular spacing = lineSpacing, offset spacing = lineSpacing * sqrt(2)
        offsetStep45 = lineSpacing * Math.sqrt(2)

        # Calculate how many lines to generate in each direction from center.
        numLinesUp = Math.ceil(diagonalSpan / offsetStep45)

        # Start from center and generate lines in both directions.
        offset = centerOffset - numLinesUp * offsetStep45
        maxOffset = centerOffset + numLinesUp * offsetStep45

        while offset <= maxOffset

            # Calculate intersection points with bounding box.
            intersections = []

            # Line equation: y = x + offset (slope = +1).

            # Check intersection with left edge (x = minX).
            y = minX + offset
            if y >= minY and y <= maxY

                intersections.push({ x: minX, y: y })

            # Check intersection with right edge (x = maxX).
            y = maxX + offset
            if y >= minY and y <= maxY

                intersections.push({ x: maxX, y: y })

            # Check intersection with bottom edge (y = minY).
            x = minY - offset
            if x >= minX and x <= maxX

                intersections.push({ x: x, y: minY })

            # Check intersection with top edge (y = maxY).
            x = maxY - offset
            if x >= minX and x <= maxX

                intersections.push({ x: x, y: maxY })

            # We should have exactly 2 intersection points.
            # However, when a line passes through a corner, we might get duplicate points.
            # Deduplicate by checking if points are too close (within a small epsilon).
            if intersections.length >= 2

                # Remove duplicate points (those within 0.001mm of each other).
                uniqueIntersections = []
                epsilon = 0.001

                for intersection in intersections

                    isDuplicate = false

                    for existing in uniqueIntersections

                        dx = intersection.x - existing.x
                        dy = intersection.y - existing.y
                        distSq = dx * dx + dy * dy

                        if distSq < epsilon * epsilon

                            isDuplicate = true
                            break

                    if not isDuplicate

                        uniqueIntersections.push(intersection)

                # Only proceed if we have exactly 2 distinct intersection points.
                if uniqueIntersections.length is 2

                    # Clip the line segment to the actual infill boundary polygon.
                    # Also exclude hole areas by clipping against hole inner walls.
                    # This ensures infill stays within the boundary and outside holes.
                    clippedSegments = helpers.clipLineWithHoles(uniqueIntersections[0], uniqueIntersections[1], infillBoundary, holeInnerWalls)

                    # Store each clipped segment for later rendering.
                    for segment in clippedSegments

                        allInfillLines.push({
                            start: segment.start
                            end: segment.end
                        })

            # Move to next diagonal line.
            offset += offsetStep45

        # Generate lines at 105° (45° + 60°), which is equivalent to -75°.
        # Slope = tan(105°) = -cot(15°) ≈ -3.732.
        # Line equation: y = -3.732 * x + offset.
        slope = -1 / Math.tan(15 * Math.PI / 180)  # tan(105°) = -cot(15°)

        # For lines at 105° angle, calculate offset step for same perpendicular spacing.
        # The perpendicular distance between lines is lineSpacing.
        # For angle 105°, offsetStep = lineSpacing / |cos(105°)| ≈ lineSpacing * 3.864
        angle105 = 105 * Math.PI / 180
        offsetStep105 = lineSpacing / Math.abs(Math.cos(angle105))

        # The center line should pass through (centerX, centerY), so: centerY = slope * centerX + centerOffset
        centerOffset = centerY - slope * centerX

        # Calculate how many lines to generate.
        numLinesUp = Math.ceil(diagonalSpan / offsetStep105)

        # Start from center and generate lines in both directions.
        offset = centerOffset - numLinesUp * offsetStep105
        maxOffset = centerOffset + numLinesUp * offsetStep105

        while offset <= maxOffset

            # Calculate intersection points with bounding box.
            intersections = []

            # Line equation: y = slope * x + offset.

            # Check intersection with left edge (x = minX).
            y = slope * minX + offset
            if y >= minY and y <= maxY

                intersections.push({ x: minX, y: y })

            # Check intersection with right edge (x = maxX).
            y = slope * maxX + offset
            if y >= minY and y <= maxY

                intersections.push({ x: maxX, y: y })

            # Check intersection with bottom edge (y = minY).
            x = (minY - offset) / slope
            if x >= minX and x <= maxX

                intersections.push({ x: x, y: minY })

            # Check intersection with top edge (y = maxY).
            x = (maxY - offset) / slope
            if x >= minX and x <= maxX

                intersections.push({ x: x, y: maxY })

            # We should have exactly 2 intersection points.
            # However, when a line passes through a corner, we might get duplicate points.
            # Deduplicate by checking if points are too close (within a small epsilon).
            if intersections.length >= 2

                # Remove duplicate points (those within 0.001mm of each other).
                uniqueIntersections = []
                epsilon = 0.001

                for intersection in intersections

                    isDuplicate = false

                    for existing in uniqueIntersections

                        dx = intersection.x - existing.x
                        dy = intersection.y - existing.y
                        distSq = dx * dx + dy * dy

                        if distSq < epsilon * epsilon

                            isDuplicate = true
                            break

                    if not isDuplicate

                        uniqueIntersections.push(intersection)

                # Only proceed if we have exactly 2 distinct intersection points.
                if uniqueIntersections.length is 2

                    # Clip the line segment to the actual infill boundary polygon.
                    # Also exclude hole areas by clipping against hole inner walls.
                    # This ensures infill stays within the boundary and outside holes.
                    clippedSegments = helpers.clipLineWithHoles(uniqueIntersections[0], uniqueIntersections[1], infillBoundary, holeInnerWalls)

                    # Store each clipped segment for later rendering.
                    for segment in clippedSegments

                        allInfillLines.push({
                            start: segment.start
                            end: segment.end
                        })

            # Move to next diagonal line.
            offset += offsetStep105

        # Generate lines at -15° (45° - 60°).
        # Slope = tan(-15°) ≈ -0.268.
        # Line equation: y = -0.268 * x + offset.
        slope = Math.tan(-15 * Math.PI / 180)

        # For lines at -15° angle, calculate offset step for same perpendicular spacing.
        # The perpendicular distance between lines is lineSpacing.
        # For angle -15°, offsetStep = lineSpacing / |cos(-15°)| ≈ lineSpacing * 1.035
        angle15 = -15 * Math.PI / 180
        offsetStep15 = lineSpacing / Math.abs(Math.cos(angle15))

        # The center line should pass through (centerX, centerY), so: centerY = slope * centerX + centerOffset
        centerOffset = centerY - slope * centerX

        # Calculate how many lines to generate.
        numLinesUp = Math.ceil(diagonalSpan / offsetStep15)

        # Start from center and generate lines in both directions.
        offset = centerOffset - numLinesUp * offsetStep15
        maxOffset = centerOffset + numLinesUp * offsetStep15

        while offset <= maxOffset

            # Calculate intersection points with bounding box.
            intersections = []

            # Line equation: y = -sqrt(3) * x + offset.

            # Check intersection with left edge (x = minX).
            y = slope * minX + offset
            if y >= minY and y <= maxY

                intersections.push({ x: minX, y: y })

            # Check intersection with right edge (x = maxX).
            y = slope * maxX + offset
            if y >= minY and y <= maxY

                intersections.push({ x: maxX, y: y })

            # Check intersection with bottom edge (y = minY).
            x = (minY - offset) / slope
            if x >= minX and x <= maxX

                intersections.push({ x: x, y: minY })

            # Check intersection with top edge (y = maxY).
            x = (maxY - offset) / slope
            if x >= minX and x <= maxX

                intersections.push({ x: x, y: maxY })

            # We should have exactly 2 intersection points.
            # However, when a line passes through a corner, we might get duplicate points.
            # Deduplicate by checking if points are too close (within a small epsilon).
            if intersections.length >= 2

                # Remove duplicate points (those within 0.001mm of each other).
                uniqueIntersections = []
                epsilon = 0.001

                for intersection in intersections

                    isDuplicate = false

                    for existing in uniqueIntersections

                        dx = intersection.x - existing.x
                        dy = intersection.y - existing.y
                        distSq = dx * dx + dy * dy

                        if distSq < epsilon * epsilon

                            isDuplicate = true
                            break

                    if not isDuplicate

                        uniqueIntersections.push(intersection)

                # Only proceed if we have exactly 2 distinct intersection points.
                if uniqueIntersections.length is 2

                    # Clip the line segment to the actual infill boundary polygon.
                    # Also exclude hole areas by clipping against hole inner walls.
                    # This ensures infill stays within the boundary and outside holes.
                    clippedSegments = helpers.clipLineWithHoles(uniqueIntersections[0], uniqueIntersections[1], infillBoundary, holeInnerWalls)

                    # Store each clipped segment for later rendering.
                    for segment in clippedSegments

                        allInfillLines.push({
                            start: segment.start
                            end: segment.end
                        })

            # Move to next diagonal line.
            offset += offsetStep15

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
