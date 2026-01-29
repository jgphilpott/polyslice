# Phase 2: Infill and skin generation.

pathsUtils = require('../utils/paths')
infillModule = require('../infill/infill')
skinModule = require('../skin/skin')
exposureModule = require('../skin/exposure/exposure')
coverage = require('../geometry/coverage')
cavityModule = require('../skin/exposure/cavity')

module.exports =

    # Process infill and skin for a single structure (outer boundary).
    processStructureInfillAndSkin: (slicer, path, pathIndex, currentPath, innermostWalls, pathIsHole, pathNestingLevel, z, centerOffsetX, centerOffsetY, layerIndex, skinLayerCount, totalLayers, allLayers, holeInnerWalls, holeInnerWallNestingLevels, holeOuterWalls, holeOuterWallNestingLevels, holeSkinWalls, holeSkinWallNestingLevels, structureSkinWalls, pathsWithInsufficientSpacingForSkinWalls, lastPathEndPoint, filterHolesByNestingLevel) ->

        return lastPathEndPoint if path.length < 3 or pathIsHole[pathIndex]
        return lastPathEndPoint if not currentPath or currentPath.length < 3

        nozzleDiameter = slicer.getNozzleDiameter()
        infillDensity = slicer.getInfillDensity()

        lastWallPoint = lastPathEndPoint or (if currentPath.length > 0 then { x: currentPath[0].x, y: currentPath[0].y, z: z } else null)

        infillBoundary = pathsUtils.createInsetPath(currentPath, nozzleDiameter, pathIsHole[pathIndex])

        # Get nesting level of current structure for hole filtering.
        currentStructureNestingLevel = pathNestingLevel[pathIndex]

        # Filter holes to only include direct children (one level deeper).
        filteredHoleInnerWalls = filterHolesByNestingLevel(holeInnerWalls, holeInnerWallNestingLevels, currentStructureNestingLevel)
        filteredHoleOuterWalls = filterHolesByNestingLevel(holeOuterWalls, holeOuterWallNestingLevels, currentStructureNestingLevel)

        # Determine if this region needs skin.
        needsSkin = false
        skinAreas = []
        isAbsoluteTopOrBottom = false
        skinSuppressedDueToSpacing = false
        coveringRegionsAbove = []
        coveringRegionsBelow = []

        # Generate skin for absolute top and bottom layers.
        if layerIndex < skinLayerCount or layerIndex >= totalLayers - skinLayerCount

            if not pathsWithInsufficientSpacingForSkinWalls[pathIndex]

                needsSkin = true
                skinAreas = [currentPath]
                isAbsoluteTopOrBottom = true

            else

                needsSkin = false
                skinAreas = []
                skinSuppressedDueToSpacing = true

        else

            # For middle layers, use exposure detection if enabled.
            if slicer.getExposureDetection()

                exposureResult = exposureModule.calculateExposedAreasForLayer(
                    currentPath,
                    layerIndex,
                    skinLayerCount,
                    totalLayers,
                    allLayers,
                    slicer.getExposureDetectionResolution()
                )

                if exposureResult

                    skinAreas = exposureResult.exposedAreas or []
                    needsSkin = skinAreas.length > 0
                    coveringRegionsAbove = exposureResult.coveringRegionsAbove or []
                    coveringRegionsBelow = exposureResult.coveringRegionsBelow or []

        # Get all skin walls for this layer (both hole and structure).
        allSkinWalls = holeSkinWalls.concat(structureSkinWalls)

        # Identify fully covered regions that need only skin walls (no skin infill).
        fullyCoveredSkinWalls = []

        if coveringRegionsAbove.length > 0 and coveringRegionsBelow.length > 0

            fullyCoveredSkinWalls = cavityModule.identifyFullyCoveredRegions(currentPath, coveringRegionsAbove, coveringRegionsBelow)

        # Get hole indices for this structure (to check for nesting).
        holeIndices = []

        for holeSkinWall, idx in holeSkinWalls

            holeLevel = if idx < holeSkinWallNestingLevels.length then holeSkinWallNestingLevels[idx] else 0

            if holeLevel is currentStructureNestingLevel + 1

                holeIndices.push(idx)

        # Generate skin and infill based on exposure and coverage.
        if needsSkin

            # For absolute top/bottom layers, generate infill then skin.
            # For middle layers with exposure, handle mixed strategy.
            if isAbsoluteTopOrBottom

                # Generate sparse infill for full region.
                if infillDensity > 0 and infillBoundary.length >= 3

                    infillModule.generateInfillGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, filteredHoleInnerWalls, filteredHoleOuterWalls)

                # Generate skin for each area.
                for skinArea in skinAreas

                    # For nested structures, skin walls were already generated in Phase 1.
                    structureAlreadyHasSkinWall = holeIndices.length > 0
                    shouldGenerateWall = not structureAlreadyHasSkinWall

                    # Skip if skin area is actually inside a hole (for simple cases without nesting).
                    # But for nested structures, we've already generated skin walls in Phase 1,
                    # so we need to generate infill here regardless.
                    if not structureAlreadyHasSkinWall and coverage.isAreaInsideAnyHoleWall(skinArea, holeSkinWalls, holeInnerWalls, holeOuterWalls)

                        continue

                    # Pass generateWall=false if skin wall was already generated in Phase 1.
                    skinModule.generateSkinGCode(slicer, skinArea, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, false, true, allSkinWalls, holeOuterWalls, fullyCoveredSkinWalls, false, shouldGenerateWall)

            else

                # Mixed layers: infill first, then skin.
                if infillDensity > 0 and infillBoundary.length >= 3

                    # Filter skin areas to exclude any that are inside holes before passing to infill generation.
                    # This reconciles two features:
                    # - PR 75: Prevent infill/skin overlap by subtracting skin areas from infill boundaries
                    # - PR 98: Ensure nested structures get infill even when inside skin regions
                    # The solution: Only subtract skin areas that will actually have skin printed.
                    # Skin generation (line 740) skips areas inside holes, so infill should do the same.
                    # This way, infill avoids overlapping with actual skin, but nested structures
                    # (which exist inside holes) still get their own infill in their own loop iterations.
                    skinAreasForInfill = []

                    for skinArea in skinAreas
                        if not coverage.isAreaInsideAnyHoleWall(skinArea, holeSkinWalls, holeInnerWalls, holeOuterWalls)
                            skinAreasForInfill.push(skinArea)

                    infillModule.generateInfillGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, filteredHoleInnerWalls, filteredHoleOuterWalls, skinAreasForInfill)

                # Generate skin for exposed areas.
                for skinArea in skinAreas

                    continue if coverage.isAreaInsideAnyHoleWall(skinArea, holeSkinWalls, holeInnerWalls, holeOuterWalls)

                    # For nested structures with holes, Phase 1 already generated skin walls.
                    # Pass generateWall=false if skin wall was already generated in Phase 1.
                    structureAlreadyHasSkinWall = holeIndices.length > 0
                    shouldGenerateWall = not structureAlreadyHasSkinWall

                    skinModule.generateSkinGCode(slicer, skinArea, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, false, true, allSkinWalls, holeOuterWalls, fullyCoveredSkinWalls, false, shouldGenerateWall)

                # Generate skin walls (no infill) for fully covered regions.
                totalInsetForInfill = nozzleDiameter + (nozzleDiameter / 2)
                fullyCoveredInfillBoundaries = []

                for fullyCoveredSkinWall in fullyCoveredSkinWalls

                    continue if fullyCoveredSkinWall.length < 3

                    continue if coverage.isAreaInsideAnyHoleWall(fullyCoveredSkinWall, holeSkinWalls, holeInnerWalls, holeOuterWalls)

                    skinModule.generateSkinGCode(slicer, fullyCoveredSkinWall, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, false, false, [], holeOuterWalls, [], true, true)

                    if infillDensity > 0

                        coveredInfillBoundary = pathsUtils.createInsetPath(fullyCoveredSkinWall, totalInsetForInfill, false)

                        if coveredInfillBoundary.length >= 3

                            fullyCoveredInfillBoundaries.push(coveredInfillBoundary)

                # Generate regular infill for fully covered regions.
                if fullyCoveredInfillBoundaries.length > 0

                    for coveredInfillBoundary in fullyCoveredInfillBoundaries

                        infillModule.generateInfillGCode(slicer, coveredInfillBoundary, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, [], filteredHoleOuterWalls, [])

        else

            # No skin needed - generate sparse infill only.
            if infillDensity > 0 and infillBoundary.length >= 3 and not skinSuppressedDueToSpacing

                infillModule.generateInfillGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, filteredHoleInnerWalls, filteredHoleOuterWalls)

        return lastPathEndPoint
