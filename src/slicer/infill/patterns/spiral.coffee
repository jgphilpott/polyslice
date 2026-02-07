# Spiral infill pattern implementation for Polyslice.

coders = require('../../gcode/coders')
primitives = require('../../utils/primitives')
clipping = require('../../utils/clipping')
combing = require('../../geometry/combing')

module.exports =

    # Generate spiral pattern infill (Archimedean spiral from center outward).
    generateSpiralInfill: (slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, infillPatternCentering, lastWallPoint = null, holeInnerWalls = [], holeOuterWalls = []) ->

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()

        travelSpeedMmMin = slicer.getTravelSpeed() * 60
        infillSpeedMmMin = slicer.getInfillSpeed() * 60

        # Calculate bounding box for spiral generation.
        minX = Infinity
        maxX = -Infinity
        minY = Infinity
        maxY = -Infinity

        for point in infillBoundary

            if point.x < minX then minX = point.x
            if point.x > maxX then maxX = point.x
            if point.y < minY then minY = point.y
            if point.y > maxY then maxY = point.y

        # Determine pattern center based on infillPatternCentering setting.
        if infillPatternCentering is 'global'
            # Global centering: use build plate center (0, 0 in local coordinates).
            centerX = 0
            centerY = 0
        else
            # Object centering: use infill boundary center (default behavior).
            centerX = (minX + maxX) / 2
            centerY = (minY + maxY) / 2

        # Calculate maximum radius needed to cover the entire boundary.
        width = maxX - minX
        height = maxY - minY
        maxRadius = Math.sqrt(width * width + height * height) / 2

        # Generate Archimedean spiral points.
        # Parametric equation: r = a * theta, where a controls spacing.
        # For lineSpacing between successive turns: a = lineSpacing / (2 * PI).
        spiralConstant = lineSpacing / (2 * Math.PI)

        # Calculate total angle needed to reach maxRadius.
        maxTheta = maxRadius / spiralConstant

        # Angular step size for smooth spiral (approximately 10 degrees per step).
        thetaStep = 10 * Math.PI / 180

        # Generate spiral path as continuous line segments.
        spiralPoints = []
        theta = 0

        while theta <= maxTheta

            radius = spiralConstant * theta
            x = centerX + radius * Math.cos(theta)
            y = centerY + radius * Math.sin(theta)

            spiralPoints.push({ x: x, y: y })

            theta += thetaStep

        return if spiralPoints.length < 2

        # Clip spiral segments to infill boundary, excluding holes.
        clippedSegments = []

        for i in [0...spiralPoints.length - 1]

            startPoint = spiralPoints[i]
            endPoint = spiralPoints[i + 1]

            # Clip segment against boundary and holes.
            segments = clipping.clipLineWithHoles(startPoint, endPoint, infillBoundary, holeInnerWalls)

            for segment in segments
                clippedSegments.push(segment)

        return if clippedSegments.length is 0

        # Render clipped spiral segments in order (no reordering needed for continuous spiral).
        lastEndPoint = lastWallPoint

        for segment in clippedSegments

            startPoint = segment.start
            endPoint = segment.end

            # Skip if segment is invalid.
            continue if not startPoint? or not endPoint?

            # Travel to start point with combing if we have a previous position.
            if lastEndPoint?

                combingPath = combing.findCombingPath(lastEndPoint, startPoint, holeOuterWalls, infillBoundary, nozzleDiameter)

                # Render combing path if it has waypoints.
                if combingPath? and combingPath.length > 1

                    for i in [0...combingPath.length - 1]

                        waypoint = combingPath[i + 1]

                        if waypoint?

                            offsetWaypointX = waypoint.x + centerOffsetX
                            offsetWaypointY = waypoint.y + centerOffsetY

                            slicer.gcode += coders.codeLinearMovement(slicer, offsetWaypointX, offsetWaypointY, z, null, travelSpeedMmMin).replace(slicer.newline, (if verbose then "; Moving to spiral segment" + slicer.newline else slicer.newline))

            else

                # First segment - direct travel to start point.
                offsetStartX = startPoint.x + centerOffsetX
                offsetStartY = startPoint.y + centerOffsetY

                slicer.gcode += coders.codeLinearMovement(slicer, offsetStartX, offsetStartY, z, null, travelSpeedMmMin).replace(slicer.newline, (if verbose then "; Moving to spiral start" + slicer.newline else slicer.newline))

            # Extrude from start to end point.
            dx = endPoint.x - startPoint.x
            dy = endPoint.y - startPoint.y
            distance = Math.sqrt(dx * dx + dy * dy)

            if distance > 0.001

                extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
                slicer.cumulativeE += extrusionDelta

                offsetEndX = endPoint.x + centerOffsetX
                offsetEndY = endPoint.y + centerOffsetY

                slicer.gcode += coders.codeLinearMovement(slicer, offsetEndX, offsetEndY, z, slicer.cumulativeE, infillSpeedMmMin)

            # Update last end point for next segment.
            lastEndPoint = endPoint
