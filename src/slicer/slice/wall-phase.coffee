# Phase 1: Wall generation and hole boundary collection.

pathsUtils = require('../utils/paths')
wallsModule = require('../walls/walls')
skinModule = require('../skin/skin')

module.exports =

    # Check spacing between paths to determine if inner/skin walls can be generated.
    checkPathSpacing: (paths, allOuterWalls, allInnermostWalls, nozzleDiameter) ->

        pathsWithInsufficientSpacingForInnerWalls = {}
        pathsWithInsufficientSpacingForSkinWalls = {}

        # Check outer wall spacing for inner walls.
        for pathIndex1 in [0...paths.length]

            outerWall1 = allOuterWalls[pathIndex1]
            continue if not outerWall1 or outerWall1.length < 3

            for pathIndex2 in [pathIndex1+1...paths.length]

                outerWall2 = allOuterWalls[pathIndex2]
                continue if not outerWall2 or outerWall2.length < 3

                minDistance = pathsUtils.calculateMinimumDistanceBetweenPaths(outerWall1, outerWall2)

                if minDistance < nozzleDiameter

                    pathsWithInsufficientSpacingForInnerWalls[pathIndex1] = true
                    pathsWithInsufficientSpacingForInnerWalls[pathIndex2] = true

        # Propagate inner wall spacing issues to skin walls.
        for pathIndex in [0...paths.length]

            if pathsWithInsufficientSpacingForInnerWalls[pathIndex]

                pathsWithInsufficientSpacingForSkinWalls[pathIndex] = true

        # Check innermost wall spacing for skin walls.
        for pathIndex1 in [0...paths.length]

            innermostWall1 = allInnermostWalls[pathIndex1]
            continue if not innermostWall1 or innermostWall1.length < 3

            for pathIndex2 in [pathIndex1+1...paths.length]

                innermostWall2 = allInnermostWalls[pathIndex2]
                continue if not innermostWall2 or innermostWall2.length < 3

                minDistance = pathsUtils.calculateMinimumDistanceBetweenPaths(innermostWall1, innermostWall2)

                # Skin walls need 2x nozzle diameter (one from each path).
                skinWallThreshold = nozzleDiameter * 2
                if minDistance < skinWallThreshold

                    pathsWithInsufficientSpacingForSkinWalls[pathIndex1] = true
                    pathsWithInsufficientSpacingForSkinWalls[pathIndex2] = true

        return { pathsWithInsufficientSpacingForInnerWalls, pathsWithInsufficientSpacingForSkinWalls }

    # Calculate innermost wall for a path without generating G-code.
    calculateInnermostWall: (path, pathIndex, isHole, wallCount, nozzleDiameter, pathsWithInsufficientSpacingForInnerWalls) ->

        return null if path.length < 3

        # Create initial offset for the outer wall.
        outerWallOffset = nozzleDiameter / 2
        currentPath = pathsUtils.createInsetPath(path, outerWallOffset, isHole)

        return null if currentPath.length < 3

        for wallIndex in [0...wallCount]

            if wallIndex > 0

                if pathsWithInsufficientSpacingForInnerWalls[pathIndex]
                    break

                testInsetPath = pathsUtils.createInsetPath(currentPath, nozzleDiameter, isHole)

                if testInsetPath.length < 3
                    break

            if wallIndex < wallCount - 1

                insetPath = pathsUtils.createInsetPath(currentPath, nozzleDiameter, isHole)

                break if insetPath.length < 3

                currentPath = insetPath

        return currentPath

    # Pre-calculate all innermost walls.
    calculateAllInnermostWalls: (paths, pathIsHole, wallCount, nozzleDiameter, pathsWithInsufficientSpacingForInnerWalls) ->

        allInnermostWalls = {}

        for path, pathIndex in paths

            innermostWall = @calculateInnermostWall(path, pathIndex, pathIsHole[pathIndex], wallCount, nozzleDiameter, pathsWithInsufficientSpacingForInnerWalls)

            if innermostWall and innermostWall.length >= 3

                allInnermostWalls[pathIndex] = innermostWall

        return allInnermostWalls

    # Generate walls for a single path.
    generateWallsForPath: (slicer, path, pathIndex, isHole, pathNestingLevel, wallCount, nozzleDiameter, z, centerOffsetX, centerOffsetY, layerIndex, pathToHoleIndex, holeOuterWalls, outerBoundaryPath, pathsWithInsufficientSpacingForInnerWalls, generateSkinWalls, holeSkinWalls, holeSkinWallNestingLevels, structureSkinWalls, holeInnerWalls, holeInnerWallNestingLevels, lastPathEndPoint) ->

        return { innermostWall: null, lastPathEndPoint: lastPathEndPoint } if path.length < 3

        # Offset by half nozzle to match design dimensions.
        outerWallOffset = nozzleDiameter / 2
        currentPath = pathsUtils.createInsetPath(path, outerWallOffset, isHole)

        return { innermostWall: null, lastPathEndPoint: lastPathEndPoint } if currentPath.length < 3

        # Generate walls from outer to inner.
        for wallIndex in [0...wallCount]

            if wallIndex is 0
                wallType = "WALL-OUTER"
            else if wallIndex is wallCount - 1
                wallType = "WALL-INNER"
            else
                wallType = "WALL-INNER"

            # Check spacing before generating inner walls.
            if wallIndex > 0

                if pathsWithInsufficientSpacingForInnerWalls[pathIndex] then break

                testInsetPath = pathsUtils.createInsetPath(currentPath, nozzleDiameter, isHole)

                if testInsetPath.length < 3

                    break

            combingStartPoint = lastPathEndPoint

            # Exclude destination hole from combing collision detection.
            excludeDestinationHole = false

            if isHole and pathToHoleIndex[pathIndex]? and lastPathEndPoint?

                if lastPathEndPoint.z is z

                    excludeDestinationHole = true

            if excludeDestinationHole

                currentHoleIdx = pathToHoleIndex[pathIndex]
                combingHoleWalls = holeOuterWalls[0...currentHoleIdx].concat(holeOuterWalls[currentHoleIdx+1...])

            else

                combingHoleWalls = holeOuterWalls

            wallEndPoint = wallsModule.generateWallGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, wallType, combingStartPoint, combingHoleWalls, outerBoundaryPath)

            lastPathEndPoint = wallEndPoint

            if wallIndex < wallCount - 1

                insetPath = pathsUtils.createInsetPath(currentPath, nozzleDiameter, isHole)

                break if insetPath.length < 3

                currentPath = insetPath

        if isHole and currentPath.length >= 3

            holeInnerWalls.push(currentPath)
            holeInnerWallNestingLevels.push(pathNestingLevel[pathIndex])

        # Generate skin walls for holes on skin layers.
        if isHole and generateSkinWalls and currentPath and currentPath.length >= 3

            skinWallInset = nozzleDiameter
            skinWallPath = pathsUtils.createInsetPath(currentPath, skinWallInset, isHole)

            if skinWallPath.length >= 3

                holeSkinWalls.push(skinWallPath)
                holeSkinWallNestingLevels.push(pathNestingLevel[pathIndex]) # Track nesting level

                if pathToHoleIndex[pathIndex]?

                    currentHoleIdx = pathToHoleIndex[pathIndex]
                    skinCombingHoleWalls = holeOuterWalls[0...currentHoleIdx].concat(holeOuterWalls[currentHoleIdx+1...])

                else

                    skinCombingHoleWalls = holeOuterWalls

                skinEndPoint = skinModule.generateSkinGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastPathEndPoint, isHole, false, [], skinCombingHoleWalls, [], false, true)

                lastPathEndPoint = skinEndPoint if skinEndPoint?

        # Generate skin walls for structures on skin layers.
        if not isHole and generateSkinWalls and currentPath and currentPath.length >= 3

            skinWallInset = nozzleDiameter
            skinWallPath = pathsUtils.createInsetPath(currentPath, skinWallInset, isHole)

            if skinWallPath.length >= 3

                structureSkinWalls.push(skinWallPath)

                # Pass currentPath (not skinWallPath) to avoid double offset.
                # generateSkinGCode will create its own inset for the skin wall.
                skinEndPoint = skinModule.generateSkinGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastPathEndPoint, isHole, false, [], holeOuterWalls, [], false, true)

                lastPathEndPoint = skinEndPoint if skinEndPoint?

        return { innermostWall: currentPath, lastPathEndPoint: lastPathEndPoint }
