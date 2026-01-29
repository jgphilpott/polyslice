# Layer orchestration - coordinates Phase 1 (walls) and Phase 2 (infill/skin).

pathsUtils = require('../utils/paths')
exposureModule = require('../skin/exposure/exposure')
helpers = require('./helpers')
wallPhase = require('./wall-phase')
infillSkinPhase = require('./infill-skin-phase')

module.exports =

    # Generate G-code for a single layer.
    generateLayerGCode: (slicer, paths, z, layerIndex, centerOffsetX = 0, centerOffsetY = 0, totalLayers = 0, allLayers = [], layerSegments = []) ->

        return if paths.length is 0

        verbose = slicer.getVerbose()

        # Initialize cumulative extrusion tracker if not exists.
        if not slicer.cumulativeE? then slicer.cumulativeE = 0

        layerHeight = slicer.getLayerHeight()
        nozzleDiameter = slicer.getNozzleDiameter()
        shellWallThickness = slicer.getShellWallThickness()
        shellSkinThickness = slicer.getShellSkinThickness()

        # Calculate number of walls based on shell wall thickness and nozzle diameter.
        # Each wall is approximately as wide as the nozzle diameter (it squishes to ~1x nozzle diameter).
        # Round down to get integer wall count.
        # Add small epsilon to handle floating point precision issues (e.g., 1.2/0.4 = 2.9999... should be 3).
        wallCount = Math.max(1, Math.floor((shellWallThickness / nozzleDiameter) + 0.0001))

        # Calculate number of skin layers (top and bottom solid layers).
        skinLayerCount = Math.max(1, Math.floor((shellSkinThickness / layerHeight) + 0.0001))

        # Detect nesting levels for all paths to handle nested holes/structures.
        nestingResult = helpers.detectNesting(paths)
        pathNestingLevel = nestingResult.pathNestingLevel
        pathIsHole = nestingResult.pathIsHole

        # Phase 1: Generate walls and collect hole boundaries.
        # We must complete this phase BEFORE generating infill, so that hole boundaries
        # are available when processing outer boundaries.
        holeInnerWalls = []  # Inner wall paths of holes (for regular infill clipping).
        holeOuterWalls = []  # Outer wall paths of holes (for travel path optimization).
        holeSkinWalls = []   # Skin wall paths of holes (for skin infill clipping).
        structureSkinWalls = []  # Skin wall paths of structures (for skin infill clipping).
        innermostWalls = []

        # Track nesting levels for holes to filter exclusion zones.
        # Key: hole index in holeOuterWalls/holeInnerWalls/holeSkinWalls, Value: nesting level
        holeOuterWallNestingLevels = []
        holeInnerWallNestingLevels = []
        holeSkinWallNestingLevels = []

        # Track last end point for travel path combing.
        lastPathEndPoint = slicer.lastLayerEndPoint

        # Initialize starting position to home position (0, 0) on build plate if this is the first layer.
        # Convert home position from build plate coordinates to mesh coordinates using center offsets.
        # This ensures nearest-neighbor sorting starts from the printer's home position.
        if not lastPathEndPoint

            lastPathEndPoint = {
                x: 0 - centerOffsetX # Home (0, 0) on build plate in mesh coordinates
                y: 0 - centerOffsetY
                z: z
            }

        outerBoundaryPath = null

        # Pre-pass: Collect all hole outer walls for combing path calculation.
        pathToHoleIndex = {}
        allOuterWalls = {}

        for path, pathIndex in paths

            continue if path.length < 3

            outerWallOffset = nozzleDiameter / 2
            currentPath = pathsUtils.createInsetPath(path, outerWallOffset, pathIsHole[pathIndex])

            continue if currentPath.length < 3

            allOuterWalls[pathIndex] = currentPath

            if pathIsHole[pathIndex]

                pathToHoleIndex[pathIndex] = holeOuterWalls.length
                holeOuterWalls.push(currentPath)
                holeOuterWallNestingLevels.push(pathNestingLevel[pathIndex])

            else

                outerBoundaryPath = path

        # Identify paths that are too close for inner/skin walls.
        pathsWithInsufficientSpacingForInnerWalls = {}
        pathsWithInsufficientSpacingForSkinWalls = {}

        # Pre-calculate all innermost walls (needed for spacing checks).
        allInnermostWalls = {}

        for path, pathIndex in paths

            innermostWall = wallPhase.calculateInnermostWall(path, pathIndex, pathIsHole[pathIndex], wallCount, nozzleDiameter, {})

            if innermostWall and innermostWall.length >= 3

                allInnermostWalls[pathIndex] = innermostWall

        # Check spacing between paths.
        spacingResult = wallPhase.checkPathSpacing(paths, allOuterWalls, allInnermostWalls, nozzleDiameter)
        pathsWithInsufficientSpacingForInnerWalls = spacingResult.pathsWithInsufficientSpacingForInnerWalls
        pathsWithInsufficientSpacingForSkinWalls = spacingResult.pathsWithInsufficientSpacingForSkinWalls

        innermostWalls = new Array(paths.length)

        outerBoundaryIndices = []
        holeIndices = []

        for pathIndex in [0...paths.length]

            if pathIsHole[pathIndex]
                holeIndices.push(pathIndex)
            else
                outerBoundaryIndices.push(pathIndex)

        # Determine if this layer needs skin (top/bottom or with exposure detection).
        layerNeedsSkin = layerIndex < skinLayerCount or layerIndex >= totalLayers - skinLayerCount or slicer.getExposureDetection()

        # Sort outer boundaries by nearest neighbor to minimize travel.
        sortedOuterBoundaryIndices = helpers.sortByNearestNeighbor(outerBoundaryIndices, paths, lastPathEndPoint)

        # Process outer boundaries in nearest-neighbor order.
        # Track which objects have been completed (for independent objects only).
        completedObjectIndices = {}

        # Calculate if this layer is absolute top or bottom (used multiple times below).
        isAbsoluteTopOrBottom = layerIndex < skinLayerCount or layerIndex >= totalLayers - skinLayerCount

        for pathIndex in sortedOuterBoundaryIndices

            path = paths[pathIndex]

            # Determine if skin walls should be generated for this structure.
            shouldGenerateSkinWalls = false

            if layerNeedsSkin and not pathsWithInsufficientSpacingForSkinWalls[pathIndex]

                if isAbsoluteTopOrBottom

                    # Only generate structure skin walls in Phase 1 if there are holes on this layer.
                    # For simple structures without holes, Phase 2 will handle skin (wall + infill).
                    # For nested structures with holes, Phase 1 generates walls for all paths to seal them.
                    if holeIndices.length > 0

                        shouldGenerateSkinWalls = true

                else if slicer.getExposureDetection()

                    # For middle layers with exposure detection, only generate skin walls if exposed.
                    if allLayers and allLayers.length > 0

                        exposureResult = exposureModule.calculateExposedAreasForLayer(
                            path,
                            layerIndex,
                            skinLayerCount,
                            totalLayers,
                            allLayers,
                            slicer.getExposureDetectionResolution()
                        )

                        if exposureResult and exposureResult.exposedAreas and exposureResult.exposedAreas.length > 0

                            shouldGenerateSkinWalls = true

            # Generate walls for this path.
            result = wallPhase.generateWallsForPath(slicer, path, pathIndex, pathIsHole[pathIndex], pathNestingLevel, wallCount, nozzleDiameter, z, centerOffsetX, centerOffsetY, layerIndex, pathToHoleIndex, holeOuterWalls, outerBoundaryPath, pathsWithInsufficientSpacingForInnerWalls, shouldGenerateSkinWalls, holeSkinWalls, holeSkinWallNestingLevels, structureSkinWalls, holeInnerWalls, holeInnerWallNestingLevels, lastPathEndPoint)

            innermostWalls[pathIndex] = result.innermostWall
            lastPathEndPoint = result.lastPathEndPoint

            # For independent objects (no holes, no exposure detection), complete immediately.
            if not slicer.getExposureDetection() and holeIndices.length is 0

                # Generate infill and skin for this object right away.
                currentPath = innermostWalls[pathIndex]

                if currentPath and currentPath.length >= 3

                    infillDensity = slicer.getInfillDensity()
                    lastWallPoint = lastPathEndPoint or (if currentPath.length > 0 then { x: currentPath[0].x, y: currentPath[0].y, z: z } else null)
                    infillBoundary = pathsUtils.createInsetPath(currentPath, nozzleDiameter, pathIsHole[pathIndex])

                    needsSkin = isAbsoluteTopOrBottom and not pathsWithInsufficientSpacingForSkinWalls[pathIndex]

                    if needsSkin

                        # Generate sparse infill then skin.
                        if infillDensity > 0 and infillBoundary.length >= 3

                            infillModule = require('../infill/infill')
                            infillModule.generateInfillGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, [], [])

                        # Generate skin.
                        skinModule = require('../skin/skin')
                        skinModule.generateSkinGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, false, true, [], [], [], false, true)

                    else

                        # No skin needed - generate sparse infill only.
                        if infillDensity > 0 and infillBoundary.length >= 3

                            infillModule = require('../infill/infill')
                            infillModule.generateInfillGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, [], [])

                    completedObjectIndices[pathIndex] = true

        # Sort holes by nearest neighbor to minimize travel.
        sortedHoleIndices = helpers.sortByNearestNeighbor(holeIndices, paths, lastPathEndPoint)

        # Process holes in sorted order with skin walls if needed.
        for pathIndex in sortedHoleIndices

            path = paths[pathIndex]

            # Determine if skin walls should be generated for this hole.
            shouldGenerateSkinWalls = false

            if layerNeedsSkin and not pathsWithInsufficientSpacingForSkinWalls[pathIndex]

                isAbsoluteTopOrBottom = layerIndex < skinLayerCount or layerIndex >= totalLayers - skinLayerCount

                if isAbsoluteTopOrBottom

                    shouldGenerateSkinWalls = true

                else if slicer.getExposureDetection()

                    shouldGenerateSkinWalls = exposureModule.shouldGenerateHoleSkinWalls(path, layerIndex, skinLayerCount, totalLayers, allLayers)

            result = wallPhase.generateWallsForPath(slicer, path, pathIndex, true, pathNestingLevel, wallCount, nozzleDiameter, z, centerOffsetX, centerOffsetY, layerIndex, pathToHoleIndex, holeOuterWalls, outerBoundaryPath, pathsWithInsufficientSpacingForInnerWalls, shouldGenerateSkinWalls, holeSkinWalls, holeSkinWallNestingLevels, structureSkinWalls, holeInnerWalls, holeInnerWallNestingLevels, lastPathEndPoint)

            innermostWalls[pathIndex] = result.innermostWall
            lastPathEndPoint = result.lastPathEndPoint

        # Helper function to filter holes by nesting level.
        # For a structure at nesting level N, only include holes at level N+1 (direct children).
        # This prevents nested structures from being excluded by holes at higher levels.
        filterHolesByNestingLevel = (holeWalls, holeNestingLevels, structureNestingLevel) =>

            return helpers.filterHolesByNestingLevel(holeWalls, holeNestingLevels, structureNestingLevel)

        # Phase 2: Generate infill and skin for outer boundaries.
        for path, pathIndex in paths

            continue if path.length < 3 or pathIsHole[pathIndex]

            # Skip objects that were already completed inline (independent objects only).
            continue if completedObjectIndices[pathIndex]

            currentPath = innermostWalls[pathIndex]

            continue if not currentPath or currentPath.length < 3

            lastPathEndPoint = infillSkinPhase.processStructureInfillAndSkin(slicer, path, pathIndex, currentPath, innermostWalls, pathIsHole, pathNestingLevel, z, centerOffsetX, centerOffsetY, layerIndex, skinLayerCount, totalLayers, allLayers, holeInnerWalls, holeInnerWallNestingLevels, holeOuterWalls, holeOuterWallNestingLevels, holeSkinWalls, holeSkinWallNestingLevels, structureSkinWalls, pathsWithInsufficientSpacingForSkinWalls, lastPathEndPoint, filterHolesByNestingLevel)

        # Save last position for cross-layer combing.
        lastGCodeLines = slicer.gcode.split(slicer.newline)

        for i in [lastGCodeLines.length - 1..0] by -1

            line = lastGCodeLines[i].trim()

            if line.match(/^G[01]\s/)

                xMatch = line.match(/X([-\d.]+)/)
                yMatch = line.match(/Y([-\d.]+)/)

                if xMatch and yMatch

                    slicer.lastLayerEndPoint = {
                        x: parseFloat(xMatch[1]) - centerOffsetX
                        y: parseFloat(yMatch[1]) - centerOffsetY
                        z: z
                    }

                    break
