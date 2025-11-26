# Polygon clipping operations for line and path clipping.
# Uses polygon-clipping library for complex operations.

polygonClipping = require('polygon-clipping')

primitives = require('./primitives')

module.exports =

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
    clipLineToPolygon: (lineStart, lineEnd, polygon) ->

        return [] if not polygon or polygon.length < 3
        return [] if not lineStart or not lineEnd

        # Find all intersection points of the line with polygon edges.
        intersections = []

        # Add the line endpoints with their inside/outside status.
        lineStartInside = primitives.pointInPolygon(lineStart, polygon)
        lineEndInside = primitives.pointInPolygon(lineEnd, polygon)

        if lineStartInside

            intersections.push({ point: lineStart, t: 0, isEndpoint: true })

        if lineEndInside

            intersections.push({ point: lineEnd, t: 1, isEndpoint: true })

        # Find intersections with polygon edges.
        for i in [0...polygon.length]

            nextIdx = if i is polygon.length - 1 then 0 else i + 1

            edgeStart = polygon[i]
            edgeEnd = polygon[nextIdx]

            intersection = primitives.lineSegmentIntersection(lineStart, lineEnd, edgeStart, edgeEnd)

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

            if primitives.pointInPolygon(midPoint, polygon)

                segments.push({
                    start: startIntersection.point
                    end: endIntersection.point
                })

        return segments

    # Clip a line segment to an inclusion polygon while excluding holes.
    # Returns an array of line segments that are inside the inclusion polygon but outside all hole polygons.
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
                    startInHole = primitives.pointInPolygon(segmentToClip.start, holePolygon)
                    endInHole = primitives.pointInPolygon(segmentToClip.end, holePolygon)

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

                            intersection = primitives.lineSegmentIntersection(segmentToClip.start, segmentToClip.end, edgeStart, edgeEnd)

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
                                if not primitives.pointInPolygon({ x: midX, y: midY }, holePolygon)

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

                            if not primitives.pointInPolygon({ x: midX, y: midY }, holePolygon)

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

                            intersection = primitives.lineSegmentIntersection(segmentToClip.start, segmentToClip.end, edgeStart, edgeEnd)

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

    # Subtract skin areas from infill boundary using polygon-clipping.
    # This prevents regular infill from overlapping with skin patches.
    subtractSkinAreasFromInfill: (infillBoundary, skinAreas = []) ->

        # If no skin areas to exclude, return original boundary as a single-element array.
        return [infillBoundary] if skinAreas.length is 0 or infillBoundary.length < 3

        # Convert boundary path to polygon-clipping format: [[[x, y], [x, y], ...]].
        # polygon-clipping expects coordinates as [x, y] arrays.
        infillPolygon = [[]]

        for point in infillBoundary

            infillPolygon[0].push([point.x, point.y])

        # Close the polygon if not already closed.
        firstPoint = infillBoundary[0]
        lastPoint = infillBoundary[infillBoundary.length - 1]

        if Math.abs(firstPoint.x - lastPoint.x) > 0.001 or Math.abs(firstPoint.y - lastPoint.y) > 0.001

            infillPolygon[0].push([firstPoint.x, firstPoint.y])

        # Convert skin areas to polygon-clipping format.
        skinPolygons = []

        for skinArea in skinAreas

            continue if skinArea.length < 3

            skinPolygon = [[]]

            for point in skinArea

                skinPolygon[0].push([point.x, point.y])

            # Close the polygon if not already closed.
            skinFirstPoint = skinArea[0]
            skinLastPoint = skinArea[skinArea.length - 1]

            if Math.abs(skinFirstPoint.x - skinLastPoint.x) > 0.001 or Math.abs(skinFirstPoint.y - skinLastPoint.y) > 0.001

                skinPolygon[0].push([skinFirstPoint.x, skinFirstPoint.y])

            skinPolygons.push(skinPolygon)

        # If all skin areas were degenerate, return original boundary.
        return [infillBoundary] if skinPolygons.length is 0

        # Use polygon-clipping difference operation to subtract skin areas from infill boundary.
        # Start with the infill boundary and subtract each skin area.
        resultPolygons = infillPolygon

        for skinPolygon, skinAreaIndex in skinPolygons

            try

                # Perform difference operation: infill - skin.
                resultPolygons = polygonClipping.difference(resultPolygons, skinPolygon)

            catch error

                # If polygon-clipping fails (e.g., invalid geometry), skip this skin area.
                console.warn("subtractSkinAreasFromInfill: polygon-clipping difference failed for skin area #{skinAreaIndex} (#{skinPolygon[0].length} points): #{error.message}")

        # Convert result back to our path format: {x, y} objects.
        resultPaths = []

        for polygon in resultPolygons

            # Each polygon can have multiple rings (outer + holes).
            # We only use the outer ring (first ring) for infill.
            outerRing = polygon[0]

            continue if not outerRing or outerRing.length < 3

            path = []

            for coord in outerRing

                path.push({ x: coord[0], y: coord[1] })

            resultPaths.push(path)

        # If no result paths (all infill was excluded), return empty array.
        return [] if resultPaths.length is 0

        return resultPaths
