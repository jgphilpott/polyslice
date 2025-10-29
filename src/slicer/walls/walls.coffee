# Wall generation module for Polyslice.

coders = require('../gcode/coders')
helpers = require('../geometry/helpers')

module.exports =

    # Generate G-code for a single wall (outer or inner).
    # Parameters:
    # - slicer: The slicer instance
    # - path: The wall path to generate
    # - z: Z-coordinate for this layer
    # - centerOffsetX, centerOffsetY: Offsets to center the print on the bed
    # - wallType: Type annotation for G-code comments (WALL-OUTER, WALL-INNER)
    # - lastEndPoint: Last position from previous wall (for combing path calculation)
    # - holeOuterWalls: Array of hole outer wall paths (for travel path combing)
    # - boundary: The outer boundary path (for travel path combing)
    # Returns: The last end point of this wall (for next wall's combing calculation)
    generateWallGCode: (slicer, path, z, centerOffsetX, centerOffsetY, wallType, lastEndPoint = null, holeOuterWalls = [], boundary = null) ->

        return lastEndPoint if path.length < 3

        verbose = slicer.getVerbose()

        # Move to start of path (travel move) with center offset.
        firstPoint = path[0]

        # Calculate the target point without offset for combing path calculation.
        targetPoint = { x: firstPoint.x, y: firstPoint.y, z: z }

        # If we have a last end point and holes to avoid, use combing path.
        if lastEndPoint? and holeOuterWalls.length > 0

            # Find combing path that avoids crossing holes.
            combingPath = helpers.findCombingPath(lastEndPoint, targetPoint, holeOuterWalls, boundary)

            # Generate travel moves for each segment of the combing path.
            # Convert speed from mm/s to mm/min for G-code.
            travelSpeedMmMin = slicer.getTravelSpeed() * 60

            for i in [0...combingPath.length - 1]

                waypoint = combingPath[i + 1]

                # Apply center offset to waypoint coordinates.
                offsetX = waypoint.x + centerOffsetX
                offsetY = waypoint.y + centerOffsetY

                # Add descriptive comment for travel move if verbose (only on first segment).
                if i is 0 and verbose
                    comment = "; Moving to #{wallType.toLowerCase().replace('-', ' ')}"
                    slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeedMmMin).replace(slicer.newline, comment + slicer.newline)
                else
                    slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeedMmMin)

        else

            # No combing needed - use direct travel move.
            offsetX = firstPoint.x + centerOffsetX
            offsetY = firstPoint.y + centerOffsetY

            # Convert speed from mm/s to mm/min for G-code.
            travelSpeedMmMin = slicer.getTravelSpeed() * 60

            # Add descriptive comment for travel move if verbose.
            comment = "; Moving to #{wallType.toLowerCase().replace('-', ' ')}"
            slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeedMmMin).replace(slicer.newline, (if verbose then comment + slicer.newline else slicer.newline))

        if verbose then slicer.gcode += "; TYPE: #{wallType}" + slicer.newline

        # Print perimeter.
        for pointIndex in [1...path.length]

            point = path[pointIndex]
            prevPoint = path[pointIndex - 1]

            # Calculate distance for extrusion.
            dx = point.x - prevPoint.x
            dy = point.y - prevPoint.y

            distance = Math.sqrt(dx * dx + dy * dy)

            # Skip negligible movements.
            continue if distance < 0.001

            # Calculate extrusion amount for this segment.
            extrusionDelta = slicer.calculateExtrusion(distance, slicer.getNozzleDiameter())

            # Add to cumulative extrusion (absolute mode).
            slicer.cumulativeE += extrusionDelta

            # Apply center offset to coordinates.
            offsetX = point.x + centerOffsetX
            offsetY = point.y + centerOffsetY

            # Convert speed from mm/s to mm/min for G-code.
            perimeterSpeedMmMin = slicer.getPerimeterSpeed() * 60

            slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, slicer.cumulativeE, perimeterSpeedMmMin)

        # Close the path by returning to start if needed.
        firstPoint = path[0]
        lastPoint = path[path.length - 1]

        dx = firstPoint.x - lastPoint.x
        dy = firstPoint.y - lastPoint.y

        distance = Math.sqrt(dx * dx + dy * dy)

        if distance > 0.001

            # Calculate extrusion amount for closing segment.
            extrusionDelta = slicer.calculateExtrusion(distance, slicer.getNozzleDiameter())

            # Add to cumulative extrusion (absolute mode).
            slicer.cumulativeE += extrusionDelta

            offsetX = firstPoint.x + centerOffsetX
            offsetY = firstPoint.y + centerOffsetY

            # Convert speed from mm/s to mm/min for G-code.
            perimeterSpeedMmMin = slicer.getPerimeterSpeed() * 60

            slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, slicer.cumulativeE, perimeterSpeedMmMin)

        # Return the last end point (first point of the closed path).
        # This will be used as the starting point for combing to the next wall.
        return { x: firstPoint.x, y: firstPoint.y, z: z }
