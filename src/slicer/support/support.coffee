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

        if not slicer._overhangFaces?

            slicer._overhangFaces = @detectOverhangs(mesh, supportThreshold, minZ, supportPlacement)

        # Group adjacent faces into unified support regions on first layer.
        if not slicer._supportRegions?

            slicer._supportRegions = @groupAdjacentFaces(slicer._overhangFaces)

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

                # Generate grid pattern for this region covering the entire area.
                @generateRegionSupportPattern(
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

        return

    # Detect overhanging faces based on support threshold angle.
    # Returns face data needed for grouping adjacent faces.
    detectOverhangs: (mesh, thresholdAngle, buildPlateZ = 0, supportPlacement = 'buildPlate') ->

        return [] unless mesh?.geometry

        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

        geometry = mesh.geometry

        positions = geometry.attributes?.position
        return [] unless positions

        overhangFaces = []

        thresholdRad = thresholdAngle * Math.PI / 180

        faceCount = positions.count / 3

        for faceIndex in [0...faceCount]

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

                        # Store complete face information for grouping
                        overhangFaces.push({
                            faceIndex: faceIndex
                            vertices: [
                                { x: v0.x, y: v0.y, z: v0.z }
                                { x: v1.x, y: v1.y, z: v1.z }
                                { x: v2.x, y: v2.y, z: v2.z }
                            ]
                            centerX: centerX
                            centerY: centerY
                            centerZ: centerZ
                            angle: angleFromHorizontalDeg
                        })

        return overhangFaces

    # Group adjacent overhang faces that share edges.
    # This creates unified support regions instead of individual face supports.
    groupAdjacentFaces: (overhangFaces) ->

        return [] unless overhangFaces.length > 0

        # Helper function to check if two edges match (shared edge between faces)
        edgesMatch = (v1a, v1b, v2a, v2b, tolerance = 0.001) ->
            # Check if edge (v1a, v1b) matches edge (v2a, v2b) in either direction
            d1 = Math.sqrt((v1a.x - v2a.x) ** 2 + (v1a.y - v2a.y) ** 2 + (v1a.z - v2a.z) ** 2)
            d2 = Math.sqrt((v1b.x - v2b.x) ** 2 + (v1b.y - v2b.y) ** 2 + (v1b.z - v2b.z) ** 2)
            match1 = d1 < tolerance and d2 < tolerance

            d3 = Math.sqrt((v1a.x - v2b.x) ** 2 + (v1a.y - v2b.y) ** 2 + (v1a.z - v2b.z) ** 2)
            d4 = Math.sqrt((v1b.x - v2a.x) ** 2 + (v1b.y - v2a.y) ** 2 + (v1b.z - v2a.z) ** 2)
            match2 = d3 < tolerance and d4 < tolerance

            return match1 or match2

        # Helper function to check if two faces share an edge
        facesAreAdjacent = (face1, face2) ->
            v1 = face1.vertices
            v2 = face2.vertices

            # Check all three edges of face1 against all three edges of face2
            for i in [0...3]
                edge1Start = v1[i]
                edge1End = v1[(i + 1) % 3]

                for j in [0...3]
                    edge2Start = v2[j]
                    edge2End = v2[(j + 1) % 3]

                    if edgesMatch(edge1Start, edge1End, edge2Start, edge2End)
                        return true

            return false

        # Build adjacency graph using union-find
        parent = {}
        for i in [0...overhangFaces.length]
            parent[i] = i

        find = (x) ->
            if parent[x] != x
                parent[x] = find(parent[x])
            return parent[x]

        union = (x, y) ->
            rootX = find(x)
            rootY = find(y)
            if rootX != rootY
                parent[rootX] = rootY

        # Find all adjacent face pairs and union them
        for i in [0...overhangFaces.length]
            for j in [i+1...overhangFaces.length]
                if facesAreAdjacent(overhangFaces[i], overhangFaces[j])
                    union(i, j)

        # Group faces by their root parent
        groups = {}
        for i in [0...overhangFaces.length]
            root = find(i)
            groups[root] ?= []
            groups[root].push(overhangFaces[i])

        # Convert groups to support regions with collective bounds
        supportRegions = []
        for root, faces of groups

            # Calculate collective bounding box and average Z
            minX = Infinity
            maxX = -Infinity
            minY = Infinity
            maxY = -Infinity
            minZ = Infinity
            maxZ = -Infinity

            # Collect all unique vertices from all faces in group
            allVertices = []
            for face in faces
                for vertex in face.vertices
                    allVertices.push(vertex)
                    minX = Math.min(minX, vertex.x)
                    maxX = Math.max(maxX, vertex.x)
                    minY = Math.min(minY, vertex.y)
                    maxY = Math.max(maxY, vertex.y)
                    minZ = Math.min(minZ, vertex.z)
                    maxZ = Math.max(maxZ, vertex.z)

            # Calculate center of bounding box
            centerX = (minX + maxX) / 2
            centerY = (minY + maxY) / 2

            supportRegions.push({
                faces: faces
                vertices: allVertices
                minX: minX
                maxX: maxX
                minY: minY
                maxY: maxY
                minZ: minZ
                maxZ: maxZ
                centerX: centerX
                centerY: centerY
            })

        return supportRegions

    # Cluster overhang regions into unified support areas.
    # Uses grid-based spatial clustering to group nearby overhang points.
    clusterOverhangRegions: (overhangRegions, nozzleDiameter) ->

        return [] unless overhangRegions.length > 0

        # Clustering distance: group points within 10× nozzle diameter.
        # This creates larger unified support regions.
        clusterDistance = nozzleDiameter * 10

        clusters = []

        # Sort regions by Z coordinate for efficient clustering.
        sortedRegions = overhangRegions.slice().sort((a, b) -> a.z - b.z)

        for region in sortedRegions

            # Try to find an existing cluster for this region.
            foundCluster = null

            for cluster in clusters

                # Check if region is within cluster distance in XY plane.
                # Also check Z proximity (within 4× cluster distance).
                dx = region.x - cluster.centerX
                dy = region.y - cluster.centerY
                dz = Math.abs(region.z - cluster.maxZ)
                xyDist = Math.sqrt(dx * dx + dy * dy)

                # Cluster if close in XY and Z.
                if xyDist < clusterDistance and dz < (clusterDistance * 4)

                    foundCluster = cluster
                    break

            if foundCluster

                # Add to existing cluster.
                foundCluster.regions.push(region)

                # Update cluster bounds.
                foundCluster.minX = Math.min(foundCluster.minX, region.x)
                foundCluster.maxX = Math.max(foundCluster.maxX, region.x)
                foundCluster.minY = Math.min(foundCluster.minY, region.y)
                foundCluster.maxY = Math.max(foundCluster.maxY, region.y)
                foundCluster.minZ = Math.min(foundCluster.minZ, region.z)
                foundCluster.maxZ = Math.max(foundCluster.maxZ, region.z)

                # Update center as average of all regions.
                sumX = 0
                sumY = 0

                for r in foundCluster.regions

                    sumX += r.x
                    sumY += r.y

                foundCluster.centerX = sumX / foundCluster.regions.length
                foundCluster.centerY = sumY / foundCluster.regions.length

            else

                # Create new cluster.
                newCluster = {
                    regions: [region]
                    minX: region.x
                    maxX: region.x
                    minY: region.y
                    maxY: region.y
                    minZ: region.z
                    maxZ: region.z
                    centerX: region.x
                    centerY: region.y
                }

                clusters.push(newCluster)

        # Post-process clusters to ensure minimum size for proper coverage.
        # Even single-point clusters need area to generate support grid.
        minClusterSize = nozzleDiameter * 3

        for cluster in clusters

            width = cluster.maxX - cluster.minX
            height = cluster.maxY - cluster.minY

            if width < minClusterSize

                # Expand cluster in X direction.
                expansion = (minClusterSize - width) / 2
                cluster.minX -= expansion
                cluster.maxX += expansion

            if height < minClusterSize

                # Expand cluster in Y direction.
                expansion = (minClusterSize - height) / 2
                cluster.minY -= expansion
                cluster.maxY += expansion

        return clusters

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

    # Generate coordinated support pattern for a grouped region.
    # The region covers the collective area of all adjacent overhang faces.
    generateRegionSupportPattern: (slicer, region, currentZ, layerIndex, centerOffsetX, centerOffsetY, nozzleDiameter, layerSolidRegions, supportPlacement, minZ, layerHeight) ->

        verbose = slicer.getVerbose()

        # Support line spacing (grid pattern).
        # Use tighter spacing for better coverage.
        supportSpacing = nozzleDiameter * 2.0

        # Shrink region bounds to create gap between support and object.
        # This ensures supports don't touch the printed part for easy removal.
        supportGap = nozzleDiameter / 2
        minX = region.minX + supportGap
        maxX = region.maxX - supportGap
        minY = region.minY + supportGap
        maxY = region.maxY - supportGap

        # Add TYPE comment on every layer (not just layer 0) for visualizer.
        if verbose

            slicer.gcode += "; TYPE: SUPPORT" + slicer.newline

        if verbose and layerIndex is 0

            slicer.gcode += "; Support region: #{region.faces.length} adjacent overhang faces" + slicer.newline
            slicer.gcode += "; Coverage area: (#{minX.toFixed(2)}, #{minY.toFixed(2)}) to (#{maxX.toFixed(2)}, #{maxY.toFixed(2)}), maxZ=#{region.maxZ.toFixed(2)}" + slicer.newline

        travelSpeed = slicer.getTravelSpeed() * 60
        supportSpeed = slicer.getPerimeterSpeed() * 60 * 0.5
        supportLineWidth = nozzleDiameter * 0.8

        # Generate grid pattern within region bounds.
        # Alternate between X and Y direction lines each layer for strength.
        useXDirection = layerIndex % 2 is 0

        gridPoints = []

        if useXDirection

            # Generate horizontal (X-direction) lines.
            y = minY

            while y <= maxY

                x = minX

                while x <= maxX

                    point = { x: x, y: y }

                    # Check if this point can have support (collision detection).
                    canGenerate = @canGenerateSupportAt(
                        { x: x, y: y, z: region.maxZ },
                        currentZ,
                        layerIndex,
                        layerSolidRegions,
                        supportPlacement,
                        minZ,
                        layerHeight
                    )

                    if canGenerate

                        gridPoints.push(point)

                    x += supportSpacing

                y += supportSpacing

        else

            # Generate vertical (Y-direction) lines.
            x = minX

            while x <= maxX

                y = minY

                while y <= maxY

                    point = { x: x, y: y }

                    # Check if this point can have support (collision detection).
                    canGenerate = @canGenerateSupportAt(
                        { x: x, y: y, z: region.maxZ },
                        currentZ,
                        layerIndex,
                        layerSolidRegions,
                        supportPlacement,
                        minZ,
                        layerHeight
                    )

                    if canGenerate

                        gridPoints.push(point)

                    y += supportSpacing

                x += supportSpacing

        # Generate support lines.
        return unless gridPoints.length > 0

        # Group consecutive points into continuous lines.
        if useXDirection

            # Group by Y coordinate (horizontal lines).
            linesByY = {}

            for point in gridPoints

                yKey = Math.round(point.y * 100) / 100 # Round to avoid floating point issues.

                linesByY[yKey] ?= []
                linesByY[yKey].push(point)

            # Generate continuous lines for each Y level.
            for yKey, points of linesByY

                # Sort points by X coordinate.
                points.sort((a, b) -> a.x - b.x)

                # Generate zig-zag line through all points.
                for i in [0...points.length]

                    point = points[i]
                    offsetX = point.x + centerOffsetX
                    offsetY = point.y + centerOffsetY

                    if i is 0

                        # Travel to start of line.
                        slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, currentZ, null, travelSpeed)

                    else

                        # Extrude to next point.
                        prevPoint = points[i - 1]
                        dx = point.x - prevPoint.x
                        dy = point.y - prevPoint.y
                        distance = Math.sqrt(dx * dx + dy * dy)

                        if distance > 0.001

                            extrusionDelta = slicer.calculateExtrusion(distance, supportLineWidth)
                            slicer.cumulativeE += extrusionDelta

                            slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, currentZ, slicer.cumulativeE, supportSpeed)

        else

            # Group by X coordinate (vertical lines).
            linesByX = {}

            for point in gridPoints

                xKey = Math.round(point.x * 100) / 100

                linesByX[xKey] ?= []
                linesByX[xKey].push(point)

            # Generate continuous lines for each X level.
            for xKey, points of linesByX

                # Sort points by Y coordinate.
                points.sort((a, b) -> a.y - b.y)

                # Generate zig-zag line through all points.
                for i in [0...points.length]

                    point = points[i]
                    offsetX = point.x + centerOffsetX
                    offsetY = point.y + centerOffsetY

                    if i is 0

                        # Travel to start of line.
                        slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, currentZ, null, travelSpeed)

                    else

                        # Extrude to next point.
                        prevPoint = points[i - 1]
                        dx = point.x - prevPoint.x
                        dy = point.y - prevPoint.y
                        distance = Math.sqrt(dx * dx + dy * dy)

                        if distance > 0.001

                            extrusionDelta = slicer.calculateExtrusion(distance, supportLineWidth)
                            slicer.cumulativeE += extrusionDelta

                            slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, currentZ, slicer.cumulativeE, supportSpeed)

        return

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
