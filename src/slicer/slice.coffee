# Main slicing method for Polyslice.

Polytree = require('@jgphilpott/polytree')

coders = require('./gcode/coders')
helpers = require('./geometry/helpers')

infillModule = require('./infill/infill')
skinModule = require('./skin/skin')
wallsModule = require('./walls/walls')
supportModule = require('./support/support')

module.exports =

    # Main slicing method that generates G-code from a scene.
    slice: (slicer, scene = {}) ->

        # Reset G-code output.
        slicer.gcode = ""

        # Extract mesh from scene if provided.
        mesh = @extractMesh(scene)

        # If no mesh provided, just generate basic initialization sequence.
        if not mesh

            if slicer.getAutohome()

                slicer.gcode += coders.codeAutohome(slicer)

            return slicer.gcode

        # Initialize THREE.js if not already available.
        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

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

        # Add small epsilon offset to starting Z position to avoid slicing exactly at geometric boundaries.
        # This prevents issues with shapes like sphere and torus where slicing at exact boundary planes
        # can cause Polytree to miss entire regions:
        # - Sphere: Slicing at the equator (Z=5 for radius 5) where many vertices exist at Z=0
        #   can result in only half the geometry being captured (semi-circle instead of full circle).
        # - Torus: Slicing at the center plane (Z=2 for tube radius 2) can miss the outer ring,
        #   printing only the inner hole.
        # Using a small epsilon (0.01mm = 10 microns) that's negligible for printing but sufficient
        # to nudge all slice planes away from exact geometric boundaries.
        SLICE_EPSILON = 0.01
        adjustedMinZ = minZ + SLICE_EPSILON

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
            layerPaths = helpers.connectSegmentsToPaths(layerSegments)

            # Generate support structures if enabled.
            # Support generation currently checks supportEnabled flag internally.
            if slicer.getSupportEnabled()

                supportModule.generateSupportGCode(slicer, mesh, allLayers, layerIndex, currentZ, centerOffsetX, centerOffsetY, minZ, layerHeight)

            # Only output layer marker if layer has content.
            if verbose and layerPaths.length > 0

                slicer.gcode += coders.codeMessage(slicer, "LAYER: #{layerIndex}")

            # Generate G-code for this layer with center offset.
            @generateLayerGCode(slicer, layerPaths, currentZ, layerIndex, centerOffsetX, centerOffsetY, totalLayers, allLayers, layerSegments)

        slicer.gcode += slicer.newline # Add blank line before post-print for readability.
        # Generate post-print sequence (retract, home, cool down, buzzer if enabled).
        slicer.gcode += coders.codePostPrint(slicer)

        return slicer.gcode

    # Extract mesh from scene object.
    extractMesh: (scene) ->

        return null if not scene

        # If scene is already a mesh, return it.
        if scene.isMesh then return scene

        # If scene has children, find first mesh.
        if scene.children and scene.children.length > 0

            for child in scene.children

                if child.isMesh then return child

        # If scene has a mesh property.
        if scene.mesh and scene.mesh.isMesh

            return scene.mesh

        return null

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
        # Holes need to be inset outward to shrink the hole, while outer boundaries inset inward.
        pathIsHole = []

        for i in [0...paths.length]

            isHole = false

            # Check if this path is contained within any other path.
            for j in [0...paths.length]

                continue if i is j

                # Test if a sample point from path i is inside path j.
                if paths[i].length > 0 and helpers.pointInPolygon(paths[i][0], paths[j])

                    isHole = true

                    break

            pathIsHole.push(isHole)

        # Phase 1: Generate walls and collect hole boundaries.
        # We must complete this phase BEFORE generating infill, so that hole boundaries
        # are available when processing outer boundaries.
        holeInnerWalls = []  # Inner wall paths of holes (for regular infill clipping).
        holeOuterWalls = []  # Outer wall paths of holes (for travel path optimization).
        holeSkinWalls = []   # Skin wall paths of holes (for skin infill clipping).
        innermostWalls = []  # Store innermost wall for each path.

        # Track last end point for travel path combing BETWEEN different paths/features.
        # Initialize with position from previous layer if available.
        lastPathEndPoint = slicer.lastLayerEndPoint

        # Track outer boundary path for travel path combing.
        outerBoundaryPath = null

        # Pre-pass: Collect all hole outer walls BEFORE generating any walls.
        # This ensures complete hole information is available for combing path calculation.
        pathToHoleIndex = {}  # Map path index to index in holeOuterWalls array
        allOuterWalls = {}    # Map path index to its outer wall path (for spacing validation)

        for path, pathIndex in paths

            # Skip degenerate paths.
            continue if path.length < 3

            # Create initial offset for the outer wall by half nozzle diameter.
            outerWallOffset = nozzleDiameter / 2
            currentPath = helpers.createInsetPath(path, outerWallOffset, pathIsHole[pathIndex])

            # Skip if offset path is degenerate.
            continue if currentPath.length < 3

            # Store ALL outer walls (both holes and non-holes) for spacing validation.
            allOuterWalls[pathIndex] = currentPath

            # Store hole outer walls for combing path avoidance.
            if pathIsHole[pathIndex]
                pathToHoleIndex[pathIndex] = holeOuterWalls.length
                holeOuterWalls.push(currentPath)
            else
                # Store outer boundary for combing constraint.
                outerBoundaryPath = path

        # After collecting all outer walls, identify paths that are too close together.
        # If outer walls from different paths are closer than one nozzle diameter,
        # those paths should not generate inner walls to avoid interference.
        pathsWithInsufficientSpacingForInnerWalls = {}  # Track which paths should skip inner walls
        pathsWithInsufficientSpacingForSkinWalls = {}   # Track which paths should skip skin walls

        for pathIndex1 in [0...paths.length]

            outerWall1 = allOuterWalls[pathIndex1]
            continue if not outerWall1 or outerWall1.length < 3

            for pathIndex2 in [pathIndex1+1...paths.length]

                outerWall2 = allOuterWalls[pathIndex2]
                continue if not outerWall2 or outerWall2.length < 3

                # Calculate minimum distance between these two outer walls.
                minDistance = helpers.calculateMinimumDistanceBetweenPaths(outerWall1, outerWall2)

                # If the gap between outer walls is less than one nozzle diameter,
                # mark both paths as having insufficient spacing for inner walls.
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
            currentPath = helpers.createInsetPath(path, outerWallOffset, isHole)

            return null if currentPath.length < 3

            # Simulate wall generation to find innermost wall.
            for wallIndex in [0...wallCount]

                # Check if inner walls should be skipped.
                if wallIndex > 0

                    if pathsWithInsufficientSpacingForInnerWalls[pathIndex]
                        break

                    testInsetPath = helpers.createInsetPath(currentPath, nozzleDiameter, isHole)

                    if testInsetPath.length < 3
                        break

                # Create inset for next wall if not the last wall.
                if wallIndex < wallCount - 1

                    insetPath = helpers.createInsetPath(currentPath, nozzleDiameter, isHole)

                    break if insetPath.length < 3

                    currentPath = insetPath

            return currentPath

        # Calculate all innermost walls.
        allInnermostWalls = {}

        for path, pathIndex in paths

            innermostWall = calculateInnermostWall(path, pathIndex, pathIsHole[pathIndex])

            if innermostWall and innermostWall.length >= 3
                allInnermostWalls[pathIndex] = innermostWall

        # Check spacing between innermost walls to determine if skin walls can be generated.
        # Inherit flags from inner wall spacing check first.
        for pathIndex in [0...paths.length]
            if pathsWithInsufficientSpacingForInnerWalls[pathIndex]
                pathsWithInsufficientSpacingForSkinWalls[pathIndex] = true

        # Then check spacing between actual innermost walls.
        for pathIndex1 in [0...paths.length]

            innermostWall1 = allInnermostWalls[pathIndex1]
            continue if not innermostWall1 or innermostWall1.length < 3

            for pathIndex2 in [pathIndex1+1...paths.length]

                innermostWall2 = allInnermostWalls[pathIndex2]
                continue if not innermostWall2 or innermostWall2.length < 3

                # Calculate minimum distance between innermost walls.
                minDistance = helpers.calculateMinimumDistanceBetweenPaths(innermostWall1, innermostWall2)

                # For skin walls, we need space for BOTH skin walls (one from each path).
                # Each skin wall requires one nozzle diameter, so total threshold is 2 * nozzle diameter.
                skinWallThreshold = nozzleDiameter * 2

                # If insufficient spacing, mark both paths.
                if minDistance < skinWallThreshold
                    pathsWithInsufficientSpacingForSkinWalls[pathIndex1] = true
                    pathsWithInsufficientSpacingForSkinWalls[pathIndex2] = true

        # Helper function to generate walls for a single path.
        # Returns the innermost wall path.
        # If generateSkinWalls is true and this is a hole, also generates skin walls immediately after regular walls.
        generateWallsForPath = (path, pathIndex, isHole, generateSkinWalls = false) =>

            # Skip degenerate paths.
            return null if path.length < 3

            # Create initial offset for the outer wall by half nozzle diameter.
            # This ensures the print matches the design dimensions exactly.
            # For outer boundaries: inset by half nozzle (shrinks the boundary inward).
            # For holes: outset by half nozzle (enlarges the hole path outward).
            outerWallOffset = nozzleDiameter / 2
            currentPath = helpers.createInsetPath(path, outerWallOffset, isHole)

            # If the offset path is degenerate, skip this path entirely.
            return null if currentPath.length < 3

            # Generate walls from outer to inner.
            # Use lastPathEndPoint for combing to the first wall of this path.
            # Within the path, walls connect directly without combing (they're concentric).
            for wallIndex in [0...wallCount]

                # Determine wall type for TYPE annotation.
                if wallIndex is 0
                    wallType = "WALL-OUTER"
                else if wallIndex is wallCount - 1
                    wallType = "WALL-INNER"
                else
                    wallType = "WALL-INNER"

                # Before generating inner walls (wallIndex > 0), check if there is sufficient space.
                # This prevents printing walls in incorrect positions when the gap between outer walls
                # is too small (e.g., first layers of a torus where the tube cross-section is narrow).
                if wallIndex > 0

                    # First, check if this path was flagged as having insufficient spacing for inner walls.
                    # If so, skip inner wall generation entirely.
                    if pathsWithInsufficientSpacingForInnerWalls[pathIndex]
                        break

                    # Check if the next inset would be degenerate (too small to print).
                    # The createInsetPath function already has sophisticated validation.
                    testInsetPath = helpers.createInsetPath(currentPath, nozzleDiameter, isHole)

                    # If the inset path is degenerate, there's no room for this wall.
                    if testInsetPath.length < 3
                        # No room for inner walls - stop generating walls for this path.
                        break

                # Use combing for all walls to avoid crossing holes, even between concentric walls.
                # The lastPathEndPoint is updated after each wall, so it always reflects the current nozzle position.
                combingStartPoint = lastPathEndPoint

                # For combing, exclude the current hole (if this is a hole) ONLY if we're traveling
                # from the same layer (i.e., lastPathEndPoint has the same Z coordinate).
                # When traveling from a different layer, include all holes in collision detection.
                excludeDestinationHole = false

                if isHole and pathToHoleIndex[pathIndex]? and lastPathEndPoint?
                    # Only exclude if we're on the same layer.
                    if lastPathEndPoint.z is z
                        excludeDestinationHole = true

                if excludeDestinationHole
                    currentHoleIdx = pathToHoleIndex[pathIndex]
                    combingHoleWalls = holeOuterWalls[0...currentHoleIdx].concat(holeOuterWalls[currentHoleIdx+1...])
                else
                    combingHoleWalls = holeOuterWalls

                # Generate this wall with combing path support.
                # Pass the hole outer walls list (excluding current hole) and boundary for combing.
                wallEndPoint = wallsModule.generateWallGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, wallType, combingStartPoint, combingHoleWalls, outerBoundaryPath)

                # Update lastPathEndPoint to track the actual nozzle position.
                # We update it for every wall, so after all walls are done, it represents
                # the end position of the innermost wall, which is where the nozzle actually is.
                lastPathEndPoint = wallEndPoint

                # Create inset path for next wall (if not last wall).
                if wallIndex < wallCount - 1

                    insetPath = helpers.createInsetPath(currentPath, nozzleDiameter, isHole)

                    # Stop if inset path becomes degenerate.
                    break if insetPath.length < 3

                    currentPath = insetPath

            # Store the innermost wall path for holes (for infill clipping).
            if isHole and currentPath.length >= 3

                holeInnerWalls.push(currentPath)

            # If this is a hole on a skin layer, generate skin walls immediately after regular walls.
            # This is more efficient than making a separate pass later.
            # Note: generateSkinWalls is only true when spacing is sufficient, so no need to check again.
            if isHole and generateSkinWalls and currentPath and currentPath.length >= 3

                # Calculate the skin wall path for this hole.
                # This is an inset of full nozzle diameter from the innermost wall.
                skinWallInset = nozzleDiameter
                skinWallPath = helpers.createInsetPath(currentPath, skinWallInset, isHole)

                if skinWallPath.length >= 3

                    holeSkinWalls.push(skinWallPath)

                    # For combing, exclude the current hole (destination).
                    # When traveling TO this hole's skin wall, we shouldn't check collision with the hole itself.
                    if pathToHoleIndex[pathIndex]?
                        currentHoleIdx = pathToHoleIndex[pathIndex]
                        skinCombingHoleWalls = holeOuterWalls[0...currentHoleIdx].concat(holeOuterWalls[currentHoleIdx+1...])
                    else
                        skinCombingHoleWalls = holeOuterWalls

                    # Generate skin wall for the hole (outward inset).
                    # Pass generateInfill=false to skip infill (only walls).
                    # Pass lastPathEndPoint for combing (it's updated from regular wall generation above).
                    skinEndPoint = skinModule.generateSkinGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastPathEndPoint, isHole, false, [], skinCombingHoleWalls)

                    # Update lastPathEndPoint with skin wall end position.
                    lastPathEndPoint = skinEndPoint if skinEndPoint?

            return currentPath

        # Helper function to calculate centroid of a path.
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

        # Helper function to calculate distance between two points.
        calculateDistance = (pointA, pointB) =>

            # If either point is missing, return a large but finite distance.
            # This allows the nearest-neighbor algorithm to continue with other holes
            # when lastPathEndPoint is null (e.g., first layer or no prior position).
            return 1000000 if not pointA or not pointB

            dx = pointA.x - pointB.x
            dy = pointA.y - pointB.y

            return Math.sqrt(dx * dx + dy * dy)

        # Initialize innermostWalls array with the correct size (same as paths).
        innermostWalls = new Array(paths.length)

        # Separate paths into outer boundaries and holes.
        outerBoundaryIndices = []
        holeIndices = []

        for pathIndex in [0...paths.length]

            if pathIsHole[pathIndex]
                holeIndices.push(pathIndex)
            else
                outerBoundaryIndices.push(pathIndex)

        # Determine if this layer needs skin.
        # This is used to decide whether to generate skin walls for holes during wall generation.
        # Include middle layers if exposure detection is enabled, as they may need adaptive skin.
        layerNeedsSkin = layerIndex < skinLayerCount or layerIndex >= totalLayers - skinLayerCount or slicer.getExposureDetection()

        # Process outer boundaries first (non-hole paths).
        for pathIndex in outerBoundaryIndices

            path = paths[pathIndex]
            innermostWall = generateWallsForPath(path, pathIndex, false, false)
            innermostWalls[pathIndex] = innermostWall

        # Sort holes by nearest neighbor to minimize travel distance.
        # Start from the last known position (where outer boundaries ended).
        # Note: This is O(n²) complexity, which is acceptable for typical geometries
        # with moderate hole counts (< 100 holes). For larger counts, consider
        # spatial indexing optimizations.
        sortedHoleIndices = []
        remainingHoleIndices = holeIndices.slice()  # Create a copy

        while remainingHoleIndices.length > 0

            # Find the nearest hole to the last position.
            nearestIndex = -1
            nearestDistance = Infinity

            for holeIdx in remainingHoleIndices

                holePath = paths[holeIdx]
                holeCentroid = calculatePathCentroid(holePath)

                if holeCentroid

                    # Calculate distance from last position to hole centroid.
                    distance = calculateDistance(lastPathEndPoint, holeCentroid)

                    if distance < nearestDistance
                        nearestDistance = distance
                        nearestIndex = holeIdx

            # If we found a nearest hole, process it.
            if nearestIndex >= 0

                sortedHoleIndices.push(nearestIndex)

                # Remove from remaining list.
                remainingHoleIndices = remainingHoleIndices.filter((idx) -> idx isnt nearestIndex)
            else

                # Fallback: just take the first remaining hole.
                sortedHoleIndices.push(remainingHoleIndices[0])
                remainingHoleIndices.shift()

        # Process holes in sorted order (nearest neighbor).
        # On skin layers, generate skin walls immediately after regular walls if spacing permits.
        # This avoids a second pass around the geometry.
        for pathIndex in sortedHoleIndices

            path = paths[pathIndex]

            # Determine if we should generate skin walls immediately for this hole.
            # Only generate skin walls if:
            # 1. This is a skin layer (layerNeedsSkin)
            # 2. The path has sufficient spacing (not flagged for insufficient spacing)
            # 3. For middle layers with exposure detection: the hole represents an actual exposure (cavity)
            shouldGenerateSkinWalls = false

            if layerNeedsSkin and not pathsWithInsufficientSpacingForSkinWalls[pathIndex]

                # For absolute top/bottom layers, always generate skin walls.
                isAbsoluteTopOrBottom = layerIndex < skinLayerCount or layerIndex >= totalLayers - skinLayerCount

                if isAbsoluteTopOrBottom

                    shouldGenerateSkinWalls = true

                else if slicer.getExposureDetection()

                    # For middle layers with exposure detection enabled:
                    # Only generate skin walls if this hole represents an actual exposure (cavity).
                    # Check if the hole exists in the layer skinLayerCount steps above and below.
                    # If the hole exists in both directions, it's a vertical hole (not exposed).
                    # If the hole is missing in either direction, it's a cavity (exposed).
                    holeExposedAbove = false
                    holeExposedBelow = false

                    # Check if hole exists in layer above.
                    checkIdxAbove = layerIndex + skinLayerCount

                    if checkIdxAbove < totalLayers

                        checkSegments = allLayers[checkIdxAbove]

                        if checkSegments? and checkSegments.length > 0

                            checkPaths = helpers.connectSegmentsToPaths(checkSegments)

                            # Check if this hole path exists in the layer above.
                            # A hole "exists" if there's a corresponding hole path in the check layer.
                            holeExistsAbove = helpers.doesHoleExistInLayer(path, checkPaths)

                            # If hole doesn't exist above, this hole is exposed from above.
                            holeExposedAbove = not holeExistsAbove

                        else

                            # No geometry above means hole is exposed from above.
                            holeExposedAbove = true

                    else

                        # Near top of model - hole is exposed from above.
                        holeExposedAbove = true

                    # Check if hole exists in layer below.
                    checkIdxBelow = layerIndex - skinLayerCount

                    if checkIdxBelow >= 0

                        checkSegments = allLayers[checkIdxBelow]

                        if checkSegments? and checkSegments.length > 0

                            checkPaths = helpers.connectSegmentsToPaths(checkSegments)

                            # Check if this hole path exists in the layer below.
                            holeExistsBelow = helpers.doesHoleExistInLayer(path, checkPaths)

                            # If hole doesn't exist below, this hole is exposed from below.
                            holeExposedBelow = not holeExistsBelow

                        else

                            # No geometry below means hole is exposed from below.
                            holeExposedBelow = true

                    else

                        # Near bottom of model - hole is exposed from below.
                        holeExposedBelow = true

                    # Generate skin walls only if hole is exposed in at least one direction.
                    shouldGenerateSkinWalls = holeExposedAbove or holeExposedBelow

            innermostWall = generateWallsForPath(path, pathIndex, true, shouldGenerateSkinWalls)
            innermostWalls[pathIndex] = innermostWall

        # Skin walls for holes are now generated immediately after their regular walls
        # in the loop above (when shouldGenerateSkinWalls is true). This avoids a
        # second pass around the geometry, which was the behavior before PR #55.
        # The spacing checks have been moved earlier (pre-calculation) so we know
        # upfront which paths can have skin walls.

        # Phase 2: Generate infill and skin.
        # Now that all hole boundaries have been collected, we can generate infill
        # for outer boundaries with proper hole exclusion.
        for path, pathIndex in paths

            # Skip degenerate paths and holes (holes already processed in phase 1).
            continue if path.length < 3 or pathIsHole[pathIndex]

            currentPath = innermostWalls[pathIndex]

            # Skip if no innermost wall was generated.
            continue if not currentPath or currentPath.length < 3

            # Skip if no innermost wall was generated.
            continue if not currentPath or currentPath.length < 3

            # The innermost wall ends at its first point (closed loop).
            # Use lastPathEndPoint from wall generation to minimize travel distance and enable combing.
            # If lastPathEndPoint is null (first path), fall back to innermost wall first point.
            lastWallPoint = lastPathEndPoint or (if currentPath.length > 0 then { x: currentPath[0].x, y: currentPath[0].y, z: z } else null)

            # Determine a safe boundary for infill by insetting one nozzle width.
            # If we cannot inset (no room inside the last wall), we should not generate infill.
            # Pass isHole parameter to ensure correct inset direction for holes.
            infillBoundary = helpers.createInsetPath(currentPath, nozzleDiameter, pathIsHole[pathIndex])

            # Determine if this region needs skin and calculate exposed areas.
            needsSkin = false
            skinAreas = [] # Will store only the exposed portions of currentPath
            isAbsoluteTopOrBottom = false # Track if this is absolute top/bottom layer
            skinSuppressedDueToSpacing = false # Track if skin was suppressed due to insufficient spacing

            # Always generate skin for the absolute top and bottom layers.
            if layerIndex < skinLayerCount or layerIndex >= totalLayers - skinLayerCount

                # Check if this path has insufficient spacing for skin walls.
                # If so, skip skin generation even on top/bottom layers.
                if not pathsWithInsufficientSpacingForSkinWalls[pathIndex]
                    needsSkin = true
                    skinAreas = [currentPath] # Use entire perimeter for absolute top/bottom
                    isAbsoluteTopOrBottom = true # Mark as absolute top/bottom
                else
                    needsSkin = false
                    skinAreas = []
                    skinSuppressedDueToSpacing = true # Mark that spacing is the reason

            else

                # For middle layers, check if exposure detection is enabled.
                # When enabled, adaptively generates skin layers for exposed surfaces.
                # When disabled, only top and bottom layers get skin (simpler but less optimal).
                if slicer.getExposureDetection()

                    # ENABLED: Exposure detection algorithm
                    # For the current layer, calculate what parts won't be covered by the layer exactly
                    # skinLayerCount steps ahead/behind. Each layer independently calculates its exposed area.
                    # Check BOTH directions to detect overhangs (exposure from above) AND cavities/holes (exposure from below).
                    exposedAreas = []

                    # Check the layer exactly skinLayerCount steps AHEAD (above).
                    checkIdxAbove = layerIndex + skinLayerCount

                    if checkIdxAbove < totalLayers

                        checkSegments = allLayers[checkIdxAbove]

                        if checkSegments? and checkSegments.length > 0

                            checkPaths = helpers.connectSegmentsToPaths(checkSegments)

                            # Calculate what parts of CURRENT layer are NOT covered by the layer ahead
                            # Use configurable resolution for exposure detection (default 961 = 31x31 grid)
                            checkExposedAreas = helpers.calculateExposedAreas(currentPath, checkPaths, slicer.getExposureDetectionResolution())

                            if checkExposedAreas.length > 0
                                exposedAreas.push(checkExposedAreas...)

                        else

                            # No geometry at the layer ahead means current layer is exposed
                            exposedAreas.push(currentPath)

                    else

                        # We're within skinLayerCount of the top - current layer will be exposed
                        exposedAreas.push(currentPath)

                    # Always check behind to detect cavities and holes (exposure from below).
                    # Previously this was only checked if exposedAreas.length was 0, which missed cavities.
                    checkIdxBelow = layerIndex - skinLayerCount

                    if checkIdxBelow >= 0

                        checkSegments = allLayers[checkIdxBelow]

                        if checkSegments? and checkSegments.length > 0

                            checkPaths = helpers.connectSegmentsToPaths(checkSegments)

                            # Calculate what parts of CURRENT layer are NOT covered by the layer behind
                            # Use configurable resolution for exposure detection (default 961 = 31x31 grid)
                            checkExposedAreas = helpers.calculateExposedAreas(currentPath, checkPaths, slicer.getExposureDetectionResolution())

                            if checkExposedAreas.length > 0
                                exposedAreas.push(checkExposedAreas...)

                        else

                            # No geometry at the layer behind means current layer is exposed
                            exposedAreas.push(currentPath)

                    else

                        # We're within skinLayerCount of the bottom - current layer will be exposed
                        exposedAreas.push(currentPath)

                    # Use calculated exposed areas for skin generation on current layer
                    skinAreas = exposedAreas
                    needsSkin = skinAreas.length > 0

                else

                    # Exposure detection disabled - no skin for middle layers.
                    needsSkin = false
                    skinAreas = []

            # Generate infill and/or skin based on exposure.
            #
            # Strategy:
            # - Absolute top/bottom layers: ONLY skin (no infill) for clean surfaces
            # - Mixed layers (partial exposure): infill first (entire layer), then skin second (exposed areas)
            #   This allows skin to cover infill pattern, preventing it from being visible on exterior
            # - Middle layers (no exposure): ONLY infill
            #
            # This ensures:
            # - Clean top/bottom surfaces (skin only, no infill overlap)
            # - On mixed layers: infill provides structural support, skin covers it for clean exterior
            # - Complete coverage (no gaps)

            infillDensity = slicer.getInfillDensity()

            if needsSkin

                if isAbsoluteTopOrBottom

                    # Absolute top/bottom layers: ONLY skin (no infill).
                    # This ensures clean top and bottom surfaces without visible infill pattern.
                    # Pass hole skin walls for clipping and hole outer walls for travel path optimization.
                    for skinArea in skinAreas

                        # Skip if skin area is completely inside a hole (>90% coverage).
                        # Check against skin walls, inner walls and outer walls to prevent patches inside holes.
                        # This prevents printing skin patch walls inside holes when the hole is larger than the patch.
                        continue if holeSkinWalls.length > 0 and helpers.isSkinAreaInsideHole(skinArea, holeSkinWalls)
                        continue if holeInnerWalls.length > 0 and helpers.isSkinAreaInsideHole(skinArea, holeInnerWalls)
                        continue if holeOuterWalls.length > 0 and helpers.isSkinAreaInsideHole(skinArea, holeOuterWalls)

                        skinModule.generateSkinGCode(slicer, skinArea, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, false, true, holeSkinWalls, holeOuterWalls)

                else

                    # Mixed layers (partial exposure): infill first, then skin second.
                    # This way the skin (printed after) covers the infill pattern on exposed surfaces.
                    if infillDensity > 0 and infillBoundary.length >= 3

                        # Use the original currentPath for infill to keep coverage consistent,
                        # but require that an inset path exists as a guard to ensure there is room inside.
                        # Pass hole inner walls for clipping and hole outer walls for travel optimization.
                        infillModule.generateInfillGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, holeInnerWalls, holeOuterWalls)

                    # Generate skin ONLY in the exposed areas.
                    # Pass hole skin walls for clipping and hole outer walls for travel path optimization.
                    for skinArea in skinAreas

                        # Skip if skin area is completely inside a hole (>90% coverage).
                        # Check against skin walls, inner walls and outer walls to prevent patches inside holes.
                        # This prevents printing skin patch walls inside holes when the hole is larger than the patch.
                        continue if holeSkinWalls.length > 0 and helpers.isSkinAreaInsideHole(skinArea, holeSkinWalls)
                        continue if holeInnerWalls.length > 0 and helpers.isSkinAreaInsideHole(skinArea, holeInnerWalls)
                        continue if holeOuterWalls.length > 0 and helpers.isSkinAreaInsideHole(skinArea, holeOuterWalls)

                        skinModule.generateSkinGCode(slicer, skinArea, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, false, true, holeSkinWalls, holeOuterWalls)

            else

                # No skin needed - generate normal sparse infill only.
                # However, if skin was suppressed due to insufficient spacing, also skip infill
                # because the area is too narrow for proper material deposition.
                if infillDensity > 0 and infillBoundary.length >= 3 and not skinSuppressedDueToSpacing

                    # Use the original currentPath for infill to keep coverage consistent,
                    # but require that an inset path exists as a guard to ensure there is room inside.
                    # Pass hole inner walls for clipping and hole outer walls for travel optimization.
                    infillModule.generateInfillGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, holeInnerWalls, holeOuterWalls)

        # Save the last position from this layer for combing to the next layer.
        # Parse the last G0/G1 command from the generated G-code to get the actual end position.
        # This accounts for infill and skin moves that happen after wall generation.
        lastGCodeLines = slicer.gcode.split(slicer.newline)

        for i in [lastGCodeLines.length - 1..0] by -1

            line = lastGCodeLines[i].trim()

            # Look for G0 or G1 commands with X and Y coordinates.
            if line.match(/^G[01]\s/)

                xMatch = line.match(/X([-\d.]+)/)
                yMatch = line.match(/Y([-\d.]+)/)

                if xMatch and yMatch

                    # Found the last position - store it without center offset.
                    slicer.lastLayerEndPoint = {
                        x: parseFloat(xMatch[1]) - centerOffsetX
                        y: parseFloat(yMatch[1]) - centerOffsetY
                        z: z
                    }

                    break
