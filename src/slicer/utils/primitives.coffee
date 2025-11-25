# Primitive geometry operations for points and lines.
# Basic building blocks used by other geometry modules.

module.exports =

    # Check if two points are within epsilon distance using squared comparison.
    # More efficient than pointsEqual because it avoids the sqrt operation.
    # Use this when you need fast comparison in tight loops.
    pointsMatch: (p1, p2, epsilon) ->

        dx = p1.x - p2.x
        dy = p1.y - p2.y

        distSq = dx * dx + dy * dy

        return distSq < epsilon * epsilon

    # Check if two points are equal within tolerance using actual distance.
    # Less efficient but may be clearer when the epsilon is an actual distance.
    # Use pointsMatch when performance matters.
    pointsEqual: (p1, p2, epsilon) ->

        dx = p1.x - p2.x
        dy = p1.y - p2.y

        return Math.sqrt(dx * dx + dy * dy) < epsilon

    # Calculate intersection point of two line segments (infinite lines).
    # Returns the intersection point if it exists, null for parallel lines.
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

    # Calculate distance from a point to a line segment.
    distanceFromPointToLineSegment: (px, py, segStart, segEnd) ->

        dx = segEnd.x - segStart.x
        dy = segEnd.y - segStart.y
        lengthSq = dx * dx + dy * dy

        if lengthSq < 0.001
            # Degenerate segment, return distance to start point.
            return Math.sqrt((px - segStart.x) ** 2 + (py - segStart.y) ** 2)

        # Calculate parameter t for closest point on line segment.
        t = Math.max(0, Math.min(1, ((px - segStart.x) * dx + (py - segStart.y) * dy) / lengthSq))

        # Calculate closest point.
        closestX = segStart.x + t * dx
        closestY = segStart.y + t * dy

        # Return distance.
        return Math.sqrt((px - closestX) ** 2 + (py - closestY) ** 2)

    # Manhattan distance heuristic (used for A* pathfinding).
    manhattanDistance: (x1, y1, x2, y2) ->

        Math.abs(x2 - x1) + Math.abs(y2 - y1)

    # Deduplicate a list of intersection points.
    # When diagonal lines pass through bounding box corners, the same point
    # can be detected as an intersection with multiple edges.
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

    # Check if a line segment crosses a polygon.
    lineSegmentCrossesPolygon: (start, end, polygon) ->

        # Check if either endpoint is inside.
        if @pointInPolygon(start, polygon) or @pointInPolygon(end, polygon)
            return true

        # Check if line intersects any edge.
        for i in [0...polygon.length]
            nextIdx = if i is polygon.length - 1 then 0 else i + 1
            edgeStart = polygon[i]
            edgeEnd = polygon[nextIdx]

            if @lineSegmentIntersection(start, end, edgeStart, edgeEnd)
                return true

        return false
