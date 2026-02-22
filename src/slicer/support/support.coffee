# Support generation module for Polyslice.
# Main dispatcher that delegates to sub-modules based on support type.

coders = require('../gcode/coders')
pathsUtils = require('../utils/paths')
primitives = require('../utils/primitives')
normalSupportModule = require('./normal/normal')
treeSupportModule = require('./tree/tree')

module.exports =

    # Generate G-code for support structures.
    generateSupportGCode: (slicer, mesh, allLayers, layerIndex, z, centerOffsetX, centerOffsetY, minZ, layerHeight) ->

        return unless slicer.getSupportEnabled()

        supportType = slicer.getSupportType()
        supportPlacement = slicer.getSupportPlacement()
        supportThreshold = slicer.getSupportThreshold()

        # Dispatch to appropriate sub-module based on support type
        if supportType is 'normal'

            # Support 'buildPlate' and 'everywhere' placements.
            return unless supportPlacement in ['buildPlate', 'everywhere']

            # Initialize layer solid regions cache on first layer.
            if not slicer._layerSolidRegions?

                slicer._layerSolidRegions = @buildLayerSolidRegions(allLayers, layerHeight, minZ)

            # Delegate overhang detection to normal support module
            if not slicer._overhangFaces?

                slicer._overhangFaces = normalSupportModule.detectOverhangs(mesh, supportThreshold, minZ, supportPlacement)

            # Delegate face grouping to normal support module
            if not slicer._supportRegions?

                slicer._supportRegions = normalSupportModule.groupAdjacentFaces(slicer._overhangFaces)

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
                # Use the region's maximum Z (highest point that needs support).
                if region.maxZ > (z + interfaceGap)

                    # Delegate grid pattern generation to normal support module
                    normalSupportModule.generateRegionSupportPattern(
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

            # Support 'buildPlate' and 'everywhere' placements.
            return unless supportPlacement in ['buildPlate', 'everywhere']

            # Initialize layer solid regions cache on first layer.
            if not slicer._layerSolidRegions?

                slicer._layerSolidRegions = @buildLayerSolidRegions(allLayers, layerHeight, minZ)

            # Detect overhangs using the same algorithm as normal supports.
            if not slicer._overhangFaces?

                slicer._overhangFaces = normalSupportModule.detectOverhangs(mesh, supportThreshold, minZ, supportPlacement)

            # Group adjacent faces into unified support regions.
            if not slicer._supportRegions?

                slicer._supportRegions = normalSupportModule.groupAdjacentFaces(slicer._overhangFaces)

            overhangFaces = slicer._overhangFaces
            supportRegions = slicer._supportRegions
            layerSolidRegions = slicer._layerSolidRegions

            return unless overhangFaces.length > 0

            verbose = slicer.getVerbose()
            nozzleDiameter = slicer.getNozzleDiameter()

            supportsGenerated = 0

            # Generate tree structure for each support region.
            for region in supportRegions

                interfaceGap = layerHeight * 1.5

                if region.maxZ > (z + interfaceGap)

                    # Delegate tree pattern generation to tree support module.
                    # Returns true only when G-code was actually emitted.
                    wasGenerated = treeSupportModule.generateTreePattern(
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

                    supportsGenerated++ if wasGenerated

            if verbose and supportsGenerated > 0 and layerIndex is 0

                slicer.gcode += "; Tree support structures detected (#{overhangFaces.length} overhang faces in #{supportRegions.length} regions)" + slicer.newline

        return

    # Build a cache of solid regions for each layer.
    # This allows us to quickly check if a point is inside solid geometry.
    # Properly handles holes - a point inside a hole is NOT considered solid.
    # This is a shared utility used by all support types.
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
