# Exposure detection module for Polyslice.
# Handles detection of exposed surfaces that need skin layers.

bounds = require('../../utils/bounds')
paths = require('../../utils/paths')
coverage = require('../../geometry/coverage')
cavity = require('./cavity')

module.exports =

    # Re-export cavity functions for backward compatibility.
    identifyFullyCoveredRegions: cavity.identifyFullyCoveredRegions
    filterFullyCoveredSkinWalls: cavity.filterFullyCoveredSkinWalls

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
