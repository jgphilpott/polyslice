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
            @generateLayerGCode(slicer, layerPaths, currentZ, layerIndex, centerOffsetX, centerOffsetY, totalLayers, allLayers)

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
    generateLayerGCode: (slicer, paths, z, layerIndex, centerOffsetX = 0, centerOffsetY = 0, totalLayers = 0, allLayers = []) ->

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

            # After walls, determine if skin or infill should be generated.
            # Skin is generated for layers within shellSkinThickness of top or bottom surfaces.
            # This provides solid layers at the top and bottom of the print and at any internal
            # horizontal surfaces (bridges, overhangs, etc.).
            
            # Check if we're within skinLayerCount of top or bottom of model.
            # Also check if there's a gap (missing layer) above or below within skin distance.
            isTopSurface = false
            isBottomSurface = false
            
            # Bottom surface detection:
            # 1. Within first skinLayerCount layers (absolute bottom)
            # 2. OR if there's a gap below (indicating start of new solid region)
            if layerIndex < skinLayerCount
                isBottomSurface = true
            else
                # Check if there's a gap in layers below this one within skinLayerCount distance.
                gapBelow = false
                for checkIdx in [Math.max(0, layerIndex - skinLayerCount)...layerIndex]
                    if not allLayers[checkIdx]? or allLayers[checkIdx].length is 0
                        gapBelow = true
                        break
                if gapBelow
                    isBottomSurface = true
            
            # Top surface detection:
            # 1. Within last skinLayerCount layers (absolute top)
            # 2. OR if there's a gap above (indicating end of solid region)
            if layerIndex >= totalLayers - skinLayerCount
                isTopSurface = true
            else
                # Check if there's a gap in layers above this one within skinLayerCount distance.
                gapAbove = false
                for checkIdx in [layerIndex + 1...Math.min(totalLayers, layerIndex + skinLayerCount + 1)]
                    if not allLayers[checkIdx]? or allLayers[checkIdx].length is 0
                        gapAbove = true
                        break
                if gapAbove
                    isTopSurface = true

            # The innermost wall ends at its first point (closed loop).
            # Track this position to minimize travel distance to infill/skin start.
            lastWallPoint = if currentPath.length > 0 then { x: currentPath[0].x, y: currentPath[0].y } else null

            if isTopSurface or isBottomSurface

                # Generate skin for this layer.
                # currentPath now holds the innermost wall boundary.
                skinModule.generateSkinGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint)

            else

                # Generate infill for middle layers (not top/bottom).
                # Only generate if density > 0.
                infillDensity = slicer.getInfillDensity()

                if infillDensity > 0

                    # currentPath now holds the innermost wall boundary.
                    infillModule.generateInfillGCode(slicer, currentPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint)
