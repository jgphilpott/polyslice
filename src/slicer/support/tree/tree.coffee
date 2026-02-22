# Tree support generation module.
# Generates tree-like branching supports for reduced material usage.
# Contact points near the overhang converge to trunk columns at the build plate.

coders = require('../../gcode/coders')
normalSupportModule = require('../normal/normal')

# Height (mm) below the overhang within which the fine contact grid is used.
BRANCH_HEIGHT = 8.0

# Contact spacing multiplier (fine grid near overhang).
CONTACT_SPACING_MULTIPLIER = 1.5

# Trunk spacing multiplier (coarse columns far from overhang).
TRUNK_SPACING_MULTIPLIER = 4.0

module.exports =

    # Generate tree-style support for a single region at a given layer.
    # Produces fine contact points near the overhang and coarse trunk columns below.
    generateTreePattern: (slicer, region, z, layerIndex, centerOffsetX, centerOffsetY, nozzleDiameter, layerSolidRegions, supportPlacement, minZ, layerHeight) ->

        verbose = slicer.getVerbose()

        # Interface gap between support top and overhang face.
        interfaceGap = layerHeight * 1.5

        # Shrink bounds to prevent the support from touching the object.
        supportGap = nozzleDiameter / 2
        minX = region.minX + supportGap
        maxX = region.maxX - supportGap
        minY = region.minY + supportGap
        maxY = region.maxY - supportGap

        return if minX >= maxX or minY >= maxY

        contactSpacing = nozzleDiameter * CONTACT_SPACING_MULTIPLIER
        trunkSpacing = nozzleDiameter * TRUNK_SPACING_MULTIPLIER
        supportLineWidth = nozzleDiameter * 0.8
        supportSpeed = slicer.getPerimeterSpeed() * 60 * 0.5

        # Distance below the highest overhang point at this layer.
        distBelow = region.maxZ - z

        supportPoints = []

        if distBelow <= BRANCH_HEIGHT

            # Branch zone: fine contact grid near the overhang.
            y = minY
            while y <= maxY

                x = minX
                while x <= maxX

                    if normalSupportModule.isPointInSupportWedge(x, y, region.faces, z, interfaceGap) and
                       normalSupportModule.canGenerateSupportAt(slicer, { x: x, y: y }, z, layerSolidRegions, supportPlacement, minZ, layerHeight, layerIndex)

                        supportPoints.push({ x: x, y: y })

                    x += contactSpacing

                y += contactSpacing

        else

            # Trunk zone: coarse grid forming vertical trunk columns.
            y = minY
            while y <= maxY

                x = minX
                while x <= maxX

                    if normalSupportModule.isPointInSupportWedge(x, y, region.faces, z, interfaceGap) and
                       normalSupportModule.canGenerateSupportAt(slicer, { x: x, y: y }, z, layerSolidRegions, supportPlacement, minZ, layerHeight, layerIndex)

                        supportPoints.push({ x: x, y: y })

                    x += trunkSpacing

                y += trunkSpacing

        return if supportPoints.length is 0

        if verbose

            slicer.gcode += "; TYPE: SUPPORT" + slicer.newline

        # Group points into lines for continuous extrusion.
        useXDirection = layerIndex % 2 is 0
        lines = @groupPointsIntoLines(supportPoints, useXDirection)

        travelSpeed = slicer.getTravelSpeed() * 60

        for line in lines when line.length > 0

            startPoint = line[0]
            offsetX = startPoint.x + centerOffsetX
            offsetY = startPoint.y + centerOffsetY

            slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeed)

            for i in [1...line.length]

                point = line[i]
                prevPoint = line[i - 1]

                dx = point.x - prevPoint.x
                dy = point.y - prevPoint.y
                distance = Math.sqrt(dx * dx + dy * dy)

                if distance > 0.001

                    extrusionDelta = slicer.calculateExtrusion(distance, supportLineWidth)
                    slicer.cumulativeE += extrusionDelta

                    offsetX = point.x + centerOffsetX
                    offsetY = point.y + centerOffsetY

                    slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, slicer.cumulativeE, supportSpeed)

        return

    # Group support points into lines for efficient printing.
    # Alternates between X-direction and Y-direction lines each layer.
    groupPointsIntoLines: (points, useXDirection) ->

        lines = {}

        for point in points
            key = if useXDirection then point.y.toFixed(3) else point.x.toFixed(3)
            lines[key] ?= []
            lines[key].push(point)

        result = []

        for key, linePoints of lines
            if useXDirection
                linePoints.sort((a, b) -> a.x - b.x)
            else
                linePoints.sort((a, b) -> a.y - b.y)
            result.push(linePoints)

        return result
