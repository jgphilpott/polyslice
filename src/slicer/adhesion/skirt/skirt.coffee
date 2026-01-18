# Skirt adhesion generation for Polyslice.

coders = require('../../gcode/coders')
boundaryHelper = require('../helpers/boundary')

module.exports =

    # Generate skirt adhesion (dispatches to circular or shape-based).
    generateSkirt: (slicer, mesh, centerOffsetX, centerOffsetY, boundingBox, firstLayerPaths = null) ->

        # Get skirt type configuration (default to 'circular').
        skirtType = slicer.getAdhesionSkirtType?() or 'circular'

        switch skirtType

            when 'circular'

                @generateCircularSkirt(slicer, mesh, centerOffsetX, centerOffsetY, boundingBox)

            when 'shape'

                @generateShapeSkirt(slicer, mesh, centerOffsetX, centerOffsetY, boundingBox, firstLayerPaths)

            else

                # Default to circular if invalid type.
                @generateCircularSkirt(slicer, mesh, centerOffsetX, centerOffsetY, boundingBox)

        return

    # Generate circular skirt around the model.
    generateCircularSkirt: (slicer, mesh, centerOffsetX, centerOffsetY, boundingBox) ->

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

        # Check if skirt extends beyond build plate boundaries using helper.
        maxRadius = baseRadius + (adhesionLineCount * nozzleDiameter)
        skirtBoundingBox = boundaryHelper.calculateCircularSkirtBounds(modelCenterX, modelCenterY, maxRadius)
        boundaryInfo = boundaryHelper.checkBuildPlateBoundaries(slicer, skirtBoundingBox, centerOffsetX, centerOffsetY)
        boundaryHelper.addBoundaryWarning(slicer, boundaryInfo, 'Skirt')

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

    # Generate shape-based skirt that follows the first layer outline.
    generateShapeSkirt: (slicer, mesh, centerOffsetX, centerOffsetY, boundingBox, firstLayerPaths = null) ->

        # Check if we have first layer paths to work with.
        if not firstLayerPaths or firstLayerPaths.length is 0

            verbose = slicer.getVerbose()

            if verbose

                slicer.gcode += "; No first layer paths available for shape skirt, using circular skirt" + slicer.newline

            # Fall back to circular skirt.
            @generateCircularSkirt(slicer, mesh, centerOffsetX, centerOffsetY, boundingBox)

            return

        pathsUtils = require('../../utils/paths')
        primitives = require('../../utils/primitives')

        nozzleDiameter = slicer.getNozzleDiameter()
        layerHeight = slicer.getLayerHeight()
        adhesionDistance = slicer.getAdhesionDistance()
        adhesionLineCount = slicer.getAdhesionLineCount()

        # First layer Z height.
        z = layerHeight

        perimeterSpeedMmMin = slicer.getPerimeterSpeed() * 60
        travelSpeedMmMin = slicer.getTravelSpeed() * 60

        # Process each path in the first layer (may have multiple independent objects or holes).
        # Filter out holes - skirt should only follow the outer boundaries.
        outerPaths = []

        for path, pathIndex in firstLayerPaths

            continue if path.length < 3

            # Check if this path is a hole by checking if it's inside another path.
            isHole = false

            for otherPath, otherIndex in firstLayerPaths

                continue if pathIndex is otherIndex

                if otherPath.length >= 3 and primitives.pointInPolygon(path[0], otherPath)

                    isHole = true
                    break

            if not isHole

                outerPaths.push(path)

        # If no outer paths found, fall back to circular.
        if outerPaths.length is 0

            verbose = slicer.getVerbose()

            if verbose

                slicer.gcode += "; No outer paths found for shape skirt, using circular skirt" + slicer.newline

            @generateCircularSkirt(slicer, mesh, centerOffsetX, centerOffsetY, boundingBox)

            return

        # Generate concentric loops around all outer paths.
        for loopIndex in [0...adhesionLineCount]

            # Calculate offset distance for this loop.
            # First loop is at adhesionDistance, subsequent loops are spaced by nozzleDiameter.
            offsetDistance = adhesionDistance + (loopIndex * nozzleDiameter)

            # Create offset paths for each outer boundary.
            # Use negative offset to expand outward (createInsetPath with negative distance).
            offsetPaths = []

            for outerPath in outerPaths

                # For skirt, we want to offset outward (expand), so use negative inset distance.
                # isHole = false because these are outer boundaries.
                skirtPath = pathsUtils.createInsetPath(outerPath, -offsetDistance, false)

                if skirtPath.length >= 3

                    offsetPaths.push(skirtPath)

            # If no valid offset paths, skip this loop.
            continue if offsetPaths.length is 0

            # Print each offset path.
            for skirtPath, pathIdx in offsetPaths

                # Travel to start of skirt path.
                if loopIndex is 0 and pathIdx is 0

                    startX = skirtPath[0].x + centerOffsetX
                    startY = skirtPath[0].y + centerOffsetY

                    slicer.gcode += coders.codeLinearMovement(slicer, startX, startY, z, null, travelSpeedMmMin)

                else

                    # Travel to start of next path.
                    startX = skirtPath[0].x + centerOffsetX
                    startY = skirtPath[0].y + centerOffsetY

                    slicer.gcode += coders.codeLinearMovement(slicer, startX, startY, z, null, travelSpeedMmMin)

                # Print the skirt loop.
                prevPoint = skirtPath[0]

                for i in [1..skirtPath.length] # Include closing move

                    # Wrap around to close the loop.
                    currentPoint = skirtPath[i % skirtPath.length]

                    dx = currentPoint.x - prevPoint.x
                    dy = currentPoint.y - prevPoint.y
                    distance = Math.sqrt(dx * dx + dy * dy)

                    if distance >= 0.001

                        extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
                        slicer.cumulativeE += extrusionDelta

                        offsetX = currentPoint.x + centerOffsetX
                        offsetY = currentPoint.y + centerOffsetY

                        slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, slicer.cumulativeE, perimeterSpeedMmMin)

                    prevPoint = currentPoint

        # Check if skirt extends beyond build plate boundaries.
        # Calculate combined bounds of all offset paths.
        allSkirtBounds = null

        for outerPath in outerPaths

            maxOffsetDistance = adhesionDistance + ((adhesionLineCount - 1) * nozzleDiameter)
            pathBounds = boundaryHelper.calculatePathBounds(outerPath, maxOffsetDistance)

            if pathBounds

                if not allSkirtBounds

                    allSkirtBounds = pathBounds

                else

                    allSkirtBounds.min.x = Math.min(allSkirtBounds.min.x, pathBounds.min.x)
                    allSkirtBounds.min.y = Math.min(allSkirtBounds.min.y, pathBounds.min.y)
                    allSkirtBounds.max.x = Math.max(allSkirtBounds.max.x, pathBounds.max.x)
                    allSkirtBounds.max.y = Math.max(allSkirtBounds.max.y, pathBounds.max.y)

        if allSkirtBounds

            boundaryInfo = boundaryHelper.checkBuildPlateBoundaries(slicer, allSkirtBounds, centerOffsetX, centerOffsetY)
            boundaryHelper.addBoundaryWarning(slicer, boundaryInfo, 'Skirt')

        return
