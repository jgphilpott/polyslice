# Skirt adhesion generation for Polyslice.

coders = require('../../gcode/coders')
boundaryHelper = require('../helpers/boundary')

module.exports =

    # Generate skirt adhesion (dispatches to circular or shape-based).
    generateSkirt: (slicer, mesh, centerOffsetX, centerOffsetY, boundingBox, firstLayerPaths = null) ->

        # Get skirt type configuration (default to 'circular').
        skirtType = slicer.getSkirtType?() or 'circular'

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
        skirtDistance = slicer.getSkirtDistance()
        skirtLineCount = slicer.getSkirtLineCount()

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
        # Add skirt distance as starting offset.
        baseRadius = Math.sqrt((modelWidth / 2) ** 2 + (modelHeight / 2) ** 2) + skirtDistance

        # First layer Z height.
        z = layerHeight

        perimeterSpeedMmMin = slicer.getPerimeterSpeed() * 60
        travelSpeedMmMin = slicer.getTravelSpeed() * 60

        # Check if skirt extends beyond build plate boundaries using helper.
        maxRadius = baseRadius + (skirtLineCount * nozzleDiameter)
        skirtBoundingBox = boundaryHelper.calculateCircularSkirtBounds(modelCenterX, modelCenterY, maxRadius)
        boundaryInfo = boundaryHelper.checkBuildPlateBoundaries(slicer, skirtBoundingBox, centerOffsetX, centerOffsetY)
        boundaryHelper.addBoundaryWarning(slicer, boundaryInfo, 'Skirt')

        # Generate concentric loops.
        for loopIndex in [0...skirtLineCount]

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
        skirtDistance = slicer.getSkirtDistance()
        skirtLineCount = slicer.getSkirtLineCount()

        # First layer Z height.
        z = layerHeight

        perimeterSpeedMmMin = slicer.getPerimeterSpeed() * 60
        travelSpeedMmMin = slicer.getTravelSpeed() * 60

        # Process each path in the first layer (may have multiple independent objects or holes).
        # Filter out holes - skirt should only follow the outer boundaries.
        # Note: This uses O(n²) nested loop for hole detection, which is acceptable since
        # first layers typically have few paths (usually <10). For optimization in extreme
        # cases with many paths, consider bounding box pre-filtering or spatial indexing.
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

        # Helper function to create an outset path (expand outward).
        # This implements a simple polygon offset algorithm using perpendicular normals.
        # While external libraries like Clipper.js could be used, this custom implementation:
        # - Avoids adding dependencies for a single operation
        # - Works well for the simple convex/near-convex shapes typical of first layers
        # - Has been validated through comprehensive testing
        # Note: For complex self-intersecting or highly concave paths, consider Clipper.js.
        createOutsetPath = (path, outsetDistance) =>

            return [] if path.length < 3

            outsetPath = []
            n = path.length

            # Calculate signed area to determine winding order.
            # Positive area = CCW (counter-clockwise), Negative = CW (clockwise).
            # This works correctly in the XY coordinate system used by slicing.
            signedArea = 0

            for i in [0...n]

                nextIdx = if i is n - 1 then 0 else i + 1
                signedArea += path[i].x * path[nextIdx].y - path[nextIdx].x * path[i].y

            isCCW = signedArea > 0

            # Create offset lines for each edge.
            offsetLines = []

            for i in [0...n]

                nextIdx = if i is n - 1 then 0 else i + 1

                p1 = path[i]
                p2 = path[nextIdx]

                # Edge vector.
                edgeX = p2.x - p1.x
                edgeY = p2.y - p1.y

                edgeLength = Math.sqrt(edgeX * edgeX + edgeY * edgeY)

                continue if edgeLength < 0.0001

                # Normalize.
                edgeX /= edgeLength
                edgeY /= edgeLength

                # Perpendicular outward normal.
                if isCCW

                    normalX = edgeY   # Outward for CCW
                    normalY = -edgeX

                else

                    normalX = -edgeY  # Outward for CW
                    normalY = edgeX

                # Offset the edge outward.
                offset1X = p1.x + normalX * outsetDistance
                offset1Y = p1.y + normalY * outsetDistance
                offset2X = p2.x + normalX * outsetDistance
                offset2Y = p2.y + normalY * outsetDistance

                offsetLines.push({
                    p1: { x: offset1X, y: offset1Y }
                    p2: { x: offset2X, y: offset2Y }
                })

            # Find intersections of adjacent offset lines.
            for i in [0...offsetLines.length]

                prevIdx = if i is 0 then offsetLines.length - 1 else i - 1

                line1 = offsetLines[prevIdx]
                line2 = offsetLines[i]

                intersection = primitives.lineIntersection(line1.p1, line1.p2, line2.p1, line2.p2)

                if intersection

                    outsetPath.push({ x: intersection.x, y: intersection.y })

                else

                    # Parallel lines - use midpoint.
                    outsetPath.push({ x: line2.p1.x, y: line2.p1.y })

            return outsetPath

        # Generate concentric loops around all outer paths.
        for loopIndex in [0...skirtLineCount]

            # Calculate offset distance for this loop.
            # First loop is at skirtDistance, subsequent loops are spaced by nozzleDiameter.
            offsetDistance = skirtDistance + (loopIndex * nozzleDiameter)

            # Create offset paths for each outer boundary.
            offsetPaths = []

            for outerPath in outerPaths

                # Create outset path (expand outward).
                skirtPath = createOutsetPath(outerPath, offsetDistance)

                if skirtPath.length >= 3

                    offsetPaths.push(skirtPath)

            # If no valid offset paths, skip this loop.
            continue if offsetPaths.length is 0

            # Print each offset path.
            for skirtPath, pathIdx in offsetPaths

                # Optimize starting point to be closest to home position (for first loop) or previous end
                # This prevents corner clipping artifacts
                if skirtPath.length >= 3
                    
                    # For the first path, start closest to home position (0, 0 in build plate coords)
                    # For subsequent paths, start closest to where we last ended
                    referenceX = if loopIndex is 0 and pathIdx is 0 then -centerOffsetX else prevPoint?.x ? -centerOffsetX
                    referenceY = if loopIndex is 0 and pathIdx is 0 then -centerOffsetY else prevPoint?.y ? -centerOffsetY
                    
                    # Find the point in the path closest to the reference position
                    minDistSq = Infinity
                    bestStartIndex = 0
                    
                    for point, idx in skirtPath
                        dx = point.x - referenceX
                        dy = point.y - referenceY
                        distSq = dx * dx + dy * dy
                        
                        if distSq < minDistSq
                            minDistSq = distSq
                            bestStartIndex = idx
                    
                    # Rotate the path to start at the best point
                    if bestStartIndex > 0
                        skirtPath = skirtPath[bestStartIndex...].concat(skirtPath[0...bestStartIndex])

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

            maxOffsetDistance = skirtDistance + ((skirtLineCount - 1) * nozzleDiameter)
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
