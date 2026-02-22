# Tree support generation module.
# Generates tree-like branching supports with convergence behavior.
# Near the overhang: fine contact grid. Far from overhang: sparse trunk columns.
# Branch contact points converge down to trunk columns as Z decreases.

coders = require('../../gcode/coders')
normalSupportModule = require('../normal/normal')

# Height (mm) below the overhang within which the fine contact grid is used.
BRANCH_HEIGHT = 8.0

# Contact spacing multiplier (fine grid near overhang).
CONTACT_SPACING_MULTIPLIER = 1.5

# Trunk spacing multiplier (coarse columns far from overhang).
TRUNK_SPACING_MULTIPLIER = 4.0

# Minimum 2D triangle area threshold for barycentric interpolation.
DEGENERATE_TRIANGLE_THRESHOLD = 0.0001

module.exports =

    # Return the interpolated face Z at (x, y) by searching all region faces.
    # Returns null if the point lies outside every face's 2D XY projection.
    # Used for per-point zone selection (branch vs trunk) on sloped overhangs.
    getFaceZAtPoint: (x, y, faces) ->

        for face in faces

            v0 = face.vertices[0]
            v1 = face.vertices[1]
            v2 = face.vertices[2]

            # Check if point lies inside this face's XY projection.
            d1 = (x - v1.x) * (v0.y - v1.y) - (v0.x - v1.x) * (y - v1.y)
            d2 = (x - v2.x) * (v1.y - v2.y) - (v1.x - v2.x) * (y - v2.y)
            d3 = (x - v0.x) * (v2.y - v0.y) - (v2.x - v0.x) * (y - v0.y)

            hasNeg = d1 < 0 or d2 < 0 or d3 < 0
            hasPos = d1 > 0 or d2 > 0 or d3 > 0

            continue if hasNeg and hasPos

            # Compute Z at (x, y) via barycentric interpolation.
            denom = (v1.y - v2.y) * (v0.x - v2.x) + (v2.x - v1.x) * (v0.y - v2.y)

            continue if Math.abs(denom) < DEGENERATE_TRIANGLE_THRESHOLD

            w0 = ((v1.y - v2.y) * (x - v2.x) + (v2.x - v1.x) * (y - v2.y)) / denom
            w1 = ((v2.y - v0.y) * (x - v2.x) + (v0.x - v2.x) * (y - v2.y)) / denom
            w2 = 1.0 - w0 - w1

            return w0 * v0.z + w1 * v1.z + w2 * v2.z

        return null

    # Check whether a point is on or near the coarse trunk grid.
    # The grid is anchored at (originX, originY) with spacing trunkSpacing.
    # Tolerance is half of contactSpacing so each fine-grid point falls in
    # exactly one trunk cell, ensuring proper convergence.
    isOnTrunkGrid: (x, y, originX, originY, trunkSpacing, tolerance) ->

        offsetX = x - originX
        offsetY = y - originY
        nearestTrunkX = Math.round(offsetX / trunkSpacing) * trunkSpacing
        nearestTrunkY = Math.round(offsetY / trunkSpacing) * trunkSpacing

        return Math.abs(offsetX - nearestTrunkX) < tolerance and
               Math.abs(offsetY - nearestTrunkY) < tolerance

    # Generate tree-style support for a single region at a given layer.
    # Scans at the fine contact spacing always. Branch-zone points (per-point distance
    # below the interpolated overhang face ≤ BRANCH_HEIGHT) are all kept. Trunk-zone
    # points are filtered to those that align with the coarse trunk grid, so the
    # structure naturally converges from many contact points at the top to few trunk
    # columns at the bottom. Returns true if any G-code was emitted.
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

        return false if minX >= maxX or minY >= maxY

        contactSpacing = nozzleDiameter * CONTACT_SPACING_MULTIPLIER
        trunkSpacing = nozzleDiameter * TRUNK_SPACING_MULTIPLIER

        # Tolerance for trunk-grid snapping: half of contact spacing.
        trunkTolerance = contactSpacing * 0.5

        supportLineWidth = nozzleDiameter * 0.8
        supportSpeed = slicer.getPerimeterSpeed() * 60 * 0.5

        supportPoints = []

        # Always scan at the fine contact spacing.
        # Per-point zone determination uses the interpolated face Z at (x, y),
        # correctly handling sloped regions where different points of the same
        # region can be in different zones.
        y = minY
        while y <= maxY

            x = minX
            while x <= maxX

                faceZ = @getFaceZAtPoint(x, y, region.faces)

                if faceZ isnt null

                    distBelow = faceZ - z
                    isBranchZone = distBelow <= BRANCH_HEIGHT

                    # Trunk-zone points are filtered to those aligning with the
                    # coarse trunk grid, creating the convergence effect.
                    isIncluded = isBranchZone or @isOnTrunkGrid(x, y, minX, minY, trunkSpacing, trunkTolerance)

                    if isIncluded and
                       normalSupportModule.isPointInSupportWedge(x, y, region.faces, z, interfaceGap) and
                       normalSupportModule.canGenerateSupportAt(slicer, { x: x, y: y }, z, layerSolidRegions, supportPlacement, minZ, layerHeight, layerIndex)

                        supportPoints.push({ x: x, y: y })

                x += contactSpacing

            y += contactSpacing

        return false if supportPoints.length is 0

        useXDirection = layerIndex % 2 is 0
        lines = @groupPointsIntoLines(supportPoints, useXDirection)

        # Single-point lines cannot produce extrusion moves: extrusion requires
        # movement between at least two points (a travel to the start, then a G1
        # with E to the second point). Filtering them out avoids orphaned travel
        # moves that waste time without printing any material.
        extrudableLines = lines.filter((line) -> line.length > 1)

        return false if extrudableLines.length is 0

        if verbose

            slicer.gcode += "; TYPE: SUPPORT" + slicer.newline

        travelSpeed = slicer.getTravelSpeed() * 60

        for line in extrudableLines

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

        return true

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
