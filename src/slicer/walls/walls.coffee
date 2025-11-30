# Wall generation module for Polyslice.

coders = require('../gcode/coders')
combing = require('../geometry/combing')

module.exports =

    # Generate G-code for a single wall (outer or inner).
    generateWallGCode: (slicer, path, z, centerOffsetX, centerOffsetY, wallType, lastEndPoint = null, holeOuterWalls = [], boundary = null) ->

        return lastEndPoint if path.length < 3

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()

        # Find optimal starting point to minimize travel.
        startIndex = 0

        if lastEndPoint? and holeOuterWalls.length > 0

            startIndex = combing.findOptimalStartPoint(path, lastEndPoint, holeOuterWalls, boundary, nozzleDiameter)

        firstPoint = path[startIndex]

        targetPoint = { x: firstPoint.x, y: firstPoint.y, z: z }

        # Use combing path if holes exist.
        if lastEndPoint? and holeOuterWalls.length > 0

            nozzleDiameter = slicer.getNozzleDiameter()
            combingPath = combing.findCombingPath(lastEndPoint, targetPoint, holeOuterWalls, boundary, nozzleDiameter)

            travelSpeedMmMin = slicer.getTravelSpeed() * 60

            for i in [0...combingPath.length - 1]

                waypoint = combingPath[i + 1]

                offsetX = waypoint.x + centerOffsetX
                offsetY = waypoint.y + centerOffsetY
                if i is 0 and verbose
                    comment = "; Moving to #{wallType.toLowerCase().replace('-', ' ')}"
                    slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeedMmMin).replace(slicer.newline, comment + slicer.newline)
                else
                    slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeedMmMin)

        else

            offsetX = firstPoint.x + centerOffsetX
            offsetY = firstPoint.y + centerOffsetY

            travelSpeedMmMin = slicer.getTravelSpeed() * 60

            comment = "; Moving to #{wallType.toLowerCase().replace('-', ' ')}"
            slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeedMmMin).replace(slicer.newline, (if verbose then comment + slicer.newline else slicer.newline))

        if verbose then slicer.gcode += "; TYPE: #{wallType}" + slicer.newline

        # Print perimeter as full closed loop.
        prevPoint = path[startIndex]
        perimeterSpeedMmMin = slicer.getPerimeterSpeed() * 60

        for i in [1..path.length]

            currentIndex = (startIndex + i) % path.length
            point = path[currentIndex]

            dx = point.x - prevPoint.x
            dy = point.y - prevPoint.y

            distance = Math.sqrt(dx * dx + dy * dy)

            if distance >= 0.001

                extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)

                slicer.cumulativeE += extrusionDelta

                offsetX = point.x + centerOffsetX
                offsetY = point.y + centerOffsetY

                slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, slicer.cumulativeE, perimeterSpeedMmMin)

            prevPoint = point

        return { x: prevPoint.x, y: prevPoint.y, z: z }
