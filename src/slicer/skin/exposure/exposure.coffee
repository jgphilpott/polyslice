# Exposure detection module for Polyslice.

bounds = require('../../utils/bounds')
paths = require('../../utils/paths')
coverage = require('../../geometry/coverage')
cavity = require('./cavity')

module.exports =

    # Re-export cavity functions.
    identifyFullyCoveredRegions: cavity.identifyFullyCoveredRegions
    filterFullyCoveredSkinWalls: cavity.filterFullyCoveredSkinWalls

    # Determine if a hole should generate skin walls based on exposure.
    shouldGenerateHoleSkinWalls: (path, layerIndex, skinLayerCount, totalLayers, allLayers) ->

        return false if not path or path.length < 3
        return false if not allLayers or not Array.isArray(allLayers) or allLayers.length is 0

        holeExposedAbove = @isHoleExposedAbove(path, layerIndex, skinLayerCount, totalLayers, allLayers)
        holeExposedBelow = @isHoleExposedBelow(path, layerIndex, skinLayerCount, allLayers)

        return holeExposedAbove or holeExposedBelow

    # Check if a hole is exposed from above.
    isHoleExposedAbove: (path, layerIndex, skinLayerCount, totalLayers, allLayers) ->

        checkIdxAbove = layerIndex + skinLayerCount

        if checkIdxAbove < totalLayers

            checkSegments = allLayers[checkIdxAbove]

            if checkSegments? and checkSegments.length > 0

                checkPaths = paths.connectSegmentsToPaths(checkSegments)
                holeExistsAbove = coverage.doesHoleExistInLayer(path, checkPaths)

                return not holeExistsAbove

            else

                return true

        else

            return true

    # Check if a hole is exposed from below.
    isHoleExposedBelow: (path, layerIndex, skinLayerCount, allLayers) ->

        checkIdxBelow = layerIndex - skinLayerCount

        if checkIdxBelow >= 0

            checkSegments = allLayers[checkIdxBelow]

            if checkSegments? and checkSegments.length > 0

                checkPaths = paths.connectSegmentsToPaths(checkSegments)
                holeExistsBelow = coverage.doesHoleExistInLayer(path, checkPaths)

                return not holeExistsBelow

            else

                return true

        else

            return true

    # Calculate exposed areas for a path based on covering layers.
    calculateExposedAreasForLayer: (currentPath, layerIndex, skinLayerCount, totalLayers, allLayers, resolution) ->

        exposedAreas = []
        coveringRegionsAbove = []
        coveringRegionsBelow = []

        checkIdxAbove = layerIndex + skinLayerCount

        if checkIdxAbove < totalLayers

            checkSegments = allLayers[checkIdxAbove]

            if checkSegments? and checkSegments.length > 0

                checkPaths = paths.connectSegmentsToPaths(checkSegments)

                coveringRegionsAbove.push(checkPaths...)

                checkExposedAreas = coverage.calculateExposedAreas(currentPath, checkPaths, resolution)

                if checkExposedAreas.length > 0
                    exposedAreas.push(checkExposedAreas...)

            else

                exposedAreas.push(currentPath)

        else

            exposedAreas.push(currentPath)

        checkIdxBelow = layerIndex - skinLayerCount

        if checkIdxBelow >= 0

            checkSegments = allLayers[checkIdxBelow]

            if checkSegments? and checkSegments.length > 0

                checkPaths = paths.connectSegmentsToPaths(checkSegments)

                coveringRegionsBelow.push(checkPaths...)

                checkExposedAreas = coverage.calculateExposedAreas(currentPath, checkPaths, resolution)

                if checkExposedAreas.length > 0

                    exposedAreas.push(checkExposedAreas...)

            else

                exposedAreas.push(currentPath)

        else

            exposedAreas.push(currentPath)

        return {
            exposedAreas: exposedAreas
            coveringRegionsAbove: coveringRegionsAbove
            coveringRegionsBelow: coveringRegionsBelow
        }
