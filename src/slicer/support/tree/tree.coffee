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

# Cross-section radius multipliers by node type (in nozzle diameters).
# Trunk is widest for structural stability; twigs are finest for easy overhang contact.
TRUNK_RADIUS_MULTIPLIER = 3.0
BRANCH_RADIUS_MULTIPLIER = 1.8
TWIG_RADIUS_MULTIPLIER = 0.8

# Number of polygon segments used to approximate the circular perimeter.
CIRCLE_SEGMENTS = 12

# Precomputed sin(π / CIRCLE_SEGMENTS) used for the chord length formula.
# Chord length = 2 * radius * CIRCLE_CHORD_SIN_FACTOR.
CIRCLE_CHORD_SIN_FACTOR = Math.sin(Math.PI / CIRCLE_SEGMENTS)

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

    # Render a circular cross-section with diagonal X infill at a single support node.
    # The shape consists of:
    #   - Outer circle (O): polygon approximation using CIRCLE_SEGMENTS segments
    #   - Inner X fill:     two diagonal lines crossing the center at ±45 degrees
    # The radius scales with nodeType: trunk is largest, branch is medium, twig is smallest.
    renderNodeAt: (slicer, px, py, z, centerOffsetX, centerOffsetY, nozzleDiameter, nodeType, supportLineWidth, supportSpeed, travelSpeed) ->

        # Radius scales with node type so the structure tapers naturally from trunk to twig.
        switch nodeType
            when 'trunk' then halfSize = nozzleDiameter * TRUNK_RADIUS_MULTIPLIER
            when 'branch' then halfSize = nozzleDiameter * BRANCH_RADIUS_MULTIPLIER
            else halfSize = nozzleDiameter * TWIG_RADIUS_MULTIPLIER

        INV_SQRT2 = 1.0 / Math.sqrt(2)

        # Chord length between adjacent polygon vertices (precomputed sin factor).
        chordLength = 2 * halfSize * CIRCLE_CHORD_SIN_FACTOR

        slicer.gcode += coders.codeLinearMovement(
            slicer,
            px + halfSize + centerOffsetX,
            py + centerOffsetY,
            z, null, travelSpeed
        )

        for i in [1..CIRCLE_SEGMENTS]

            angle = i * 2 * Math.PI / CIRCLE_SEGMENTS
            segX = px + halfSize * Math.cos(angle) + centerOffsetX
            segY = py + halfSize * Math.sin(angle) + centerOffsetY

            extrusionDelta = slicer.calculateExtrusion(chordLength, supportLineWidth)
            slicer.cumulativeE += extrusionDelta

            slicer.gcode += coders.codeLinearMovement(
                slicer, segX, segY, z, slicer.cumulativeE, supportSpeed
            )

        # Diagonal X infill arm 1: bottom-left (−45°) → top-right (+135°).
        arm = halfSize * INV_SQRT2

        slicer.gcode += coders.codeLinearMovement(
            slicer,
            px - arm + centerOffsetX,
            py - arm + centerOffsetY,
            z, null, travelSpeed
        )

        extrusionDelta = slicer.calculateExtrusion(halfSize * 2, supportLineWidth)
        slicer.cumulativeE += extrusionDelta

        slicer.gcode += coders.codeLinearMovement(
            slicer,
            px + arm + centerOffsetX,
            py + arm + centerOffsetY,
            z, slicer.cumulativeE, supportSpeed
        )

        # Diagonal X infill arm 2: top-left (+45°) → bottom-right (−135°).
        slicer.gcode += coders.codeLinearMovement(
            slicer,
            px - arm + centerOffsetX,
            py + arm + centerOffsetY,
            z, null, travelSpeed
        )

        extrusionDelta = slicer.calculateExtrusion(halfSize * 2, supportLineWidth)
        slicer.cumulativeE += extrusionDelta

        slicer.gcode += coders.codeLinearMovement(
            slicer,
            px + arm + centerOffsetX,
            py - arm + centerOffsetY,
            z, slicer.cumulativeE, supportSpeed
        )

    # Generate tree-style support G-code for a region at a given layer.
    # Finds the cross-section of every tree segment (trunk, branch, twig) at height Z
    # and renders a circular O+X node at each intersection point:
    #   - Bottom layers: one large trunk node at the centroid (convergence)
    #   - Middle layers: medium branch nodes spreading outward from the trunk
    #   - Top layers: many small twig nodes spread across the overhang contact area
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

                supportPoints.push({ x: px, y: py, type: seg.type })

        # Collapse multiple paths that converge to the same trunk position.
        deduplicated = @deduplicatePoints(supportPoints, nozzleDiameter * 0.5)

        return false if deduplicated.length is 0

        if verbose

            slicer.gcode += "; TYPE: SUPPORT" + slicer.newline

        supportLineWidth = nozzleDiameter * 0.8
        supportSpeed = slicer.getPerimeterSpeed() * 60 * 0.5
        travelSpeed = slicer.getTravelSpeed() * 60

        # Render an O+X node at each support cross-section, sized by node type.
        for point in deduplicated

            @renderNodeAt(
                slicer, point.x, point.y, z,
                centerOffsetX, centerOffsetY,
                nozzleDiameter, point.type, supportLineWidth, supportSpeed, travelSpeed
            )

        return true
