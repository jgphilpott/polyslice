# Support generation module for Polyslice.

coders = require('../gcode/coders')
pathsUtils = require('../utils/paths')
primitives = require('../utils/primitives')

module.exports =

    # Generate G-code for support structures.
    generateSupportGCode: (slicer, mesh, allLayers, layerIndex, z, centerOffsetX, centerOffsetY, minZ, layerHeight) ->

        return unless slicer.getSupportEnabled()

        supportType = slicer.getSupportType()
        supportPlacement = slicer.getSupportPlacement()
        supportThreshold = slicer.getSupportThreshold()

        return unless supportType is 'normal'

        # Support 'buildPlate' and 'everywhere' placements.
        return unless supportPlacement in ['buildPlate', 'everywhere']

        # Initialize layer solid regions cache on first layer.
        if not slicer._layerSolidRegions?

            slicer._layerSolidRegions = @buildLayerSolidRegions(allLayers, layerHeight, minZ)

        if not slicer._overhangRegions?

            slicer._overhangRegions = @detectOverhangs(mesh, supportThreshold, minZ, supportPlacement)

        overhangRegions = slicer._overhangRegions
        layerSolidRegions = slicer._layerSolidRegions

        return unless overhangRegions.length > 0

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()

        supportsGenerated = 0

        for region in overhangRegions

            interfaceGap = layerHeight * 1.5

            if region.z > (z + interfaceGap)

                # Check if support can be generated at this position based on placement mode.
                canGenerateSupport = @canGenerateSupportAt(
                    region,
                    z,
                    layerIndex,
                    layerSolidRegions,
                    supportPlacement,
                    minZ,
                    layerHeight
                )

                if canGenerateSupport

                    @generateSupportColumn(slicer, region, z, centerOffsetX, centerOffsetY, nozzleDiameter)
                    supportsGenerated++

        if verbose and supportsGenerated > 0 and layerIndex is 0

            slicer.gcode += "; Support structures detected (#{overhangRegions.length} regions)" + slicer.newline

        return

    # Detect overhanging regions based on support threshold angle.
    detectOverhangs: (mesh, thresholdAngle, buildPlateZ = 0, supportPlacement = 'buildPlate') ->

        return [] unless mesh?.geometry

        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

        geometry = mesh.geometry

        positions = geometry.attributes?.position
        return [] unless positions

        overhangRegions = []
        processedFaces = new Set()

        thresholdRad = thresholdAngle * Math.PI / 180

        faceCount = positions.count / 3

        for faceIndex in [0...faceCount]

            continue if processedFaces.has(faceIndex)

            i0 = faceIndex * 3
            i1 = i0 + 1
            i2 = i0 + 2

            v0 = new THREE.Vector3(
                positions.getX(i0),
                positions.getY(i0),
                positions.getZ(i0)
            )

            v1 = new THREE.Vector3(
                positions.getX(i1),
                positions.getY(i1),
                positions.getZ(i1)
            )

            v2 = new THREE.Vector3(
                positions.getX(i2),
                positions.getY(i2),
                positions.getZ(i2)
            )

            v0.applyMatrix4(mesh.matrixWorld)
            v1.applyMatrix4(mesh.matrixWorld)
            v2.applyMatrix4(mesh.matrixWorld)

            edge1 = new THREE.Vector3().subVectors(v1, v0)
            edge2 = new THREE.Vector3().subVectors(v2, v0)
            normal = new THREE.Vector3().crossVectors(edge1, edge2).normalize()

            # Check downward-facing surfaces.
            if normal.z < 0

                angleFromHorizontal = Math.acos(Math.abs(normal.z))

                angleFromHorizontalDeg = angleFromHorizontal * 180 / Math.PI

                supportAngleLimit = 90 - thresholdAngle

                if angleFromHorizontalDeg < supportAngleLimit

                    centerX = (v0.x + v1.x + v2.x) / 3
                    centerY = (v0.y + v1.y + v2.y) / 3
                    centerZ = (v0.z + v1.z + v2.z) / 3

                    # For 'buildPlate' placement, only generate supports above build plate.
                    # For 'everywhere' placement, support all overhangs regardless of height.
                    shouldGenerateSupport = if supportPlacement is 'everywhere'
                        centerZ > buildPlateZ
                    else
                        centerZ > buildPlateZ + 0.5

                    if shouldGenerateSupport

                        overhangRegions.push({
                            x: centerX
                            y: centerY
                            z: centerZ
                            angle: angleFromHorizontalDeg
                        })

                        processedFaces.add(faceIndex)

        return overhangRegions

    # Build a cache of solid regions for each layer.
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

    # Check if support can be generated at a given position.
    # For 'buildPlate' mode: path must be clear from build plate to support position.
    # For 'everywhere' mode: support can start from any solid surface below the overhang.
    canGenerateSupportAt: (region, currentZ, currentLayerIndex, layerSolidRegions, supportPlacement, minZ, layerHeight) ->

        # Point to check (support column position).
        point = { x: region.x, y: region.y }

        if supportPlacement is 'buildPlate'

            # Check all layers below current layer for collisions.
            # If any solid region contains this point, support cannot be generated.
            for layerData in layerSolidRegions

                # Only check layers below current layer.
                if layerData.layerIndex < currentLayerIndex

                    # Check if point is inside solid geometry (accounting for holes).
                    if @isPointInsideSolidGeometry(point, layerData.paths, layerData.pathIsHole)

                        # Point is blocked by solid geometry.
                        return false

            # Path is clear to build plate.
            return true

        else if supportPlacement is 'everywhere'

            # For 'everywhere' mode, support should only be generated above solid surfaces.
            # We need to find if there's solid geometry at this XY position below the current layer.

            highestSolidZ = minZ # Start at build plate (no solid surface found yet).
            hasBlockingGeometry = false

            # Check all layers below current layer.
            for layerData in layerSolidRegions

                if layerData.layerIndex < currentLayerIndex

                    # Check if point is inside solid geometry (accounting for holes).
                    if @isPointInsideSolidGeometry(point, layerData.paths, layerData.pathIsHole)

                        # Found solid geometry at this layer.
                        hasBlockingGeometry = true

                        # Update highest solid surface.
                        if layerData.z > highestSolidZ

                            highestSolidZ = layerData.z

            # If there's no blocking geometry below, support can go all the way to build plate.
            if not hasBlockingGeometry

                return true

            # If there is blocking geometry, only generate support ABOVE the highest solid surface.
            # We need to find the TOP of the solid geometry, not just the highest layer we found.
            # Check if solid geometry continues at the current layer - if so, no support yet.
            
            # Check if there's solid geometry at layers just below current layer.
            # If the previous layer (or nearby layers) have solid geometry, support shouldn't start yet.
            layersToCheck = Math.min(3, currentLayerIndex) # Check up to 3 layers back
            
            for i in [1..layersToCheck]
                checkLayerIndex = currentLayerIndex - i
                if checkLayerIndex >= 0 and checkLayerIndex < layerSolidRegions.length
                    layerData = layerSolidRegions[checkLayerIndex]
                    if @isPointInsideSolidGeometry(point, layerData.paths, layerData.pathIsHole)
                        # Solid geometry found in recent layers below - don't generate support yet.
                        # The solid surface hasn't ended yet.
                        return false

            # Solid geometry has ended - we can generate support now.
            # Add a gap (1 layer height) above the highest solid surface.
            minimumSupportZ = highestSolidZ + layerHeight

            return currentZ >= minimumSupportZ

        return false

    # Check if a point is inside solid geometry (accounting for holes).
    # A point is inside solid geometry if:
    # - It's inside at least one outer boundary (even nesting level)
    # - AND it's not inside any hole (odd nesting level)
    # We use nesting level logic: count how many paths contain the point.
    # If the count is odd, the point is in a hole (empty space).
    # If the count is even (including 0), the point is outside or in solid.
    isPointInsideSolidGeometry: (point, paths, pathIsHole) ->

        return false if not paths or paths.length is 0

        epsilon = 0.001
        containmentCount = 0

        # Count how many paths contain this point.
        for i in [0...paths.length]

            path = paths[i]

            if path.length >= 3 and primitives.pointInPolygon(point, path, epsilon)

                containmentCount++

        # Standard even-odd winding rule for nested boundaries:
        # - Count 0: outside everything (not solid)
        # - Count 1: inside one boundary (the outer structure - solid)
        # - Count 2: inside two boundaries (outer + hole - NOT solid, it's empty space)
        # - Count 3: inside three boundaries (solid again - structure inside hole)
        # Rule: ODD count = solid, EVEN count = not solid
        return containmentCount > 0 and containmentCount % 2 is 1

    # Check if a point is inside a solid region (path).
    # A point is inside if it's within the outer boundary and not in any holes.
    isPointInsideSolidRegion: (point, path) ->

        return false if not path or path.length < 3

        # Use point-in-polygon test.
        # Use a small epsilon to handle boundary cases.
        epsilon = 0.001

        return primitives.pointInPolygon(point, path, epsilon)

    # Generate a support column from build plate to overhang region.
    generateSupportColumn: (slicer, region, currentZ, centerOffsetX, centerOffsetY, nozzleDiameter) ->

        verbose = slicer.getVerbose()

        supportLineWidth = nozzleDiameter * 0.8
        supportSpacing = nozzleDiameter * 2

        patchSize = supportLineWidth * 2

        if verbose

            slicer.gcode += "; TYPE: SUPPORT" + slicer.newline
            slicer.gcode += "; Support column at (#{region.x.toFixed(2)}, #{region.y.toFixed(2)}, z=#{region.z.toFixed(2)})" + slicer.newline

        travelSpeed = slicer.getTravelSpeed() * 60
        supportSpeed = slicer.getPerimeterSpeed() * 60 * 0.5

        offsetX = region.x + centerOffsetX
        offsetY = region.y + centerOffsetY

        slicer.gcode += coders.codeLinearMovement(slicer, offsetX - patchSize, offsetY, currentZ, null, travelSpeed)

        distance1 = patchSize * 2
        extrusion1 = slicer.calculateExtrusion(distance1, supportLineWidth)
        slicer.cumulativeE += extrusion1
        slicer.gcode += coders.codeLinearMovement(slicer, offsetX + patchSize, offsetY, currentZ, slicer.cumulativeE, supportSpeed)

        slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY - patchSize, currentZ, null, travelSpeed)

        distance2 = patchSize * 2
        extrusion2 = slicer.calculateExtrusion(distance2, supportLineWidth)
        slicer.cumulativeE += extrusion2
        slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY + patchSize, currentZ, slicer.cumulativeE, supportSpeed)

        return
