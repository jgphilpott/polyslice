# Support generation module for Polyslice.

normalSupport = require('./normal/normal')
treeSupport = require('./tree/tree')
pathsUtils = require('../utils/paths')
primitives = require('../utils/primitives')

module.exports =

    # Generate G-code for support structures.
    generateSupportGCode: (slicer, mesh, allLayers, layerIndex, z, centerOffsetX, centerOffsetY, minZ, layerHeight) ->

        return unless slicer.getSupportEnabled()

        supportType = slicer.getSupportType()
        supportPlacement = slicer.getSupportPlacement()
        supportThreshold = slicer.getSupportThreshold()

        # Dispatch to appropriate support type module
        if supportType is 'normal'

            # Support 'buildPlate' and 'everywhere' placements.
            return unless supportPlacement in ['buildPlate', 'everywhere']

            # Initialize layer solid regions cache on first layer.
            if not slicer._layerSolidRegions?

                slicer._layerSolidRegions = @buildLayerSolidRegions(allLayers, layerHeight, minZ)

            if not slicer._overhangFaces?

                slicer._overhangFaces = normalSupport.detectOverhangs(mesh, supportThreshold, minZ, supportPlacement)

            # Group adjacent faces into unified support regions on first layer.
            if not slicer._supportRegions?

                slicer._supportRegions = normalSupport.groupAdjacentFaces(slicer._overhangFaces)

            overhangFaces = slicer._overhangFaces
            supportRegions = slicer._supportRegions
            layerSolidRegions = slicer._layerSolidRegions

            return unless overhangFaces.length > 0

            verbose = slicer.getVerbose()
            nozzleDiameter = slicer.getNozzleDiameter()

            supportsGenerated = 0

            # Generate coordinated support structures for each region.
            for region in supportRegions

                interfaceGap = layerHeight * 1.5

                # Check if this region needs support at current Z height.
                # Support should only be generated BELOW the overhang surface, not through/above it.
                # Use the region's minimum Z (lowest point of overhang) to determine when to stop.
                # Only generate support if current layer is below the bottom of the overhang.
                if z < (region.minZ - interfaceGap)

                    # Generate grid pattern for this region covering the entire area.
                    normalSupport.generateRegionSupportPattern(
                        slicer,
                        region,
                        z,
                        layerIndex,
                        centerOffsetX,
                        centerOffsetY,
                        nozzleDiameter,
                        layerSolidRegions,
                        supportPlacement,
                        minZ,
                        layerHeight
                    )

                    supportsGenerated++

            if verbose and supportsGenerated > 0 and layerIndex is 0

                slicer.gcode += "; Support structures detected (#{overhangFaces.length} overhang faces in #{supportRegions.length} regions)" + slicer.newline

        else if supportType is 'tree'

            # Tree support not yet implemented
            treeSupport.generateTreeSupport(slicer, mesh, allLayers, layerIndex, z, centerOffsetX, centerOffsetY, minZ, layerHeight)

        return

    # Build a cache of solid regions for each layer.
    # This is shared utility used by both normal and tree supports.
    # This allows us to quickly check if a point is inside solid geometry.
    # Properly handles holes - a point inside a hole is NOT considered solid.
    buildLayerSolidRegions: (allLayers, layerHeight, minZ) ->

        layerSolidRegions = []

        SLICE_EPSILON = 0.001

        for layerIndex in [0...allLayers.length]

            layerSegments = allLayers[layerIndex]
            layerZ = minZ + SLICE_EPSILON + layerIndex * layerHeight

            # Convert segments to closed paths.
            layerPaths = pathsUtils.connectSegmentsToPaths(layerSegments)

            # Calculate nesting levels to identify holes.
            # Paths at odd nesting levels (1, 3, 5, ...) are holes.
            # Paths at even nesting levels (0, 2, 4, ...) are structures.
            pathIsHole = []

            for i in [0...layerPaths.length]

                nestingLevel = 0

                # Count how many other paths contain this path.
                for j in [0...layerPaths.length]

                    continue if i is j

                    if layerPaths[i].length > 0 and primitives.pointInPolygon(layerPaths[i][0], layerPaths[j])

                        nestingLevel++

                # Odd nesting levels represent holes, even levels represent structures.
                isHole = nestingLevel % 2 is 1

                pathIsHole.push(isHole)

            # Store paths and hole information for this layer.
            layerSolidRegions.push({
                z: layerZ
                paths: layerPaths
                pathIsHole: pathIsHole
                layerIndex: layerIndex
            })

        return layerSolidRegions
