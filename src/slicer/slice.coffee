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
adhesionModule = require('./adhesion/adhesion')
exposureModule = require('./skin/exposure/exposure')
preprocessingModule = require('./preprocessing/preprocessing')

module.exports =

    # Helper function to call progress callback if it exists.
    reportProgress: (slicer, stage, percentComplete, currentLayer = null, totalLayers = null, message = null) ->

        if slicer.progressCallback and typeof slicer.progressCallback is "function"

            progressInfo = {
                stage: stage                    # String: current stage of slicing
                percent: percentComplete        # Number: percentage complete (0-100)
                currentLayer: currentLayer      # Number or null: current layer being processed
                totalLayers: totalLayers        # Number or null: total number of layers
                message: message                # String or null: optional status message
            }

            try

                slicer.progressCallback(progressInfo)

            catch error

                # Silently ignore errors in user callback to avoid disrupting slicing.
                console.error("Error in progressCallback:", error)

    # Main slicing method that generates G-code from a scene.
    slice: (slicer, scene = {}) ->

        # Report starting progress immediately.
        @reportProgress(slicer, "initializing", 0, null, null, "Starting...")

        # Reset G-code output.
        slicer.gcode = ""

        # Reset cached overhang regions for support generation.
        # This ensures supports are recalculated for each new mesh/orientation.
        slicer._overhangRegions = null
        slicer._layerSolidRegions = null

        # Extract mesh from scene if provided.
        originalMesh = preprocessingModule.extractMesh(scene)

        # If no mesh provided, just generate basic initialization sequence.
        if not originalMesh

            if slicer.getAutohome()

                slicer.gcode += coders.codeAutohome(slicer)

            return slicer.gcode

        # Update progress - mesh extracted.
        @reportProgress(slicer, "initializing", 2, null, null, "Preparing mesh...")

        # Initialize THREE.js if not already available.
        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

        # Clone mesh to avoid modifying the original object.
        # This preserves the original mesh's position, rotation, and scale in the scene.
        # We use clone(true) for recursive cloning, then manually clone geometry to prevent
        # any shared state modifications (e.g., from computeBoundingBox calls).
        mesh = originalMesh.clone(true)
        mesh.geometry = originalMesh.geometry.clone()
        mesh.updateMatrixWorld()

        # Report pre-print progress.
        @reportProgress(slicer, "pre-print", 5, null, null, "Generating pre-print sequence...")

        # Generate pre-print sequence (metadata, heating, autohome, test strip if enabled).
        slicer.gcode += coders.codePrePrint(slicer)
        slicer.gcode += slicer.newline

        # Reset cumulative extrusion counter (absolute mode starts at 0).
        slicer.cumulativeE = 0

        # Initialize print statistics tracking.
        slicer.totalFilamentLength = 0 # Total filament extruded (mm).
        slicer.totalLayers = 0 # Number of layers printed.

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
        # Use layerHeight / 2 to ensure we're well into the model geometry,
        # avoiding numerical precision issues at boundary surfaces.
        SLICE_EPSILON = layerHeight / 2
        adjustedMinZ = minZ + SLICE_EPSILON

        # Check mesh complexity and warn about potential performance issues.
        # The path connection algorithm (connectSegmentsToPaths) has O(n³) complexity
        # where n is the number of segments per layer. This complexity metric is an
        # approximation based on triangles × layers; actual performance may vary based
        # on geometric complexity per layer (e.g., flat objects with many small features).
        geometry = mesh.geometry
        if geometry and geometry.attributes and geometry.attributes.position

            positionCount = geometry.attributes.position.count
            triangleCount = if geometry.index then Math.floor(geometry.index.count / 3) else Math.floor(positionCount / 3)
            estimatedLayers = Math.ceil((maxZ - minZ) / layerHeight)

            # Complexity metric: triangles * layers (approximation)
            # Based on testing:
            # - Under 500k: Fast (< 10s)
            # - 500k - 1M: Moderate (10s - 30s)
            # - 1M - 5M: Slow (30s - 2min)
            # - Over 5M: Very slow or may appear to hang (>2min)
            complexityScore = triangleCount * estimatedLayers

            COMPLEXITY_WARNING_THRESHOLD = 1000000  # 1M
            COMPLEXITY_CRITICAL_THRESHOLD = 5000000  # 5M

            if complexityScore > COMPLEXITY_CRITICAL_THRESHOLD

                console.warn("    WARNING: Very high mesh complexity detected!")
                console.warn("    Triangles: #{triangleCount}, Estimated layers: #{estimatedLayers}")
                console.warn("    Complexity score: #{Math.floor(complexityScore / 1000)}k")
                console.warn("    Slicing may take several minutes or appear to hang.")
                console.warn("    Consider reducing mesh detail or increasing layer height.")
                console.warn("    See: https://github.com/jgphilpott/polyslice/blob/main/docs/slicer/MESH_COMPLEXITY.md\n")

            else if complexityScore > COMPLEXITY_WARNING_THRESHOLD

                console.warn("    High mesh complexity detected. Slicing may take 30-60 seconds.")
                console.warn("    Triangles: #{triangleCount}, Layers: #{estimatedLayers}, Score: #{Math.floor(complexityScore / 1000)}k\n")

        # Apply mesh preprocessing (Loop subdivision) if enabled.
        if slicer.getMeshPreprocessing and slicer.getMeshPreprocessing()

            mesh = preprocessingModule.preprocessMesh(mesh)

        # Use Polytree to slice the mesh into layers with adjusted starting position.
        allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, adjustedMinZ, maxZ)

        # Calculate center offset to position mesh on build plate center.
        # We need to account for the mesh's actual position in world space.
        buildPlateWidth = slicer.getBuildPlateWidth()
        buildPlateLength = slicer.getBuildPlateLength()

        # Calculate the mesh's bounding box center in XY plane.
        meshCenterX = (boundingBox.min.x + boundingBox.max.x) / 2
        meshCenterY = (boundingBox.min.y + boundingBox.max.y) / 2

        # Calculate offsets to center the mesh on the build plate.
        # The offset should map the mesh center to the build plate center.
        centerOffsetX = (buildPlateWidth / 2) - meshCenterX
        centerOffsetY = (buildPlateLength / 2) - meshCenterY

        # Store center offsets for smart wipe nozzle in post-print.
        slicer.centerOffsetX = centerOffsetX
        slicer.centerOffsetY = centerOffsetY

        # Store bounding box for metadata (convert to build plate coordinates)
        slicer.meshBounds = {
            minX: boundingBox.min.x + centerOffsetX
            maxX: boundingBox.max.x + centerOffsetX
            minY: boundingBox.min.y + centerOffsetY
            maxY: boundingBox.max.y + centerOffsetY
            minZ: boundingBox.min.z
            maxZ: boundingBox.max.z
        }

        verbose = slicer.getVerbose()

        # Report adhesion progress if enabled.
        if slicer.getAdhesionEnabled()

            @reportProgress(slicer, "adhesion", 10, null, null, "Generating adhesion structures...")

        # Generate adhesion structures (skirt, brim, or raft) if enabled.
        if slicer.getAdhesionEnabled()

            # Get first layer paths for shape-based adhesion.
            firstLayerPaths = null

            if allLayers.length > 0

                firstLayerSegments = allLayers[0]
                firstLayerPaths = pathsUtils.connectSegmentsToPaths(firstLayerSegments)

            adhesionModule.generateAdhesionGCode(slicer, mesh, centerOffsetX, centerOffsetY, boundingBox, firstLayerPaths)

        # Turn on fan if configured (after pre-print, before actual printing).
        fanSpeed = slicer.getFanSpeed()

        if fanSpeed > 0

            slicer.gcode += coders.codeFanSpeed(slicer, fanSpeed).replace(slicer.newline, (if verbose then "; Start Cooling Fan" + slicer.newline else slicer.newline))

        if verbose then slicer.gcode += coders.codeMessage(slicer, "Printing #{allLayers.length} layers...")

        # Calculate Z offset for raft if enabled.
        raftZOffset = 0

        if slicer.getAdhesionEnabled() and slicer.getAdhesionType() is 'raft'

            raftBaseThickness = slicer.getRaftBaseThickness()
            raftInterfaceLayers = slicer.getRaftInterfaceLayers()
            raftInterfaceThickness = slicer.getRaftInterfaceThickness()
            raftAirGap = slicer.getRaftAirGap()

            # Total raft height = base + all interface layers + air gap.
            raftZOffset = raftBaseThickness + (raftInterfaceLayers * raftInterfaceThickness) + raftAirGap

        # Process each layer.
        totalLayers = allLayers.length

        # Track last position across layers for combing between layers.
        slicer.lastLayerEndPoint = null

        # Report start of layer processing.
        @reportProgress(slicer, "slicing", 15, 0, totalLayers, "Processing layers...")

        for layerIndex in [0...totalLayers]

            layerSegments = allLayers[layerIndex]
            currentZ = adjustedMinZ + layerIndex * layerHeight + raftZOffset

            # Report progress for this layer (15% to 85% range for layer processing).
            layerPercent = 15 + Math.floor(((layerIndex + 1) / totalLayers) * 70)
            @reportProgress(slicer, "slicing", layerPercent, layerIndex + 1, totalLayers, "Layer #{layerIndex + 1}/#{totalLayers}")

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

        # Store final print statistics after all layers are processed.
        slicer.totalFilamentLength = slicer.cumulativeE # Final extrusion value equals total filament used (mm).
        slicer.totalLayers = totalLayers

        # Report post-print progress.
        @reportProgress(slicer, "post-print", 90, null, null, "Generating post-print sequence...")

        slicer.gcode += slicer.newline # Add blank line before post-print for readability.
        # Generate post-print sequence (retract, home, cool down, buzzer if enabled).
        slicer.gcode += coders.codePostPrint(slicer)

        # Update metadata with print statistics after all G-code is generated.
        coders.updateMetadataWithStats(slicer)

        # Report completion.
        @reportProgress(slicer, "complete", 100, null, null, "G-code generation complete")

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

        # Detect nesting levels for all paths to handle nested holes/structures.
        # Paths at odd nesting levels (1, 3, 5, ...) are holes.
        # Paths at even nesting levels (0, 2, 4, ...) are structures.
        # pathNestingLevel is tracked primarily for debugging but also documents the logic.
        pathNestingLevel = []
        pathIsHole = []

        for i in [0...paths.length]

            nestingLevel = 0

            # Count how many other paths contain this path.
            for j in [0...paths.length]

                continue if i is j

                if paths[i].length > 0 and primitives.pointInPolygon(paths[i][0], paths[j])

                    nestingLevel++

            pathNestingLevel.push(nestingLevel)

            # Odd nesting levels represent holes, even levels represent structures.
            isHole = nestingLevel % 2 is 1

            pathIsHole.push(isHole)

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

        for pathIndex1 in [0...paths.length]

            outerWall1 = allOuterWalls[pathIndex1]
            continue if not outerWall1 or outerWall1.length < 3

            for pathIndex2 in [pathIndex1+1...paths.length]

                outerWall2 = allOuterWalls[pathIndex2]
                continue if not outerWall2 or outerWall2.length < 3

                # Only check spacing between paths of the same type.
                # Holes expand outward, structures expand inward, so they won't collide.
                isHole1 = pathIsHole[pathIndex1]
                isHole2 = pathIsHole[pathIndex2]

                continue if isHole1 isnt isHole2

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

                # Only check spacing between paths of the same type.
                # Holes expand outward, structures expand inward, so they won't collide.
                isHole1 = pathIsHole[pathIndex1]
                isHole2 = pathIsHole[pathIndex2]

                continue if isHole1 isnt isHole2

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

        # Sort outer boundaries by nearest neighbor to minimize travel.
        sortedOuterBoundaryIndices = []
        remainingOuterBoundaryIndices = outerBoundaryIndices.slice()

        while remainingOuterBoundaryIndices.length > 0

            nearestIndex = -1
            nearestDistance = Infinity

            for boundaryIdx in remainingOuterBoundaryIndices

                boundaryPath = paths[boundaryIdx]
                boundaryCentroid = calculatePathCentroid(boundaryPath)

                if boundaryCentroid

                    distance = calculateDistance(lastPathEndPoint, boundaryCentroid)

                    if distance < nearestDistance

                        nearestDistance = distance
                        nearestIndex = boundaryIdx

            if nearestIndex >= 0

                sortedOuterBoundaryIndices.push(nearestIndex)

                remainingOuterBoundaryIndices = remainingOuterBoundaryIndices.filter((idx) -> idx isnt nearestIndex)

            else

                sortedOuterBoundaryIndices.push(remainingOuterBoundaryIndices[0])
                remainingOuterBoundaryIndices.shift()

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

                # Note: For structures on middle layers with exposure detection,
                # we don't generate skin walls. Instead, skin infill is generated
                # in Phase 2 for exposed areas only.

            innermostWall = generateWallsForPath(path, pathIndex, false, shouldGenerateSkinWalls)
            innermostWalls[pathIndex] = innermostWall

            # Check if sequential object completion optimization can be used.
            # This optimization completes each independent object (walls + skin/infill) before moving to the next,
            # minimizing travel distance between objects.
            #
            # Conditions for using this optimization:
            # 1. No holes on this layer (independent objects)
            # 2. Valid innermost wall exists
            #
            # For independent objects, we always use sequential completion because:
            # - Objects don't interfere with each other
            # - Optimal travel path is to complete one object before moving to the next
            # - Exposure detection (if enabled) can be applied independently to each object
            canUseSequentialCompletion = holeIndices.length is 0 and innermostWall and innermostWall.length >= 3

            if canUseSequentialCompletion

                # Sequential object completion: generate skin/infill immediately after walls.
                currentPath = innermostWall
                infillBoundary = pathsUtils.createInsetPath(currentPath, nozzleDiameter, false)

                # Determine if this region needs skin based on layer position and exposure detection.
                needsSkin = false
                skinAreas = []
                isAbsoluteTopOrBottom = false
                coveringRegionsAbove = []
                coveringRegionsBelow = []

                # Check for absolute top/bottom layers.
                if layerIndex < skinLayerCount or layerIndex >= totalLayers - skinLayerCount

                    needsSkin = true
                    skinAreas = [currentPath]
                    isAbsoluteTopOrBottom = true

                else if slicer.getExposureDetection()

                    # For middle layers with exposure detection enabled, check if this object
                    # has exposed areas (e.g., due to changing cross-section like pyramids/cones).
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

                # Strategy: top/bottom = skin only; mixed = infill then skin; middle = infill only.
                infillDensity = slicer.getInfillDensity()

                if needsSkin

                    # Identify fully covered areas for skin infill exclusion.
                    fullyCoveredRegions = exposureModule.identifyFullyCoveredRegions(currentPath, coveringRegionsAbove, coveringRegionsBelow)
                    fullyCoveredSkinWalls = exposureModule.filterFullyCoveredSkinWalls(fullyCoveredRegions, currentPath)

                    if isAbsoluteTopOrBottom

                        # Absolute top/bottom layers: skin only for clean surfaces.
                        for skinArea in skinAreas
                            skinModule.generateSkinGCode(slicer, skinArea, z, centerOffsetX, centerOffsetY, layerIndex, lastPathEndPoint, false, true, [], [], fullyCoveredSkinWalls, false, true)

                    else

                        # Mixed layers: infill first, then skin.
                        if infillDensity > 0 and infillBoundary.length >= 3

                            # For mixed layers, pass skin areas to infill to prevent overlap.
                            infillModule.generateInfillGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastPathEndPoint, [], [], skinAreas)

                        # Generate skin for exposed areas.
                        for skinArea in skinAreas
                            skinModule.generateSkinGCode(slicer, skinArea, z, centerOffsetX, centerOffsetY, layerIndex, lastPathEndPoint, false, true, [], [], fullyCoveredSkinWalls, false, true)

                        # Generate skin walls (no infill) for fully covered regions.
                        for fullyCoveredSkinWall in fullyCoveredSkinWalls
                            continue if fullyCoveredSkinWall.length < 3
                            skinModule.generateSkinGCode(slicer, fullyCoveredSkinWall, z, centerOffsetX, centerOffsetY, layerIndex, lastPathEndPoint, false, false, [], [], [], true, true)

                            if infillDensity > 0
                                infillGap = 0
                                skinWallInset = nozzleDiameter
                                totalInsetForInfill = skinWallInset + infillGap
                                coveredInfillBoundary = pathsUtils.createInsetPath(fullyCoveredSkinWall, totalInsetForInfill, false)

                                if coveredInfillBoundary.length >= 3
                                    infillModule.generateInfillGCode(slicer, coveredInfillBoundary, z, centerOffsetX, centerOffsetY, layerIndex, lastPathEndPoint, [], [], [])

                else

                    # No skin needed - generate sparse infill only.
                    if infillDensity > 0 and infillBoundary.length >= 3
                        infillModule.generateInfillGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastPathEndPoint, [], [])

                completedObjectIndices[pathIndex] = true

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

        # Helper function to filter holes by nesting level.
        # For a structure at nesting level N, only include holes at level N+1 (direct children).
        # This prevents nested structures from being excluded by holes at higher levels.
        filterHolesByNestingLevel = (holeWalls, holeNestingLevels, structureNestingLevel) =>

            filteredWalls = []

            # Validate parameters.
            return filteredWalls if not holeWalls or not holeNestingLevels
            return filteredWalls if holeWalls.length is 0 or holeNestingLevels.length is 0

            for holeWall, idx in holeWalls

                # Bounds check to ensure array lengths match.
                continue if idx >= holeNestingLevels.length

                holeLevel = holeNestingLevels[idx]

                # Only include holes that are direct children (one level deeper).
                if holeLevel is structureNestingLevel + 1

                    filteredWalls.push(holeWall)

            return filteredWalls

        # Phase 2: Generate infill and skin for outer boundaries.
        for path, pathIndex in paths

            continue if path.length < 3 or pathIsHole[pathIndex]

            # Skip objects that were already completed inline (independent objects only).
            continue if completedObjectIndices[pathIndex]

            currentPath = innermostWalls[pathIndex]

            continue if not currentPath or currentPath.length < 3

            continue if not currentPath or currentPath.length < 3

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

                # Filter hole skin walls to only include direct children (one level deeper).
                # This prevents nested structures from having their infill excluded by unrelated holes.
                filteredHoleSkinWalls = filterHolesByNestingLevel(holeSkinWalls, holeSkinWallNestingLevels, currentStructureNestingLevel)

                # Use only hole skin walls for exclusion zones.
                # Structure skin walls from Phase 1 should NOT exclude their own infill.
                allSkinWalls = filteredHoleSkinWalls

                if isAbsoluteTopOrBottom

                    # Absolute top/bottom layers: skin only for clean surfaces.
                    for skinArea in skinAreas

                        # For nested structures with holes, Phase 1 already generated skin walls.
                        # In Phase 2, we need to generate skin infill only (not duplicate walls).
                        # The simplest approach: check if this structure already has skin walls from Phase 1.
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
                        # For nested structures with holes on absolute top/bottom layers, Phase 1 already generated skin walls.
                        # But for middle layers with exposure detection, Phase 1 does NOT generate structure skin walls.
                        # So we need to check if this is an absolute top/bottom layer before skipping wall generation.
                        structureAlreadyHasSkinWall = holeIndices.length > 0 and isAbsoluteTopOrBottom
                        shouldGenerateWall = not structureAlreadyHasSkinWall

                        skinModule.generateSkinGCode(slicer, skinArea, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, false, true, allSkinWalls, holeOuterWalls, fullyCoveredSkinWalls, false, shouldGenerateWall)

                    # Generate skin walls (no infill) for fully covered regions.
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
