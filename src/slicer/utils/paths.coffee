# Path manipulation operations for closed polygon paths.
# Includes segment connection, inset generation, and path analysis.

primitives = require('./primitives')
bounds = require('./bounds')

# Minimum number of corners needed for proper rectangular insets.
MIN_SIMPLIFIED_CORNERS = 4

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

        # Helper to select best candidate using leftmost-turn heuristic.
        selectBestCandidate = (candidates, prevPoint, currentPoint) =>

            return null if candidates.length is 0
            return candidates[0] if candidates.length is 1

            # Calculate current direction.
            currentDirX = currentPoint.x - prevPoint.x
            currentDirY = currentPoint.y - prevPoint.y
            currentLen = Math.sqrt(currentDirX * currentDirX + currentDirY * currentDirY)

            return candidates[0] if currentLen <= 0.0001

            currentDirX /= currentLen
            currentDirY /= currentLen

            bestCandidate = null
            bestCrossProduct = -Infinity

            for candidate in candidates

                nextDirX = candidate.nextPoint.x - currentPoint.x
                nextDirY = candidate.nextPoint.y - currentPoint.y
                nextLen = Math.sqrt(nextDirX * nextDirX + nextDirY * nextDirY)

                if nextLen > 0.0001

                    nextDirX /= nextLen
                    nextDirY /= nextLen

                    # Cross product: positive = left turn (CCW), negative = right turn (CW).
                    crossProduct = currentDirX * nextDirY - currentDirY * nextDirX

                    if crossProduct > bestCrossProduct

                        bestCrossProduct = crossProduct
                        bestCandidate = candidate

            return bestCandidate ? candidates[0]

        # Bidirectional greedy path connection.
        for startEdgeIndex in [0...edges.length]

            continue if usedSegments.has(startEdgeIndex)

            currentPath = []
            currentEdge = edges[startEdgeIndex]
            usedSegments.add(startEdgeIndex)

            # Start with the edge in path.
            currentPath.push(currentEdge.start)
            currentPath.push(currentEdge.end)

            # Extend forward (from end).
            maxIterations = edges.length
            iterations = 0

            while iterations < maxIterations

                iterations++

                lastPoint = currentPath[currentPath.length - 1]
                prevPoint = currentPath[currentPath.length - 2]

                # Find all connecting edges at the end.
                candidates = []

                for nextEdgeIndex in [0...edges.length]

                    continue if usedSegments.has(nextEdgeIndex)

                    nextEdge = edges[nextEdgeIndex]

                    if primitives.pointsMatch(lastPoint, nextEdge.start, epsilon)

                        candidates.push({
                            index: nextEdgeIndex
                            edge: nextEdge
                            nextPoint: nextEdge.end
                        })

                    else if primitives.pointsMatch(lastPoint, nextEdge.end, epsilon)

                        candidates.push({
                            index: nextEdgeIndex
                            edge: nextEdge
                            nextPoint: nextEdge.start
                        })

                break if candidates.length is 0

                bestCandidate = selectBestCandidate(candidates, prevPoint, lastPoint)

                if bestCandidate?

                    currentPath.push(bestCandidate.nextPoint)
                    usedSegments.add(bestCandidate.index)

                else

                    break

            # Extend backward (from start).
            iterations = 0

            while iterations < maxIterations

                iterations++

                firstPoint = currentPath[0]
                secondPoint = currentPath[1]

                # Find all connecting edges at the start.
                candidates = []

                for nextEdgeIndex in [0...edges.length]

                    continue if usedSegments.has(nextEdgeIndex)

                    nextEdge = edges[nextEdgeIndex]

                    if primitives.pointsMatch(firstPoint, nextEdge.start, epsilon)

                        candidates.push({
                            index: nextEdgeIndex
                            edge: nextEdge
                            nextPoint: nextEdge.end
                        })

                    else if primitives.pointsMatch(firstPoint, nextEdge.end, epsilon)

                        candidates.push({
                            index: nextEdgeIndex
                            edge: nextEdge
                            nextPoint: nextEdge.start
                        })

                break if candidates.length is 0

                bestCandidate = selectBestCandidate(candidates, secondPoint, firstPoint)

                if bestCandidate?

                    currentPath.unshift(bestCandidate.nextPoint)
                    usedSegments.add(bestCandidate.index)

                else

                    break

            # Only add paths with at least 3 points and remove duplicate last point if it matches first.
            if currentPath.length >= 3

                firstPoint = currentPath[0]
                lastPoint = currentPath[currentPath.length - 1]

                # Remove last point if it's the same as first (closed loop).
                if primitives.pointsMatch(firstPoint, lastPoint, epsilon)

                    currentPath.pop()

                # Only add if still have at least 3 points.
                if currentPath.length >= 3 then paths.push(currentPath)

        return paths

    # Create an inset path (shrink inward by specified distance).
    # If isHole is true, the path represents a hole and will be inset outward (shrinking the hole).
    createInsetPath: (path, insetDistance, isHole = false) ->

        return [] if path.length < 3

        # Step 1: Iteratively remove degenerate/backtracking vertices until the path stabilises.
        # Each pass removes:
        #   1. Collinear points (|cross| near zero), and
        #   2. Near-reversal (backtracking) vertices (dot near -1).
        # Multiple passes are needed because removing one backtracking vertex can expose the
        # previous vertex as a new backtracking vertex (cascading U-turns in arc-to-wall
        # junctions where the arc overshoots the corner before returning to the wall).
        angleThreshold = 0.0001 # ~0.0057 degrees - only removes perfectly collinear points
        currentPath = path
        changed = true

        while changed and currentPath.length >= MIN_SIMPLIFIED_CORNERS

            changed = false
            simplifiedPath = []
            n = currentPath.length

            for i in [0...n]

                prevIdx = if i is 0 then n - 1 else i - 1
                nextIdx = if i is n - 1 then 0 else i + 1

                p1 = currentPath[prevIdx]
                p2 = currentPath[i]
                p3 = currentPath[nextIdx]

                # Calculate vectors for the two edges.
                v1x = p2.x - p1.x
                v1y = p2.y - p1.y
                v2x = p3.x - p2.x
                v2y = p3.y - p2.y

                len1 = Math.sqrt(v1x * v1x + v1y * v1y)
                len2 = Math.sqrt(v2x * v2x + v2y * v2y)

                # Skip degenerate edges.
                if len1 < 0.0001 or len2 < 0.0001 then continue

                # Normalize vectors.
                v1x /= len1
                v1y /= len1
                v2x /= len2
                v2y /= len2

                # Calculate cross and dot products.
                cross = v1x * v2y - v1y * v2x
                dot = v1x * v2x + v1y * v2y

                if Math.abs(cross) > angleThreshold and dot > -0.99

                    simplifiedPath.push(p2)

                else

                    changed = true

            # If too few points remain, fall back to the original path and stop iterating.
            if simplifiedPath.length < MIN_SIMPLIFIED_CORNERS
                simplifiedPath = path
                changed = false
            else
                currentPath = simplifiedPath

        simplifiedPath = currentPath

        # Additional pass: Remove any remaining duplicate consecutive points.
        # This prevents issues where duplicate points can cause degenerate edges
        # in the offset calculation, leading to extreme intersection coordinates.
        # Note: This uses a larger epsilon (0.01mm) than edge simplification (0.0001mm)
        # because we need to remove near-duplicates that passed initial simplification
        # but would still create problematic near-parallel edges in offset calculation.
        dedupedPath = []
        epsilon = 0.01  # 0.01mm threshold to remove near-duplicate points

        for i in [0...simplifiedPath.length]

            currentPoint = simplifiedPath[i]
            nextIdx = if i is simplifiedPath.length - 1 then 0 else i + 1
            nextPoint = simplifiedPath[nextIdx]

            # Check if current point is different from next point.
            dx = nextPoint.x - currentPoint.x
            dy = nextPoint.y - currentPoint.y
            distSq = dx * dx + dy * dy

            # Only add point if it's not a duplicate of the next point.
            if distSq >= epsilon * epsilon
                dedupedPath.push(currentPoint)

        # Use deduplicated path if it has enough points.
        if dedupedPath.length >= 3
            simplifiedPath = dedupedPath
        else
            return []  # Path is too degenerate after deduplication.

        # Step 2: Create inset using the simplified path.
        insetPath = []
        n = simplifiedPath.length

        # Calculate bounding box for validation (done early for intersection checks).
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

            # Direction check.
            midX = (p1.x + p2.x) / 2
            midY = (p1.y + p2.y) / 2

            testX = midX + normalX * (insetDistance * 0.5)
            testY = midY + normalY * (insetDistance * 0.5)

            isTestPointInside = primitives.pointInPolygon({ x: testX, y: testY }, simplifiedPath)

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
        # Miter-limit: clamp at MITER_LIMIT_MULTIPLIER × insetDistance to handle near-parallel
        # edges (e.g., sphere arcs meeting box edges) where adjacent normals are nearly opposite
        # due to numerical precision in the pointInPolygon test.
        MITER_LIMIT_MULTIPLIER = 100
        for i in [0...offsetLines.length]

            prevIdx = if i is 0 then offsetLines.length - 1 else i - 1

            line1 = offsetLines[prevIdx]
            line2 = offsetLines[i]

            intersection = primitives.lineIntersection(line1.p1, line1.p2, line2.p1, line2.p2)

            origVertex = simplifiedPath[line2.originalIdx]

            if intersection

                # Validate intersection is reasonable using distance from original vertex.
                # For a corner of angle θ, the intersection is insetDistance/sin(θ/2) from the vertex.
                # Additionally reject any intersection that lands outside the original path's
                # bounding box for non-holes: a valid inward inset must stay inside the original.
                distFromVertex = Math.sqrt((intersection.x - origVertex.x) ** 2 + (intersection.y - origVertex.y) ** 2)
                outsideBounds = not isHole and (
                    intersection.x < originalMinX - insetDistance or
                    intersection.x > originalMaxX + insetDistance or
                    intersection.y < originalMinY - insetDistance or
                    intersection.y > originalMaxY + insetDistance)

                if distFromVertex > insetDistance * MITER_LIMIT_MULTIPLIER or outsideBounds

                    # Near-parallel or diverging edges - use midpoint fallback.
                    insetPath.push({
                        x: line2.p1.x
                        y: line2.p1.y
                        z: origVertex.z
                    })

                else

                    insetPath.push({ x: intersection.x, y: intersection.y, z: origVertex.z })

            else

                # Parallel lines - use midpoint of offset segment.
                insetPath.push({
                    x: line2.p1.x
                    y: line2.p1.y
                    z: origVertex.z
                })

        # Validate the inset path.
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

            # Floating-point epsilon for bounding-box size validation.
            # Concave re-entrant corners can shift the inset bounding box by a tiny amount
            # (up to ~insetDistance * 0.1) due to midpoint fallbacks; anything larger indicates
            # a genuinely wrong normal direction and the path should be rejected.
            floatEpsilon = insetDistance * 0.1

            if isHole

                widthIncrease = insetWidth - originalWidth
                heightIncrease = insetHeight - originalHeight

                # A hole outset should expand the bounding box; allow only float noise shrinkage.
                if widthIncrease < -floatEpsilon or heightIncrease < -floatEpsilon

                    return []

            else

                widthReduction = originalWidth - insetWidth
                heightReduction = originalHeight - insetHeight

                # A non-hole inset should shrink or stay near the bounding box; allow only float noise expansion.
                if widthReduction < -floatEpsilon or heightReduction < -floatEpsilon

                    return []

            minViableDimension = insetDistance * 0.2

            if insetWidth < minViableDimension or insetHeight < minViableDimension

                return []

        return insetPath

    # Calculate the minimum distance between two closed paths.
    calculateMinimumDistanceBetweenPaths: (path1, path2) ->

        return Infinity if path1.length < 3 or path2.length < 3

        minDistance = Infinity

        # Check distance from each point in path1 to each edge in path2.
        for point in path1

            for i in [0...path2.length]

                nextIdx = if i is path2.length - 1 then 0 else i + 1

                segStart = path2[i]
                segEnd = path2[nextIdx]

                distance = primitives.distanceFromPointToLineSegment(point.x, point.y, segStart, segEnd)

                minDistance = Math.min(minDistance, distance)

        # Check distance from each point in path2 to each edge in path1.
        for point in path2

            for i in [0...path1.length]

                nextIdx = if i is path1.length - 1 then 0 else i + 1

                segStart = path1[i]
                segEnd = path1[nextIdx]

                distance = primitives.distanceFromPointToLineSegment(point.x, point.y, segStart, segEnd)

                minDistance = Math.min(minDistance, distance)

        return minDistance
