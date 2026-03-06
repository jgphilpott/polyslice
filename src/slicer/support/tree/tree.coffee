# Tree support generation module.
# Generates anatomically-correct tree supports that grow upward from a single trunk,
# splitting into branches and fine twig tips that contact the overhang surface.
# The structure converges as it descends toward the build plate:
#   - Many fine twig tips spread across the overhang area (top)
#   - Twig tips merge into branch nodes at approximately 45-degree angles
#   - Branches converge to a single vertical trunk column (middle)
#   - Roots spread outward and downward from the trunk base (bottom)

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
# Roots are slightly wider than branches to provide a stable base footprint.
TRUNK_RADIUS_MULTIPLIER = 3.0
ROOT_RADIUS_MULTIPLIER = 2.0
BRANCH_RADIUS_MULTIPLIER = 1.8
TWIG_RADIUS_MULTIPLIER = 0.8

# Number of polygon segments used to approximate the circular perimeter.
CIRCLE_SEGMENTS = 12

# Precomputed sin(π / CIRCLE_SEGMENTS) used for the chord length formula.
# Chord length = 2 * radius * CIRCLE_CHORD_SIN_FACTOR.
CIRCLE_CHORD_SIN_FACTOR = Math.sin(Math.PI / CIRCLE_SEGMENTS)

# Number of layers by which each twig overlaps its parent branch.
# Twigs start this many layers below the branch endpoint so that branch and twig
# material are printed at the same Z level, physically bonding the joint.
TWIG_OVERLAP_LAYERS = 1

# Number of root segments spread radially outward and downward from the trunk base.
# Roots connect the trunk to the build plate at multiple XY positions, increasing
# the base footprint and improving the structural stability of the tree support.
ROOT_COUNT = 4

# Fractional distances (as multiples of rootHeight) sampled along each root ray
# when checking for solid geometry in 'everywhere' mode.
# Sampling from 0.5× to 2× rootHeight detects curved surfaces (e.g. dome walls)
# that lie further from the trunk than the root base point itself.
ROOT_RAY_SAMPLE_FRACTIONS = [0.5, 1.0, 1.5, 2.0]

# |sin| or |cos| threshold below which an angle is considered axis-aligned.
# Used in findAccessibleTrunkPosition to skip angles already covered by the
# explicit ±X / ±Y axis checks.
AXIS_ANGLE_THRESHOLD = 0.15

