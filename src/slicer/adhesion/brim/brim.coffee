# Brim adhesion generation for Polyslice.
#
# A brim is a flat area of filament printed around the base of the model
# to increase adhesion and prevent warping. Unlike a skirt, the brim is
# attached directly to the model.

coders = require('../../gcode/coders')
boundaryHelper = require('../helpers/boundary')

module.exports =

    # Generate brim around the model base.
    generateBrim: (slicer, mesh, centerOffsetX, centerOffsetY, boundingBox, firstLayerPaths = null) ->

        # Check if we have first layer paths to work with.
        if not firstLayerPaths or firstLayerPaths.length is 0

            verbose = slicer.getVerbose()

            if verbose

                slicer.gcode += "; No first layer paths available for brim generation" + slicer.newline

            return

        pathsUtils = require('../../utils/paths')
        primitives = require('../../utils/primitives')

        nozzleDiameter = slicer.getNozzleDiameter()
        layerHeight = slicer.getLayerHeight()
        adhesionLineCount = slicer.getAdhesionLineCount()

        # First layer Z height.
        z = layerHeight

        perimeterSpeedMmMin = slicer.getPerimeterSpeed() * 60
        travelSpeedMmMin = slicer.getTravelSpeed() * 60

        # Process each path in the first layer (may have multiple independent objects or holes).
        # Filter out holes - brim should only follow the outer boundaries.
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

        # If no outer paths found, skip brim generation.
        if outerPaths.length is 0

            verbose = slicer.getVerbose()

            if verbose

                slicer.gcode += "; No outer paths found for brim generation" + slicer.newline

            return

        # Helper function to create an outset path (expand outward).
        # This is identical to the skirt implementation.
        createOutsetPath = (path, outsetDistance) =>

            return [] if path.length < 3

            outsetPath = []
            n = path.length

            # Calculate signed area to determine winding order.
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
        # Key difference from skirt: brim starts at nozzleDiameter/2 (attached to model).
        for loopIndex in [0...adhesionLineCount]

            # Calculate offset distance for this loop.
            # First loop starts at nozzleDiameter/2 (half nozzle width from model edge).
            # Subsequent loops are spaced by nozzleDiameter.
            offsetDistance = (nozzleDiameter / 2) + (loopIndex * nozzleDiameter)

            # Create offset paths for each outer boundary.
            offsetPaths = []

            for outerPath in outerPaths

                # Create outset path (expand outward from model).
                brimPath = createOutsetPath(outerPath, offsetDistance)

                if brimPath.length >= 3

                    offsetPaths.push(brimPath)

            # If no valid offset paths, skip this loop.
            continue if offsetPaths.length is 0

            # Print each offset path.
            for brimPath, pathIdx in offsetPaths

                # Travel to start of brim path.
                if loopIndex is 0 and pathIdx is 0

                    startX = brimPath[0].x + centerOffsetX
                    startY = brimPath[0].y + centerOffsetY

                    slicer.gcode += coders.codeLinearMovement(slicer, startX, startY, z, null, travelSpeedMmMin)

                else

                    # Travel to start of next path.
                    startX = brimPath[0].x + centerOffsetX
                    startY = brimPath[0].y + centerOffsetY

                    slicer.gcode += coders.codeLinearMovement(slicer, startX, startY, z, null, travelSpeedMmMin)

                # Print the brim loop.
                prevPoint = brimPath[0]

                for i in [1..brimPath.length] # Include closing move

                    # Wrap around to close the loop.
                    currentPoint = brimPath[i % brimPath.length]

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

        # Check if brim extends beyond build plate boundaries.
        # Calculate combined bounds of all offset paths.
        allBrimBounds = null

        for outerPath in outerPaths

            # Maximum offset distance (last loop).
            maxOffsetDistance = (nozzleDiameter / 2) + ((adhesionLineCount - 1) * nozzleDiameter)
            pathBounds = boundaryHelper.calculatePathBounds(outerPath, maxOffsetDistance)

            if pathBounds

                if not allBrimBounds

                    allBrimBounds = pathBounds

                else

                    allBrimBounds.min.x = Math.min(allBrimBounds.min.x, pathBounds.min.x)
                    allBrimBounds.min.y = Math.min(allBrimBounds.min.y, pathBounds.min.y)
                    allBrimBounds.max.x = Math.max(allBrimBounds.max.x, pathBounds.max.x)
                    allBrimBounds.max.y = Math.max(allBrimBounds.max.y, pathBounds.max.y)

        if allBrimBounds

            boundaryInfo = boundaryHelper.checkBuildPlateBoundaries(slicer, allBrimBounds, centerOffsetX, centerOffsetY)
            boundaryHelper.addBoundaryWarning(slicer, boundaryInfo, 'Brim')

        return
