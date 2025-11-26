# Cavity detection module for Polyslice.
# Handles detection of fully covered regions (cavities) that should be excluded from skin infill.

bounds = require('../../utils/bounds')

module.exports =

    # Identify fully covered regions that should be excluded from skin infill.
    # A fully covered area has geometry both above AND below.
    #
    # @param currentPath [Array] The current layer path.
    # @param coveringRegionsAbove [Array] Regions from layer above.
    # @param coveringRegionsBelow [Array] Regions from layer below.
    # @return [Array] Array of fully covered region paths.
    identifyFullyCoveredRegions: (currentPath, coveringRegionsAbove, coveringRegionsBelow) ->

        fullyCoveredRegions = []

        currentPathBounds = bounds.calculatePathBounds(currentPath)

        return fullyCoveredRegions if not currentPathBounds?
        return fullyCoveredRegions if coveringRegionsAbove.length is 0
        return fullyCoveredRegions if coveringRegionsBelow.length is 0

        currentWidth = currentPathBounds.maxX - currentPathBounds.minX
        currentHeight = currentPathBounds.maxY - currentPathBounds.minY
        currentArea = currentWidth * currentHeight

        for regionAbove in coveringRegionsAbove

            continue if regionAbove.length < 3

            boundsAbove = bounds.calculatePathBounds(regionAbove)
            continue unless boundsAbove?

            aboveWidth = boundsAbove.maxX - boundsAbove.minX
            aboveHeight = boundsAbove.maxY - boundsAbove.minY
            aboveArea = aboveWidth * aboveHeight

            for regionBelow in coveringRegionsBelow

                continue if regionBelow.length < 3

                boundsBelow = bounds.calculatePathBounds(regionBelow)
                continue unless boundsBelow?

                belowWidth = boundsBelow.maxX - boundsBelow.minX
                belowHeight = boundsBelow.maxY - boundsBelow.minY
                belowArea = belowWidth * belowHeight

                # Check for overlap between regions.
                overlapMinX = Math.max(boundsAbove.minX, boundsBelow.minX)
                overlapMaxX = Math.min(boundsAbove.maxX, boundsBelow.maxX)
                overlapMinY = Math.max(boundsAbove.minY, boundsBelow.minY)
                overlapMaxY = Math.min(boundsAbove.maxY, boundsBelow.maxY)

                if overlapMinX < overlapMaxX and overlapMinY < overlapMaxY

                    overlapWidth = overlapMaxX - overlapMinX
                    overlapHeight = overlapMaxY - overlapMinY
                    overlapArea = overlapWidth * overlapHeight

                    if aboveArea > 0 and currentArea > 0

                        # Check if overlap is substantial (≥50% of regionAbove).
                        if (overlapArea / aboveArea) >= 0.5

                            aboveRatio = aboveArea / currentArea
                            belowRatio = belowArea / currentArea

                            # Check if at least one region is smaller than current layer (step/transition).
                            if aboveRatio < 0.9 or belowRatio < 0.9

                                smallerArea = Math.min(aboveArea, belowArea)
                                largerArea = Math.max(aboveArea, belowArea)
                                sizeRatio = smallerArea / largerArea

                                # Filter: size ratio 10-55% (excludes tiny holes and similar-sized regions).
                                # Only mark as covered when smaller region is from above.
                                if sizeRatio >= 0.10 and sizeRatio < 0.55 and aboveArea < belowArea

                                    fullyCoveredRegions.push(regionAbove)
                                    break

        return fullyCoveredRegions

    # Filter fully covered regions for skin infill exclusion.
    # Removes regions that are too similar in size to the current path.
    #
    # @param fullyCoveredRegions [Array] Array of fully covered region paths.
    # @param currentPath [Array] The current layer path.
    # @return [Array] Filtered array of fully covered skin wall paths.
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