module.exports =

    TWIG_OVERLAP_LAYERS: TWIG_OVERLAP_LAYERS
    TRUNK_RADIUS_MULTIPLIER: TRUNK_RADIUS_MULTIPLIER
    ROOT_COUNT: ROOT_COUNT
    ROOT_RADIUS_MULTIPLIER: ROOT_RADIUS_MULTIPLIER
    ROOT_RAY_SAMPLE_FRACTIONS: ROOT_RAY_SAMPLE_FRACTIONS
    CONTACT_SPACING_MULTIPLIER: CONTACT_SPACING_MULTIPLIER
    BRANCH_CLUSTER_SIZE: BRANCH_CLUSTER_SIZE

    # Check if a trunk at (trunkX, trunkY) is accessible from the build plate.
    # Only checks layers at Z <= maxZ so that solid geometry above the trunk top
    # (e.g. the arch cap above an upright arch cavity) does not falsely block an
    # otherwise clear trunk path.
    # Returns true if no relevant layer has solid geometry at this XY position.
    isTrunkAccessible: (trunkX, trunkY, layerSolidRegions, maxZ = Infinity) ->

        point = { x: trunkX, y: trunkY }

        for layerData in layerSolidRegions

            continue if layerData.z > maxZ

            if normalSupportModule.isPointInsideSolidGeometry(point, layerData.paths, layerData.pathIsHole)

                return false

        return true

    # Find the nearest accessible trunk position for 'buildPlate' tree support.
    # Searches outward from the ideal centroid (cx, cy) until a position is found
    # that is clear of solid geometry at every layer up to maxZ.
    # Axis-aligned directions (±X then ±Y) are tried first at each ring so that
    # the result stays as centred as possible (e.g. same Y as the centroid when
    # the arch body only blocks the X axis).
    # clearance adds a safety margin: the centre and four cardinal boundary points
    # of a circle of that radius must all be outside solid geometry, preventing the
    # trunk cross-section circle from overlapping arch walls.
    # Returns { x, y } or null if none found within the search radius.
    findAccessibleTrunkPosition: (cx, cy, layerSolidRegions, searchStep, maxSearchRadius, maxZ = Infinity, clearance = 0) ->

        # Build solid footprint bounding box from relevant layers for fast pre-check.
        # Any position outside this bounding box is guaranteed to be accessible.
        fpMinX = Infinity
        fpMaxX = -Infinity
        fpMinY = Infinity
        fpMaxY = -Infinity

        for layerData in layerSolidRegions

            continue if layerData.z > maxZ

            for path in layerData.paths

                for point in path

                    fpMinX = Math.min(fpMinX, point.x)
                    fpMaxX = Math.max(fpMaxX, point.x)
                    fpMinY = Math.min(fpMinY, point.y)
                    fpMaxY = Math.max(fpMaxY, point.y)

        isAccessible = (x, y) ->

            # Collect the centre point plus four cardinal clearance points.
            checkPoints = [{ x, y }]

            if clearance > 0

                for i in [0...4]

                    angle = i * Math.PI / 2
                    checkPoints.push({
                        x: x + clearance * Math.cos(angle)
                        y: y + clearance * Math.sin(angle)
                    })

            for checkPoint in checkPoints

                # Quick bounding box pre-check: any point outside the solid geometry
                # bounding box is guaranteed to be outside every solid polygon.
                continue if checkPoint.x < fpMinX or checkPoint.x > fpMaxX or
                             checkPoint.y < fpMinY or checkPoint.y > fpMaxY

                for layerData in layerSolidRegions

                    continue if layerData.z > maxZ

                    if normalSupportModule.isPointInsideSolidGeometry(checkPoint, layerData.paths, layerData.pathIsHole)

                        return false

            return true

        # Check the centroid itself first.
        return { x: cx, y: cy } if isAccessible(cx, cy)

        # Expanding search: try axis-aligned directions first at each ring radius.
        # ±X first preserves the centroid Y (centering in Y); ±Y next preserves X;
        # then diagonal angles for remaining directions.
        radius = searchStep

        while radius <= maxSearchRadius

            # ±X: same Y as centroid (Y-centred result).
            return { x: cx + radius, y: cy } if isAccessible(cx + radius, cy)
            return { x: cx - radius, y: cy } if isAccessible(cx - radius, cy)

            # ±Y: same X as centroid (X-centred result).
            return { x: cx, y: cy + radius } if isAccessible(cx, cy + radius)
            return { x: cx, y: cy - radius } if isAccessible(cx, cy - radius)

            # Diagonal directions (45° increments, skipping the axis angles).
            numAngles = Math.max(8, Math.ceil(2 * Math.PI * radius / searchStep))

            for i in [0...numAngles]

                angle = i * 2 * Math.PI / numAngles

                # Skip angles close to 0°, 90°, 180°, 270° (already tried above).
                sinA = Math.abs(Math.sin(angle))
                cosA = Math.abs(Math.cos(angle))
                continue if sinA < AXIS_ANGLE_THRESHOLD or cosA < AXIS_ANGLE_THRESHOLD

                candidateX = cx + radius * Math.cos(angle)
                candidateY = cy + radius * Math.sin(angle)

                return { x: candidateX, y: candidateY } if isAccessible(candidateX, candidateY)

            radius += searchStep

        return null

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

    # Build the tree segment structure for a support region.
    # Pre-computes trunk, branch, and twig line segments from build plate to overhang.
    # Segments are cached on the region object so they are computed only once per slice.
    # Root segments are generated dynamically in generateTreePattern based on the
    # effective trunk base (first printable trunk layer) and are not included here.
    # Optional trunkXOverride / trunkYOverride place the trunk at a specific XY position
    # instead of the tip centroid; used when the centroid is inaccessible from the build plate.
    # Returns an array of {x1, y1, z1, x2, y2, z2, type} segment objects.
    buildTreeStructure: (region, nozzleDiameter, buildPlateZ, layerHeight, trunkXOverride = null, trunkYOverride = null) ->

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

        # Compute the trunk base position: centroid of all contact tips in XY,
        # or use the override coordinates if provided (e.g. when the centroid is
        # blocked from the build plate and an accessible position was found nearby).
        if trunkXOverride? and trunkYOverride?

            trunkX = trunkXOverride
            trunkY = trunkYOverride

        else

            trunkX = 0
            trunkY = 0

            for tip in tips

                trunkX += tip.x
                trunkY += tip.y

            trunkX /= tips.length
            trunkY /= tips.length

        # Cluster tips into branch groups using a grid anchored to the region's own minX/minY.
        # Using floor((tip - min) / spacing) keeps cell boundaries region-local so clustering
        # is stable regardless of the model's absolute position on the build plate.
        clusterSpacing = contactSpacing * BRANCH_CLUSTER_SIZE
        clusterMap = {}

        for tip in tips

            cellX = Math.floor((tip.x - minX) / clusterSpacing)
            cellY = Math.floor((tip.y - minY) / clusterSpacing)
            key = "#{cellX},#{cellY}"
            clusterMap[key] ?= []
            clusterMap[key].push(tip)

        # Build branch nodes from cluster centroids.
        branchNodes = []

        for key, clusterTips of clusterMap

            cx = 0
            cy = 0

            for tip in clusterTips

                cx += tip.x
                cy += tip.y

            cx /= clusterTips.length
            cy /= clusterTips.length

            # Compute the branch node Z from the 45-degree constraint applied to each tip.
            # nodeZ = min(tip.z - tdist) guarantees every twig rises at ≤ 45 degrees from
            # the branch endpoint to its contact tip, eliminating orphaned twig segments.
            nodeZ = Infinity

            for tip in clusterTips

                tdx = tip.x - cx
                tdy = tip.y - cy
                tdist = Math.sqrt(tdx * tdx + tdy * tdy)
                nodeZ = Math.min(nodeZ, tip.z - tdist)

            nodeZ = Math.max(nodeZ, buildPlateZ + layerHeight)

            # Round to 0.1 µm to avoid floating-point edge cases in the twig-emission
            # condition (node.z < tip.z - layerHeight) when large absolute coordinates
            # accumulate tiny rounding errors that differ from small-coordinate equivalents.
            nodeZ = Math.round(nodeZ * 10000) / 10000

            branchNodes.push({ x: cx, y: cy, z: nodeZ, tips: clusterTips })

        # Compute branch root heights: where each branch diverges from the shared trunk.
        # The ideal root height is determined by the 45° angle constraint
        # (vertical rise = horizontal spread from trunk to branch centroid).
        # Root Z is clamped to the first printable layer above the build plate;
        # the clamp may reduce the effective angle below 45° for wide or low overhangs.
        branchRootZs = []

        for node in branchNodes

            dx = node.x - trunkX
            dy = node.y - trunkY
            dist = Math.sqrt(dx * dx + dy * dy)

            idealZ = node.z - dist
            branchRootZs.push(Math.max(idealZ, buildPlateZ + layerHeight))

        # Single shared trunk segment: vertical column from build plate to the highest
        # branch split point.  One segment (rather than one per branch) avoids duplicate
        # overlapping trunk renders at the same trunk XY on every layer.
        trunkTopZ = buildPlateZ + layerHeight

        for bz in branchRootZs

            trunkTopZ = Math.max(trunkTopZ, bz)

        segments = [{
            x1: trunkX, y1: trunkY, z1: buildPlateZ
            x2: trunkX, y2: trunkY, z2: trunkTopZ
            type: 'trunk'
        }]

        for nodeIdx in [0...branchNodes.length]

            node = branchNodes[nodeIdx]
            branchRootZ = branchRootZs[nodeIdx]

            # Guarantee the branch spans at least one printable layer.
            # When nodeZ was clamped to buildPlateZ + layerHeight and branchRootZ was also
            # clamped to the same value, the branch segment collapses to zero height and
            # never intersects any layer Z plane.  Nudging node.z up by layerHeight ensures
            # a non-zero segment without changing the already-computed branchRootZ.
            node.z = Math.max(node.z, Math.round((branchRootZ + layerHeight) * 10000) / 10000)

            # Branch segment: angled from trunk toward the branch node.
            segments.push({
                x1: trunkX, y1: trunkY, z1: branchRootZ
                x2: node.x, y2: node.y, z2: node.z
                type: 'branch'
            })

            # Twig segments: fine sub-branches from cluster node to individual contact tips.
            # Twigs start TWIG_OVERLAP_LAYERS below the branch endpoint so that both the
            # branch (nearing its end) and the twig (at its root) are printed at the same Z,
            # creating a physical bond that strengthens the twig/branch joint.
            # Floor is branchRootZ (not buildPlateZ) so twigs never start below the branch.
            twigStartZ = Math.max(node.z - TWIG_OVERLAP_LAYERS * layerHeight, branchRootZ)

            for tip in node.tips

                if twigStartZ < tip.z - layerHeight

                    segments.push({
                        x1: node.x, y1: node.y, z1: twigStartZ
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
    # The radius scales with nodeType: trunk is largest, roots and branches are medium, twig is smallest.
    renderNodeAt: (slicer, px, py, z, centerOffsetX, centerOffsetY, nozzleDiameter, nodeType, supportLineWidth, supportSpeed, travelSpeed) ->

        # Radius scales with node type so the structure tapers naturally from trunk to twig.
        switch nodeType
            when 'trunk' then halfSize = nozzleDiameter * TRUNK_RADIUS_MULTIPLIER
            when 'root' then halfSize = nozzleDiameter * ROOT_RADIUS_MULTIPLIER
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
    #   - Bottom layers: trunk node plus root nodes spreading outward from the effective base
    #   - Middle layers: medium branch nodes spreading outward from the trunk
    #   - Top layers: many small twig nodes spread across the overhang contact area
    # Roots are generated dynamically based on region._effectiveTrunkBaseZ, which is set
    # to the first layer Z at which the trunk actually prints (handling floating trunks).
    # Returns true if any G-code was emitted, false otherwise.
    generateTreePattern: (slicer, region, z, layerIndex, centerOffsetX, centerOffsetY, nozzleDiameter, layerSolidRegions, supportPlacement, minZ, layerHeight) ->

        verbose = slicer.getVerbose()

        # Build tree structure once per region per slice (cached on the region object).
        if not region._treeSegments?

            region._treeSegments = @buildTreeStructure(region, nozzleDiameter, minZ, layerHeight)

            # For 'buildPlate' tree support: if the computed trunk centroid is not accessible
            # from the build plate (blocked by solid geometry at some lower layer), search for
            # a nearby accessible trunk position and rebuild the tree from there.
            # This enables branches that start from an accessible trunk to reach overhang areas
            # that solid walls would otherwise block from direct vertical access.
            if supportPlacement is 'buildPlate' and region._treeSegments.length > 0 and layerSolidRegions.length > 0

                trunkSeg = region._treeSegments.find (s) -> s.type is 'trunk'

                if trunkSeg? and not @isTrunkAccessible(trunkSeg.x1, trunkSeg.y1, layerSolidRegions, trunkSeg.z2)

                    contactSpacing = nozzleDiameter * CONTACT_SPACING_MULTIPLIER
                    maxSearchRadius = Math.max(60, region.maxZ - minZ)
                    trunkClearance = nozzleDiameter * TRUNK_RADIUS_MULTIPLIER

                    accessibleTrunk = @findAccessibleTrunkPosition(
                        trunkSeg.x1, trunkSeg.y1,
                        layerSolidRegions, contactSpacing, maxSearchRadius,
                        trunkSeg.z2, trunkClearance
                    )

                    if accessibleTrunk?

                        region._treeSegments = @buildTreeStructure(
                            region, nozzleDiameter, minZ, layerHeight,
                            accessibleTrunk.x, accessibleTrunk.y
                        )

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

            # Use the appropriate collision check based on support placement and segment type.
            # For 'buildPlate' tree support, trunk segments use the strict cumulative check
            # (clear vertical path from build plate), while branch and twig segments use a
            # relaxed current-layer check.  This allows branches from an accessible trunk to
            # enter overhang cavities that become accessible at higher Z, even if the same XY
            # position was inside solid geometry at lower layers.
            if supportPlacement is 'buildPlate' and seg.type isnt 'trunk'

                currentLayerData = layerSolidRegions[layerIndex]

                isAccessible = if currentLayerData?
                    not normalSupportModule.isPointInsideSolidGeometry(
                        { x: px, y: py }, currentLayerData.paths, currentLayerData.pathIsHole
                    )
                else
                    true

            else

                isAccessible = normalSupportModule.canGenerateSupportAt(
                    slicer, { x: px, y: py }, z,
                    layerSolidRegions, supportPlacement, minZ, layerHeight, layerIndex
                )

            supportPoints.push({ x: px, y: py, type: seg.type }) if isAccessible

        # Track the lowest Z at which the trunk actually prints.
        # This gives the effective base for root placement even when the trunk starts
        # above the physical build plate (e.g., 'everywhere' mode on an arch print).
        trunkPrinted = supportPoints.some (p) -> p.type is 'trunk'

        if trunkPrinted and (not region._effectiveTrunkBaseZ? or z < region._effectiveTrunkBaseZ)

            region._effectiveTrunkBaseZ = z

        # Generate root cross-sections dynamically from the effective trunk base.
        # Roots spread radially outward at the base (spread = rootHeight for 45° angle)
        # and converge back to the trunk XY over the rootHeight vertical range.
        if region._effectiveTrunkBaseZ?

            trunkSeg = segments.find (s) -> s.type is 'trunk'

            if trunkSeg?

                trunkX = trunkSeg.x1
                trunkY = trunkSeg.y1

                contactSpacing = nozzleDiameter * CONTACT_SPACING_MULTIPLIER
                trunkHeight = Math.abs(trunkSeg.z2 - trunkSeg.z1)
                rootSpread = Math.min(contactSpacing * BRANCH_CLUSTER_SIZE, trunkHeight)
                effectiveBaseZ = region._effectiveTrunkBaseZ
                # rootHeight equals rootSpread/2; roots spread by rootHeight horizontally
                # so horizontal == vertical, giving exactly a 45-degree outward angle.
                rootHeight = rootSpread * 0.5
                rootTopZ = effectiveBaseZ + rootHeight

                if z >= effectiveBaseZ and z <= rootTopZ and rootHeight >= layerHeight

                    # Pre-compute which roots are actually supported on first visit.
                    # A root is valid only if its spread direction leads toward a solid
                    # surface in 'everywhere' mode — this eliminates hanging roots that
                    # point into empty space beyond the edge of the surface the trunk
                    # rests on.
                    if not region._validRootIndices?

                        region._validRootIndices = []

                        # Pre-filter: only layers at or below effectiveBaseZ within the
                        # rootHeight window.  This avoids iterating all layers on tall
                        # prints for every root × sampleFraction combination.
                        relevantLayers = layerSolidRegions.filter (ld) ->
                            ld.z <= effectiveBaseZ and (effectiveBaseZ - ld.z) <= rootHeight

                        for i in [0...ROOT_COUNT]

                            angle = i * 2 * Math.PI / ROOT_COUNT

                            rootIsSupported = true

                            if supportPlacement is 'everywhere'

                                # Cast a ray in the root direction and sample multiple
                                # distances (0.5× to 2× rootHeight) to detect nearby solid
                                # surfaces such as the interior of a curved dome.
                                # A root is "hanging" only if NO solid geometry is found at
                                # ANY sample distance within rootHeight layers of effectiveBaseZ.
                                rootIsSupported = false

                                foundSolid = false

                                for sampleFraction in ROOT_RAY_SAMPLE_FRACTIONS

                                    break if foundSolid

                                    sampleX = trunkX + rootHeight * sampleFraction * Math.cos(angle)
                                    sampleY = trunkY + rootHeight * sampleFraction * Math.sin(angle)
                                    samplePoint = { x: sampleX, y: sampleY }

                                    for layerData in relevantLayers

                                        if normalSupportModule.isPointInsideSolidGeometry(
                                            samplePoint, layerData.paths, layerData.pathIsHole
                                        )

                                            foundSolid = true
                                            break

                                rootIsSupported = foundSolid

                            region._validRootIndices.push(i) if rootIsSupported

                    # Linear interpolation: t=0 at effective base (roots at full spread),
                    # t=1 at rootTopZ (roots converged back to trunk XY).
                    t = (z - effectiveBaseZ) / rootHeight

                    for i in region._validRootIndices

                        angle = i * 2 * Math.PI / ROOT_COUNT
                        # Spread equals rootHeight for a 45-degree outward angle.
                        rootEndX = trunkX + rootHeight * Math.cos(angle)
                        rootEndY = trunkY + rootHeight * Math.sin(angle)

                        # Interpolate from spread XY (base) toward trunk XY (top).
                        rootX = rootEndX + t * (trunkX - rootEndX)
                        rootY = rootEndY + t * (trunkY - rootEndY)

                        if normalSupportModule.canGenerateSupportAt(
                            slicer, { x: rootX, y: rootY }, z,
                            layerSolidRegions, supportPlacement, minZ, layerHeight, layerIndex
                        )

                            supportPoints.push({ x: rootX, y: rootY, type: 'root' })

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
