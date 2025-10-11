# Wall generation module for Polyslice.

coders = require('../gcode/coders')

module.exports =

    # Generate G-code for a single wall (outer or inner).
    generateWallGCode: (slicer, path, z, centerOffsetX, centerOffsetY, wallType) ->

        return if path.length < 3

        verbose = slicer.getVerbose()

        # Move to start of path (travel move) with center offset.
        firstPoint = path[0]

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
