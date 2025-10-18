# Geometry helper functions for slicing operations.

module.exports =

    # Convert Polytree line segments (Line3 objects) to closed paths.
    connectSegmentsToPaths: (segments) ->

        return [] if not segments or segments.length is 0

        paths = []
        usedSegments = new Set()
        epsilon = 0.001 # Tolerance for point matching.

        # Convert segments to simple edge format for easier processing.
        edges = []

        for segment in segments

            edges.push({
                start: {x: segment.start.x, y: segment.start.y}
                end: {x: segment.end.x, y: segment.end.y}
            })

        # Simple greedy path connection.
        for startEdgeIndex in [0...edges.length]

            continue if usedSegments.has(startEdgeIndex)

            currentPath = []
            currentEdge = edges[startEdgeIndex]
            usedSegments.add(startEdgeIndex)

            currentPath.push(currentEdge.start)
            currentPath.push(currentEdge.end)

            # Try to extend the path.
            searching = true
            maxIterations = edges.length * 2 # Prevent infinite loops.
            iterations = 0

            while searching and iterations < maxIterations

                iterations++

                searching = false
                lastPoint = currentPath[currentPath.length - 1]

                # Find next connecting edge.
                for nextEdgeIndex in [0...edges.length]

                    continue if usedSegments.has(nextEdgeIndex)

                    nextEdge = edges[nextEdgeIndex]

                    # Check if next edge connects to current path end.
                    if @pointsMatch(lastPoint, nextEdge.start, epsilon)

                        currentPath.push(nextEdge.end)
                        usedSegments.add(nextEdgeIndex)

                        searching = true

                        break

                    else if @pointsMatch(lastPoint, nextEdge.end, epsilon)

                        currentPath.push(nextEdge.start)
                        usedSegments.add(nextEdgeIndex)

                        searching = true

                        break

            # Only add paths with at least 3 points and remove duplicate last point if it matches first.
            if currentPath.length >= 3

                firstPoint = currentPath[0]
                lastPoint = currentPath[currentPath.length - 1]

                # Remove last point if it's the same as first (closed loop).
                if @pointsMatch(firstPoint, lastPoint, epsilon)

                    currentPath.pop()

                # Only add if still have at least 3 points.
                if currentPath.length >= 3 then paths.push(currentPath)

        return paths

    # Check if two points are within epsilon distance.
    pointsMatch: (p1, p2, epsilon) ->

        dx = p1.x - p2.x
        dy = p1.y - p2.y

        distSq = dx * dx + dy * dy

        return distSq < epsilon * epsilon

    # Create an inset path (shrink inward by specified distance).
    # First simplifies path by merging near-collinear edges, then applies perpendicular offset.
    createInsetPath: (path, insetDistance) ->

        return [] if path.length < 3

        # Step 1: Simplify the path by detecting significant corners only.
        # A significant corner is one where the direction changes by more than a threshold.
        simplifiedPath = []
        angleThreshold = 0.05 # ~2.9 degrees in radians

        n = path.length

        for i in [0...n]

            prevIdx = if i is 0 then n - 1 else i - 1
            nextIdx = if i is n - 1 then 0 else i + 1

            p1 = path[prevIdx]
            p2 = path[i]
            p3 = path[nextIdx]

            # Calculate vectors for the two edges.
            v1x = p2.x - p1.x
            v1y = p2.y - p1.y
            v2x = p3.x - p2.x
            v2y = p3.y - p2.y

            len1 = Math.sqrt(v1x * v1x + v1y * v1y)
            len2 = Math.sqrt(v2x * v2x + v2y * v2y)

            # Skip if either edge is degenerate.
            if len1 < 0.0001 or len2 < 0.0001 then continue

            # Normalize vectors.
            v1x /= len1
            v1y /= len1
            v2x /= len2
            v2y /= len2

            # Calculate cross product to detect direction change.
            cross = v1x * v2y - v1y * v2x

            # If direction changes significantly, this is a real corner.
            if Math.abs(cross) > angleThreshold then simplifiedPath.push(p2)

        # If simplification resulted in < 4 points for rectangular shapes, use original path.
        # We want at least 4 corners for proper rectangular insets.
        if simplifiedPath.length < 4 then simplifiedPath = path

        # Step 2: Create inset using the simplified path.
        insetPath = []
        n = simplifiedPath.length

        # Calculate signed area to determine winding order.
        signedArea = 0

        for i in [0...n]

            nextIdx = if i is n - 1 then 0 else i + 1
            signedArea += simplifiedPath[i].x * simplifiedPath[nextIdx].y - simplifiedPath[nextIdx].x * simplifiedPath[i].y

        isCCW = signedArea > 0

        # Create offset lines for each edge.
        offsetLines = []

        for i in [0...n]

            nextIdx = if i is n - 1 then 0 else i + 1

            p1 = simplifiedPath[i]
            p2 = simplifiedPath[nextIdx]

            # Edge vector.
            edgeX = p2.x - p1.x
            edgeY = p2.y - p1.y

            edgeLength = Math.sqrt(edgeX * edgeX + edgeY * edgeY)

            if edgeLength < 0.0001 then continue

            # Normalize.
            edgeX /= edgeLength
            edgeY /= edgeLength

            if isCCW # Perpendicular inward normal.

                normalX = -edgeY
                normalY = edgeX

            else

                normalX = edgeY
                normalY = -edgeX

            # Offset the edge.
            offset1X = p1.x + normalX * insetDistance
            offset1Y = p1.y + normalY * insetDistance
            offset2X = p2.x + normalX * insetDistance
            offset2Y = p2.y + normalY * insetDistance

            offsetLines.push({
                p1: { x: offset1X, y: offset1Y }
                p2: { x: offset2X, y: offset2Y }
                originalIdx: i
            })

        # Find intersections of adjacent offset lines.
        for i in [0...offsetLines.length]

            prevIdx = if i is 0 then offsetLines.length - 1 else i - 1

            line1 = offsetLines[prevIdx]
            line2 = offsetLines[i]

            intersection = @lineIntersection(line1.p1, line1.p2, line2.p1, line2.p2)

            origVertex = simplifiedPath[line2.originalIdx]

            if intersection

                insetPath.push({ x: intersection.x, y: intersection.y, z: origVertex.z })

            else

                # Parallel lines - use midpoint of offset segment.
                insetPath.push({
                    x: line2.p1.x
                    y: line2.p1.y
                    z: origVertex.z
                })

        # Validate the inset path to detect when the area is too small.
        # When a path becomes too small (e.g., near the tip of a cone), the inset calculation
        # can produce invalid results where the inset path expands instead of contracts.
        # This happens because offset line intersections can fall outside the original boundary
        # when the inset distance is larger than the path's "radius".
        #
        # Detection strategy:
        # 1. Check if the inset path is meaningfully smaller than the original
        # 2. Check if the remaining area is large enough for meaningful geometry
        # 3. Reject paths that are too small or have insufficient area
        if insetPath.length >= 3

            # Calculate bounding boxes.
            originalMinX = Infinity
            originalMaxX = -Infinity
            originalMinY = Infinity
            originalMaxY = -Infinity

            for point in simplifiedPath
                originalMinX = Math.min(originalMinX, point.x)
                originalMaxX = Math.max(originalMaxX, point.x)
                originalMinY = Math.min(originalMinY, point.y)
                originalMaxY = Math.max(originalMaxY, point.y)

            originalWidth = originalMaxX - originalMinX
            originalHeight = originalMaxY - originalMinY

            insetMinX = Infinity
            insetMaxX = -Infinity
            insetMinY = Infinity
            insetMaxY = -Infinity

            for point in insetPath
                insetMinX = Math.min(insetMinX, point.x)
                insetMaxX = Math.max(insetMaxX, point.x)
                insetMinY = Math.min(insetMinY, point.y)
                insetMaxY = Math.max(insetMaxY, point.y)

            insetWidth = insetMaxX - insetMinX
            insetHeight = insetMaxY - insetMinY

            # The inset path should be smaller in both dimensions.
            # We expect the bounding box to shrink by approximately 2 * insetDistance (both sides).
            # However, due to geometric variations (corners, few vertices, etc.), we use a lenient threshold.
            # If the inset is not at least 10% smaller in both dimensions, reject it.
            # This 10% threshold accounts for edge cases like sphere poles or cone tips.
            expectedSizeReduction = insetDistance * 2 * 0.1

            widthReduction = originalWidth - insetWidth
            heightReduction = originalHeight - insetHeight

            # Check if either dimension didn't shrink enough (or expanded).
            if widthReduction < expectedSizeReduction or heightReduction < expectedSizeReduction

                # Inset path is not sufficiently smaller than original - path is too small.
                return []

            # Additional check: Ensure the inset path has enough area for meaningful geometry.
            # The minimum viable dimension should be very small - only reject truly degenerate paths.
            # This prevents generating paths where the area is actually zero (single point).
            # Use a threshold of 0.2 * insetDistance to allow small but valid geometry.
            minViableDimension = insetDistance * 0.2

            if insetWidth < minViableDimension or insetHeight < minViableDimension

                # Inset path is too small - approaching a point or line.
                return []

        return insetPath

    # Calculate intersection point of two line segments.
    lineIntersection: (p1, p2, p3, p4) ->

        x1 = p1.x
        y1 = p1.y

        x2 = p2.x
        y2 = p2.y

        x3 = p3.x
        y3 = p3.y

        x4 = p4.x
        y4 = p4.y

        denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)

        # Lines are parallel or coincident.
        if Math.abs(denom) < 0.0001 then return null

        t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom

        # Calculate intersection point.
        x = x1 + t * (x2 - x1)
        y = y1 + t * (y2 - y1)

        return { x: x, y: y }

    # Clip a line segment to a polygon boundary.
    # Returns an array of line segments that are inside the polygon.
    #
    # This function is critical for skin infill generation - it ensures that infill lines
    # stay within circular and irregular boundary shapes, not just rectangular bounding boxes.
    #
    # Algorithm:
    # 1. Find all intersection points between the line and polygon edges
    # 2. Determine which line endpoints are inside the polygon
    # 3. Sort all points by their parametric position along the line (t value 0-1)
    # 4. Test midpoints between consecutive intersections to identify inside segments
    # 5. Return only the portions of the line that lie within the polygon
    #
    # Note: This is NOT the Sutherland-Hodgman algorithm (which is for polygon clipping).
    # This is specifically designed for line segment to polygon clipping.
    clipLineToPolygon: (lineStart, lineEnd, polygon) ->

        return [] if not polygon or polygon.length < 3
        return [] if not lineStart or not lineEnd

        # Find all intersection points of the line with polygon edges.
        intersections = []

        # Add the line endpoints with their inside/outside status.
        lineStartInside = @pointInPolygon(lineStart, polygon)
        lineEndInside = @pointInPolygon(lineEnd, polygon)

        if lineStartInside
            intersections.push({ point: lineStart, t: 0, isEndpoint: true })

        if lineEndInside
            intersections.push({ point: lineEnd, t: 1, isEndpoint: true })

        # Find intersections with polygon edges.
        for i in [0...polygon.length]

            nextIdx = if i is polygon.length - 1 then 0 else i + 1

            edgeStart = polygon[i]
            edgeEnd = polygon[nextIdx]

            intersection = @lineSegmentIntersection(lineStart, lineEnd, edgeStart, edgeEnd)

            if intersection

                # Calculate parametric t value (0 to 1) along the line.
                dx = lineEnd.x - lineStart.x
                dy = lineEnd.y - lineStart.y

                if Math.abs(dx) > Math.abs(dy)
                    t = (intersection.x - lineStart.x) / dx
                else
                    t = (intersection.y - lineStart.y) / dy

                # Only add if not already added as an endpoint (with small tolerance).
                isNew = true
                for existing in intersections
                    if Math.abs(existing.t - t) < 0.0001
                        isNew = false
                        break

                if isNew
                    intersections.push({ point: intersection, t: t, isEndpoint: false })

        # Return empty if no intersections found.
        return [] if intersections.length < 2

        # Sort intersections by parametric t value.
        intersections.sort((a, b) -> a.t - b.t)

        # Build segments from pairs of intersections.
        # Segments between consecutive intersections are inside if the midpoint is inside.
        segments = []

        for i in [0...intersections.length - 1]

            startIntersection = intersections[i]
            endIntersection = intersections[i + 1]

            # Calculate midpoint to test if this segment is inside.
            midT = (startIntersection.t + endIntersection.t) / 2
            midX = lineStart.x + midT * (lineEnd.x - lineStart.x)
            midY = lineStart.y + midT * (lineEnd.y - lineStart.y)
            midPoint = { x: midX, y: midY }

            if @pointInPolygon(midPoint, polygon)

                segments.push({
                    start: startIntersection.point
                    end: endIntersection.point
                })

        return segments

    # Calculate intersection point of two line segments (with boundary checking).
    # Returns the intersection point if it exists within both segments, null otherwise.
    lineSegmentIntersection: (p1, p2, p3, p4) ->

        x1 = p1.x
        y1 = p1.y

        x2 = p2.x
        y2 = p2.y

        x3 = p3.x
        y3 = p3.y

        x4 = p4.x
        y4 = p4.y

        denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)

        # Lines are parallel or coincident.
        if Math.abs(denom) < 0.0001 then return null

        t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
        u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom

        # Check if intersection is within both segments.
        if t >= 0 and t <= 1 and u >= 0 and u <= 1

            # Calculate intersection point.
            x = x1 + t * (x2 - x1)
            y = y1 + t * (y2 - y1)

            return { x: x, y: y }

        return null

    # Calculate the bounding box of a path.
    calculatePathBounds: (path) ->

        return null if not path or path.length is 0

        minX = Infinity
        maxX = -Infinity
        minY = Infinity
        maxY = -Infinity

        for point in path

            minX = Math.min(minX, point.x)
            maxX = Math.max(maxX, point.x)
            minY = Math.min(minY, point.y)
            maxY = Math.max(maxY, point.y)

        return {
            minX: minX
            maxX: maxX
            minY: minY
            maxY: maxY
        }

    # Check if two bounding boxes overlap in XY plane.
    # Uses a small tolerance to account for touching edges.
    boundsOverlap: (bounds1, bounds2, tolerance = 0.1) ->

        return false if not bounds1 or not bounds2

        # Check if bounds are separated on X axis.
        if bounds1.maxX + tolerance < bounds2.minX or bounds2.maxX + tolerance < bounds1.minX

            return false

        # Check if bounds are separated on Y axis.
        if bounds1.maxY + tolerance < bounds2.minY or bounds2.maxY + tolerance < bounds1.minY

            return false

        # Boxes overlap.
        return true

    # Calculate the overlapping area between two bounding boxes.
    calculateOverlapArea: (bounds1, bounds2) ->

        return 0 if not bounds1 or not bounds2

        # Check if bounds overlap first.
        if not @boundsOverlap(bounds1, bounds2, 0)

            return 0

        # Calculate overlap dimensions.
        overlapMinX = Math.max(bounds1.minX, bounds2.minX)
        overlapMaxX = Math.min(bounds1.maxX, bounds2.maxX)
        overlapMinY = Math.max(bounds1.minY, bounds2.minY)
        overlapMaxY = Math.min(bounds1.maxY, bounds2.maxY)

        overlapWidth = overlapMaxX - overlapMinX
        overlapHeight = overlapMaxY - overlapMinY

        # Return overlap area.
        return overlapWidth * overlapHeight

    # Check if a point is inside a polygon using ray casting algorithm.
    # This is the standard point-in-polygon test used in computational geometry.
    pointInPolygon: (point, polygon) ->

        return false if not point or not polygon or polygon.length < 3

        x = point.x
        y = point.y

        inside = false

        j = polygon.length - 1

        for i in [0...polygon.length]

            xi = polygon[i].x
            yi = polygon[i].y
            xj = polygon[j].x
            yj = polygon[j].y

            # Ray casting: cast a ray from point to infinity and count intersections.
            intersect = ((yi > y) isnt (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

            if intersect

                inside = not inside

            j = i

        return inside

    # Check if a region (polygon) is substantially covered by another region.
    # Uses multi-point sampling for accurate coverage detection.
    # Returns the coverage ratio (0.0 to 1.0).
    calculateRegionCoverage: (testRegion, coveringRegions, sampleCount = 9) ->

        return 0 if not testRegion or testRegion.length < 3
        return 0 if not coveringRegions or coveringRegions.length is 0

        # Calculate bounds for generating sample points.
        bounds = @calculatePathBounds(testRegion)

        return 0 if not bounds

        width = bounds.maxX - bounds.minX
        height = bounds.maxY - bounds.minY

        # Generate sample points in a grid pattern across the region.
        # Use sqrt(sampleCount) to get grid dimensions.
        gridSize = Math.ceil(Math.sqrt(sampleCount))
        samplePoints = []

        for i in [0...gridSize]

            for j in [0...gridSize]

                # Calculate sample point position.
                xRatio = (i + 0.5) / gridSize
                yRatio = (j + 0.5) / gridSize

                sampleX = bounds.minX + width * xRatio
                sampleY = bounds.minY + height * yRatio

                samplePoints.push({ x: sampleX, y: sampleY })

        # Count how many sample points are inside the test region AND inside at least one covering region.
        validSamples = 0
        coveredSamples = 0

        for samplePoint in samplePoints

            # First check if sample point is actually inside the test region.
            if @pointInPolygon(samplePoint, testRegion)

                validSamples++

                # Check if this point is covered by any of the covering regions.
                for coveringRegion in coveringRegions

                    if @pointInPolygon(samplePoint, coveringRegion)

                        coveredSamples++

                        break

        # Return coverage ratio (0.0 to 1.0).
        return if validSamples > 0 then coveredSamples / validSamples else 0

    # Calculate the exposed (uncovered) areas of a region.
    # Returns an array of polygons representing the exposed portions.
    # Uses dense sampling to identify uncovered areas and groups them into regions.
    calculateExposedAreas: (testRegion, coveringRegions, sampleCount = 81) ->

        return [testRegion] if not coveringRegions or coveringRegions.length is 0
        return [] if not testRegion or testRegion.length < 3

        # Calculate bounds for generating sample points.
        bounds = @calculatePathBounds(testRegion)

        return [testRegion] if not bounds

        width = bounds.maxX - bounds.minX
        height = bounds.maxY - bounds.minY

        # Generate dense sample points in a grid pattern across the region.
        # Use sqrt(sampleCount) to get grid dimensions.
        gridSize = Math.ceil(Math.sqrt(sampleCount))

        # Create 2D grid to track exposed points.
        exposedGrid = []

        for i in [0...gridSize]

            row = []

            for j in [0...gridSize]

                # Calculate sample point position.
                xRatio = (i + 0.5) / gridSize
                yRatio = (j + 0.5) / gridSize

                sampleX = bounds.minX + width * xRatio
                sampleY = bounds.minY + height * yRatio

                point = { x: sampleX, y: sampleY }

                # Check if point is inside test region and NOT covered.
                isInside = @pointInPolygon(point, testRegion)
                isCovered = false

                if isInside

                    for coveringRegion in coveringRegions

                        if @pointInPolygon(point, coveringRegion)

                            isCovered = true

                            break

                # Mark as exposed if inside but not covered.
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

        # If no exposed points, return empty array (fully covered).
        return [] if not hasExposedPoints

        # If most points are exposed (>80%), return the entire region.
        # This avoids unnecessary computation for mostly-exposed surfaces.
        exposedCount = 0
        totalValidPoints = 0

        for row in exposedGrid

            for point in row

                if point?

                    exposedCount++
                    totalValidPoints++

                else

                    # Check if this grid position was inside the test region.
                    i = exposedGrid.indexOf(row)
                    j = row.indexOf(point)

                    xRatio = (i + 0.5) / gridSize
                    yRatio = (j + 0.5) / gridSize

                    sampleX = bounds.minX + width * xRatio
                    sampleY = bounds.minY + height * yRatio

                    testPoint = { x: sampleX, y: sampleY }

                    if @pointInPolygon(testPoint, testRegion)

                        totalValidPoints++

        if totalValidPoints > 0 and exposedCount / totalValidPoints > 0.8

            return [testRegion]

        # For partially exposed regions, create simplified exposed area polygons.
        # Strategy: Find exposed regions and create bounding rectangles for them.
        exposedAreas = []

        # Find contiguous exposed regions using flood fill approach.
        visited = []

        for i in [0...gridSize]

            row = []

            for j in [0...gridSize]

                row.push(false)

            visited.push(row)

        for i in [0...gridSize]

            for j in [0...gridSize]

                if exposedGrid[i][j]? and not visited[i][j]

                    # Found an unvisited exposed point - flood fill to find region.
                    region = @floodFillExposedRegion(exposedGrid, visited, i, j, gridSize)

                    if region.length > 0

                        # Create a bounding box for this exposed region.
                        minI = Math.min.apply(null, region.map((p) -> p.i))
                        maxI = Math.max.apply(null, region.map((p) -> p.i))
                        minJ = Math.min.apply(null, region.map((p) -> p.j))
                        maxJ = Math.max.apply(null, region.map((p) -> p.j))

                        # Convert grid coordinates to actual coordinates.
                        minX = bounds.minX + width * (minI / gridSize)
                        maxX = bounds.minX + width * ((maxI + 1) / gridSize)
                        minY = bounds.minY + height * (minJ / gridSize)
                        maxY = bounds.minY + height * ((maxJ + 1) / gridSize)

                        # Create rectangle polygon for this exposed area.
                        exposedPoly = [
                            { x: minX, y: minY, z: testRegion[0].z }
                            { x: maxX, y: minY, z: testRegion[0].z }
                            { x: maxX, y: maxY, z: testRegion[0].z }
                            { x: minX, y: maxY, z: testRegion[0].z }
                        ]

                        exposedAreas.push(exposedPoly)

        # If we found exposed areas, return them. Otherwise return entire region.
        return if exposedAreas.length > 0 then exposedAreas else [testRegion]

    # Flood fill algorithm to find contiguous exposed regions in a grid.
    # Calculate non-exposed areas (areas that should get infill, not skin).
    # This takes the full boundary path and subtracts the exposed areas.
    # Returns an array of bounding boxes representing non-exposed regions.
    calculateNonExposedAreas: (fullBoundary, exposedAreas) ->

        return [fullBoundary] if not exposedAreas or exposedAreas.length is 0

        # For simplicity, we'll use a sampling-based approach:
        # - Sample points across the full boundary
        # - Check which points are NOT in any exposed area
        # - Group contiguous non-exposed points into regions
        #
        # This is similar to calculateExposedAreas but inverted.

        bounds = @calculatePathBounds(fullBoundary)

        return [] if not bounds

        # Use coarse grid (9x9) for non-exposed areas since infill doesn't need to be as precise.
        gridSize = 9
        stepX = (bounds.maxX - bounds.minX) / (gridSize - 1)
        stepY = (bounds.maxY - bounds.minY) / (gridSize - 1)

        # Sample and classify each point.
        nonExposedPoints = []

        for i in [0...gridSize]

            for j in [0...gridSize]

                pointX = bounds.minX + i * stepX
                pointY = bounds.minY + j * stepY
                testPoint = { x: pointX, y: pointY }

                # Check if point is inside the full boundary.
                if @pointInPolygon(testPoint, fullBoundary)

                    # Check if point is inside any exposed area.
                    isExposed = false

                    for exposedArea in exposedAreas

                        if @pointInPolygon(testPoint, exposedArea)

                            isExposed = true
                            break

                    # If not in any exposed area, it's a non-exposed point.
                    if not isExposed

                        nonExposedPoints.push({ x: pointX, y: pointY, i: i, j: j })

        # If most points are non-exposed (>80%), return entire boundary for efficiency.
        totalPoints = gridSize * gridSize
        nonExposedCount = nonExposedPoints.length

        if nonExposedCount > totalPoints * 0.8

            return [fullBoundary]

        # If no non-exposed points, return empty (entire boundary is exposed).
        return [] if nonExposedPoints.length is 0

        # Group contiguous non-exposed points using flood fill.
        visited = new Set()
        nonExposedRegions = []

        for point in nonExposedPoints

            key = "#{point.i},#{point.j}"

            continue if visited.has(key)

            # Start a new region from this point.
            regionPoints = @floodFillNonExposedRegion(nonExposedPoints, visited, point.i, point.j, gridSize)

            continue if regionPoints.length is 0

            # Create bounding box for this region.
            minX = Infinity
            maxX = -Infinity
            minY = Infinity
            maxY = -Infinity

            for p in regionPoints

                minX = Math.min(minX, p.x)
                maxX = Math.max(maxX, p.x)
                minY = Math.min(minY, p.y)
                maxY = Math.max(maxY, p.y)

            # Create a rectangular path for this non-exposed region.
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

        # Build a quick lookup map for non-exposed points.
        pointMap = {}

        for point in nonExposedPoints

            key = "#{point.i},#{point.j}"
            pointMap[key] = point

        # Flood fill starting from (startI, startJ).
        regionPoints = []
        stack = [{ i: startI, j: startJ }]

        while stack.length > 0

            current = stack.pop()
            key = "#{current.i},#{current.j}"

            continue if visited.has(key)
            continue if not pointMap[key]?

            visited.add(key)
            regionPoints.push(pointMap[key])

            # Check 4-connected neighbors.
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

    floodFillExposedRegion: (exposedGrid, visited, startI, startJ, gridSize) ->

        region = []
        stack = [{ i: startI, j: startJ }]

        while stack.length > 0
            pos = stack.pop()
            i = pos.i
            j = pos.j

            # Check bounds.
            continue if i < 0 or i >= gridSize or j < 0 or j >= gridSize

            # Check if already visited or not exposed.
            continue if visited[i][j] or not exposedGrid[i][j]?

            # Mark as visited and add to region.
            visited[i][j] = true
            region.push({ i: i, j: j, point: exposedGrid[i][j] })

            # Add neighbors to stack.
            stack.push({ i: i + 1, j: j })
            stack.push({ i: i - 1, j: j })
            stack.push({ i: i, j: j + 1 })
            stack.push({ i: i, j: j - 1 })

        return region
