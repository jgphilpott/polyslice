# Exposure detection module for Polyslice.
# Handles detection of exposed surfaces that need skin layers.

bounds = require('../../utils/bounds')
paths = require('../../utils/paths')
coverage = require('../../geometry/coverage')

module.exports =

    # Determine if a hole should generate skin walls based on exposure.
    # Returns true if the hole is exposed from above or below (cavity detection).
    #
    # @param path [Array] The hole path to check.
    # @param layerIndex [Number] Current layer index.
    # @param skinLayerCount [Number] Number of skin layers configured.
    # @param totalLayers [Number] Total number of layers.
    # @param allLayers [Array] All layer segments.
    # @return [Boolean] True if skin walls should be generated for this hole.
    shouldGenerateHoleSkinWalls: (path, layerIndex, skinLayerCount, totalLayers, allLayers) ->

        return false if not path or path.length < 3
        return false if not allLayers or not Array.isArray(allLayers) or allLayers.length is 0

        holeExposedAbove = @isHoleExposedAbove(path, layerIndex, skinLayerCount, totalLayers, allLayers)
        holeExposedBelow = @isHoleExposedBelow(path, layerIndex, skinLayerCount, allLayers)

        return holeExposedAbove or holeExposedBelow

    # Check if a hole is exposed from above.
    #
    # @param path [Array] The hole path to check.
    # @param layerIndex [Number] Current layer index.
    # @param skinLayerCount [Number] Number of skin layers configured.
    # @param totalLayers [Number] Total number of layers.
    # @param allLayers [Array] All layer segments.
    # @return [Boolean] True if hole is exposed from above.
    isHoleExposedAbove: (path, layerIndex, skinLayerCount, totalLayers, allLayers) ->

        checkIdxAbove = layerIndex + skinLayerCount

        if checkIdxAbove < totalLayers

            checkSegments = allLayers[checkIdxAbove]

            if checkSegments? and checkSegments.length > 0

                checkPaths = paths.connectSegmentsToPaths(checkSegments)
                holeExistsAbove = coverage.doesHoleExistInLayer(path, checkPaths)

                return not holeExistsAbove

            else

                # No geometry above means hole is exposed from above.
                return true

        else

            # Near top of model - hole is exposed from above.
            return true

    # Check if a hole is exposed from below.
    #
    # @param path [Array] The hole path to check.
    # @param layerIndex [Number] Current layer index.
    # @param skinLayerCount [Number] Number of skin layers configured.
    # @param allLayers [Array] All layer segments.
    # @return [Boolean] True if hole is exposed from below.
    isHoleExposedBelow: (path, layerIndex, skinLayerCount, allLayers) ->

        checkIdxBelow = layerIndex - skinLayerCount

        if checkIdxBelow >= 0

            checkSegments = allLayers[checkIdxBelow]

            if checkSegments? and checkSegments.length > 0

                checkPaths = paths.connectSegmentsToPaths(checkSegments)
                holeExistsBelow = coverage.doesHoleExistInLayer(path, checkPaths)

                return not holeExistsBelow

            else

                # No geometry below means hole is exposed from below.
                return true

        else

            # Near bottom of model - hole is exposed from below.
            return true

    # Calculate exposed areas for a path based on covering layers.
    # Checks both above and below to detect overhangs and cavities.
    #
    # @param currentPath [Array] The current layer path.
    # @param layerIndex [Number] Current layer index.
    # @param skinLayerCount [Number] Number of skin layers configured.
    # @param totalLayers [Number] Total number of layers.
    # @param allLayers [Array] All layer segments.
    # @param resolution [Number] Sample count for exposure detection.
    # @return [Object] Object containing exposedAreas, coveringRegionsAbove, and coveringRegionsBelow.
    calculateExposedAreasForLayer: (currentPath, layerIndex, skinLayerCount, totalLayers, allLayers, resolution) ->

        exposedAreas = []
        coveringRegionsAbove = []
        coveringRegionsBelow = []

        # Check the layer exactly skinLayerCount steps AHEAD (above).
        checkIdxAbove = layerIndex + skinLayerCount

        if checkIdxAbove < totalLayers

            checkSegments = allLayers[checkIdxAbove]

            if checkSegments? and checkSegments.length > 0

                checkPaths = paths.connectSegmentsToPaths(checkSegments)

                # Store covering regions for fully covered area detection.
                coveringRegionsAbove.push(checkPaths...)

                # Calculate exposed areas not covered by layer ahead.
                checkExposedAreas = coverage.calculateExposedAreas(currentPath, checkPaths, resolution)

                if checkExposedAreas.length > 0
                    exposedAreas.push(checkExposedAreas...)

            else

                # No geometry at the layer ahead means current layer is exposed.
                exposedAreas.push(currentPath)

        else

            # We're within skinLayerCount of the top - current layer will be exposed.
            exposedAreas.push(currentPath)

        # Check behind to detect cavities and holes.
        checkIdxBelow = layerIndex - skinLayerCount

        if checkIdxBelow >= 0

            checkSegments = allLayers[checkIdxBelow]

            if checkSegments? and checkSegments.length > 0

                checkPaths = paths.connectSegmentsToPaths(checkSegments)

                # Store covering regions for fully covered area detection.
                coveringRegionsBelow.push(checkPaths...)

                # Calculate exposed areas not covered by layer behind.
                checkExposedAreas = coverage.calculateExposedAreas(currentPath, checkPaths, resolution)

                if checkExposedAreas.length > 0
                    exposedAreas.push(checkExposedAreas...)

            else

                # No geometry at the layer behind means current layer is exposed.
                exposedAreas.push(currentPath)

        else

            # We're within skinLayerCount of the bottom - current layer will be exposed.
            exposedAreas.push(currentPath)

        return {
            exposedAreas: exposedAreas
            coveringRegionsAbove: coveringRegionsAbove
            coveringRegionsBelow: coveringRegionsBelow
        }

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
