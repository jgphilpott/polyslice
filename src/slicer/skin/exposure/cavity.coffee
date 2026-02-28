# Cavity detection module for Polyslice.

bounds = require('../../utils/bounds')

# Scan regionCandidates against regionRefs and return candidates that qualify as
# fully covered interior regions.  A candidate qualifies when:
# - It is interior to currentPath (does not touch its boundary).
# - It is the smaller of the two paired regions (candidateArea < refArea).
# - A reference region covers ≥50% of its area.
# - The size ratio between the two regions is within the step-transition range (10-55%).
#
# The boundary check is applied to the candidate only.  The reference region may
# legitimately extend to the layer boundary (e.g. the larger slab in an inverted
# pyramid), so it is not subject to the same guard.
findCoveredRegions = (regionCandidates, regionRefs, currentPathBounds, currentArea, BOUNDARY_EPSILON) ->

    covered = []

    for candidate in regionCandidates

        continue if candidate.length < 3

        candidateBounds = bounds.calculatePathBounds(candidate)
        continue unless candidateBounds?

        # Skip candidates that extend to or beyond the current path's boundary.
        # Such regions are structural elements (e.g. arch pillars) that continue
        # from layer to layer, not interior cavity features.
        touchesBoundary = (
            candidateBounds.minX <= currentPathBounds.minX + BOUNDARY_EPSILON or
            candidateBounds.maxX >= currentPathBounds.maxX - BOUNDARY_EPSILON or
            candidateBounds.minY <= currentPathBounds.minY + BOUNDARY_EPSILON or
            candidateBounds.maxY >= currentPathBounds.maxY - BOUNDARY_EPSILON
        )
        continue if touchesBoundary

        candidateWidth = candidateBounds.maxX - candidateBounds.minX
        candidateHeight = candidateBounds.maxY - candidateBounds.minY
        candidateArea = candidateWidth * candidateHeight

        for ref in regionRefs

            continue if ref.length < 3

            refBounds = bounds.calculatePathBounds(ref)
            continue unless refBounds?

            refWidth = refBounds.maxX - refBounds.minX
            refHeight = refBounds.maxY - refBounds.minY
            refArea = refWidth * refHeight

            overlapMinX = Math.max(candidateBounds.minX, refBounds.minX)
            overlapMaxX = Math.min(candidateBounds.maxX, refBounds.maxX)
            overlapMinY = Math.max(candidateBounds.minY, refBounds.minY)
            overlapMaxY = Math.min(candidateBounds.maxY, refBounds.maxY)

            if overlapMinX < overlapMaxX and overlapMinY < overlapMaxY

                overlapWidth = overlapMaxX - overlapMinX
                overlapHeight = overlapMaxY - overlapMinY
                overlapArea = overlapWidth * overlapHeight

                if candidateArea > 0 and currentArea > 0

                    # Check if overlap is substantial (≥50% of candidate).
                    if (overlapArea / candidateArea) >= 0.5

                        candidateRatio = candidateArea / currentArea
                        refRatio = refArea / currentArea

                        # Check if at least one region is smaller than the current layer.
                        if candidateRatio < 0.9 or refRatio < 0.9

                            smallerArea = Math.min(candidateArea, refArea)
                            largerArea = Math.max(candidateArea, refArea)
                            sizeRatio = smallerArea / largerArea

                            # Filter: size ratio 10-55% (excludes tiny holes and similar-sized regions).
                            # Candidate must be the smaller of the two regions.
                            if sizeRatio >= 0.10 and sizeRatio < 0.55 and candidateArea < refArea

                                covered.push(candidate)
                                break

    return covered

module.exports =

    # Identify fully covered regions (have geometry both above AND below).
    identifyFullyCoveredRegions: (currentPath, coveringRegionsAbove, coveringRegionsBelow) ->

        fullyCoveredRegions = []

        currentPathBounds = bounds.calculatePathBounds(currentPath)

        return fullyCoveredRegions if not currentPathBounds?
        return fullyCoveredRegions if coveringRegionsAbove.length is 0
        return fullyCoveredRegions if coveringRegionsBelow.length is 0

        currentWidth = currentPathBounds.maxX - currentPathBounds.minX
        currentHeight = currentPathBounds.maxY - currentPathBounds.minY
        currentArea = currentWidth * currentHeight

        # Tolerance used to determine whether a region touches the current path boundary.
        # Regions that reach the outer boundary are structural elements, not interior cavities.
        BOUNDARY_EPSILON = 0.001

        # Pass 1: candidate from above (normal pyramid - smaller region above the transition).
        aboveCovered = findCoveredRegions(coveringRegionsAbove, coveringRegionsBelow, currentPathBounds, currentArea, BOUNDARY_EPSILON)
        fullyCoveredRegions.push(aboveCovered...)

        # Pass 2: candidate from below (inverted pyramid - smaller region below the transition).
        belowCovered = findCoveredRegions(coveringRegionsBelow, coveringRegionsAbove, currentPathBounds, currentArea, BOUNDARY_EPSILON)
        fullyCoveredRegions.push(belowCovered...)

        return fullyCoveredRegions

    # Filter fully covered regions for skin infill exclusion.
    filterFullyCoveredSkinWalls: (fullyCoveredRegions, currentPath) ->

        fullyCoveredSkinWalls = []

        return fullyCoveredSkinWalls if fullyCoveredRegions.length is 0

        currentPathBounds = bounds.calculatePathBounds(currentPath)

        for fullyCoveredRegion in fullyCoveredRegions

            continue if fullyCoveredRegion.length < 3

            coveredBounds = bounds.calculatePathBounds(fullyCoveredRegion)

            # Skip regions >= 90% of current path (same geometry).
            if currentPathBounds? and coveredBounds?

                currentWidth = currentPathBounds.maxX - currentPathBounds.minX
                currentHeight = currentPathBounds.maxY - currentPathBounds.minY
                coveredWidth = coveredBounds.maxX - coveredBounds.minX
                coveredHeight = coveredBounds.maxY - coveredBounds.minY

                if coveredWidth >= currentWidth * 0.9 and coveredHeight >= currentHeight * 0.9

                    continue

            fullyCoveredSkinWalls.push(fullyCoveredRegion)

        return fullyCoveredSkinWalls
