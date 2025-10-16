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

        # Use Polytree to slice the mesh into layers.
        allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ, maxZ)

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

        # Process each closed path (perimeter).
        for path in paths

            # Skip degenerate paths.
            continue if path.length < 3

            currentPath = path

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

                    insetPath = helpers.createInsetPath(currentPath, nozzleDiameter)

                    # Stop if inset path becomes degenerate.
                    break if insetPath.length < 3

                    currentPath = insetPath

            # After walls, determine if skin or infill should be generated for THIS specific region.
            #
            # Professional slicer skin detection strategy:
            # 1. Identify "exposed surfaces" - regions where there's minimal coverage from adjacent layer
            # 2. For TOP surfaces (not covered from above): generate skin on the exposed layer AND
            #    skinLayerCount-1 layers immediately BELOW it
            # 3. For BOTTOM surfaces (not covered from below): generate skin on the exposed layer AND
            #    skinLayerCount-1 layers immediately ABOVE it
            #
            # Example: If layer 150 is a top surface (not covered by 151) and skinLayerCount=4:
            #   - Layers 147, 148, 149, 150 all get skin (4 total layers)
            #
            # Implementation:
            # - Check if any layer within skinLayerCount distance is an exposed surface
            # - If yes, this layer gets skin

            # The innermost wall ends at its first point (closed loop).
            # Track this position to minimize travel distance to infill/skin start.
            lastWallPoint = if currentPath.length > 0 then { x: currentPath[0].x, y: currentPath[0].y } else null

            # Determine if this region needs skin and calculate exposed areas.
            needsSkin = false
            skinAreas = [] # Will store only the exposed portions of currentPath
            isAbsoluteTopOrBottom = false # Track if this is absolute top/bottom layer

            # Always generate skin for the absolute top and bottom layers.
            if layerIndex < skinLayerCount or layerIndex >= totalLayers - skinLayerCount

                needsSkin = true
                skinAreas = [currentPath] # Use entire perimeter for absolute top/bottom
                isAbsoluteTopOrBottom = true # Mark as absolute top/bottom

            else

                # For middle layers, check if this region is within skinLayerCount distance
                # of an exposed surface (top or bottom).
                #
                # Algorithm:
                # - Check layers within skinLayerCount range above/below current layer
                # - If any of those layers is an exposed surface, calculate the exposed areas
                # - Generate skin only for the exposed portions

                coverageThreshold = 0.7
                exposedFromAbove = []
                exposedFromBelow = []

                # Check if there's a top surface within skinLayerCount layers above us.
                # A top surface is a layer that's not covered by the layer above it.
                # We need to check up to skinLayerCount layers, so range is [layerIndex..layerIndex + skinLayerCount - 1]
                for checkIdx in [layerIndex..Math.min(totalLayers - 1, layerIndex + skinLayerCount - 1)]

                    # Is checkIdx a top surface?
                    if checkIdx < totalLayers - 1

                        # Check if layer checkIdx+1 covers this region
                        aboveSegments = allLayers[checkIdx + 1]

                        if aboveSegments? and aboveSegments.length > 0

                            abovePaths = helpers.connectSegmentsToPaths(aboveSegments)
                            coverageFromAbove = helpers.calculateRegionCoverage(currentPath, abovePaths, 9)

                            if coverageFromAbove < coverageThreshold

                                # checkIdx is a top surface exposure - calculate exposed areas
                                exposedAreas = helpers.calculateExposedAreas(currentPath, abovePaths, 81)
                                exposedFromAbove.push(exposedAreas...)

                                # Found exposure - current layer gets skin if within range
                                break

                        else

                            # No geometry above means top surface - entire region is exposed
                            exposedFromAbove.push(currentPath)

                            break

                    else

                        # checkIdx is the very top layer
                        exposedFromAbove.push(currentPath)

                        break

                # Check if there's a bottom surface within skinLayerCount layers below us.
                # A bottom surface is a layer that's not covered by the layer below it.
                # We need to check down to skinLayerCount layers, so range is [layerIndex down to layerIndex - skinLayerCount + 1]
                if exposedFromAbove.length is 0

                    for checkIdx in [layerIndex..Math.max(0, layerIndex - skinLayerCount + 1)] by -1

                        # Is checkIdx a bottom surface?
                        if checkIdx > 0

                            # Check if layer checkIdx-1 covers this region
                            belowSegments = allLayers[checkIdx - 1]

                            if belowSegments? and belowSegments.length > 0

                                belowPaths = helpers.connectSegmentsToPaths(belowSegments)
                                coverageFromBelow = helpers.calculateRegionCoverage(currentPath, belowPaths, 9)

                                if coverageFromBelow < coverageThreshold

                                    # checkIdx is a bottom surface exposure - calculate exposed areas
                                    exposedAreas = helpers.calculateExposedAreas(currentPath, belowPaths, 81)
                                    exposedFromBelow.push(exposedAreas...)
                                    # Found exposure - current layer gets skin if within range
                                    break

                            else

                                # No geometry below means bottom surface - entire region is exposed
                                exposedFromBelow.push(currentPath)
                                break

                        else

                            # checkIdx is layer 0 (bottom layer)
                            exposedFromBelow.push(currentPath)
                            break

                # Combine exposed areas from above and below.
                skinAreas = exposedFromAbove.concat(exposedFromBelow)
                needsSkin = skinAreas.length > 0

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
                    for skinArea in skinAreas

                        skinModule.generateSkinGCode(slicer, skinArea, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint)

                else

                    # Mixed layers (partial exposure): infill first, then skin second.
                    # This way the skin (printed after) covers the infill pattern on exposed surfaces.
                    if infillDensity > 0

                        infillModule.generateInfillGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint)

                    # Generate skin ONLY in the exposed areas.
                    for skinArea in skinAreas

                        skinModule.generateSkinGCode(slicer, skinArea, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint)

            else

                # No skin needed - generate normal sparse infill only.
                if infillDensity > 0

                    infillModule.generateInfillGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint)
