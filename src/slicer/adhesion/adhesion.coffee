# Adhesion generation module for Polyslice.

coders = require('../gcode/coders')
pathsUtils = require('../utils/paths')

module.exports =

    # Generate G-code for build plate adhesion (skirt, brim, or raft).
    generateAdhesionGCode: (slicer, mesh, centerOffsetX, centerOffsetY, boundingBox) ->

        return unless slicer.getAdhesionEnabled()

        adhesionType = slicer.getAdhesionType()

        return unless adhesionType is 'skirt'

        verbose = slicer.getVerbose()

        if verbose then slicer.gcode += "; TYPE: SKIRT" + slicer.newline

        @generateSkirtGCode(slicer, mesh, centerOffsetX, centerOffsetY, boundingBox)

        return

    # Generate skirt around the model outline.
    generateSkirtGCode: (slicer, mesh, centerOffsetX, centerOffsetY, boundingBox) ->

        nozzleDiameter = slicer.getNozzleDiameter()
        layerHeight = slicer.getLayerHeight()
        adhesionDistance = slicer.getAdhesionDistance()
        adhesionLineCount = slicer.getAdhesionLineCount()

        # Calculate model dimensions in XY plane.
        modelMinX = boundingBox.min.x
        modelMaxX = boundingBox.max.x
        modelMinY = boundingBox.min.y
        modelMaxY = boundingBox.max.y

        modelCenterX = (modelMinX + modelMaxX) / 2
        modelCenterY = (modelMinY + modelMaxY) / 2

        modelWidth = modelMaxX - modelMinX
        modelHeight = modelMaxY - modelMinY

        # Calculate the radius for circular skirt (use larger dimension).
        # Add adhesion distance as starting offset.
        baseRadius = Math.sqrt((modelWidth / 2) ** 2 + (modelHeight / 2) ** 2) + adhesionDistance

        # First layer Z height.
        z = layerHeight

        perimeterSpeedMmMin = slicer.getPerimeterSpeed() * 60
        travelSpeedMmMin = slicer.getTravelSpeed() * 60

        # Generate concentric loops.
        for loopIndex in [0...adhesionLineCount]

            radius = baseRadius + (loopIndex * nozzleDiameter)

            # Generate circular path with segments.
            # Use 64 segments for smooth circle.
            segments = 64
            angleStep = (2 * Math.PI) / segments

            skirtPath = []

            for i in [0..segments]

                angle = i * angleStep
                x = modelCenterX + radius * Math.cos(angle)
                y = modelCenterY + radius * Math.sin(angle)

                skirtPath.push({ x: x, y: y })

            # Travel to start of skirt.
            if loopIndex is 0

                startX = skirtPath[0].x + centerOffsetX
                startY = skirtPath[0].y + centerOffsetY

                slicer.gcode += coders.codeLinearMovement(slicer, startX, startY, z, null, travelSpeedMmMin)

            # Print the skirt loop.
            for i in [1...skirtPath.length]

                prevPoint = skirtPath[i - 1]
                currentPoint = skirtPath[i]

                dx = currentPoint.x - prevPoint.x
                dy = currentPoint.y - prevPoint.y
                distance = Math.sqrt(dx * dx + dy * dy)

                if distance >= 0.001

                    extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
                    slicer.cumulativeE += extrusionDelta

                    offsetX = currentPoint.x + centerOffsetX
                    offsetY = currentPoint.y + centerOffsetY

                    slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, slicer.cumulativeE, perimeterSpeedMmMin)

        return
