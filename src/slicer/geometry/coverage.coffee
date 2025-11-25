# Region coverage detection for exposed areas and skin generation.
# Includes flood fill, marching squares, and coverage calculation algorithms.

primitives = require('../utils/primitives')
bounds = require('../utils/bounds')

module.exports =

    # Check if a region (polygon) is substantially covered by another region.
    # Uses multi-point sampling for accurate coverage detection.
    # Returns the coverage ratio (0.0 to 1.0).
    calculateRegionCoverage: (testRegion, coveringRegions, sampleCount = 9) ->

        return 0 if not testRegion or testRegion.length < 3
        return 0 if not coveringRegions or coveringRegions.length is 0

        # Calculate bounds for generating sample points.
        testBounds = bounds.calculatePathBounds(testRegion)

        return 0 if not testBounds

        width = testBounds.maxX - testBounds.minX
        height = testBounds.maxY - testBounds.minY

        # Generate sample points in a grid pattern across the region.
        gridSize = Math.ceil(Math.sqrt(sampleCount))
        samplePoints = []

        for i in [0...gridSize]

            for j in [0...gridSize]

                # Calculate sample point position.
                xRatio = (i + 0.5) / gridSize
                yRatio = (j + 0.5) / gridSize

                sampleX = testBounds.minX + width * xRatio
                sampleY = testBounds.minY + height * yRatio

                samplePoints.push({ x: sampleX, y: sampleY })

        # Count how many sample points are inside the test region AND inside at least one covering region.
        validSamples = 0
        coveredSamples = 0

        for samplePoint in samplePoints

            # First check if sample point is actually inside the test region.
            if primitives.pointInPolygon(samplePoint, testRegion)

                validSamples++

                # Check if this point is covered by any of the covering regions.
                for coveringRegion in coveringRegions

                    if primitives.pointInPolygon(samplePoint, coveringRegion)

                        coveredSamples++

                        break

        # Return coverage ratio (0.0 to 1.0).
        return if validSamples > 0 then coveredSamples / validSamples else 0

    # Check if a skin area is completely inside a hole.
    # Returns true if the skin area is substantially (>90%) inside any hole.
    isSkinAreaInsideHole: (skinArea, holePolygons) ->

        return false if not skinArea or skinArea.length < 3
        return false if not holePolygons or holePolygons.length is 0

        # Check coverage by each hole.
        for holePolygon in holePolygons

            coverage = @calculateRegionCoverage(skinArea, [holePolygon], 12)

            if coverage > 0.90

                return true

        return false

    # Check if an area is inside any of the provided hole wall arrays.
    # This is a convenience function that checks against multiple wall types.
    isAreaInsideAnyHoleWall: (area, holeSkinWalls = [], holeInnerWalls = [], holeOuterWalls = []) ->

        return false if not area or area.length < 3

        # Check against skin walls.
        if holeSkinWalls.length > 0 and @isSkinAreaInsideHole(area, holeSkinWalls)
            return true

        # Check against inner walls.
        if holeInnerWalls.length > 0 and @isSkinAreaInsideHole(area, holeInnerWalls)
            return true

        # Check against outer walls.
        if holeOuterWalls.length > 0 and @isSkinAreaInsideHole(area, holeOuterWalls)
            return true

        return false

    # Calculate the exposed (uncovered) areas of a region.
    # Returns an array of polygons representing the exposed portions.
    calculateExposedAreas: (testRegion, coveringRegions, sampleCount = 81) ->

        return [testRegion] if not coveringRegions or coveringRegions.length is 0
        return [] if not testRegion or testRegion.length < 3

        # Calculate bounds for generating sample points.
        testBounds = bounds.calculatePathBounds(testRegion)

        return [testRegion] if not testBounds

        width = testBounds.maxX - testBounds.minX
        height = testBounds.maxY - testBounds.minY

        # Identify which covering regions are holes.
        holeIndices = new Set()

        for regionIdx in [0...coveringRegions.length]

            region = coveringRegions[regionIdx]
            continue if region.length < 3

            testPoint = region[0]

            for otherIdx in [0...coveringRegions.length]

                continue if otherIdx is regionIdx

                otherRegion = coveringRegions[otherIdx]
                continue if otherRegion.length < 3

                if primitives.pointInPolygon(testPoint, otherRegion)

                    holeIndices.add(regionIdx)

                    break

        # Separate covering regions into solid regions and holes.
        solidRegions = []
        holeRegions = []

        for region, idx in coveringRegions

            if holeIndices.has(idx)
                holeRegions.push(region)
            else
                solidRegions.push(region)

        # Generate dense sample points in a grid pattern.
        gridSize = Math.ceil(Math.sqrt(sampleCount))

        # Create 2D grid to track exposed points.
        exposedGrid = []

        for i in [0...gridSize]

            row = []

            for j in [0...gridSize]

                xRatio = (i + 0.5) / gridSize
                yRatio = (j + 0.5) / gridSize

                sampleX = testBounds.minX + width * xRatio
                sampleY = testBounds.minY + height * yRatio

                point = { x: sampleX, y: sampleY }

                isInside = primitives.pointInPolygon(point, testRegion)
                isCovered = false

                if isInside

                    if solidRegions.length > 0

                        for solidRegion in solidRegions

                            if primitives.pointInPolygon(point, solidRegion)

                                inHole = false

                                for holeRegion in holeRegions

                                    if primitives.pointInPolygon(point, holeRegion)

                                        inHole = true

                                        break

                                if not inHole

                                    isCovered = true

                                    break

                row.push(if isInside and not isCovered then point else null)

            exposedGrid.push(row)

        # Check if we have any exposed points.
        hasExposedPoints = false

        for row in exposedGrid

            for point in row

                if point?

                    hasExposedPoints = true

                    break

            break if hasExposedPoints

        return [] if not hasExposedPoints

        # Count exposed and total points.
        exposedCount = 0
        totalValidPoints = 0

        for row in exposedGrid

            for point in row

                if point?

                    exposedCount++
                    totalValidPoints++

                else

                    i = exposedGrid.indexOf(row)
                    j = row.indexOf(point)

                    xRatio = (i + 0.5) / gridSize
                    yRatio = (j + 0.5) / gridSize

                    sampleX = testBounds.minX + width * xRatio
                    sampleY = testBounds.minY + height * yRatio

                    testPoint = { x: sampleX, y: sampleY }

                    if primitives.pointInPolygon(testPoint, testRegion)

                        totalValidPoints++

        # Detect "ring" pattern.
        perimeterExposedCount = 0
        perimeterTotalCount = 0

        for i in [0...gridSize]

            for j in [0...gridSize]

                isPerimeter = (i is 0 or i is gridSize - 1 or j is 0 or j is gridSize - 1)

                continue if not isPerimeter

                xRatio = (i + 0.5) / gridSize
                yRatio = (j + 0.5) / gridSize
                sampleX = testBounds.minX + width * xRatio
                sampleY = testBounds.minY + height * yRatio
                testPoint = { x: sampleX, y: sampleY }

                if primitives.pointInPolygon(testPoint, testRegion)

                    perimeterTotalCount++

                    if exposedGrid[i][j]?
                        perimeterExposedCount++

        if perimeterTotalCount > 0 and (perimeterExposedCount / perimeterTotalCount) > 0.8 and exposedCount > 0

            return [testRegion]

        # Use marching squares for complex patterns.
        exposedAreas = []

        visited = []

        for i in [0...gridSize]

            row = []

            for j in [0...gridSize]

                row.push(false)

            visited.push(row)

        for i in [0...gridSize]

            for j in [0...gridSize]

                if exposedGrid[i][j]? and not visited[i][j]

                    region = @floodFillExposedRegion(exposedGrid, visited, i, j, gridSize)

                    if region.length > 0

                        exposedPoly = @marchingSquares(exposedGrid, region, testBounds, gridSize, testRegion[0].z)

                        if exposedPoly.length > 0
                            exposedAreas.push(exposedPoly)

        return if exposedAreas.length > 0 then exposedAreas else [testRegion]

    # Calculate non-exposed areas (areas that should get infill, not skin).
    calculateNonExposedAreas: (fullBoundary, exposedAreas) ->

        return [fullBoundary] if not exposedAreas or exposedAreas.length is 0

        fullBounds = bounds.calculatePathBounds(fullBoundary)

        return [] if not fullBounds

        gridSize = 9
        stepX = (fullBounds.maxX - fullBounds.minX) / (gridSize - 1)
        stepY = (fullBounds.maxY - fullBounds.minY) / (gridSize - 1)

        nonExposedPoints = []

        for i in [0...gridSize]

            for j in [0...gridSize]

                pointX = fullBounds.minX + i * stepX
                pointY = fullBounds.minY + j * stepY
                testPoint = { x: pointX, y: pointY }

                if primitives.pointInPolygon(testPoint, fullBoundary)

                    isExposed = false

                    for exposedArea in exposedAreas

                        if primitives.pointInPolygon(testPoint, exposedArea)

                            isExposed = true
                            break

                    if not isExposed

                        nonExposedPoints.push({ x: pointX, y: pointY, i: i, j: j })

        totalPoints = gridSize * gridSize
        nonExposedCount = nonExposedPoints.length

        if nonExposedCount > totalPoints * 0.8

            return [fullBoundary]

        return [] if nonExposedPoints.length is 0

        visited = new Set()
        nonExposedRegions = []

        for point in nonExposedPoints

            key = "#{point.i},#{point.j}"

            continue if visited.has(key)

            regionPoints = @floodFillNonExposedRegion(nonExposedPoints, visited, point.i, point.j, gridSize)

            continue if regionPoints.length is 0

            minX = Infinity
            maxX = -Infinity
            minY = Infinity
            maxY = -Infinity

            for p in regionPoints

                minX = Math.min(minX, p.x)
                maxX = Math.max(maxX, p.x)
                minY = Math.min(minY, p.y)
                maxY = Math.max(maxY, p.y)

            nonExposedPath = [
                { x: minX, y: minY }
                { x: maxX, y: minY }
                { x: maxX, y: maxY }
                { x: minX, y: maxY }
            ]

            nonExposedRegions.push(nonExposedPath)

        return nonExposedRegions

    # Flood fill helper for non-exposed region detection.
    floodFillNonExposedRegion: (nonExposedPoints, visited, startI, startJ, gridSize) ->

        pointMap = {}

        for point in nonExposedPoints

            key = "#{point.i},#{point.j}"
            pointMap[key] = point

        regionPoints = []
        stack = [{ i: startI, j: startJ }]

        while stack.length > 0

            current = stack.pop()
            key = "#{current.i},#{current.j}"

            continue if visited.has(key)
            continue if not pointMap[key]?

            visited.add(key)
            regionPoints.push(pointMap[key])

            neighbors = [
                { i: current.i - 1, j: current.j }
                { i: current.i + 1, j: current.j }
                { i: current.i, j: current.j - 1 }
                { i: current.i, j: current.j + 1 }
            ]

            for neighbor in neighbors

                continue if neighbor.i < 0 or neighbor.i >= gridSize
                continue if neighbor.j < 0 or neighbor.j >= gridSize

                neighborKey = "#{neighbor.i},#{neighbor.j}"

                if not visited.has(neighborKey) and pointMap[neighborKey]?

                    stack.push(neighbor)

        return regionPoints

    # Flood fill to find contiguous exposed regions.
    floodFillExposedRegion: (exposedGrid, visited, startI, startJ, gridSize) ->

        region = []
        stack = [{ i: startI, j: startJ }]

        while stack.length > 0
            pos = stack.pop()
            i = pos.i
            j = pos.j

            continue if i < 0 or i >= gridSize or j < 0 or j >= gridSize

            continue if visited[i][j] or not exposedGrid[i][j]?

            visited[i][j] = true
            region.push({ i: i, j: j, point: exposedGrid[i][j] })

            stack.push({ i: i + 1, j: j })
            stack.push({ i: i - 1, j: j })
            stack.push({ i: i, j: j + 1 })
            stack.push({ i: i, j: j - 1 })

        return region

    # Marching squares algorithm to trace smooth contours of exposed regions.
    marchingSquares: (exposedGrid, region, testBounds, gridSize, z) ->

        return [] if not region or region.length is 0

        regionSet = new Set()
        for cell in region
            regionSet.add("#{cell.i},#{cell.j}")

        width = testBounds.maxX - testBounds.minX
        height = testBounds.maxY - testBounds.minY
        cellWidth = width / gridSize
        cellHeight = height / gridSize

        isExposed = (i, j) ->
            return false if i < 0 or i >= gridSize or j < 0 or j >= gridSize
            return regionSet.has("#{i},#{j}")

        gridToWorld = (i, j) ->
            x: testBounds.minX + (i / gridSize) * width
            y: testBounds.minY + (j / gridSize) * height
            z: z

        vertexSet = new Set()
        vertices = []

        for cell in region
            i = cell.i
            j = cell.j

            # Check each corner.
            adjacentCells = [
                isExposed(i - 1, j - 1)
                isExposed(i, j - 1)
                isExposed(i - 1, j)
                isExposed(i, j)
            ]
            exposedCount = adjacentCells.filter((x) -> x).length
            if exposedCount > 0 and exposedCount < 4
                key = "#{i},#{j}"
                if not vertexSet.has(key)
                    vertexSet.add(key)
                    vertices.push({ i: i, j: j, point: gridToWorld(i, j) })

            adjacentCells = [
                isExposed(i, j - 1)
                isExposed(i + 1, j - 1)
                isExposed(i, j)
                isExposed(i + 1, j)
            ]
            exposedCount = adjacentCells.filter((x) -> x).length
            if exposedCount > 0 and exposedCount < 4
                key = "#{i + 1},#{j}"
                if not vertexSet.has(key)
                    vertexSet.add(key)
                    vertices.push({ i: i + 1, j: j, point: gridToWorld(i + 1, j) })

            adjacentCells = [
                isExposed(i - 1, j)
                isExposed(i, j)
                isExposed(i - 1, j + 1)
                isExposed(i, j + 1)
            ]
            exposedCount = adjacentCells.filter((x) -> x).length
            if exposedCount > 0 and exposedCount < 4
                key = "#{i},#{j + 1}"
                if not vertexSet.has(key)
                    vertexSet.add(key)
                    vertices.push({ i: i, j: j + 1, point: gridToWorld(i, j + 1) })

            adjacentCells = [
                isExposed(i, j)
                isExposed(i + 1, j)
                isExposed(i, j + 1)
                isExposed(i + 1, j + 1)
            ]
            exposedCount = adjacentCells.filter((x) -> x).length
            if exposedCount > 0 and exposedCount < 4
                key = "#{i + 1},#{j + 1}"
                if not vertexSet.has(key)
                    vertexSet.add(key)
                    vertices.push({ i: i + 1, j: j + 1, point: gridToWorld(i + 1, j + 1) })

        return [] if vertices.length < 3

        # Sort vertices by angle from centroid.
        centroidI = 0
        centroidJ = 0
        for vertex in vertices
            centroidI += vertex.i
            centroidJ += vertex.j
        centroidI /= vertices.length
        centroidJ /= vertices.length

        sortedVertices = vertices.slice().sort (a, b) ->
            angleA = Math.atan2(a.j - centroidJ, a.i - centroidI)
            angleB = Math.atan2(b.j - centroidJ, b.i - centroidI)
            return angleA - angleB

        contour = sortedVertices.map((v) -> v.point)

        # Simplify.
        simplifiedContour = []
        epsilon = Math.min(cellWidth, cellHeight) * 0.01

        for i in [0...contour.length]
            point = contour[i]

            if simplifiedContour.length is 0
                simplifiedContour.push(point)
            else
                lastPoint = simplifiedContour[simplifiedContour.length - 1]
                dx = point.x - lastPoint.x
                dy = point.y - lastPoint.y
                dist = Math.sqrt(dx * dx + dy * dy)

                if dist > epsilon
                    simplifiedContour.push(point)

        return [] if simplifiedContour.length < 3

        return @smoothContour(simplifiedContour)

    # Smooth a polygon contour using Chaikin's corner cutting algorithm.
    smoothContour: (contour, iterations = 1, ratio = 0.5) ->

        return contour if not contour or contour.length < 3

        smoothed = contour.slice()

        for iter in [0...iterations]

            newContour = []

            for i in [0...smoothed.length]

                p1 = smoothed[i]
                p2 = smoothed[(i + 1) % smoothed.length]

                q = {
                    x: p1.x + (p2.x - p1.x) * ratio
                    y: p1.y + (p2.y - p1.y) * ratio
                    z: p1.z
                }

                r = {
                    x: p1.x + (p2.x - p1.x) * (1 - ratio)
                    y: p1.y + (p2.y - p1.y) * (1 - ratio)
                    z: p1.z
                }

                newContour.push(q)
                newContour.push(r)

            smoothed = newContour

        return smoothed

    # Check if a hole path exists in a layer's paths.
    doesHoleExistInLayer: (holePath, layerPaths) ->

        return false if not holePath or holePath.length < 3
        return false if not layerPaths or layerPaths.length is 0

        # First identify which paths in layerPaths are holes.
        layerHoles = []

        for pathIdx in [0...layerPaths.length]

            path = layerPaths[pathIdx]
            continue if path.length < 3

            isHole = false

            for otherIdx in [0...layerPaths.length]

                continue if pathIdx is otherIdx

                otherPath = layerPaths[otherIdx]
                continue if otherPath.length < 3

                if primitives.pointInPolygon(path[0], otherPath)

                    isHole = true

                    break

            if isHole

                layerHoles.push(path)

        # Calculate centroid.
        holeCentroidX = 0
        holeCentroidY = 0

        for point in holePath

            holeCentroidX += point.x
            holeCentroidY += point.y

        holeCentroidX /= holePath.length
        holeCentroidY /= holePath.length

        holeBounds = bounds.calculatePathBounds(holePath)

        return false if not holeBounds

        holeWidth = holeBounds.maxX - holeBounds.minX
        holeHeight = holeBounds.maxY - holeBounds.minY
        holeSize = Math.sqrt(holeWidth * holeWidth + holeHeight * holeHeight)

        for layerHole in layerHoles

            layerHoleCentroidX = 0
            layerHoleCentroidY = 0

            for point in layerHole

                layerHoleCentroidX += point.x
                layerHoleCentroidY += point.y

            layerHoleCentroidX /= layerHole.length
            layerHoleCentroidY /= layerHole.length

            layerHoleBounds = bounds.calculatePathBounds(layerHole)

            continue if not layerHoleBounds

            dx = holeCentroidX - layerHoleCentroidX
            dy = holeCentroidY - layerHoleCentroidY
            centroidDistance = Math.sqrt(dx * dx + dy * dy)

            layerHoleWidth = layerHoleBounds.maxX - layerHoleBounds.minX
            layerHoleHeight = layerHoleBounds.maxY - layerHoleBounds.minY
            layerHoleSize = Math.sqrt(layerHoleWidth * layerHoleWidth + layerHoleHeight * layerHoleHeight)

            sizeDifference = Math.abs(holeSize - layerHoleSize)

            centroidThreshold = Math.max(0.5, holeSize * 0.1)
            sizeThreshold = holeSize * 0.2

            if centroidDistance < centroidThreshold and sizeDifference < sizeThreshold

                return true

        return false
