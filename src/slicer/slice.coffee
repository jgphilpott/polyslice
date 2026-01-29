# Main slicing method for Polyslice.

coders = require('./gcode/coders')
pathsUtils = require('./utils/paths')

adhesionModule = require('./adhesion/adhesion')
supportModule = require('./support/support')

# New modular components
initialization = require('./slice/initialization')
layerOrchestrator = require('./slice/layer-orchestrator')

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

        # Initialize mesh from scene.
        meshInit = initialization.initializeMesh(scene)

        # If no mesh provided, just generate basic initialization sequence.
        if not meshInit

            if slicer.getAutohome()

                slicer.gcode += coders.codeAutohome(slicer)

            return slicer.gcode

        mesh = meshInit.mesh
        THREE = meshInit.THREE

        # Update progress - mesh extracted.
        @reportProgress(slicer, "initializing", 2, null, null, "Preparing mesh...")

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

        # Prepare mesh for slicing (calculate bounding box, adjust Z position).
        prepResult = initialization.prepareMeshForSlicing(mesh, THREE)
        boundingBox = prepResult.boundingBox
        minZ = prepResult.minZ
        maxZ = prepResult.maxZ

        layerHeight = slicer.getLayerHeight()

        # Check mesh complexity and warn about potential performance issues.
        initialization.checkMeshComplexity(mesh, minZ, maxZ, layerHeight)

        # Apply mesh preprocessing (Loop subdivision) if enabled.
        mesh = initialization.preprocessMesh(slicer, mesh)

        # Slice mesh into layers.
        sliceResult = initialization.sliceMeshIntoLayers(mesh, layerHeight, minZ, maxZ)
        allLayers = sliceResult.allLayers
        adjustedMinZ = sliceResult.adjustedMinZ

        # Calculate center offset to position mesh on build plate center.
        buildPlateWidth = slicer.getBuildPlateWidth()
        buildPlateLength = slicer.getBuildPlateLength()

        offsetResult = initialization.calculateCenterOffsets(boundingBox, buildPlateWidth, buildPlateLength)
        centerOffsetX = offsetResult.centerOffsetX
        centerOffsetY = offsetResult.centerOffsetY

        # Store center offsets for smart wipe nozzle in post-print.
        slicer.centerOffsetX = centerOffsetX
        slicer.centerOffsetY = centerOffsetY

        # Store mesh bounds for metadata.
        initialization.storeMeshBounds(slicer, boundingBox, centerOffsetX, centerOffsetY)

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
            layerOrchestrator.generateLayerGCode(slicer, layerPaths, currentZ, layerIndex, centerOffsetX, centerOffsetY, totalLayers, allLayers, layerSegments)

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

    # Generate G-code for a single layer (delegates to layer orchestrator).
    generateLayerGCode: (slicer, paths, z, layerIndex, centerOffsetX = 0, centerOffsetY = 0, totalLayers = 0, allLayers = [], layerSegments = []) ->

        return layerOrchestrator.generateLayerGCode(slicer, paths, z, layerIndex, centerOffsetX, centerOffsetY, totalLayers, allLayers, layerSegments)
