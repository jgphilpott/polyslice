# Helper functions for slice module.

primitives = require('../utils/primitives')

module.exports =

    # Calculate path centroid.
    calculatePathCentroid: (path) ->

        return null if path.length is 0

        sumX = 0
        sumY = 0

        for point in path

            sumX += point.x
            sumY += point.y

        return {
            x: sumX / path.length
            y: sumY / path.length
        }

    # Calculate distance between two points.
    calculateDistance: (pointA, pointB) ->

        return 1000000 if not pointA or not pointB

        dx = pointA.x - pointB.x
        dy = pointA.y - pointB.y

        return Math.sqrt(dx * dx + dy * dy)

    # Detect nesting levels for all paths to handle nested holes/structures.
    # Paths at odd nesting levels (1, 3, 5, ...) are holes.
    # Paths at even nesting levels (0, 2, 4, ...) are structures.
    detectNesting: (paths) ->

        pathNestingLevel = []
        pathIsHole = []

        for i in [0...paths.length]

            nestingLevel = 0

            # Count how many other paths contain this path.
            for j in [0...paths.length]

                continue if i is j

                if paths[i].length > 0 and primitives.pointInPolygon(paths[i][0], paths[j])

                    nestingLevel++

            pathNestingLevel.push(nestingLevel)

            # Odd nesting levels represent holes, even levels represent structures.
            isHole = nestingLevel % 2 is 1

            pathIsHole.push(isHole)

        return { pathNestingLevel, pathIsHole }

    # Filter holes by nesting level to only include direct children.
    filterHolesByNestingLevel: (holeArray, nestingLevels, parentNestingLevel) ->

        filtered = []

        for i in [0...holeArray.length]

            holeNestingLevel = nestingLevels[i]

            # Only include holes that are one level deeper (direct children).
            if holeNestingLevel is parentNestingLevel + 1

                filtered.push(holeArray[i])

        return filtered

    # Sort indices by nearest neighbor to minimize travel.
    sortByNearestNeighbor: (indices, paths, lastPosition) ->

        sorted = []
        remaining = indices.slice()

        while remaining.length > 0

            nearestIndex = -1
            nearestDistance = Infinity

            for idx in remaining

                path = paths[idx]
                centroid = @calculatePathCentroid(path)

                if centroid

                    distance = @calculateDistance(lastPosition, centroid)

                    if distance < nearestDistance

                        nearestDistance = distance
                        nearestIndex = idx

            if nearestIndex >= 0

                sorted.push(nearestIndex)

                remaining = remaining.filter((idx) -> idx isnt nearestIndex)

            else

                sorted.push(remaining[0])
                remaining.shift()

        return sorted
