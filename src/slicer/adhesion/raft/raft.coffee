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

        # Calculate separate raft regions per contact area when possible.
        raftRegions = @calculateRaftRegions(boundingBox, firstLayerPaths, raftMargin)

        # Check if raft extends beyond build plate boundaries (combined bounds of all regions).
        combinedMinX = Infinity
        combinedMaxX = -Infinity
        combinedMinY = Infinity
        combinedMaxY = -Infinity

        for region in raftRegions

            combinedMinX = Math.min(combinedMinX, region.minX)
            combinedMaxX = Math.max(combinedMaxX, region.maxX)
            combinedMinY = Math.min(combinedMinY, region.minY)
            combinedMaxY = Math.max(combinedMaxY, region.maxY)

        raftBoundingBox = {
            min: { x: combinedMinX, y: combinedMinY }
            max: { x: combinedMaxX, y: combinedMaxY }
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

        for region in raftRegions

            @generateRaftLayer(slicer, region.minX, region.maxX, region.minY, region.maxY, z, centerOffsetX, centerOffsetY, raftLineSpacing * 2, 0, raftSpeedMmMin, travelSpeedMmMin)

        # Generate interface layers.
        for layerIndex in [0...raftInterfaceLayers]

            z = raftBaseThickness + (layerIndex + 1) * raftInterfaceThickness

            if verbose

                slicer.gcode += "; Raft interface layer #{layerIndex + 1}" + slicer.newline

            # Alternate line direction (90° rotation between layers).
            angle = if layerIndex % 2 is 0 then 0 else 90

            for region in raftRegions

                @generateRaftLayer(slicer, region.minX, region.maxX, region.minY, region.maxY, z, centerOffsetX, centerOffsetY, raftLineSpacing, angle, raftSpeedMmMin, travelSpeedMmMin)

        return

    # Calculate raft regions: separate regions per contact area when firstLayerPaths is available,
    # or fall back to a single region from the mesh bounding box.
    calculateRaftRegions: (boundingBox, firstLayerPaths, raftMargin) ->

        if firstLayerPaths and firstLayerPaths.length > 0

            # Filter out holes using nesting parity - paths at odd nesting levels are holes.
            # Even nesting level (0, 2, 4...) = printable structure; odd (1, 3, 5...) = hole.
            outerPaths = []

            for path, pathIndex in firstLayerPaths

                continue if path.length < 3

                nestingLevel = 0

                for otherPath, otherIndex in firstLayerPaths

                    continue if pathIndex is otherIndex

                    if otherPath.length >= 3 and primitives.pointInPolygon(path[0], otherPath)

                        nestingLevel++

                if nestingLevel % 2 is 0

                    outerPaths.push(path)

            if outerPaths.length > 0

                # Create a separate raft region for each outer path's bounding box.
                regions = []

                for path in outerPaths

                    minX = Infinity
                    maxX = -Infinity
                    minY = Infinity
                    maxY = -Infinity

                    for point in path

                        minX = Math.min(minX, point.x)
                        maxX = Math.max(maxX, point.x)
                        minY = Math.min(minY, point.y)
                        maxY = Math.max(maxY, point.y)

                    regions.push({
                        minX: minX - raftMargin
                        maxX: maxX + raftMargin
                        minY: minY - raftMargin
                        maxY: maxY + raftMargin
                    })

                return regions

        # Fall back to a single region from the mesh bounding box.
        return [{
            minX: boundingBox.min.x - raftMargin
            maxX: boundingBox.max.x + raftMargin
            minY: boundingBox.min.y - raftMargin
            maxY: boundingBox.max.y + raftMargin
        }]

    # Generate a single raft layer with lines at specified angle.
    generateRaftLayer: (slicer, minX, maxX, minY, maxY, z, centerOffsetX, centerOffsetY, lineSpacing, angle, raftSpeedMmMin, travelSpeedMmMin) ->

        nozzleDiameter = slicer.getNozzleDiameter()

        width = maxX - minX
        height = maxY - minY

        # Generate lines at specified angle.
        allLines = []

        # Tolerance for floating-point boundary comparisons.
        edgeEpsilon = 0.001

        if angle is 0

            # Horizontal lines (along Y axis).
            numLines = Math.floor(height / lineSpacing) + 1
            startY = minY

            for i in [0...numLines]

                y = startY + i * lineSpacing

                if y >= minY - edgeEpsilon and y <= maxY + edgeEpsilon

                    allLines.push({
                        start: { x: minX, y: y }
                        end: { x: maxX, y: y }
                    })

            # Add a far-edge line when the last grid line stops short of maxY.
            # This covers both truly non-aligned heights and floating-point cases
            # where lastY slightly exceeds maxY (handled by loop epsilon above).
            lastY = startY + (numLines - 1) * lineSpacing

            if maxY - lastY > edgeEpsilon

                allLines.push({
                    start: { x: minX, y: maxY }
                    end: { x: maxX, y: maxY }
                })

        else

            # Vertical lines (along X axis).
            numLines = Math.floor(width / lineSpacing) + 1
            startX = minX

            for i in [0...numLines]

                x = startX + i * lineSpacing

                if x >= minX - edgeEpsilon and x <= maxX + edgeEpsilon

                    allLines.push({
                        start: { x: x, y: minY }
                        end: { x: x, y: maxY }
                    })

            # Add a far-edge line when the last grid line stops short of maxX.
            lastX = startX + (numLines - 1) * lineSpacing

            if maxX - lastX > edgeEpsilon

                allLines.push({
                    start: { x: maxX, y: minY }
                    end: { x: maxX, y: maxY }
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
