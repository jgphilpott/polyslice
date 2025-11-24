# Skin generation module for Polyslice.

coders = require('../gcode/coders')
helpers = require('../geometry/helpers')

module.exports =

    # Generate G-code for skin (top/bottom solid infill).
    # If generateInfill is false, only skin walls are generated (useful for holes).
    # holeSkinWalls: Array of hole skin wall paths to exclude from skin infill.
    # holeOuterWalls: Array of hole outer wall paths for travel path optimization (avoiding holes).
    # coveredAreaSkinWalls: Array of covered area boundaries to exclude from skin infill (used as-is without offset).
    # isCoveredArea: Boolean indicating if this is a covered area (not a real hole), which affects offset direction.
    generateSkinGCode: (slicer, boundaryPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint = null, isHole = false, generateInfill = true, holeSkinWalls = [], holeOuterWalls = [], coveredAreaSkinWalls = [], isCoveredArea = false) ->

        return if boundaryPath.length < 3

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()

        if verbose then slicer.gcode += "; TYPE: SKIN" + slicer.newline

        # Step 1: Generate skin wall (perimeter pass around skin boundary).
        # Create an inset of full nozzle diameter from the boundary path.
        # For covered areas (isCoveredArea=true), inset inward (treat as outer boundary).
        # For real holes (isHole=true), outset outward (to shrink the hole).
        # For normal skin boundaries (both false), inset inward.
        skinWallInset = nozzleDiameter
        offsetDirection = if isCoveredArea then false else isHole
        skinWallPath = helpers.createInsetPath(boundaryPath, skinWallInset, offsetDirection)

        if skinWallPath.length >= 3

            # Choose starting point closest to last wall position to minimize travel.
            if lastWallPoint?

                # Find the point in skinWallPath closest to lastWallPoint.
                minDistSq = Infinity
                startIdx = 0

                for point, idx in skinWallPath

                    distSq = (point.x - lastWallPoint.x) ** 2 + (point.y - lastWallPoint.y) ** 2

                    if distSq < minDistSq

                        minDistSq = distSq
                        startIdx = idx

                # Rotate the path to start from the closest point.
                skinWallPath = skinWallPath[startIdx...] .concat(skinWallPath[0...startIdx]) if startIdx > 0

            # Move to start of skin wall.
            firstPoint = skinWallPath[0]
            targetPoint = { x: firstPoint.x, y: firstPoint.y, z: z }

            # Use combing if we have a last wall point and holes to avoid.
            if lastWallPoint? and holeOuterWalls.length > 0

                # Find combing path that avoids crossing holes.
                # Pass boundaryPath as the boundary constraint.
                combingPath = helpers.findCombingPath(lastWallPoint, targetPoint, holeOuterWalls, boundaryPath, nozzleDiameter)

                # Generate travel moves for each segment of the combing path.
                travelSpeedMmMin = slicer.getTravelSpeed() * 60

                for i in [0...combingPath.length - 1]

                    waypoint = combingPath[i + 1]

                    offsetX = waypoint.x + centerOffsetX
                    offsetY = waypoint.y + centerOffsetY

                    # Add descriptive comment for travel move if verbose (only on first segment).
                    if i is 0 and verbose
                        slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeedMmMin).replace(slicer.newline, "; Moving to skin wall" + slicer.newline)
                    else
                        slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeedMmMin)

            else

                # No combing needed - use direct travel move.
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

            # Close the skin wall loop.
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

        # Step 2: Generate diagonal skin infill at 45-degree angle.
        # Skip infill generation if requested (e.g., for holes where we only want walls).
        return unless generateInfill

        # Calculate bounding box with additional inset for gap from skin wall.
        infillGap = nozzleDiameter / 2  # Gap between skin wall and infill.
        infillInset = skinWallInset + infillGap  # Total: 1.5 * nozzleDiameter from boundary.

        # Create inset boundary for infill area.
        # Pass isHole parameter to ensure correct inset direction for holes.
        infillBoundary = helpers.createInsetPath(boundaryPath, infillInset, isHole)

        return if infillBoundary.length < 3

        # Create inset versions of hole skin walls to maintain the same gap.
        # For holes, we want to shrink them (outset from the hole's perspective) by the same infill gap.
        # This ensures skin infill maintains a consistent gap from all walls, including hole skin walls.
        holeSkinWallsWithGap = []

        for holeSkinWall in holeSkinWalls

            if holeSkinWall.length >= 3

                # Create outset path for the hole (isHole=true means it will shrink the hole).
                holeSkinWallWithGap = helpers.createInsetPath(holeSkinWall, infillGap, true)

                if holeSkinWallWithGap.length >= 3

                    holeSkinWallsWithGap.push(holeSkinWallWithGap)

        # Use covered area boundaries directly as exclusion zones.
        # For covered areas (solid regions fully covered above and below), we use the boundary
        # from the layer above without any additional offset. This prevents skin infill from
        # entering the covered region while maintaining precise boundary alignment.
        coveredAreaSkinWallsWithGap = []

        for coveredAreaSkinWall in coveredAreaSkinWalls

            if coveredAreaSkinWall.length >= 3

                # Use the covered area boundary directly as the exclusion zone.
                coveredAreaSkinWallsWithGap.push(coveredAreaSkinWall)

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

        # Generate diagonal infill lines at 45-degree angle.
        # Alternate direction per layer: odd layers at -45°, even layers at +45°.
        # Line spacing equal to nozzle diameter for solid infill.
        lineSpacing = nozzleDiameter

        # For 45-degree lines, we'll iterate along a diagonal axis.
        # Calculate the diagonal span.
        width = maxX - minX
        height = maxY - minY

        diagonalSpan = Math.sqrt(width * width + height * height)

        travelSpeedMmMin = slicer.getTravelSpeed() * 60
        infillSpeedMmMin = slicer.getInfillSpeed() * 60

        # Determine infill angle based on layer index.
        # Odd layers: -45° (y = -x + offset), Even layers: +45° (y = x + offset).
        useNegativeSlope = (layerIndex % 2) is 1

        # Start from appropriate diagonal position.
        if useNegativeSlope

            # For -45° (y = -x + offset): offset ranges from minY + minX to maxY + maxX.
            offset = minY + minX - diagonalSpan
            maxOffset = maxY + maxX

        else

            # For +45° (y = x + offset): offset ranges from minY - maxX to maxY - minX.
            offset = minY - maxX - diagonalSpan
            maxOffset = maxY - minX

        # Collect all skin infill line segments first for region-based ordering.
        # This allows us to group segments by side of holes and minimize travel.
        allSkinLines = []

        while offset < maxOffset

            # Calculate intersection points with bounding box.
            intersections = []

            if useNegativeSlope

                # Line equation: y = -x + offset (slope = -1).

                # Check intersection with left edge (x = minX).
                y = offset - minX
                if y >= minY and y <= maxY

                    intersections.push({ x: minX, y: y })

                # Check intersection with right edge (x = maxX).
                y = offset - maxX
                if y >= minY and y <= maxY

                    intersections.push({ x: maxX, y: y })

                # Check intersection with bottom edge (y = minY).
                x = offset - minY
                if x >= minX and x <= maxX

                    intersections.push({ x: x, y: minY })

                # Check intersection with top edge (y = maxY).
                x = offset - maxY
                if x >= minX and x <= maxX

                    intersections.push({ x: x, y: maxY })

            else

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
            if intersections.length >= 2

                # Clip the line segment to the actual infill boundary polygon.
                # Also exclude hole areas and covered areas by clipping against their boundaries.
                # Holes are expanded outward by infillGap, covered areas use boundaries as-is.
                # This ensures skin infill stays within the boundary and outside holes/covered areas with proper clearance.
                allExclusionWalls = holeSkinWallsWithGap.concat(coveredAreaSkinWallsWithGap)
                clippedSegments = helpers.clipLineWithHoles(intersections[0], intersections[1], infillBoundary, allExclusionWalls)

                # Store each clipped segment for later rendering.
                for segment in clippedSegments

                    allSkinLines.push({
                        start: segment.start
                        end: segment.end
                    })

            # Move to next diagonal line.
            offset += lineSpacing * Math.sqrt(2)  # Account for 45-degree angle.

        # Now render all collected lines in optimal order to minimize travel.
        # Use nearest-neighbor selection with combing to avoid crossing holes.
        # This groups segments naturally by region (e.g., sides of a hole).
        # Initialize lastEndPoint with the end position of the skin wall.
        # The skin wall loop closes back to firstPoint, so that's where we are now.
        lastEndPoint = if skinWallPath.length >= 3 then { x: skinWallPath[0].x, y: skinWallPath[0].y, z: z } else null

        while allSkinLines.length > 0

            # Find the line with an endpoint closest to current position.
            minDistSq = Infinity
            bestLineIdx = 0
            bestFlipped = false

            # If no last position, start with the first line.
            # Otherwise, find the line with endpoint closest to current position.
            if lastEndPoint?

                for line, idx in allSkinLines

                    # Check distance to both endpoints of this line.
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

            # Get the best line and remove it from the list.
            bestLine = allSkinLines[bestLineIdx]
            allSkinLines.splice(bestLineIdx, 1)

            # Determine start and end based on whether we need to flip.
            if bestFlipped

                startPoint = bestLine.end
                endPoint = bestLine.start

            else

                startPoint = bestLine.start
                endPoint = bestLine.end

            # Move to start of line (travel move with combing).
            # Find a path that avoids crossing holes.
            combingPath = helpers.findCombingPath(lastEndPoint or startPoint, startPoint, holeOuterWalls, infillBoundary, nozzleDiameter)

            # Generate travel moves for each segment of the combing path.
            for i in [0...combingPath.length - 1]

                waypoint = combingPath[i + 1]
                offsetWaypointX = waypoint.x + centerOffsetX
                offsetWaypointY = waypoint.y + centerOffsetY

                slicer.gcode += coders.codeLinearMovement(slicer, offsetWaypointX, offsetWaypointY, z, null, travelSpeedMmMin).replace(slicer.newline, (if verbose then "; Moving to skin infill line" + slicer.newline else slicer.newline))

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

        # Return the last endpoint for combing path tracking.
        # If we generated infill, return the last infill line endpoint.
        # If we only generated skin wall, return the skin wall start/end point.
        # If nothing was generated, return null.
        if lastEndPoint?
            return lastEndPoint
        else if skinWallPath? and skinWallPath.length > 0
            return { x: skinWallPath[0].x, y: skinWallPath[0].y, z: z }
        else
            return null
