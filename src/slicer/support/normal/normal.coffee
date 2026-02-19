# Normal support generation module.
# Generates grid-pattern supports for standard FDM printing.

coders = require('../../gcode/coders')
pathsUtils = require('../../utils/paths')
primitives = require('../../utils/primitives')

module.exports =

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

    # Generate coordinated grid pattern for a support region.
    # Covers the entire bounding box of grouped faces with support.
    generateRegionSupportPattern: (slicer, region, z, layerIndex, centerOffsetX, centerOffsetY, nozzleDiameter, layerSolidRegions, supportPlacement, minZ, layerHeight) ->

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

        # Support line width and speed.
        supportLineWidth = nozzleDiameter * 0.8
        supportSpeed = slicer.getPerimeterSpeed() * 60 * 0.5  # Half speed for better adhesion

        # Alternate between X and Y direction lines per layer.
        useXDirection = layerIndex % 2 is 0

        # Generate grid of support points.
        supportPoints = []

        if useXDirection
            # X-direction lines (horizontal)
            y = minY
            while y <= maxY
                x = minX
                while x <= maxX
                    point = { x: x, y: y }
                    # Check collision detection
                    if @canGenerateSupportAt(slicer, point, z, layerSolidRegions, supportPlacement, minZ, layerHeight, layerIndex)
                        supportPoints.push(point)
                    x += supportSpacing
                y += supportSpacing
        else
            # Y-direction lines (vertical)
            x = minX
            while x <= maxX
                y = minY
                while y <= maxY
                    point = { x: x, y: y }
                    # Check collision detection
                    if @canGenerateSupportAt(slicer, point, z, layerSolidRegions, supportPlacement, minZ, layerHeight, layerIndex)
                        supportPoints.push(point)
                    y += supportSpacing
                x += supportSpacing

        return if supportPoints.length is 0

        # Group points into continuous lines.
        lines = []
        if useXDirection
            # Group by Y coordinate (horizontal lines)
            linesByY = {}
            for point in supportPoints
                yKey = point.y.toFixed(3)
                linesByY[yKey] ?= []
                linesByY[yKey].push(point)

            for yKey, linePoints of linesByY
                # Sort points by X
                linePoints.sort((a, b) -> a.x - b.x)
                lines.push(linePoints)
        else
            # Group by X coordinate (vertical lines)
            linesByX = {}
            for point in supportPoints
                xKey = point.x.toFixed(3)
                linesByX[xKey] ?= []
                linesByX[xKey].push(point)

            for xKey, linePoints of linesByX
                # Sort points by Y
                linePoints.sort((a, b) -> a.y - b.y)
                lines.push(linePoints)

        # Generate G-code for each line.
        for line in lines when line.length > 1
            # Travel to start of line
            startPoint = line[0]
            offsetX = startPoint.x + centerOffsetX
            offsetY = startPoint.y + centerOffsetY
            travelSpeed = slicer.getTravelSpeed() * 60

            slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeed)

            # Extrude through all points in line
            for i in [1...line.length]
                point = line[i]
                prevPoint = line[i - 1]

                dx = point.x - prevPoint.x
                dy = point.y - prevPoint.y
                distance = Math.sqrt(dx * dx + dy * dy)

                if distance > 0.001
                    extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
                    slicer.cumulativeE += extrusionDelta

                    offsetX = point.x + centerOffsetX
                    offsetY = point.y + centerOffsetY

                    slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, slicer.cumulativeE, supportSpeed)

        return

    # Check if support can be generated at a specific point.
    # Uses collision detection to prevent supports going through solid geometry.
    canGenerateSupportAt: (slicer, point, currentZ, layerSolidRegions, supportPlacement, minZ, layerHeight, currentLayerIndex) ->

        # Collision detection depends on placement mode
        if supportPlacement is 'buildPlate'
            # For buildPlate mode, check if there's ANY solid geometry at this XY position in layers below
            for layerData in layerSolidRegions
                if layerData.layerIndex < currentLayerIndex
                    if @isPointInsideSolidGeometry(point, layerData.paths, layerData.pathIsHole)
                        return false  # Blocked by solid geometry

            return true  # Clear path from build plate

        else if supportPlacement is 'everywhere'
            # For everywhere mode, find the highest solid surface below and check if it continues
            highestSolidZ = minZ
            hasBlockingGeometry = false

            for layerData in layerSolidRegions
                if layerData.layerIndex < currentLayerIndex
                    if @isPointInsideSolidGeometry(point, layerData.paths, layerData.pathIsHole)
                        hasBlockingGeometry = true
                        highestSolidZ = Math.max(highestSolidZ, layerData.z)

            if not hasBlockingGeometry
                return true  # Clear path from build plate

            # Check if solid geometry has ended (look back a few layers)
            layersToCheck = Math.min(3, currentLayerIndex)
            for i in [1..layersToCheck]
                checkLayerIndex = currentLayerIndex - i
                layerData = layerSolidRegions[checkLayerIndex]
                if @isPointInsideSolidGeometry(point, layerData.paths, layerData.pathIsHole)
                    return false  # Still solid

            # Solid geometry has ended, start support above it
            minimumSupportZ = highestSolidZ + layerHeight
            return currentZ >= minimumSupportZ

        return false

    # Check if a point is inside solid geometry using even-odd winding rule.
    isPointInsideSolidGeometry: (point, paths, pathIsHole) ->

        containmentCount = 0

        # Count how many paths contain this point
        for i in [0...paths.length]
            if primitives.pointInPolygon(point, paths[i])
                containmentCount++

        # Even-odd winding rule:
        # Odd count (1, 3, 5...) = inside solid geometry
        # Even count (0, 2, 4...) = outside or inside hole (empty space)
        return containmentCount > 0 and containmentCount % 2 is 1
