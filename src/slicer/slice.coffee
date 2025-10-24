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

        # Add small epsilon offset to layer height to avoid slicing exactly at geometric boundaries.
        # This prevents issues with shapes like torus where slicing at exact boundary planes
        # can cause Polytree to miss entire regions (e.g., the outer ring at center plane).
        # Using a very small epsilon (0.00000001mm) that's negligible for printing but sufficient
        # to nudge slice planes away from exact geometric boundaries.
        SLICE_EPSILON = 0.00000001
        adjustedLayerHeight = layerHeight + SLICE_EPSILON

        # Use Polytree to slice the mesh into layers with adjusted layer height.
        allLayers = Polytree.sliceIntoLayers(mesh, adjustedLayerHeight, minZ, maxZ)

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

        for layerIndex in [0...totalLayers]

            layerSegments = allLayers[layerIndex]
            currentZ = minZ + layerIndex * layerHeight

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
        holeSkinWalls = []   # Skin wall paths of holes (for skin infill clipping).
        innermostWalls = []  # Store innermost wall for each path.

        # Process each closed path to generate walls.
        for path, pathIndex in paths

            # Skip degenerate paths.
            if path.length < 3
                innermostWalls.push(null)
                continue

            # Create initial offset for the outer wall by half nozzle diameter.
            # This ensures the print matches the design dimensions exactly.
            # For outer boundaries: inset by half nozzle (shrinks the boundary inward).
            # For holes: outset by half nozzle (enlarges the hole path outward).
            outerWallOffset = nozzleDiameter / 2
            currentPath = helpers.createInsetPath(path, outerWallOffset, pathIsHole[pathIndex])

            # If the offset path is degenerate, skip this path entirely.
            if currentPath.length < 3

                innermostWalls.push(null)
                continue

            # Generate walls from outer to inner.
            for wallIndex in [0...wallCount]

                # Determine wall type for TYPE annotation.
                if wallIndex is 0
                    wallType = "WALL-OUTER"
                else if wallIndex is wallCount - 1
                    wallType = "WALL-INNER"
                else
                    wallType = "WALL-INNER"

                # Generate this wall.
                wallsModule.generateWallGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, wallType)

                # Create inset path for next wall (if not last wall).
                if wallIndex < wallCount - 1

                    insetPath = helpers.createInsetPath(currentPath, nozzleDiameter, pathIsHole[pathIndex])

                    # Stop if inset path becomes degenerate.
                    break if insetPath.length < 3

                    currentPath = insetPath

            # Store the innermost wall path.
            innermostWalls.push(currentPath)

            # Store the innermost wall path for holes (for infill clipping).
            if pathIsHole[pathIndex] and currentPath.length >= 3

                holeInnerWalls.push(currentPath)

        # Determine if this layer needs skin (before Phase 2).
        # This is used to decide whether to generate hole skin walls.
        layerNeedsSkin = layerIndex <= skinLayerCount or layerIndex >= totalLayers - skinLayerCount

        # If layer needs skin, generate hole skin walls for clipping.
        if layerNeedsSkin

            for path, pathIndex in paths

                continue unless pathIsHole[pathIndex]

                currentPath = innermostWalls[pathIndex]

                continue unless currentPath and currentPath.length >= 3

                # Calculate the skin wall path for this hole.
                # This is an inset of full nozzle diameter from the innermost wall.
                skinWallInset = nozzleDiameter
                skinWallPath = helpers.createInsetPath(currentPath, skinWallInset, pathIsHole[pathIndex])

                if skinWallPath.length >= 3

                    holeSkinWalls.push(skinWallPath)

                # Generate skin wall for the hole (outward inset).
                # Pass generateInfill=false to skip infill (only walls).
                skinModule.generateSkinGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, null, pathIsHole[pathIndex], false)

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
            # Track this position to minimize travel distance to infill/skin start.
            lastWallPoint = if currentPath.length > 0 then { x: currentPath[0].x, y: currentPath[0].y } else null

            # Determine a safe boundary for infill by insetting one nozzle width.
            # If we cannot inset (no room inside the last wall), we should not generate infill.
            # Pass isHole parameter to ensure correct inset direction for holes.
            infillBoundary = helpers.createInsetPath(currentPath, nozzleDiameter, pathIsHole[pathIndex])

            # Determine if this region needs skin and calculate exposed areas.
            needsSkin = false
            skinAreas = [] # Will store only the exposed portions of currentPath
            isAbsoluteTopOrBottom = false # Track if this is absolute top/bottom layer

            # Always generate skin for the absolute top and bottom layers.
            if layerIndex <= skinLayerCount or layerIndex >= totalLayers - skinLayerCount

                needsSkin = true
                skinAreas = [currentPath] # Use entire perimeter for absolute top/bottom
                isAbsoluteTopOrBottom = true # Mark as absolute top/bottom

            else

                # For middle layers, disable exposure detection for now.
                # TODO: Improve exposure detection algorithm to handle complex geometries like torus.
                # The current algorithm has too many false positives for curved surfaces.
                needsSkin = false
                skinAreas = []

                # DISABLED: Exposure detection algorithm
                # coverageThreshold = 0.1
                # exposedFromAbove = []
                # exposedFromBelow = []
                #
                # # Check if there's a top surface within skinLayerCount layers above us.
                # # A top surface is a layer that's not covered by the layer above it.
                # # We need to check up to skinLayerCount layers, so range is [layerIndex..layerIndex + skinLayerCount - 1]
                # for checkIdx in [layerIndex..Math.min(totalLayers - 1, layerIndex + skinLayerCount - 1)]
                #
                #     # Is checkIdx a top surface?
                #     if checkIdx < totalLayers - 1
                #
                #         # Check if layer checkIdx+1 covers this region
                #         aboveSegments = allLayers[checkIdx + 1]
                #
                #         if aboveSegments? and aboveSegments.length > 0
                #
                #             abovePaths = helpers.connectSegmentsToPaths(aboveSegments)
                #             coverageFromAbove = helpers.calculateRegionCoverage(currentPath, abovePaths, 9)
                #
                #             if coverageFromAbove < coverageThreshold
                #
                #                 # checkIdx is a top surface exposure - calculate exposed areas
                #                 exposedAreas = helpers.calculateExposedAreas(currentPath, abovePaths, 81)
                #                 exposedFromAbove.push(exposedAreas...)
                #
                #                 # Found exposure - current layer gets skin if within range
                #                 break
                #
                #         else
                #
                #             # No geometry above means top surface - entire region is exposed
                #             exposedFromAbove.push(currentPath)
                #
                #             break
                #
                #     else
                #
                #         # checkIdx is the very top layer
                #         exposedFromAbove.push(currentPath)
                #
                #         break
                #
                # # Check if there's a bottom surface within skinLayerCount layers below us.
                # # A bottom surface is a layer that's not covered by the layer below it.
                # # We need to check down to skinLayerCount layers, so range is [layerIndex down to layerIndex - skinLayerCount + 1]
                # if exposedFromAbove.length is 0
                #
                #     for checkIdx in [layerIndex..Math.max(0, layerIndex - skinLayerCount + 1)] by -1
                #
                #         # Is checkIdx a bottom surface?
                #         if checkIdx > 0
                #
                #             # Check if layer checkIdx-1 covers this region
                #             belowSegments = allLayers[checkIdx - 1]
                #
                #             if belowSegments? and belowSegments.length > 0
                #
                #                 belowPaths = helpers.connectSegmentsToPaths(belowSegments)
                #                 coverageFromBelow = helpers.calculateRegionCoverage(currentPath, belowPaths, 9)
                #
                #                 if coverageFromBelow < coverageThreshold
                #
                #                     # checkIdx is a bottom surface exposure - calculate exposed areas
                #                     exposedAreas = helpers.calculateExposedAreas(currentPath, belowPaths, 81)
                #                     exposedFromBelow.push(exposedAreas...)
                #                     # Found exposure - current layer gets skin if within range
                #                     break
                #
                #             else
                #
                #                 # No geometry below means bottom surface - entire region is exposed
                #                 exposedFromBelow.push(currentPath)
                #                 break
                #
                #         else
                #
                #             # checkIdx is layer 0 (bottom layer)
                #             exposedFromBelow.push(currentPath)
                #             break
                #
                # # Combine exposed areas from above and below.
                # skinAreas = exposedFromAbove.concat(exposedFromBelow)
                # needsSkin = skinAreas.length > 0

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
                    # Pass hole skin walls for clipping.
                    for skinArea in skinAreas

                        skinModule.generateSkinGCode(slicer, skinArea, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, false, true, holeSkinWalls)

                else

                    # Mixed layers (partial exposure): infill first, then skin second.
                    # This way the skin (printed after) covers the infill pattern on exposed surfaces.
                    if infillDensity > 0 and infillBoundary.length >= 3

                        # Use the original currentPath for infill to keep coverage consistent,
                        # but require that an inset path exists as a guard to ensure there is room inside.
                        # Pass hole inner walls for clipping.
                        infillModule.generateInfillGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, holeInnerWalls)

                    # Generate skin ONLY in the exposed areas.
                    # Pass hole skin walls for clipping.
                    for skinArea in skinAreas

                        skinModule.generateSkinGCode(slicer, skinArea, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, false, true, holeSkinWalls)

            else

                # No skin needed - generate normal sparse infill only.
                if infillDensity > 0 and infillBoundary.length >= 3

                    # Use the original currentPath for infill to keep coverage consistent,
                    # but require that an inset path exists as a guard to ensure there is room inside.
                    # Pass hole inner walls for clipping.
                    infillModule.generateInfillGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, holeInnerWalls)
