# Main slicing method for Polyslice.

Polytree = require('@jgphilpott/polytree')

coders = require('./gcode/coders')
primitives = require('./utils/primitives')
pathsUtils = require('./utils/paths')
clipping = require('./utils/clipping')
coverage = require('./geometry/coverage')

infillModule = require('./infill/infill')
skinModule = require('./skin/skin')
wallsModule = require('./walls/walls')
supportModule = require('./support/support')
exposureModule = require('./skin/exposure/exposure')
preprocessingModule = require('./preprocessing/preprocessing')

module.exports =

    # Main slicing method that generates G-code from a scene.
    slice: (slicer, scene = {}) ->

        # Reset G-code output.
        slicer.gcode = ""

        # Extract mesh from scene if provided.
        originalMesh = preprocessingModule.extractMesh(scene)

        # If no mesh provided, just generate basic initialization sequence.
        if not originalMesh

            if slicer.getAutohome()

                slicer.gcode += coders.codeAutohome(slicer)

            return slicer.gcode

        # Initialize THREE.js if not already available.
        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

        # Clone mesh to avoid modifying the original object.
        # This preserves the original mesh's position, rotation, and scale in the scene.
        # We use clone(true) for recursive cloning, then manually clone geometry to prevent
        # any shared state modifications (e.g., from computeBoundingBox calls).
        mesh = originalMesh.clone(true)
        mesh.geometry = originalMesh.geometry.clone()
        mesh.updateMatrixWorld()

        # Generate pre-print sequence (metadata, heating, autohome, test strip if enabled).
        slicer.gcode += coders.codePrePrint(slicer)
        slicer.gcode += slicer.newline

        # Reset cumulative extrusion counter (absolute mode starts at 0).
        slicer.cumulativeE = 0

        # Get mesh bounding box for slicing.
        boundingBox = new THREE.Box3().setFromObject(mesh)

        minZ = boundingBox.min.z
        maxZ = boundingBox.max.z

        # Ensure the mesh is positioned above the build plate (no negative Z).
        # If minZ < 0, raise the entire mesh so it sits on the build plate.
        if minZ < 0

            zOffset = -minZ
            mesh.position.z += zOffset
            mesh.updateMatrixWorld()

            # Recalculate bounding box after adjustment.
            boundingBox = new THREE.Box3().setFromObject(mesh)

            minZ = boundingBox.min.z
            maxZ = boundingBox.max.z

        layerHeight = slicer.getLayerHeight()

        # Small epsilon offset avoids slicing at exact geometric boundaries.
        SLICE_EPSILON = 0.001
        adjustedMinZ = minZ + SLICE_EPSILON

        # Apply mesh preprocessing (Loop subdivision) if enabled.
        if slicer.getMeshPreprocessing and slicer.getMeshPreprocessing()

            mesh = preprocessingModule.preprocessMesh(mesh)

        # Use Polytree to slice the mesh into layers with adjusted starting position.
        allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, adjustedMinZ, maxZ)

        # Calculate center offset to position on build plate.
        buildPlateWidth = slicer.getBuildPlateWidth()
        buildPlateLength = slicer.getBuildPlateLength()

        centerOffsetX = buildPlateWidth / 2
        centerOffsetY = buildPlateLength / 2

        verbose = slicer.getVerbose()

        # Turn on fan if configured (after pre-print, before actual printing).
        fanSpeed = slicer.getFanSpeed()

        if fanSpeed > 0

            slicer.gcode += coders.codeFanSpeed(slicer, fanSpeed).replace(slicer.newline, (if verbose then "; Start Cooling Fan" + slicer.newline else slicer.newline))

        if verbose then slicer.gcode += coders.codeMessage(slicer, "Printing #{allLayers.length} layers...")

        # Process each layer.
        totalLayers = allLayers.length

        # Track last position across layers for combing between layers.
        slicer.lastLayerEndPoint = null

        for layerIndex in [0...totalLayers]

            layerSegments = allLayers[layerIndex]
            currentZ = adjustedMinZ + layerIndex * layerHeight

            # Convert Polytree line segments to closed paths.
            layerPaths = pathsUtils.connectSegmentsToPaths(layerSegments)

            # Generate support structures if enabled.
            # Support generation currently checks supportEnabled flag internally.
            if slicer.getSupportEnabled()

                supportModule.generateSupportGCode(slicer, mesh, allLayers, layerIndex, currentZ, centerOffsetX, centerOffsetY, minZ, layerHeight)

            # Only output layer marker if layer has content.
            if verbose and layerPaths.length > 0

                slicer.gcode += coders.codeMessage(slicer, "LAYER: #{layerIndex + 1} of #{totalLayers}")

            # Generate G-code for this layer with center offset.
            @generateLayerGCode(slicer, layerPaths, currentZ, layerIndex, centerOffsetX, centerOffsetY, totalLayers, allLayers, layerSegments)

        slicer.gcode += slicer.newline # Add blank line before post-print for readability.
        # Generate post-print sequence (retract, home, cool down, buzzer if enabled).
        slicer.gcode += coders.codePostPrint(slicer)

        return slicer.gcode

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

        # Detect which paths are holes (contained within other paths).
        pathIsHole = []

        for i in [0...paths.length]

            isHole = false

            for j in [0...paths.length]

                continue if i is j

                if paths[i].length > 0 and primitives.pointInPolygon(paths[i][0], paths[j])

                    isHole = true

                    break

            pathIsHole.push(isHole)

        # Phase 1: Generate walls and collect hole boundaries.
        # We must complete this phase BEFORE generating infill, so that hole boundaries
        # are available when processing outer boundaries.
        holeInnerWalls = []  # Inner wall paths of holes (for regular infill clipping).
        holeOuterWalls = []  # Outer wall paths of holes (for travel path optimization).
        holeSkinWalls = []   # Skin wall paths of holes (for skin infill clipping).
        innermostWalls = []

        # Track last end point for travel path combing.
        lastPathEndPoint = slicer.lastLayerEndPoint

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

            else

                outerBoundaryPath = path

        # Identify paths that are too close for inner/skin walls.
        pathsWithInsufficientSpacingForInnerWalls = {}
        pathsWithInsufficientSpacingForSkinWalls = {}

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

        # Pre-calculate innermost walls to determine spacing for skin walls.
        # This allows us to generate skin walls immediately after regular walls (single pass).
        # Helper function to calculate innermost wall without generating G-code.
        calculateInnermostWall = (path, pathIndex, isHole) =>

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

        allInnermostWalls = {}

        for path, pathIndex in paths

            innermostWall = calculateInnermostWall(path, pathIndex, pathIsHole[pathIndex])

            if innermostWall and innermostWall.length >= 3

                allInnermostWalls[pathIndex] = innermostWall

        # Check spacing between innermost walls for skin wall generation.
        for pathIndex in [0...paths.length]

            if pathsWithInsufficientSpacingForInnerWalls[pathIndex]

                pathsWithInsufficientSpacingForSkinWalls[pathIndex] = true

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

        # Helper function to generate walls for a single path.
        generateWallsForPath = (path, pathIndex, isHole, generateSkinWalls = false) =>

            return null if path.length < 3

            # Offset by half nozzle to match design dimensions.
            outerWallOffset = nozzleDiameter / 2
            currentPath = pathsUtils.createInsetPath(path, outerWallOffset, isHole)

            return null if currentPath.length < 3

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

            # Generate skin walls for holes on skin layers.
            if isHole and generateSkinWalls and currentPath and currentPath.length >= 3

                skinWallInset = nozzleDiameter
                skinWallPath = pathsUtils.createInsetPath(currentPath, skinWallInset, isHole)

                if skinWallPath.length >= 3

                    holeSkinWalls.push(skinWallPath)

                    if pathToHoleIndex[pathIndex]?

                        currentHoleIdx = pathToHoleIndex[pathIndex]
                        skinCombingHoleWalls = holeOuterWalls[0...currentHoleIdx].concat(holeOuterWalls[currentHoleIdx+1...])

                    else

                        skinCombingHoleWalls = holeOuterWalls

                    skinEndPoint = skinModule.generateSkinGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastPathEndPoint, isHole, false, [], skinCombingHoleWalls, [], false)

                    lastPathEndPoint = skinEndPoint if skinEndPoint?

            return currentPath

        calculatePathCentroid = (path) =>

            return null if path.length is 0

            sumX = 0
            sumY = 0

            for point in path

                sumX += point.x
                sumY += point.y

            return {
                x: sumX / path.length
                y: sumY / path.length
            }

        calculateDistance = (pointA, pointB) =>

            return 1000000 if not pointA or not pointB

            dx = pointA.x - pointB.x
            dy = pointA.y - pointB.y

            return Math.sqrt(dx * dx + dy * dy)

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

        # Process outer boundaries first.
        for pathIndex in outerBoundaryIndices

            path = paths[pathIndex]
            innermostWall = generateWallsForPath(path, pathIndex, false, false)
            innermostWalls[pathIndex] = innermostWall

        # Sort holes by nearest neighbor to minimize travel.
        sortedHoleIndices = []
        remainingHoleIndices = holeIndices.slice()

        while remainingHoleIndices.length > 0

            nearestIndex = -1
            nearestDistance = Infinity

            for holeIdx in remainingHoleIndices

                holePath = paths[holeIdx]
                holeCentroid = calculatePathCentroid(holePath)

                if holeCentroid

                    distance = calculateDistance(lastPathEndPoint, holeCentroid)

                    if distance < nearestDistance

                        nearestDistance = distance
                        nearestIndex = holeIdx

            if nearestIndex >= 0

                sortedHoleIndices.push(nearestIndex)

                remainingHoleIndices = remainingHoleIndices.filter((idx) -> idx isnt nearestIndex)

            else

                sortedHoleIndices.push(remainingHoleIndices[0])
                remainingHoleIndices.shift()

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

            innermostWall = generateWallsForPath(path, pathIndex, true, shouldGenerateSkinWalls)
            innermostWalls[pathIndex] = innermostWall

        # Phase 2: Generate infill and skin for outer boundaries.
        for path, pathIndex in paths

            continue if path.length < 3 or pathIsHole[pathIndex]

            currentPath = innermostWalls[pathIndex]

            continue if not currentPath or currentPath.length < 3

            continue if not currentPath or currentPath.length < 3

            lastWallPoint = lastPathEndPoint or (if currentPath.length > 0 then { x: currentPath[0].x, y: currentPath[0].y, z: z } else null)

            infillBoundary = pathsUtils.createInsetPath(currentPath, nozzleDiameter, pathIsHole[pathIndex])

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

                    skinAreas = exposureResult.exposedAreas
                    coveringRegionsAbove = exposureResult.coveringRegionsAbove
                    coveringRegionsBelow = exposureResult.coveringRegionsBelow
                    needsSkin = skinAreas.length > 0

                else

                    needsSkin = false
                    skinAreas = []

            # Strategy: top/bottom = skin only; mixed = infill then skin; middle = infill only.
            infillDensity = slicer.getInfillDensity()

            if needsSkin

                # Identify fully covered areas for skin infill exclusion.
                fullyCoveredRegions = exposureModule.identifyFullyCoveredRegions(currentPath, coveringRegionsAbove, coveringRegionsBelow)

                fullyCoveredSkinWalls = exposureModule.filterFullyCoveredSkinWalls(fullyCoveredRegions, currentPath)

                infillGap = 0
                skinWallInset = nozzleDiameter
                totalInsetForInfill = skinWallInset + infillGap

                if isAbsoluteTopOrBottom

                    # Absolute top/bottom layers: skin only for clean surfaces.
                    for skinArea in skinAreas

                        continue if coverage.isAreaInsideAnyHoleWall(skinArea, holeSkinWalls, holeInnerWalls, holeOuterWalls)

                        skinModule.generateSkinGCode(slicer, skinArea, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, false, true, holeSkinWalls, holeOuterWalls, fullyCoveredSkinWalls)

                else

                    # Mixed layers: infill first, then skin.
                    if infillDensity > 0 and infillBoundary.length >= 3

                        actualSkinAreasForInfill = skinAreas

                        if fullyCoveredSkinWalls.length > 0

                            filteredSkinAreas = []

                            for skinArea in skinAreas

                                continue if skinArea.length < 3

                                remainingAreas = clipping.subtractSkinAreasFromInfill(skinArea, fullyCoveredSkinWalls)
                                filteredSkinAreas.push remainingAreas... if remainingAreas.length > 0

                            actualSkinAreasForInfill = filteredSkinAreas

                        infillModule.generateInfillGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, holeInnerWalls, holeOuterWalls, actualSkinAreasForInfill)

                    # Generate skin for exposed areas.
                    for skinArea in skinAreas

                        continue if coverage.isAreaInsideAnyHoleWall(skinArea, holeSkinWalls, holeInnerWalls, holeOuterWalls)

                        skinModule.generateSkinGCode(slicer, skinArea, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, false, true, holeSkinWalls, holeOuterWalls, fullyCoveredSkinWalls)

                    # Generate skin walls (no infill) for fully covered regions.
                    fullyCoveredInfillBoundaries = []

                    for fullyCoveredSkinWall in fullyCoveredSkinWalls

                        continue if fullyCoveredSkinWall.length < 3

                        continue if coverage.isAreaInsideAnyHoleWall(fullyCoveredSkinWall, holeSkinWalls, holeInnerWalls, holeOuterWalls)

                        skinModule.generateSkinGCode(slicer, fullyCoveredSkinWall, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, false, false, [], holeOuterWalls, [], true)

                        if infillDensity > 0

                            coveredInfillBoundary = pathsUtils.createInsetPath(fullyCoveredSkinWall, totalInsetForInfill, false)

                            if coveredInfillBoundary.length >= 3

                                fullyCoveredInfillBoundaries.push(coveredInfillBoundary)

                    # Generate regular infill for fully covered regions.
                    if fullyCoveredInfillBoundaries.length > 0

                        for coveredInfillBoundary in fullyCoveredInfillBoundaries

                            infillModule.generateInfillGCode(slicer, coveredInfillBoundary, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, [], holeOuterWalls, [])

            else

                # No skin needed - generate sparse infill only.
                if infillDensity > 0 and infillBoundary.length >= 3 and not skinSuppressedDueToSpacing

                    infillModule.generateInfillGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, holeInnerWalls, holeOuterWalls)

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
