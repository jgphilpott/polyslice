# Geometry helper functions for slicing operations.

# Backoff multiplier for hole avoidance in combing paths.
# This value determines how far to back off from holes (multiplied by nozzle diameter).
# A value of 3.0 provides adequate clearance to prevent paths from grazing hole boundaries.
BACKOFF_MULTIPLIER = 3.0

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
    # If isHole is true, the path represents a hole and will be inset outward (shrinking the hole).
    createInsetPath: (path, insetDistance, isHole = false) ->

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

        # Precompute a simple centroid for inward direction checks.
        centroidX = 0
        centroidY = 0

        for p in simplifiedPath

            centroidX += p.x
            centroidY += p.y

        centroidX /= n
        centroidY /= n

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

            # For holes, we want the inset to go OUTWARD from the hole (shrinking the hole).
            # For outer boundaries, we want the inset to go INWARD (shrinking the boundary).
            #
            # The robust direction check ensures the normal points in the desired direction:
            # - For outer boundaries: normal should point INSIDE the polygon
            # - For holes: normal should point OUTSIDE the polygon
            midX = (p1.x + p2.x) / 2
            midY = (p1.y + p2.y) / 2

            testX = midX + normalX * (insetDistance * 0.5)
            testY = midY + normalY * (insetDistance * 0.5)

            isTestPointInside = @pointInPolygon({ x: testX, y: testY }, simplifiedPath)

            # For outer boundaries: normal should point inside (test point should be inside)
            # For holes: normal should point outside (test point should NOT be inside)
            shouldBeInside = not isHole

            if isTestPointInside isnt shouldBeInside

                normalX = -normalX
                normalY = -normalY

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
        # 1. For outer boundaries: Check if the inset path is meaningfully smaller
        # 2. For holes: Check if the inset path is meaningfully larger (hole shrinks)
        # 3. Check if the remaining area is large enough for meaningful geometry
        # 4. Reject paths that are too small or have insufficient area
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

            # If the original shape is too small to accommodate an inset of this distance
            # (i.e., diameter/width less than approximately 2 * insetDistance), then
            # there is no room for an inner wall. Use a small margin to avoid flicker
            # across adjacent layers due to floating-point noise.
            minRequiredDimension = 2 * insetDistance + insetDistance * 0.2

            if originalWidth < minRequiredDimension or originalHeight < minRequiredDimension

                return []

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

            # The validation differs based on whether this is a hole or outer boundary:
            # - Outer boundaries: inset should be smaller (boundary contracts)
            # - Holes: inset should be larger (hole boundary expands, shrinking the hole)
            #
            # We expect the bounding box to change by approximately 2 * insetDistance (both sides).
            # However, due to geometric variations (corners, few vertices, etc.), we use a lenient threshold.
            # If the change is not at least 10% of expected, reject it.
            # This 10% threshold accounts for edge cases like sphere poles or cone tips.
            expectedSizeChange = insetDistance * 2 * 0.1

            if isHole

                # For holes, inset should make the path larger (hole shrinks).
                widthIncrease = insetWidth - originalWidth
                heightIncrease = insetHeight - originalHeight

                # Check if either dimension didn't grow enough (or shrank).
                if widthIncrease < expectedSizeChange or heightIncrease < expectedSizeChange

                    # Inset path is not sufficiently larger than original - hole is too small.
                    return []

            else

                # For outer boundaries, inset should make the path smaller.
                widthReduction = originalWidth - insetWidth
                heightReduction = originalHeight - insetHeight

                # Check if either dimension didn't shrink enough (or expanded).
                if widthReduction < expectedSizeChange or heightReduction < expectedSizeChange

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

    # Clip a line segment to an inclusion polygon while excluding holes.
    # Returns an array of line segments that are inside the inclusion polygon but outside all hole polygons.
    #
    # This function extends clipLineToPolygon to support hole exclusion.
    # It first clips to the inclusion boundary, then removes segments that fall within holes.
    #
    # Parameters:
    # - lineStart: Start point of the line
    # - lineEnd: End point of the line
    # - inclusionPolygon: The polygon to clip to (infill boundary)
    # - exclusionPolygons: Array of hole polygons to exclude from the result
    clipLineWithHoles: (lineStart, lineEnd, inclusionPolygon, exclusionPolygons = []) ->

        # First clip to the inclusion boundary.
        segments = @clipLineToPolygon(lineStart, lineEnd, inclusionPolygon)

        return segments if exclusionPolygons.length is 0

        # For each segment clipped to the inclusion boundary, further clip against holes.
        finalSegments = []

        for segment in segments

            # Start with the segment from the inclusion clipping.
            segmentsToProcess = [segment]

            # Process each hole (exclusion polygon).
            for holePolygon in exclusionPolygons

                newSegmentsToProcess = []

                # For each segment, remove the parts that fall inside the hole.
                for segmentToClip in segmentsToProcess

                    # Check if segment endpoints are inside the hole.
                    startInHole = @pointInPolygon(segmentToClip.start, holePolygon)
                    endInHole = @pointInPolygon(segmentToClip.end, holePolygon)

                    # If both endpoints are inside the hole, the entire segment is excluded.
                    if startInHole and endInHole
                        continue

                    # If neither endpoint is in the hole, check for intersections.
                    if not startInHole and not endInHole

                        # Find intersections with the hole boundary.
                        intersections = []

                        for i in [0...holePolygon.length]

                            nextIdx = if i is holePolygon.length - 1 then 0 else i + 1

                            edgeStart = holePolygon[i]
                            edgeEnd = holePolygon[nextIdx]

                            intersection = @lineSegmentIntersection(segmentToClip.start, segmentToClip.end, edgeStart, edgeEnd)

                            if intersection

                                # Calculate parametric t value along the segment.
                                dx = segmentToClip.end.x - segmentToClip.start.x
                                dy = segmentToClip.end.y - segmentToClip.start.y

                                if Math.abs(dx) > Math.abs(dy)
                                    t = (intersection.x - segmentToClip.start.x) / dx
                                else
                                    t = (intersection.y - segmentToClip.start.y) / dy

                                intersections.push({ point: intersection, t: t })

                        # If there are no intersections, the segment doesn't cross the hole - keep it.
                        if intersections.length is 0

                            newSegmentsToProcess.push(segmentToClip)

                        else

                            # Sort intersections by t value.
                            intersections.sort((a, b) -> a.t - b.t)

                            # Build segments from non-hole portions.
                            # Start from segment start.
                            prevT = 0
                            prevPoint = segmentToClip.start

                            for intersection in intersections

                                # Calculate midpoint between previous point and intersection.
                                midT = (prevT + intersection.t) / 2
                                midX = segmentToClip.start.x + midT * (segmentToClip.end.x - segmentToClip.start.x)
                                midY = segmentToClip.start.y + midT * (segmentToClip.end.y - segmentToClip.start.y)

                                # If midpoint is NOT in the hole, keep this segment.
                                if not @pointInPolygon({ x: midX, y: midY }, holePolygon)

                                    newSegmentsToProcess.push({
                                        start: prevPoint
                                        end: intersection.point
                                    })

                                prevT = intersection.t
                                prevPoint = intersection.point

                            # Check the final segment from last intersection to end.
                            midT = (prevT + 1) / 2
                            midX = segmentToClip.start.x + midT * (segmentToClip.end.x - segmentToClip.start.x)
                            midY = segmentToClip.start.y + midT * (segmentToClip.end.y - segmentToClip.start.y)

                            if not @pointInPolygon({ x: midX, y: midY }, holePolygon)

                                newSegmentsToProcess.push({
                                    start: prevPoint
                                    end: segmentToClip.end
                                })

                    else

                        # One endpoint is in the hole, one is not - need to find intersection.
                        intersections = []

                        for i in [0...holePolygon.length]

                            nextIdx = if i is holePolygon.length - 1 then 0 else i + 1

                            edgeStart = holePolygon[i]
                            edgeEnd = holePolygon[nextIdx]

                            intersection = @lineSegmentIntersection(segmentToClip.start, segmentToClip.end, edgeStart, edgeEnd)

                            if intersection

                                # Calculate parametric t value along the segment.
                                dx = segmentToClip.end.x - segmentToClip.start.x
                                dy = segmentToClip.end.y - segmentToClip.start.y

                                if Math.abs(dx) > Math.abs(dy)
                                    t = (intersection.x - segmentToClip.start.x) / dx
                                else
                                    t = (intersection.y - segmentToClip.start.y) / dy

                                intersections.push({ point: intersection, t: t })

                        if intersections.length > 0

                            # Sort and take the closest intersection.
                            intersections.sort((a, b) -> a.t - b.t)

                            # Keep the segment that's outside the hole.
                            if startInHole

                                # Start is in hole, end is out - keep from first intersection to end.
                                newSegmentsToProcess.push({
                                    start: intersections[0].point
                                    end: segmentToClip.end
                                })

                            else

                                # Start is out, end is in hole - keep from start to first intersection.
                                newSegmentsToProcess.push({
                                    start: segmentToClip.start
                                    end: intersections[0].point
                                })

                # Update segments to process with the new clipped segments.
                segmentsToProcess = newSegmentsToProcess

            # Add the final segments (after processing all holes) to the result.
            finalSegments.push(segmentsToProcess...)

        # Filter out degenerate segments (where start and end are too close).
        minSegmentLength = 0.001
        filteredSegments = []

        for segment in finalSegments

            dx = segment.end.x - segment.start.x
            dy = segment.end.y - segment.start.y
            length = Math.sqrt(dx * dx + dy * dy)

            if length >= minSegmentLength

                filteredSegments.push(segment)

        return filteredSegments

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

    # Deduplicate a list of intersection points.
    # When diagonal lines pass through bounding box corners, the same point
    # can be detected as an intersection with multiple edges.
    # This function removes duplicate points within a small epsilon tolerance.
    #
    # @param intersections Array of points with {x, y} coordinates
    # @param epsilon Tolerance for considering points as duplicates (default: 0.001mm)
    # @return Array of unique intersection points
    deduplicateIntersections: (intersections, epsilon = 0.001) ->

        return [] if not intersections or intersections.length is 0

        uniqueIntersections = []

        for intersection in intersections

            isDuplicate = false

            for existing in uniqueIntersections

                dx = intersection.x - existing.x
                dy = intersection.y - existing.y
                distSq = dx * dx + dy * dy

                if distSq < epsilon * epsilon

                    isDuplicate = true
                    break

            if not isDuplicate

                uniqueIntersections.push(intersection)

        return uniqueIntersections

    # Check if a travel path between two points crosses through any holes.
    # Returns true if the path intersects with any hole boundary (enters or crosses the hole).
    travelPathCrossesHoles: (startPoint, endPoint, holePolygons = []) ->

        return false if holePolygons.length is 0
        return false if not startPoint or not endPoint

        # Small margin to account for paths that graze the hole boundary
        margin = 0.5  # 0.5mm margin

        # Check if travel path intersects with any hole boundary.
        for holePolygon in holePolygons

            continue if holePolygon.length < 3

            # Check if either endpoint is inside the hole (with margin).
            startInHole = @pointInPolygon(startPoint, holePolygon)
            endInHole = @pointInPolygon(endPoint, holePolygon)

            # If either endpoint is inside a hole, this path crosses it.
            if startInHole or endInHole

                return true

            # Check if the travel path intersects with any edge of the hole.
            for i in [0...holePolygon.length]

                nextIdx = if i is holePolygon.length - 1 then 0 else i + 1

                edgeStart = holePolygon[i]
                edgeEnd = holePolygon[nextIdx]

                intersection = @lineSegmentIntersection(startPoint, endPoint, edgeStart, edgeEnd)

                if intersection

                    return true

            # Check if the path passes too close to the hole center.
            # Calculate approximate hole center (average of all points).
            centerX = 0
            centerY = 0
            for point in holePolygon
                centerX += point.x
                centerY += point.y
            centerX /= holePolygon.length
            centerY /= holePolygon.length

            # Calculate approximate hole radius (average distance from center).
            totalDist = 0
            for point in holePolygon
                dx = point.x - centerX
                dy = point.y - centerY
                totalDist += Math.sqrt(dx * dx + dy * dy)
            avgRadius = totalDist / holePolygon.length

            # Calculate closest distance from path to hole center.
            # Use formula for distance from point to line segment.
            dx = endPoint.x - startPoint.x
            dy = endPoint.y - startPoint.y
            lengthSq = dx * dx + dy * dy

            if lengthSq > 0.001
                # Parameter t for closest point on line segment
                t = Math.max(0, Math.min(1, ((centerX - startPoint.x) * dx + (centerY - startPoint.y) * dy) / lengthSq))
                closestX = startPoint.x + t * dx
                closestY = startPoint.y + t * dy
                distToCenter = Math.sqrt((closestX - centerX) ** 2 + (closestY - centerY) ** 2)

                # If path comes within the hole radius + margin, consider it crossing
                if distToCenter < avgRadius + margin
                    return true

        return false

    # Group infill line segments into connected regions that can be traversed without crossing holes.
    # This enables printing all lines in one region before moving to another, minimizing spider web artifacts.
    # Find a travel path that avoids crossing holes using A* pathfinding.
    # Returns an array of waypoints from start to end.
    # Uses grid-based A* search to find optimal multi-waypoint paths around holes.
    findCombingPath: (start, end, holePolygons = [], boundary = null, nozzleDiameter = 0.4) ->

        # If no holes, return direct path.
        if holePolygons.length is 0
            return [start, end]

        # Check if direct path crosses holes.
        crosses = @travelPathCrossesHoles(start, end, holePolygons)

        if not crosses
            return [start, end]

        # Apply back-off strategy if start/end points are too close to hole boundaries.
        # This widens the range of potential path angles.
        backOffDistance = nozzleDiameter * BACKOFF_MULTIPLIER
        adjustedStart = @backOffFromHoles(start, holePolygons, backOffDistance, boundary)
        adjustedEnd = @backOffFromHoles(end, holePolygons, backOffDistance, boundary)

        # If back-off created a valid direct path, use it.
        if not @travelPathCrossesHoles(adjustedStart, adjustedEnd, holePolygons)

            # Build path with safe transitions for back-off segments.
            startSegment = @buildSafePathSegment(start, adjustedStart, holePolygons)
            path = [startSegment[0]]  # Start with first point from start segment

            # Add adjusted start if different from start
            if startSegment.length > 1
                path.push(startSegment[1])

            # Add adjusted end if different from adjusted start
            if not @pointsEqual(adjustedStart, adjustedEnd, 0.001)
                path.push(adjustedEnd)

            # Add original end point if safe transition from adjusted end
            @addSafeEndpoint(path, adjustedEnd, end, holePolygons)

            return path

        # Try simple heuristic first (single waypoint) for performance.
        simplePath = @findSimpleCombingPath(adjustedStart, adjustedEnd, holePolygons, boundary)

        # If simple path found a waypoint (length > 2), use it.
        if simplePath.length > 2

            # Build complete path with safe transitions for back-off segments.
            startSegment = @buildSafePathSegment(start, adjustedStart, holePolygons)
            fullPath = [startSegment[0]]

            # Add adjusted start if different from start
            if startSegment.length > 1
                fullPath.push(startSegment[1])

            # Add simple path waypoints (excluding start/end which are adjustedStart/adjustedEnd).
            for waypoint, i in simplePath when i > 0 and i < simplePath.length - 1
                fullPath.push(waypoint)

            # Add adjusted end if different from adjusted start
            if not @pointsEqual(adjustedStart, adjustedEnd, 0.001)
                fullPath.push(adjustedEnd)

            # Add original end point if safe transition from adjusted end
            @addSafeEndpoint(fullPath, adjustedEnd, end, holePolygons)

            return fullPath

        # Simple heuristic failed - use A* pathfinding for complex scenarios.
        astarPath = @findAStarCombingPath(adjustedStart, adjustedEnd, holePolygons, boundary)

        # Build complete path with safe transitions for back-off segments.
        startSegment = @buildSafePathSegment(start, adjustedStart, holePolygons)
        fullPath = [startSegment[0]]

        # Add adjusted start if different from start
        if startSegment.length > 1
            fullPath.push(startSegment[1])

        # Add A* waypoints (excluding start/end which are adjustedStart/adjustedEnd).
        for waypoint, i in astarPath when i > 0 and i < astarPath.length - 1
            fullPath.push(waypoint)

        # Add adjusted end if different from adjusted start
        if not @pointsEqual(adjustedStart, adjustedEnd, 0.001)
            fullPath.push(adjustedEnd)

        # Add original end point if safe transition from adjusted end
        @addSafeEndpoint(fullPath, adjustedEnd, end, holePolygons)

        return fullPath

    # Back off from nearby hole boundaries to widen pathfinding options.
    # Returns a new point that is farther from holes, or original point if no better position found.
    backOffFromHoles: (point, holePolygons, backOffDistance, boundary) ->

        # Check if point is close to any hole boundary.
        closestHole = null
        closestDistance = Infinity

        for hole in holePolygons

            # Calculate hole center.
            centerX = 0
            centerY = 0

            for p in hole
                centerX += p.x
                centerY += p.y

            centerX /= hole.length
            centerY /= hole.length

            # Calculate distance to hole center.
            dx = point.x - centerX
            dy = point.y - centerY
            distToCenter = Math.sqrt(dx * dx + dy * dy)

            # Calculate approximate hole radius.
            maxRadius = 0

            for p in hole
                pDx = p.x - centerX
                pDy = p.y - centerY
                dist = Math.sqrt(pDx * pDx + pDy * pDy)
                maxRadius = Math.max(maxRadius, dist)

            # Distance to hole boundary.
            distToBoundary = distToCenter - maxRadius

            if distToBoundary < closestDistance
                closestDistance = distToBoundary
                closestHole = { center: { x: centerX, y: centerY }, radius: maxRadius }

        # If not close to any hole (more than 2x backOffDistance away), no need to back off.
        if closestDistance > backOffDistance * 2
            return point

        # Back off directly away from closest hole center.
        if closestHole?

            dx = point.x - closestHole.center.x
            dy = point.y - closestHole.center.y
            dist = Math.sqrt(dx * dx + dy * dy)

            if dist > 0.001

                # Normalize direction away from hole.
                dirX = dx / dist
                dirY = dy / dist

                # Calculate new position.
                newX = point.x + dirX * backOffDistance
                newY = point.y + dirY * backOffDistance
                newPoint = { x: newX, y: newY }

                # Verify new point is within boundary and not inside any hole.
                if boundary? and not @pointInPolygon(newPoint, boundary)
                    return point

                for hole in holePolygons
                    if @pointInPolygon(newPoint, hole)
                        return point

                return newPoint

        return point

    # Simple heuristic pathfinding (single waypoint perpendicular to midpoint).
    # This is the original algorithm, kept for performance on simple cases.
    findSimpleCombingPath: (start, end, holePolygons, boundary) ->

        dx = end.x - start.x
        dy = end.y - start.y
        pathLength = Math.sqrt(dx * dx + dy * dy)

        if pathLength < 0.001
            return [start, end]

        # Calculate perpendicular directions.
        perpX1 = -dy / pathLength
        perpY1 = dx / pathLength
        perpX2 = dy / pathLength
        perpY2 = -dx / pathLength

        # Try waypoints at increasing perpendicular offsets.
        for offset in [3, 5, 8, 12, 18, 25, 35]

            # Try both perpendicular directions.
            for [perpX, perpY] in [[perpX1, perpY1], [perpX2, perpY2]]

                # Place waypoint perpendicular to midpoint.
                midX = (start.x + end.x) / 2
                midY = (start.y + end.y) / 2
                waypointX = midX + perpX * offset
                waypointY = midY + perpY * offset

                waypoint = { x: waypointX, y: waypointY }

                # Check if waypoint is in boundary.
                if boundary? and not @pointInPolygon(waypoint, boundary)
                    continue

                # Check if both legs avoid holes.
                leg1Clear = not @travelPathCrossesHoles(start, waypoint, holePolygons)
                leg2Clear = not @travelPathCrossesHoles(waypoint, end, holePolygons)

                if leg1Clear and leg2Clear
                    return [start, waypoint, end]

        # No valid single waypoint found.
        return [start, end]

    # A* pathfinding to find multi-waypoint path around holes.
    # Uses grid-based search to navigate complex hole configurations.
    findAStarCombingPath: (start, end, holePolygons, boundary) ->

        # Define grid resolution (larger cell = faster but less precise).
        gridSize = 2.0  # 2mm grid cells

        # Calculate bounds for the search space.
        minX = Math.min(start.x, end.x) - 20
        maxX = Math.max(start.x, end.x) + 20
        minY = Math.min(start.y, end.y) - 20
        maxY = Math.max(start.y, end.y) + 20

        # Constrain to boundary if provided.
        if boundary?

            for p in boundary
                minX = Math.min(minX, p.x)
                maxX = Math.max(maxX, p.x)
                minY = Math.min(minY, p.y)
                maxY = Math.max(maxY, p.y)

        # Convert points to grid coordinates.
        pointToGrid = (p) =>
            gx: Math.floor((p.x - minX) / gridSize)
            gy: Math.floor((p.y - minY) / gridSize)

        gridToPoint = (gx, gy) =>
            x: minX + (gx + 0.5) * gridSize
            y: minY + (gy + 0.5) * gridSize

        # Pre-calculate hole centers and radii to avoid repeated computation.
        # This optimization improves A* performance significantly for dense hole patterns.
        holeCentersAndRadii = []
        margin = 0.5  # Same margin as travelPathCrossesHoles (0.5mm).

        for hole in holePolygons
            # Calculate approximate hole center (average of all points).
            centerX = 0
            centerY = 0
            for p in hole
                centerX += p.x
                centerY += p.y
            centerX /= hole.length
            centerY /= hole.length

            # Calculate approximate hole radius (average distance from center).
            totalDist = 0
            for p in hole
                dx = p.x - centerX
                dy = p.y - centerY
                totalDist += Math.sqrt(dx * dx + dy * dy)
            avgRadius = totalDist / hole.length

            holeCentersAndRadii.push({ centerX, centerY, avgRadius, hole })

        # Check if grid cell is valid (within boundary and not in/near hole).
        isValidCell = (gx, gy) =>

            point = gridToPoint(gx, gy)

            # Check boundary constraint.
            if boundary? and not @pointInPolygon(point, boundary)
                return false

            # Check hole constraints using pre-calculated centers and radii.
            for holeData in holeCentersAndRadii
                # Check if cell center is inside hole.
                if @pointInPolygon(point, holeData.hole)
                    return false

                # Check if cell is too close to hole boundary.
                dx = point.x - holeData.centerX
                dy = point.y - holeData.centerY
                distToCenter = Math.sqrt(dx * dx + dy * dy)

                # If cell center is within hole radius + margin, invalid.
                if distToCenter < holeData.avgRadius + margin
                    return false

            return true

        startGrid = pointToGrid(start)
        endGrid = pointToGrid(end)

        # A* data structures.
        openSet = [startGrid]
        cameFrom = {}
        gScore = {}
        fScore = {}

        makeKey = (gx, gy) -> "#{gx},#{gy}"

        startKey = makeKey(startGrid.gx, startGrid.gy)
        gScore[startKey] = 0
        fScore[startKey] = @manhattanDistance(startGrid.gx, startGrid.gy, endGrid.gx, endGrid.gy)

        # A* search loop.
        maxIterations = 2000  # Prevent infinite loops.
        iterations = 0

        while openSet.length > 0 and iterations < maxIterations

            iterations++

            # Find node in openSet with lowest fScore.
            current = null
            lowestF = Infinity

            for node in openSet

                key = makeKey(node.gx, node.gy)

                if fScore[key]? and fScore[key] < lowestF
                    lowestF = fScore[key]
                    current = node

            # If we reached the end, reconstruct path.
            if current? and current.gx is endGrid.gx and current.gy is endGrid.gy

                # Reconstruct path from cameFrom.
                path = []
                currentKey = makeKey(current.gx, current.gy)

                while cameFrom[currentKey]?

                    path.unshift(gridToPoint(current.gx, current.gy))
                    prev = cameFrom[currentKey]
                    current = prev
                    currentKey = makeKey(current.gx, current.gy)

                # Add start and end points.
                path.unshift(start)
                path.push(end)

                # Simplify path by removing unnecessary waypoints.
                return @simplifyPath(path, holePolygons)

            # Remove current from openSet (find and remove by index for efficiency).
            if current?

                removeIdx = -1

                for node, idx in openSet
                    if node.gx is current.gx and node.gy is current.gy
                        removeIdx = idx
                        break

                if removeIdx >= 0
                    openSet.splice(removeIdx, 1)

                # Check all neighbors (8-connected grid).
                neighbors = [
                    { gx: current.gx - 1, gy: current.gy }
                    { gx: current.gx + 1, gy: current.gy }
                    { gx: current.gx, gy: current.gy - 1 }
                    { gx: current.gx, gy: current.gy + 1 }
                    { gx: current.gx - 1, gy: current.gy - 1 }
                    { gx: current.gx + 1, gy: current.gy - 1 }
                    { gx: current.gx - 1, gy: current.gy + 1 }
                    { gx: current.gx + 1, gy: current.gy + 1 }
                ]

                for neighbor in neighbors

                    # Skip invalid cells.
                    continue unless isValidCell(neighbor.gx, neighbor.gy)

                    # Calculate tentative gScore.
                    neighborKey = makeKey(neighbor.gx, neighbor.gy)
                    currentKey = makeKey(current.gx, current.gy)

                    # Diagonal moves cost more (sqrt(2) ≈ 1.414).
                    isDiagonal = (neighbor.gx isnt current.gx) and (neighbor.gy isnt current.gy)
                    moveCost = if isDiagonal then 1.414 else 1.0

                    tentativeG = (gScore[currentKey] or 0) + moveCost

                    if not gScore[neighborKey]? or tentativeG < gScore[neighborKey]

                        # This path to neighbor is better.
                        cameFrom[neighborKey] = current
                        gScore[neighborKey] = tentativeG
                        fScore[neighborKey] = tentativeG + @manhattanDistance(neighbor.gx, neighbor.gy, endGrid.gx, endGrid.gy)

                        # Add to openSet if not already there.
                        # Use key-based lookup for efficiency.
                        alreadyInOpen = false

                        for node in openSet
                            if node.gx is neighbor.gx and node.gy is neighbor.gy
                                alreadyInOpen = true
                                break

                        if not alreadyInOpen
                            openSet.push(neighbor)

        # A* failed to find path - try fallback strategy using boundary waypoints.
        # Instead of returning a direct path that may cross holes, route around the boundary.
        if boundary? and boundary.length >= 4
            # Find boundary corners to use as waypoints.
            # Determine which corners to use based on quadrant.
            startQuadrant = @getQuadrant(start, boundary)
            endQuadrant = @getQuadrant(end, boundary)

            # If start and end are in opposite quadrants, use corner waypoint.
            if startQuadrant isnt endQuadrant
                cornerWaypoint = @findBoundaryCorner(startQuadrant, endQuadrant, boundary)
                if cornerWaypoint?
                    # Verify both segments of the corner path don't cross holes.
                    seg1Safe = not @travelPathCrossesHoles(start, cornerWaypoint, holePolygons)
                    seg2Safe = not @travelPathCrossesHoles(cornerWaypoint, end, holePolygons)

                    if seg1Safe and seg2Safe
                        return [start, cornerWaypoint, end]

        # Last resort - return direct path.
        # Note: This path may cross holes, but caller should have already checked
        # and will handle the unsafe transition appropriately.
        return [start, end]

    # Determine which quadrant a point is in relative to boundary center.
    # Returns: 1 (NE), 2 (NW), 3 (SW), 4 (SE)
    getQuadrant: (point, boundary) ->

        # Calculate boundary center.
        centerX = 0
        centerY = 0
        for p in boundary
            centerX += p.x
            centerY += p.y
        centerX /= boundary.length
        centerY /= boundary.length

        # Determine quadrant.
        if point.x >= centerX
            if point.y >= centerY then 1 else 4  # NE or SE
        else
            if point.y >= centerY then 2 else 3  # NW or SW

    # Find an appropriate boundary corner to use as waypoint between quadrants.
    findBoundaryCorner: (startQuadrant, endQuadrant, boundary) ->

        # Find min/max coordinates of boundary.
        minX = Infinity
        maxX = -Infinity
        minY = Infinity
        maxY = -Infinity

        for p in boundary
            minX = Math.min(minX, p.x)
            maxX = Math.max(maxX, p.x)
            minY = Math.min(minY, p.y)
            maxY = Math.max(maxY, p.y)

        # Inset corners by 1mm to ensure waypoints stay well inside the outer wall boundary.
        # The boundary polygon is the original design boundary, but the actual printed outer wall
        # is inset by half a nozzle diameter (~0.2mm). Adding 1mm inset ensures waypoints are
        # safely inside even after wall generation.
        inset = 1.0

        # Define corners with inset.
        corners = {
            1: { x: maxX - inset, y: maxY - inset }  # NE
            2: { x: minX + inset, y: maxY - inset }  # NW
            3: { x: minX + inset, y: minY + inset }  # SW
            4: { x: maxX - inset, y: minY + inset }  # SE
        }

        # For opposite quadrants, use a corner between them.
        # E.g., from SE (4) to NW (2), use either NE (1) or SW (3).
        if startQuadrant is 1 and endQuadrant is 3  # NE to SW
            return corners[2]  # Go via NW
        if startQuadrant is 3 and endQuadrant is 1  # SW to NE
            return corners[4]  # Go via SE
        if startQuadrant is 2 and endQuadrant is 4  # NW to SE
            return corners[1]  # Go via NE
        if startQuadrant is 4 and endQuadrant is 2  # SE to NW
            return corners[3]  # Go via SW

        # For adjacent quadrants, use the corner between them.
        if (startQuadrant is 1 and endQuadrant is 2) or (startQuadrant is 2 and endQuadrant is 1)
            return corners[2]  # Between NE and NW
        if (startQuadrant is 2 and endQuadrant is 3) or (startQuadrant is 3 and endQuadrant is 2)
            return corners[3]  # Between NW and SW
        if (startQuadrant is 3 and endQuadrant is 4) or (startQuadrant is 4 and endQuadrant is 3)
            return corners[4]  # Between SW and SE
        if (startQuadrant is 4 and endQuadrant is 1) or (startQuadrant is 1 and endQuadrant is 4)
            return corners[1]  # Between SE and NE

        # Same quadrant - no corner needed.
        return null

    # Manhattan distance heuristic for A*.
    manhattanDistance: (x1, y1, x2, y2) ->
        Math.abs(x2 - x1) + Math.abs(y2 - y1)

    # Simplify path by removing waypoints that don't change direction significantly.
    # This reduces unnecessary waypoints while maintaining obstacle avoidance.
    simplifyPath: (path, holePolygons) ->

        return path if path.length <= 2

        simplified = [path[0]]

        for i in [1...path.length - 1]

            prev = simplified[simplified.length - 1]
            current = path[i]
            next = path[i + 1]

            # Check if we can skip current waypoint (direct path from prev to next).
            if not @travelPathCrossesHoles(prev, next, holePolygons)

                # We can skip this waypoint - path from prev to next is clear.
                continue

            else

                # Need to keep this waypoint.
                simplified.push(current)

        simplified.push(path[path.length - 1])

        return simplified

    # Check if two points are equal within tolerance.
    pointsEqual: (p1, p2, epsilon) ->

        dx = p1.x - p2.x
        dy = p1.y - p2.y

        return Math.sqrt(dx * dx + dy * dy) < epsilon

    # Build a safe path segment that avoids adding points if the transition crosses holes.
    # Used internally by findCombingPath to ensure back-off transitions are safe.
    #
    # When pathfinding backs off from holes, we need to ensure the transition segments
    # (from original to adjusted points) don't cross holes. This helper checks the transition
    # and returns the appropriate point(s) to use in the path.
    #
    # @param originalPoint {Object} - The original point {x, y, z}
    # @param adjustedPoint {Object} - The adjusted (backed-off) point {x, y, z}
    # @param holePolygons {Array} - Array of hole polygons to avoid
    # @param epsilon {Number} - Tolerance for point equality check (default: 0.001)
    # @return {Array} - Array of 1 or 2 points representing the safe segment
    buildSafePathSegment: (originalPoint, adjustedPoint, holePolygons, epsilon = 0.001) ->

        points = []

        # If points are different, check if transition is safe.
        if not @pointsEqual(originalPoint, adjustedPoint, epsilon)

            # Check if transition from original to adjusted point crosses holes.
            if not @travelPathCrossesHoles(originalPoint, adjustedPoint, holePolygons)

                # Transition is safe - include both points.
                points.push(originalPoint)
                points.push(adjustedPoint)

            else

                # Transition crosses hole - only use adjusted point.
                points.push(adjustedPoint)

        else

            # Points are the same - use original.
            points.push(originalPoint)

        return points

    # Add an endpoint to a path only if the transition from the last point is safe.
    # This is a specialized helper for adding the final destination point after back-off.
    #
    # @param path {Array} - The path array to potentially add the endpoint to
    # @param adjustedEnd {Object} - The adjusted (backed-off) endpoint {x, y, z}
    # @param originalEnd {Object} - The original endpoint {x, y, z}
    # @param holePolygons {Array} - Array of hole polygons to avoid
    # @param epsilon {Number} - Tolerance for point equality check (default: 0.001)
    # @return {void} - Modifies path in place
    addSafeEndpoint: (path, adjustedEnd, originalEnd, holePolygons, epsilon = 0.001) ->

        # Only add if points are different
        if not @pointsEqual(adjustedEnd, originalEnd, epsilon)

            # Check if transition from adjusted to original end is safe
            if not @travelPathCrossesHoles(adjustedEnd, originalEnd, holePolygons)

                path.push(originalEnd)

    # Helper: Calculate distance from a point to a line segment
    distanceFromPointToLineSegment: (px, py, segStart, segEnd) ->
        dx = segEnd.x - segStart.x
        dy = segEnd.y - segStart.y
        lengthSq = dx * dx + dy * dy

        if lengthSq < 0.001
            # Degenerate segment, return distance to start point
            return Math.sqrt((px - segStart.x) ** 2 + (py - segStart.y) ** 2)

        # Calculate parameter t for closest point on line segment
        t = Math.max(0, Math.min(1, ((px - segStart.x) * dx + (py - segStart.y) * dy) / lengthSq))

        # Calculate closest point
        closestX = segStart.x + t * dx
        closestY = segStart.y + t * dy

        # Return distance
        return Math.sqrt((px - closestX) ** 2 + (py - closestY) ** 2)

    # Helper: Check if a line segment crosses a polygon
    lineSegmentCrossesPolygon: (start, end, polygon) ->

        # Check if either endpoint is inside
        if @pointInPolygon(start, polygon) or @pointInPolygon(end, polygon)
            return true

        # Check if line intersects any edge
        for i in [0...polygon.length]
            nextIdx = if i is polygon.length - 1 then 0 else i + 1
            edgeStart = polygon[i]
            edgeEnd = polygon[nextIdx]

            if @lineSegmentIntersection(start, end, edgeStart, edgeEnd)
                return true

        return false

    # Calculate the minimum distance between two closed paths.
    # This is useful for determining if there is enough space between walls.
    # Returns the minimum distance found, or a large number if paths are far apart.
    calculateMinimumDistanceBetweenPaths: (path1, path2) ->

        return Infinity if path1.length < 3 or path2.length < 3

        minDistance = Infinity

        # Check distance from each point in path1 to each edge in path2.
        for point in path1

            for i in [0...path2.length]

                nextIdx = if i is path2.length - 1 then 0 else i + 1

                segStart = path2[i]
                segEnd = path2[nextIdx]

                distance = @distanceFromPointToLineSegment(point.x, point.y, segStart, segEnd)

                minDistance = Math.min(minDistance, distance)

        # Check distance from each point in path2 to each edge in path1.
        for point in path2

            for i in [0...path1.length]

                nextIdx = if i is path1.length - 1 then 0 else i + 1

                segStart = path1[i]
                segEnd = path1[nextIdx]

                distance = @distanceFromPointToLineSegment(point.x, point.y, segStart, segEnd)

                minDistance = Math.min(minDistance, distance)

        return minDistance

    # Find the optimal starting point along a closed path for printing.
    # This searches for the point that's easiest to reach from the current position,
    # avoiding the need for complex pathfinding around holes.
    #
    # @param path {Array} - The closed path (polygon) to print
    # @param fromPoint {Object} - The current nozzle position {x, y, z}
    # @param holePolygons {Array} - Array of hole polygons to avoid
    # @param boundary {Object} - The outer boundary polygon
    # @param nozzleDiameter {Number} - Nozzle diameter for backoff calculations
    # @return {Number} - The index in the path array to use as starting point
    findOptimalStartPoint: (path, fromPoint, holePolygons = [], boundary = null, nozzleDiameter = 0.4) ->

        return 0 if not path or path.length < 3
        return 0 if not fromPoint

        # If no holes to avoid, just use the closest point.
        if holePolygons.length is 0

            minDistSq = Infinity
            bestIndex = 0

            for point, index in path

                dx = point.x - fromPoint.x
                dy = point.y - fromPoint.y
                distSq = dx * dx + dy * dy

                if distSq < minDistSq

                    minDistSq = distSq
                    bestIndex = index

            return bestIndex

        # With holes, we need to find a point that's both close AND accessible.
        # Strategy: Check each point and score it based on distance and path complexity.
        bestScore = Infinity
        bestIndex = 0

        for point, index in path

            # Calculate straight-line distance.
            dx = point.x - fromPoint.x
            dy = point.y - fromPoint.y
            straightDist = Math.sqrt(dx * dx + dy * dy)

            # Check if direct path crosses holes.
            crossesHoles = @travelPathCrossesHoles(fromPoint, point, holePolygons)

            if not crossesHoles

                # Direct path is clear - this is a good candidate.
                # Score is just the distance (lower is better).
                score = straightDist

            else

                # Need to path around holes - calculate actual combing path.
                combingPath = @findCombingPath(fromPoint, point, holePolygons, boundary, nozzleDiameter)

                # Calculate total path length.
                totalDist = 0

                for i in [0...combingPath.length - 1]

                    segStart = combingPath[i]
                    segEnd = combingPath[i + 1]

                    segDx = segEnd.x - segStart.x
                    segDy = segEnd.y - segStart.y

                    totalDist += Math.sqrt(segDx * segDx + segDy * segDy)

                # Score is the total path length.
                # Add a penalty for paths that require combing (to prefer direct paths).
                score = totalDist + straightDist * 0.1

            if score < bestScore

                bestScore = score
                bestIndex = index

        return bestIndex

    # Calculate the area of a polygon using the shoelace formula.
    # Returns absolute area (always positive).
    calculatePolygonArea: (path) ->

        return 0 if not path or path.length < 3

        signedArea = 0

        for i in [0...path.length]

            nextIdx = if i is path.length - 1 then 0 else i + 1

            signedArea += path[i].x * path[nextIdx].y - path[nextIdx].x * path[i].y

        # Return absolute area.
        return Math.abs(signedArea / 2)

    # Convert a path (array of {x, y} points) to polygon-clipping format.
    # polygon-clipping uses format: [[[x, y], [x, y], ...]]
    pathToPolygonClippingFormat: (path) ->

        return null if not path or path.length < 3

        # Convert points to [x, y] array format.
        coordinates = []

        for point in path

            coordinates.push([point.x, point.y])

        # Close the polygon if not already closed.
        firstPoint = coordinates[0]
        lastPoint = coordinates[coordinates.length - 1]

        if firstPoint[0] isnt lastPoint[0] or firstPoint[1] isnt lastPoint[1]

            coordinates.push([firstPoint[0], firstPoint[1]])

        # Return in polygon-clipping format (polygon with one ring, no holes).
        return [coordinates]

    # Convert polygon-clipping format back to path format.
    polygonClippingFormatToPath: (polygonData) ->

        return [] if not polygonData or polygonData.length is 0

        # polygon-clipping returns MultiPolygon format: [polygon1, polygon2, ...]
        # Each polygon is: [outerRing, hole1, hole2, ...]
        # We'll extract just the outer rings for now.
        paths = []

        for polygon in polygonData

            continue if not polygon or polygon.length is 0

            # Get outer ring (first ring of each polygon).
            outerRing = polygon[0]

            continue if not outerRing or outerRing.length < 3

            # Convert to path format.
            path = []

            for coord in outerRing

                path.push({ x: coord[0], y: coord[1] })

            # Remove duplicate closing point if present.
            if path.length > 1

                firstPoint = path[0]
                lastPoint = path[path.length - 1]

                if firstPoint.x is lastPoint.x and firstPoint.y is lastPoint.y

                    path.pop()

            paths.push(path) if path.length >= 3

        return paths

    # Calculate exposed areas using polygon difference operation.
    # This is the Cura-style polygon-based approach.
    # Returns array of paths representing exposed (uncovered) regions.
    calculateExposedAreasPolygonBased: (testRegion, coveringRegions) ->

        return [testRegion] if not coveringRegions or coveringRegions.length is 0
        return [] if not testRegion or testRegion.length < 3

        # Import polygon-clipping library.
        polygonClipping = require('polygon-clipping')

        # Convert test region to polygon-clipping format.
        testPolygon = @pathToPolygonClippingFormat(testRegion)

        return [testRegion] if not testPolygon

        # Start with the full test region.
        exposedPolygon = testPolygon

        # Subtract each covering region from the exposed area.
        for coveringRegion in coveringRegions

            continue if not coveringRegion or coveringRegion.length < 3

            coveringPolygon = @pathToPolygonClippingFormat(coveringRegion)

            continue if not coveringPolygon

            # Calculate difference: exposedPolygon - coveringPolygon
            # This removes the covered area from the exposed area.
            try

                exposedPolygon = polygonClipping.difference(exposedPolygon, coveringPolygon)

            catch error

                # If polygon operation fails, log and continue.
                console.warn("Polygon difference operation failed:", error.message)

                continue

            # If nothing left exposed, return empty.
            break if not exposedPolygon or exposedPolygon.length is 0

        # Convert result back to path format.
        return [] if not exposedPolygon or exposedPolygon.length is 0

        exposedPaths = @polygonClippingFormatToPath(exposedPolygon)

        return exposedPaths

    # Calculate region coverage using polygon intersection.
    # Returns coverage ratio (0.0 to 1.0).
    calculateRegionCoveragePolygonBased: (testRegion, coveringRegions) ->

        return 0 if not testRegion or testRegion.length < 3
        return 0 if not coveringRegions or coveringRegions.length is 0

        # Import polygon-clipping library.
        polygonClipping = require('polygon-clipping')

        # Convert test region to polygon-clipping format.
        testPolygon = @pathToPolygonClippingFormat(testRegion)

        return 0 if not testPolygon

        # Calculate area of test region.
        testArea = @calculatePolygonArea(testRegion)

        return 0 if testArea <= 0

        # Union all covering regions together first.
        coveringUnion = null

        for coveringRegion in coveringRegions

            continue if not coveringRegion or coveringRegion.length < 3

            coveringPolygon = @pathToPolygonClippingFormat(coveringRegion)

            continue if not coveringPolygon

            try

                if not coveringUnion

                    coveringUnion = coveringPolygon

                else

                    coveringUnion = polygonClipping.union(coveringUnion, coveringPolygon)

            catch error

                console.warn("Polygon union operation failed:", error.message)

                continue

        # If no valid covering regions, coverage is 0.
        return 0 if not coveringUnion or coveringUnion.length is 0

        # Calculate intersection between test region and covering union.
        try

            intersection = polygonClipping.intersection(testPolygon, coveringUnion)

        catch error

            console.warn("Polygon intersection operation failed:", error.message)

            return 0

        # If no intersection, coverage is 0.
        return 0 if not intersection or intersection.length is 0

        # Calculate area of intersection.
        intersectionPaths = @polygonClippingFormatToPath(intersection)

        return 0 if intersectionPaths.length is 0

        intersectionArea = 0

        for path in intersectionPaths

            intersectionArea += @calculatePolygonArea(path)

        # Return coverage ratio.
        coverage = intersectionArea / testArea

        # Clamp to [0, 1] to handle floating point errors.
        return Math.max(0, Math.min(1, coverage))
