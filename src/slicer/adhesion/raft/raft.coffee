# Raft adhesion generation for Polyslice.
#
# A raft is a horizontal mesh of filament printed below the model.
# It provides excellent bed adhesion and creates a flat surface for the model,
# especially useful for models with small contact areas or warping issues.

coders = require('../../gcode/coders')
boundaryHelper = require('../helpers/boundary')
primitives = require('../../utils/primitives')

module.exports =

    # Generate raft beneath the model.
    generateRaft: (slicer, mesh, centerOffsetX, centerOffsetY, boundingBox, firstLayerPaths = null) ->

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()
        raftMargin = slicer.getRaftMargin()
        raftBaseThickness = slicer.getRaftBaseThickness()
        raftInterfaceLayers = slicer.getRaftInterfaceLayers()
        raftInterfaceThickness = slicer.getRaftInterfaceThickness()
        raftLineSpacing = slicer.getRaftLineSpacing()

        # Calculate raft dimensions based on model bounding box + margin.
        modelMinX = boundingBox.min.x
        modelMaxX = boundingBox.max.x
        modelMinY = boundingBox.min.y
        modelMaxY = boundingBox.max.y

        raftMinX = modelMinX - raftMargin
        raftMaxX = modelMaxX + raftMargin
        raftMinY = modelMinY - raftMargin
        raftMaxY = modelMaxY + raftMargin

        raftWidth = raftMaxX - raftMinX
        raftHeight = raftMaxY - raftMinY

        # Check if raft extends beyond build plate boundaries.
        raftBoundingBox = {
            min: { x: raftMinX, y: raftMinY }
            max: { x: raftMaxX, y: raftMaxY }
        }
        boundaryInfo = boundaryHelper.checkBuildPlateBoundaries(slicer, raftBoundingBox, centerOffsetX, centerOffsetY)
        boundaryHelper.addBoundaryWarning(slicer, boundaryInfo, 'Raft')

        perimeterSpeedMmMin = slicer.getPerimeterSpeed() * 60
        travelSpeedMmMin = slicer.getTravelSpeed() * 60

        # Slow down for raft (50% of normal speed for better adhesion).
        raftSpeedMmMin = perimeterSpeedMmMin * 0.5

        # Generate base layer at Z = raftBaseThickness.
        z = raftBaseThickness

        if verbose

            slicer.gcode += "; Raft base layer" + slicer.newline

        @generateRaftLayer(slicer, raftMinX, raftMaxX, raftMinY, raftMaxY, z, centerOffsetX, centerOffsetY, raftLineSpacing * 2, 0, raftSpeedMmMin, travelSpeedMmMin)

        # Generate interface layers.
        for layerIndex in [0...raftInterfaceLayers]

            z = raftBaseThickness + (layerIndex + 1) * raftInterfaceThickness

            if verbose

                slicer.gcode += "; Raft interface layer #{layerIndex + 1}" + slicer.newline

            # Alternate line direction (90° rotation between layers).
            angle = if layerIndex % 2 is 0 then 0 else 90

            @generateRaftLayer(slicer, raftMinX, raftMaxX, raftMinY, raftMaxY, z, centerOffsetX, centerOffsetY, raftLineSpacing, angle, raftSpeedMmMin, travelSpeedMmMin)

        return

    # Generate a single raft layer with lines at specified angle.
    generateRaftLayer: (slicer, minX, maxX, minY, maxY, z, centerOffsetX, centerOffsetY, lineSpacing, angle, raftSpeedMmMin, travelSpeedMmMin) ->

        nozzleDiameter = slicer.getNozzleDiameter()

        width = maxX - minX
        height = maxY - minY

        # Generate lines at specified angle.
        allLines = []

        if angle is 0

            # Horizontal lines (along Y axis).
            numLines = Math.floor(height / lineSpacing) + 1
            startY = minY

            for i in [0...numLines]

                y = startY + i * lineSpacing

                if y >= minY and y <= maxY

                    allLines.push({
                        start: { x: minX, y: y }
                        end: { x: maxX, y: y }
                    })

        else

            # Vertical lines (along X axis).
            numLines = Math.floor(width / lineSpacing) + 1
            startX = minX

            for i in [0...numLines]

                x = startX + i * lineSpacing

                if x >= minX and x <= maxX

                    allLines.push({
                        start: { x: x, y: minY }
                        end: { x: x, y: maxY }
                    })

        # Render lines in order (no need for nearest-neighbor since raft is simple).
        lastEndPoint = null

        for line in allLines

            startPoint = line.start
            endPoint = line.end

            # Travel to start of line.
            startX = startPoint.x + centerOffsetX
            startY = startPoint.y + centerOffsetY

            slicer.gcode += coders.codeLinearMovement(slicer, startX, startY, z, null, travelSpeedMmMin)

            # Print the line.
            dx = endPoint.x - startPoint.x
            dy = endPoint.y - startPoint.y
            distance = Math.sqrt(dx * dx + dy * dy)

            if distance >= 0.001

                extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
                slicer.cumulativeE += extrusionDelta

                endX = endPoint.x + centerOffsetX
                endY = endPoint.y + centerOffsetY

                slicer.gcode += coders.codeLinearMovement(slicer, endX, endY, z, slicer.cumulativeE, raftSpeedMmMin)

            lastEndPoint = endPoint

        return
