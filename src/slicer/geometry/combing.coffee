# Travel path optimization (combing) to avoid crossing holes during moves.
# Includes A* wayfinding and various path optimization strategies.

primitives = require('../utils/primitives')

# Backoff multiplier for hole avoidance in combing paths.
# This value is multiplied by nozzle diameter to determine the backoff distance.
# A value of 3.0 provides adequate clearance (e.g., 3.0 * 0.4mm = 1.2mm backoff).
BACKOFF_MULTIPLIER = 3.0

module.exports =

    # Check if a travel path between two points crosses through any holes.
    travelPathCrossesHoles: (startPoint, endPoint, holePolygons = []) ->

        return false if holePolygons.length is 0
        return false if not startPoint or not endPoint

        margin = 0.5  # 0.5mm margin

        for holePolygon in holePolygons

            continue if holePolygon.length < 3

            startInHole = primitives.pointInPolygon(startPoint, holePolygon)
            endInHole = primitives.pointInPolygon(endPoint, holePolygon)

            if startInHole or endInHole

                return true

            for i in [0...holePolygon.length]

                nextIdx = if i is holePolygon.length - 1 then 0 else i + 1

                edgeStart = holePolygon[i]
                edgeEnd = holePolygon[nextIdx]

                intersection = primitives.lineSegmentIntersection(startPoint, endPoint, edgeStart, edgeEnd)

                if intersection

                    return true

            # Check if path passes too close to hole center.
            centerX = 0
            centerY = 0

            for point in holePolygon

                centerX += point.x
                centerY += point.y

            centerX /= holePolygon.length
            centerY /= holePolygon.length

            totalDist = 0

            for point in holePolygon

                dx = point.x - centerX
                dy = point.y - centerY

                totalDist += Math.sqrt(dx * dx + dy * dy)

            avgRadius = totalDist / holePolygon.length

            dx = endPoint.x - startPoint.x
            dy = endPoint.y - startPoint.y

            lengthSq = dx * dx + dy * dy

            if lengthSq > 0.001

                t = Math.max(0, Math.min(1, ((centerX - startPoint.x) * dx + (centerY - startPoint.y) * dy) / lengthSq))

                closestX = startPoint.x + t * dx
                closestY = startPoint.y + t * dy

                distToCenter = Math.sqrt((closestX - centerX) ** 2 + (closestY - centerY) ** 2)

                if distToCenter < avgRadius + margin

                    return true

        return false

    # Find a travel path that avoids crossing holes using A* wayfinding.
    findCombingPath: (start, end, holePolygons = [], boundary = null, nozzleDiameter = 0.4) ->

        if holePolygons.length is 0

            return [start, end]

        crosses = @travelPathCrossesHoles(start, end, holePolygons)

        if not crosses

            return [start, end]

        # Apply back-off strategy.
        backOffDistance = nozzleDiameter * BACKOFF_MULTIPLIER
        adjustedStart = @backOffFromHoles(start, holePolygons, backOffDistance, boundary)
        adjustedEnd = @backOffFromHoles(end, holePolygons, backOffDistance, boundary)

        if not @travelPathCrossesHoles(adjustedStart, adjustedEnd, holePolygons)

            startSegment = @buildSafePathSegment(start, adjustedStart, holePolygons)
            path = [startSegment[0]]

            if startSegment.length > 1

                path.push(startSegment[1])

            if not @pointsEqual(adjustedStart, adjustedEnd, 0.001)

                path.push(adjustedEnd)

            @addSafeEndpoint(path, adjustedEnd, end, holePolygons)

            return path

        # Try simple heuristic first.
        simplePath = @findSimpleCombingPath(adjustedStart, adjustedEnd, holePolygons, boundary)

        if simplePath.length > 2

            startSegment = @buildSafePathSegment(start, adjustedStart, holePolygons)
            fullPath = [startSegment[0]]

            if startSegment.length > 1

                fullPath.push(startSegment[1])

            for waypoint, i in simplePath when i > 0 and i < simplePath.length - 1

                fullPath.push(waypoint)

            if not @pointsEqual(adjustedStart, adjustedEnd, 0.001)

                fullPath.push(adjustedEnd)

            @addSafeEndpoint(fullPath, adjustedEnd, end, holePolygons)

            return fullPath

        # Use A* wayfinding.
        astarPath = @findAStarCombingPath(adjustedStart, adjustedEnd, holePolygons, boundary)

        startSegment = @buildSafePathSegment(start, adjustedStart, holePolygons)
        fullPath = [startSegment[0]]

        if startSegment.length > 1

            fullPath.push(startSegment[1])

        for waypoint, i in astarPath when i > 0 and i < astarPath.length - 1

            fullPath.push(waypoint)

        if not @pointsEqual(adjustedStart, adjustedEnd, 0.001)

            fullPath.push(adjustedEnd)

        @addSafeEndpoint(fullPath, adjustedEnd, end, holePolygons)

        return fullPath

    # Back off from nearby hole boundaries.
    backOffFromHoles: (point, holePolygons, backOffDistance, boundary) ->

        closestHole = null
        closestDistance = Infinity

        for hole in holePolygons

            centerX = 0
            centerY = 0

            for p in hole

                centerX += p.x
                centerY += p.y

            centerX /= hole.length
            centerY /= hole.length

            dx = point.x - centerX
            dy = point.y - centerY

            distToCenter = Math.sqrt(dx * dx + dy * dy)

            maxRadius = 0

            for p in hole

                pDx = p.x - centerX
                pDy = p.y - centerY

                dist = Math.sqrt(pDx * pDx + pDy * pDy)
                maxRadius = Math.max(maxRadius, dist)

            distToBoundary = distToCenter - maxRadius

            if distToBoundary < closestDistance

                closestDistance = distToBoundary
                closestHole = { center: { x: centerX, y: centerY }, radius: maxRadius }

        if closestDistance > backOffDistance * 2

            return point

        if closestHole?

            dx = point.x - closestHole.center.x
            dy = point.y - closestHole.center.y

            dist = Math.sqrt(dx * dx + dy * dy)

            if dist > 0.001

                dirX = dx / dist
                dirY = dy / dist

                newX = point.x + dirX * backOffDistance
                newY = point.y + dirY * backOffDistance

                newPoint = { x: newX, y: newY }

                if boundary? and not primitives.pointInPolygon(newPoint, boundary)

                    return point

                for hole in holePolygons

                    if primitives.pointInPolygon(newPoint, hole)

                        return point

                return newPoint

        return point

    # Simple heuristic wayfinding (single waypoint).
    findSimpleCombingPath: (start, end, holePolygons, boundary) ->

        dx = end.x - start.x
        dy = end.y - start.y

        pathLength = Math.sqrt(dx * dx + dy * dy)

        if pathLength < 0.001

            return [start, end]

        perpX1 = -dy / pathLength
        perpY1 = dx / pathLength
        perpX2 = dy / pathLength
        perpY2 = -dx / pathLength

        for offset in [3, 5, 8, 12, 18, 25, 35]

            for [perpX, perpY] in [[perpX1, perpY1], [perpX2, perpY2]]

                midX = (start.x + end.x) / 2
                midY = (start.y + end.y) / 2

                waypointX = midX + perpX * offset
                waypointY = midY + perpY * offset

                waypoint = { x: waypointX, y: waypointY }

                if boundary? and not primitives.pointInPolygon(waypoint, boundary)

                    continue

                leg1Clear = not @travelPathCrossesHoles(start, waypoint, holePolygons)
                leg2Clear = not @travelPathCrossesHoles(waypoint, end, holePolygons)

                if leg1Clear and leg2Clear

                    return [start, waypoint, end]

        return [start, end]

    # A* wayfinding to find multi-waypoint path around holes.
    findAStarCombingPath: (start, end, holePolygons, boundary) ->

        gridSize = 2.0

        minX = Math.min(start.x, end.x) - 20
        maxX = Math.max(start.x, end.x) + 20
        minY = Math.min(start.y, end.y) - 20
        maxY = Math.max(start.y, end.y) + 20

        if boundary?

            for p in boundary

                minX = Math.min(minX, p.x)
                maxX = Math.max(maxX, p.x)
                minY = Math.min(minY, p.y)
                maxY = Math.max(maxY, p.y)

        pointToGrid = (p) =>

            gx: Math.floor((p.x - minX) / gridSize)
            gy: Math.floor((p.y - minY) / gridSize)

        gridToPoint = (gx, gy) =>

            x: minX + (gx + 0.5) * gridSize
            y: minY + (gy + 0.5) * gridSize

        # Pre-calculate hole centers and radii.
        holeCentersAndRadii = []
        margin = 0.5

        for hole in holePolygons

            centerX = 0
            centerY = 0

            for p in hole

                centerX += p.x
                centerY += p.y

            centerX /= hole.length
            centerY /= hole.length

            totalDist = 0

            for p in hole

                dx = p.x - centerX
                dy = p.y - centerY

                totalDist += Math.sqrt(dx * dx + dy * dy)

            avgRadius = totalDist / hole.length

            holeCentersAndRadii.push({ centerX, centerY, avgRadius, hole })

        isValidCell = (gx, gy) =>

            point = gridToPoint(gx, gy)

            if boundary? and not primitives.pointInPolygon(point, boundary)

                return false

            for holeData in holeCentersAndRadii

                if primitives.pointInPolygon(point, holeData.hole)

                    return false

                dx = point.x - holeData.centerX
                dy = point.y - holeData.centerY

                distToCenter = Math.sqrt(dx * dx + dy * dy)

                if distToCenter < holeData.avgRadius + margin

                    return false

            return true

        startGrid = pointToGrid(start)
        endGrid = pointToGrid(end)

        openSet = [startGrid]
        cameFrom = {}
        gScore = {}
        fScore = {}

        makeKey = (gx, gy) -> "#{gx},#{gy}"

        startKey = makeKey(startGrid.gx, startGrid.gy)
        gScore[startKey] = 0
        fScore[startKey] = primitives.manhattanDistance(startGrid.gx, startGrid.gy, endGrid.gx, endGrid.gy)

        maxIterations = 2000
        iterations = 0

        while openSet.length > 0 and iterations < maxIterations

            iterations++

            current = null
            lowestF = Infinity

            for node in openSet

                key = makeKey(node.gx, node.gy)

                if fScore[key]? and fScore[key] < lowestF

                    lowestF = fScore[key]
                    current = node

            if current? and current.gx is endGrid.gx and current.gy is endGrid.gy

                path = []
                currentKey = makeKey(current.gx, current.gy)

                while cameFrom[currentKey]?

                    path.unshift(gridToPoint(current.gx, current.gy))
                    prev = cameFrom[currentKey]
                    current = prev
                    currentKey = makeKey(current.gx, current.gy)

                path.unshift(start)
                path.push(end)

                return @simplifyPath(path, holePolygons)

            if current?

                removeIdx = -1

                for node, idx in openSet

                    if node.gx is current.gx and node.gy is current.gy

                        removeIdx = idx
                        break

                if removeIdx >= 0

                    openSet.splice(removeIdx, 1)

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

                    continue unless isValidCell(neighbor.gx, neighbor.gy)

                    neighborKey = makeKey(neighbor.gx, neighbor.gy)
                    currentKey = makeKey(current.gx, current.gy)

                    isDiagonal = (neighbor.gx isnt current.gx) and (neighbor.gy isnt current.gy)
                    moveCost = if isDiagonal then 1.414 else 1.0

                    tentativeG = (gScore[currentKey] or 0) + moveCost

                    if not gScore[neighborKey]? or tentativeG < gScore[neighborKey]

                        cameFrom[neighborKey] = current
                        gScore[neighborKey] = tentativeG
                        fScore[neighborKey] = tentativeG + primitives.manhattanDistance(neighbor.gx, neighbor.gy, endGrid.gx, endGrid.gy)

                        alreadyInOpen = false

                        for node in openSet

                            if node.gx is neighbor.gx and node.gy is neighbor.gy

                                alreadyInOpen = true
                                break

                        if not alreadyInOpen

                            openSet.push(neighbor)

        # Fallback using boundary waypoints.
        if boundary? and boundary.length >= 4

            startQuadrant = @getQuadrant(start, boundary)
            endQuadrant = @getQuadrant(end, boundary)

            if startQuadrant isnt endQuadrant

                cornerWaypoint = @findBoundaryCorner(startQuadrant, endQuadrant, boundary)

                if cornerWaypoint?

                    seg1Safe = not @travelPathCrossesHoles(start, cornerWaypoint, holePolygons)
                    seg2Safe = not @travelPathCrossesHoles(cornerWaypoint, end, holePolygons)

                    if seg1Safe and seg2Safe

                        return [start, cornerWaypoint, end]

        return [start, end]

    # Determine which quadrant a point is in relative to boundary center.
    getQuadrant: (point, boundary) ->

        centerX = 0
        centerY = 0

        for p in boundary

            centerX += p.x
            centerY += p.y

        centerX /= boundary.length
        centerY /= boundary.length

        if point.x >= centerX
            if point.y >= centerY then 1 else 4
        else
            if point.y >= centerY then 2 else 3

    # Find an appropriate boundary corner to use as waypoint.
    findBoundaryCorner: (startQuadrant, endQuadrant, boundary) ->

        minX = Infinity
        maxX = -Infinity
        minY = Infinity
        maxY = -Infinity

        for p in boundary

            minX = Math.min(minX, p.x)
            maxX = Math.max(maxX, p.x)
            minY = Math.min(minY, p.y)
            maxY = Math.max(maxY, p.y)

        inset = 1.0

        corners = {
            1: { x: maxX - inset, y: maxY - inset }
            2: { x: minX + inset, y: maxY - inset }
            3: { x: minX + inset, y: minY + inset }
            4: { x: maxX - inset, y: minY + inset }
        }

        if startQuadrant is 1 and endQuadrant is 3
            return corners[2]
        if startQuadrant is 3 and endQuadrant is 1
            return corners[4]
        if startQuadrant is 2 and endQuadrant is 4
            return corners[1]
        if startQuadrant is 4 and endQuadrant is 2
            return corners[3]

        if (startQuadrant is 1 and endQuadrant is 2) or (startQuadrant is 2 and endQuadrant is 1)
            return corners[2]
        if (startQuadrant is 2 and endQuadrant is 3) or (startQuadrant is 3 and endQuadrant is 2)
            return corners[3]
        if (startQuadrant is 3 and endQuadrant is 4) or (startQuadrant is 4 and endQuadrant is 3)
            return corners[4]
        if (startQuadrant is 4 and endQuadrant is 1) or (startQuadrant is 1 and endQuadrant is 4)
            return corners[1]

        return null

    # Simplify path by removing unnecessary waypoints.
    simplifyPath: (path, holePolygons) ->

        return path if path.length <= 2

        simplified = [path[0]]

        for i in [1...path.length - 1]

            prev = simplified[simplified.length - 1]
            current = path[i]
            next = path[i + 1]

            if not @travelPathCrossesHoles(prev, next, holePolygons)

                continue

            else

                simplified.push(current)

        simplified.push(path[path.length - 1])

        return simplified

    # Check if two points are equal within tolerance.
    pointsEqual: (p1, p2, epsilon) ->

        dx = p1.x - p2.x
        dy = p1.y - p2.y

        return Math.sqrt(dx * dx + dy * dy) < epsilon

    # Build a safe path segment.
    buildSafePathSegment: (originalPoint, adjustedPoint, holePolygons, epsilon = 0.001) ->

        points = []

        if not @pointsEqual(originalPoint, adjustedPoint, epsilon)

            if not @travelPathCrossesHoles(originalPoint, adjustedPoint, holePolygons)

                points.push(originalPoint)
                points.push(adjustedPoint)

            else

                points.push(adjustedPoint)

        else

            points.push(originalPoint)

        return points

    # Add an endpoint to a path only if the transition is safe.
    addSafeEndpoint: (path, adjustedEnd, originalEnd, holePolygons, epsilon = 0.001) ->

        if not @pointsEqual(adjustedEnd, originalEnd, epsilon)

            if not @travelPathCrossesHoles(adjustedEnd, originalEnd, holePolygons)

                path.push(originalEnd)

    # Find the optimal starting point along a closed path for printing.
    findOptimalStartPoint: (path, fromPoint, holePolygons = [], boundary = null, nozzleDiameter = 0.4) ->

        return 0 if not path or path.length < 3
        return 0 if not fromPoint

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

        bestScore = Infinity
        bestIndex = 0

        for point, index in path

            dx = point.x - fromPoint.x
            dy = point.y - fromPoint.y

            straightDist = Math.sqrt(dx * dx + dy * dy)

            crossesHoles = @travelPathCrossesHoles(fromPoint, point, holePolygons)

            if not crossesHoles

                score = straightDist

            else

                combingPath = @findCombingPath(fromPoint, point, holePolygons, boundary, nozzleDiameter)

                totalDist = 0

                for i in [0...combingPath.length - 1]

                    segStart = combingPath[i]
                    segEnd = combingPath[i + 1]

                    segDx = segEnd.x - segStart.x
                    segDy = segEnd.y - segStart.y

                    totalDist += Math.sqrt(segDx * segDx + segDy * segDy)

                score = totalDist + straightDist * 0.1

            if score < bestScore

                bestScore = score
                bestIndex = index

        return bestIndex
