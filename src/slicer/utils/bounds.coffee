# Bounding box calculations and overlap detection.
# Used for spatial queries and optimization.

module.exports =

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
