# Tree support generation module.
# Generates anatomically-correct tree supports that grow upward from a single trunk,
# splitting into branches and fine twig tips that contact the overhang surface.
# The structure converges as it descends toward the build plate:
#   - Many fine twig tips spread across the overhang area (top)
#   - Twig tips merge into branch nodes at approximately 45-degree angles
#   - Branches converge to a single vertical trunk column (bottom)

coders = require('../../gcode/coders')
normalSupportModule = require('../normal/normal')

# Minimum 2D triangle area threshold for barycentric interpolation.
DEGENERATE_TRIANGLE_THRESHOLD = 0.0001

# Spacing between contact tip grid points (in nozzle diameters).
# Tree supports intentionally use a coarser contact grid than normal supports
# because the angled twig tips provide adequate coverage with wider spacing.
CONTACT_SPACING_MULTIPLIER = 3.0

# Cluster cell size as a multiple of contact spacing.
# Tips within one cluster cell share a branch node.
BRANCH_CLUSTER_SIZE = 3.0

# Half-size of the cross arms as a multiplier of nozzle diameter.
CROSS_SIZE_MULTIPLIER = 0.8

module.exports =

    # Return the interpolated face Z at (x, y) by searching all region faces.
    # Returns null if the point lies outside every face's 2D XY projection.
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

    # Build the complete tree segment structure for a support region.
    # Pre-computes all trunk, branch, and twig line segments from build plate to overhang.
    # Segments are cached on the region object so they are computed only once per slice.
    # Returns an array of {x1, y1, z1, x2, y2, z2, type} segment objects.
    buildTreeStructure: (region, nozzleDiameter, buildPlateZ, layerHeight) ->

        contactSpacing = nozzleDiameter * CONTACT_SPACING_MULTIPLIER
        interfaceGap = layerHeight * 1.5
        supportGap = nozzleDiameter / 2

        minX = region.minX + supportGap
        maxX = region.maxX - supportGap
        minY = region.minY + supportGap
        maxY = region.maxY - supportGap

        return [] if minX >= maxX or minY >= maxY

        # Generate contact tips: fine grid points just below the overhang surface.
        tips = []

        y = minY

        while y <= maxY

            x = minX

            while x <= maxX

                faceZ = @getFaceZAtPoint(x, y, region.faces)

                if faceZ isnt null

                    contactZ = faceZ - interfaceGap

                    if contactZ > buildPlateZ + layerHeight

                        tips.push({ x: x, y: y, z: contactZ })

                x += contactSpacing

            y += contactSpacing

        return [] if tips.length is 0

        # Compute the trunk base position: centroid of all contact tips in XY.
        trunkX = 0
        trunkY = 0

        for tip in tips

            trunkX += tip.x
            trunkY += tip.y

        trunkX /= tips.length
        trunkY /= tips.length

        # Cluster tips into branch groups using a regular grid of cells.
        clusterSpacing = contactSpacing * BRANCH_CLUSTER_SIZE
        clusterMap = {}

        for tip in tips

            cellX = Math.round(tip.x / clusterSpacing)
            cellY = Math.round(tip.y / clusterSpacing)
            key = "#{cellX},#{cellY}"
            clusterMap[key] ?= []
            clusterMap[key].push(tip)

        # Build branch nodes from cluster centroids.
        branchNodes = []

        for key, clusterTips of clusterMap

            cx = 0
            cy = 0
            maxZ = -Infinity

            for tip in clusterTips

                cx += tip.x
                cy += tip.y
                maxZ = Math.max(maxZ, tip.z)

            cx /= clusterTips.length
            cy /= clusterTips.length

            branchNodes.push({ x: cx, y: cy, z: maxZ, tips: clusterTips })

        # Build trunk, branch, and twig segments for each branch node.
        segments = []

        for node in branchNodes

            dx = node.x - trunkX
            dy = node.y - trunkY
            dist = Math.sqrt(dx * dx + dy * dy)

            # Enforce 45-degree constraint: vertical rise equals horizontal spread.
            branchRootZ = node.z - dist
            branchRootZ = Math.max(branchRootZ, buildPlateZ + layerHeight)

            # Trunk segment: vertical column from build plate to where this branch splits off.
            if branchRootZ > buildPlateZ + layerHeight

                segments.push({
                    x1: trunkX, y1: trunkY, z1: buildPlateZ
                    x2: trunkX, y2: trunkY, z2: branchRootZ
                    type: 'trunk'
                })

            # Branch segment: angled from trunk top toward the branch node at ~45 degrees.
            segments.push({
                x1: trunkX, y1: trunkY, z1: branchRootZ
                x2: node.x, y2: node.y, z2: node.z
                type: 'branch'
            })

            # Twig segments: fine sub-branches from cluster node to individual contact tips.
            for tip in node.tips

                tdx = tip.x - node.x
                tdy = tip.y - node.y
                tdist = Math.sqrt(tdx * tdx + tdy * tdy)

                twigRootZ = tip.z - tdist
                twigRootZ = Math.max(twigRootZ, branchRootZ + layerHeight)

                if twigRootZ < tip.z - layerHeight

                    segments.push({
                        x1: node.x, y1: node.y, z1: twigRootZ
                        x2: tip.x, y2: tip.y, z2: tip.z
                        type: 'twig'
                    })

        return segments

    # Remove points that are within 'tolerance' distance of an already-kept point.
    # Collapses multiple tree paths that converge to the same trunk position.
    deduplicatePoints: (points, tolerance) ->

        result = []
        toleranceSq = tolerance * tolerance

        for point in points

            isDuplicate = false

            for existing in result

                dx = point.x - existing.x
                dy = point.y - existing.y

                if dx * dx + dy * dy < toleranceSq

                    isDuplicate = true
                    break

            result.push(point) unless isDuplicate

        return result

    # Render a small cross-shaped extrusion at a single support node position.
    # The cross is the characteristic cross-section shape of tree support trunks
    # and branches, creating a solid anchor point at each layer.
    renderCrossAt: (slicer, px, py, z, centerOffsetX, centerOffsetY, nozzleDiameter, supportLineWidth, supportSpeed, travelSpeed) ->

        halfSize = nozzleDiameter * CROSS_SIZE_MULTIPLIER

        # Horizontal arm: travel to left end, extrude to right end.
        slicer.gcode += coders.codeLinearMovement(
            slicer,
            px - halfSize + centerOffsetX,
            py + centerOffsetY,
            z, null, travelSpeed
        )

        extrusionDelta = slicer.calculateExtrusion(halfSize * 2, supportLineWidth)
        slicer.cumulativeE += extrusionDelta

        slicer.gcode += coders.codeLinearMovement(
            slicer,
            px + halfSize + centerOffsetX,
            py + centerOffsetY,
            z, slicer.cumulativeE, supportSpeed
        )

        # Vertical arm: travel to bottom end, extrude to top end.
        slicer.gcode += coders.codeLinearMovement(
            slicer,
            px + centerOffsetX,
            py - halfSize + centerOffsetY,
            z, null, travelSpeed
        )

        extrusionDelta = slicer.calculateExtrusion(halfSize * 2, supportLineWidth)
        slicer.cumulativeE += extrusionDelta

        slicer.gcode += coders.codeLinearMovement(
            slicer,
            px + centerOffsetX,
            py + halfSize + centerOffsetY,
            z, slicer.cumulativeE, supportSpeed
        )

    # Generate tree-style support G-code for a region at a given layer.
    # Finds the cross-section of every tree segment (trunk, branch, twig) at height Z
    # and renders a small cross at each intersection point:
    #   - Bottom layers: one cross at the trunk centroid (convergence)
    #   - Middle layers: a few crosses where branches have split from the trunk
    #   - Top layers: many fine crosses spread across the overhang contact area
    # Returns true if any G-code was emitted, false otherwise.
    generateTreePattern: (slicer, region, z, layerIndex, centerOffsetX, centerOffsetY, nozzleDiameter, layerSolidRegions, supportPlacement, minZ, layerHeight) ->

        verbose = slicer.getVerbose()

        # Build tree structure once per region per slice (cached on the region object).
        if not region._treeSegments?

            region._treeSegments = @buildTreeStructure(region, nozzleDiameter, minZ, layerHeight)

        segments = region._treeSegments

        return false if segments.length is 0

        # Find the cross-section point of every segment that spans this layer Z.
        supportPoints = []

        for seg in segments

            segMinZ = Math.min(seg.z1, seg.z2)
            segMaxZ = Math.max(seg.z1, seg.z2)

            continue if z < segMinZ or z > segMaxZ

            # Interpolate XY position at height Z along the segment.
            if Math.abs(seg.z2 - seg.z1) < 0.0001

                px = (seg.x1 + seg.x2) / 2
                py = (seg.y1 + seg.y2) / 2

            else

                t = (z - seg.z1) / (seg.z2 - seg.z1)
                px = seg.x1 + t * (seg.x2 - seg.x1)
                py = seg.y1 + t * (seg.y2 - seg.y1)

            # Verify no solid geometry blocks the support path from below.
            if normalSupportModule.canGenerateSupportAt(
                slicer, { x: px, y: py }, z,
                layerSolidRegions, supportPlacement, minZ, layerHeight, layerIndex
            )

                supportPoints.push({ x: px, y: py })

        # Collapse multiple paths that converge to the same trunk position.
        deduplicated = @deduplicatePoints(supportPoints, nozzleDiameter * 0.5)

        return false if deduplicated.length is 0

        if verbose

            slicer.gcode += "; TYPE: SUPPORT" + slicer.newline

        supportLineWidth = nozzleDiameter * 0.8
        supportSpeed = slicer.getPerimeterSpeed() * 60 * 0.5
        travelSpeed = slicer.getTravelSpeed() * 60

        # Render a cross at each support node cross-section.
        for point in deduplicated

            @renderCrossAt(
                slicer, point.x, point.y, z,
                centerOffsetX, centerOffsetY,
                nozzleDiameter, supportLineWidth, supportSpeed, travelSpeed
            )

        return true
