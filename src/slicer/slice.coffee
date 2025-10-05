# Main slicing method for Polyslice.

coders = require('./coders')

Polytree = require('@jgphilpott/polytree')

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

        # Generate initialization sequence.
        slicer.gcode += coders.codeMessage(slicer, "Starting print...")

        if slicer.getAutohome()

            slicer.gcode += coders.codeAutohome(slicer)

        slicer.gcode += coders.codeWorkspacePlane(slicer)
        slicer.gcode += coders.codeLengthUnit(slicer)

        # Heat up bed and nozzle.
        bedTemp = slicer.getBedTemperature()
        nozzleTemp = slicer.getNozzleTemperature()

        if bedTemp > 0

            slicer.gcode += coders.codeMessage(slicer, "Heating bed...")
            slicer.gcode += coders.codeBedTemperature(slicer, bedTemp, true)

        if nozzleTemp > 0

            slicer.gcode += coders.codeMessage(slicer, "Heating nozzle...")
            slicer.gcode += coders.codeNozzleTemperature(slicer, nozzleTemp, true)

        # Enable fan if configured.
        fanSpeed = slicer.getFanSpeed()

        if fanSpeed > 0

            slicer.gcode += coders.codeFanSpeed(slicer, fanSpeed)

        # Get mesh bounding box for slicing.
        boundingBox = new THREE.Box3().setFromObject(mesh)
        minZ = boundingBox.min.z
        maxZ = boundingBox.max.z
        layerHeight = slicer.getLayerHeight()

        # Calculate number of layers.
        numLayers = Math.ceil((maxZ - minZ) / layerHeight)

        slicer.gcode += coders.codeMessage(slicer, "Printing #{numLayers} layers...")

        # Slice and generate G-code for each layer.
        for layerIndex in [0...numLayers]

            currentZ = minZ + (layerIndex + 1) * layerHeight
            currentZ = Math.min(currentZ, maxZ) # Clamp to max Z.

            slicer.gcode += coders.codeMessage(slicer, "Layer #{layerIndex + 1}/#{numLayers}")

            # Slice the mesh at this Z height.
            layerPaths = @sliceAtHeight(mesh, currentZ, layerHeight)

            # Generate G-code for this layer.
            @generateLayerGCode(slicer, layerPaths, currentZ, layerIndex)

        # End sequence.
        slicer.gcode += coders.codeMessage(slicer, "Print completed!")
        slicer.gcode += coders.codeFanSpeed(slicer, 0)
        slicer.gcode += coders.codeNozzleTemperature(slicer, 0, false)
        slicer.gcode += coders.codeBedTemperature(slicer, 0, false)

        if slicer.getAutohome()

            slicer.gcode += coders.codeAutohome(slicer)

        slicer.gcode += coders.codeMessage(slicer, "Ready for next print")

        return slicer.gcode

    # Extract mesh from scene object.
    extractMesh: (scene) ->

        return null if not scene

        # If scene is already a mesh, return it.
        if scene.isMesh

            return scene

        # If scene has children, find first mesh.
        if scene.children and scene.children.length > 0

            for child in scene.children

                if child.isMesh

                    return child

        # If scene has a mesh property.
        if scene.mesh and scene.mesh.isMesh

            return scene.mesh

        return null

    # Slice mesh at a specific Z height to get 2D paths.
    sliceAtHeight: (mesh, z, layerHeight) ->

        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

        # Get geometry from mesh.
        geometry = mesh.geometry

        # Ensure we have position attribute.
        if not geometry.attributes or not geometry.attributes.position

            return []

        positions = geometry.attributes.position
        indices = geometry.index

        paths = []
        edges = []

        # Iterate through triangles and find intersections with Z plane.
        triangleCount = if indices then indices.count / 3 else positions.count / 3

        for triangleIndex in [0...triangleCount]

            # Get triangle vertices.
            if indices

                i0 = indices.getX(triangleIndex * 3)
                i1 = indices.getX(triangleIndex * 3 + 1)
                i2 = indices.getX(triangleIndex * 3 + 2)

            else

                i0 = triangleIndex * 3
                i1 = triangleIndex * 3 + 1
                i2 = triangleIndex * 3 + 2

            # Get vertex positions.
            v0 = new THREE.Vector3(positions.getX(i0), positions.getY(i0), positions.getZ(i0))
            v1 = new THREE.Vector3(positions.getX(i1), positions.getY(i1), positions.getZ(i1))
            v2 = new THREE.Vector3(positions.getX(i2), positions.getY(i2), positions.getZ(i2))

            # Apply mesh transformations.
            v0.applyMatrix4(mesh.matrixWorld)
            v1.applyMatrix4(mesh.matrixWorld)
            v2.applyMatrix4(mesh.matrixWorld)

            # Check if triangle intersects with Z plane.
            intersection = @intersectTriangleWithPlane(v0, v1, v2, z)

            if intersection

                edges.push(intersection)

        # Connect edges to form closed paths.
        paths = @connectEdgesToPaths(edges)

        return paths

    # Find intersection of triangle with horizontal plane at Z.
    intersectTriangleWithPlane: (v0, v1, v2, z) ->

        vertices = [v0, v1, v2]
        intersections = []

        # Check each edge of the triangle.
        for edgeIndex in [0...3]

            vStart = vertices[edgeIndex]
            vEnd = vertices[(edgeIndex + 1) % 3]

            # Check if edge crosses the plane.
            if (vStart.z <= z and vEnd.z >= z) or (vStart.z >= z and vEnd.z <= z)

                # Skip if both vertices are exactly on the plane.
                if vStart.z is z and vEnd.z is z

                    continue

                # Calculate intersection point.
                if Math.abs(vEnd.z - vStart.z) < 0.0001

                    # Edge is parallel to plane.
                    continue

                t = (z - vStart.z) / (vEnd.z - vStart.z)
                intersectionX = vStart.x + t * (vEnd.x - vStart.x)
                intersectionY = vStart.y + t * (vEnd.y - vStart.y)

                intersections.push({x: intersectionX, y: intersectionY})

        # Return edge if we have exactly 2 intersections.
        if intersections.length is 2

            return {start: intersections[0], end: intersections[1]}

        return null

    # Connect edges to form closed paths.
    connectEdgesToPaths: (edges) ->

        return [] if edges.length is 0

        paths = []
        usedEdges = new Set()
        epsilon = 0.001 # Tolerance for point matching.

        # Simple greedy path connection.
        for startEdgeIndex in [0...edges.length]

            continue if usedEdges.has(startEdgeIndex)

            currentPath = []
            currentEdge = edges[startEdgeIndex]
            usedEdges.add(startEdgeIndex)

            currentPath.push(currentEdge.start)
            currentPath.push(currentEdge.end)

            # Try to extend the path.
            searching = true

            while searching

                searching = false
                lastPoint = currentPath[currentPath.length - 1]

                # Find next connecting edge.
                for nextEdgeIndex in [0...edges.length]

                    continue if usedEdges.has(nextEdgeIndex)

                    nextEdge = edges[nextEdgeIndex]

                    # Check if next edge connects to current path end.
                    if @pointsMatch(lastPoint, nextEdge.start, epsilon)

                        currentPath.push(nextEdge.end)
                        usedEdges.add(nextEdgeIndex)
                        searching = true
                        break

                    else if @pointsMatch(lastPoint, nextEdge.end, epsilon)

                        currentPath.push(nextEdge.start)
                        usedEdges.add(nextEdgeIndex)
                        searching = true
                        break

            # Only add paths with at least 3 points.
            if currentPath.length >= 3

                paths.push(currentPath)

        return paths

    # Check if two points are within epsilon distance.
    pointsMatch: (p1, p2, epsilon) ->

        dx = p1.x - p2.x
        dy = p1.y - p2.y
        distSq = dx * dx + dy * dy

        return distSq < epsilon * epsilon

    # Generate G-code for a single layer.
    generateLayerGCode: (slicer, paths, z, layerIndex) ->

        return if paths.length is 0

        # Process each closed path (perimeter).
        for path in paths

            # Move to start of path (travel move).
            firstPoint = path[0]

            slicer.gcode += coders.codeLinearMovement(slicer, firstPoint.x, firstPoint.y, z, null, slicer.getTravelSpeed())

            # Print perimeter.
            for pointIndex in [1...path.length]

                point = path[pointIndex]
                prevPoint = path[pointIndex - 1]

                # Calculate distance for extrusion.
                dx = point.x - prevPoint.x
                dy = point.y - prevPoint.y
                distance = Math.sqrt(dx * dx + dy * dy)

                # Calculate extrusion amount.
                extrusion = slicer.calculateExtrusion(distance, slicer.getNozzleDiameter())

                slicer.gcode += coders.codeLinearMovement(slicer, point.x, point.y, z, extrusion, slicer.getPerimeterSpeed())

            # Close the path by returning to start.
            if path.length > 2

                firstPoint = path[0]
                lastPoint = path[path.length - 1]

                dx = firstPoint.x - lastPoint.x
                dy = firstPoint.y - lastPoint.y
                distance = Math.sqrt(dx * dx + dy * dy)

                if distance > 0.001

                    extrusion = slicer.calculateExtrusion(distance, slicer.getNozzleDiameter())
                    slicer.gcode += coders.codeLinearMovement(slicer, firstPoint.x, firstPoint.y, z, extrusion, slicer.getPerimeterSpeed())
