# Smart wipe nozzle utilities for post-print sequence.

module.exports =

    # Calculate the best direction to wipe the nozzle away from the mesh.
    # Returns a direction vector { x, y } normalized and scaled by the wipe distance.
    calculateSmartWipeDirection: (lastPosition, meshBounds, centerOffsetX, centerOffsetY, wipeDistance = 10) ->

        # If no last position is available, fall back to simple wipe (X+5, Y+5).
        if not lastPosition or not meshBounds

            return { x: 5, y: 5 }

        # Last position is in local mesh coordinates, convert to build plate coordinates.
        currentX = lastPosition.x + centerOffsetX
        currentY = lastPosition.y + centerOffsetY

        # Mesh bounds in build plate coordinates.
        minX = meshBounds.min.x + centerOffsetX
        maxX = meshBounds.max.x + centerOffsetX
        minY = meshBounds.min.y + centerOffsetY
        maxY = meshBounds.max.y + centerOffsetY

        # Calculate distances to each boundary.
        distToLeft = currentX - minX
        distToRight = maxX - currentX
        distToBottom = currentY - minY
        distToTop = maxY - currentY

        # Find the closest boundary.
        minDist = Math.min(distToLeft, distToRight, distToBottom, distToTop)

        # Additional backoff distance beyond the boundary (mm).
        backoffDistance = 3.0

        # Determine wipe direction based on closest boundary.
        if minDist is distToLeft

            # Move left (negative X).
            distanceToMove = distToLeft + backoffDistance
            return { x: -Math.min(distanceToMove, wipeDistance), y: 0 }

        else if minDist is distToRight

            # Move right (positive X).
            distanceToMove = distToRight + backoffDistance
            return { x: Math.min(distanceToMove, wipeDistance), y: 0 }

        else if minDist is distToBottom

            # Move toward front (negative Y).
            distanceToMove = distToBottom + backoffDistance
            return { x: 0, y: -Math.min(distanceToMove, wipeDistance) }

        else if minDist is distToTop

            # Move toward back (positive Y).
            distanceToMove = distToTop + backoffDistance
            return { x: 0, y: Math.min(distanceToMove, wipeDistance) }

        # Fallback (shouldn't reach here).
        return { x: 5, y: 5 }

    # Check if a point is inside the mesh bounding box (in build plate coordinates).
    isPointInsideMeshBounds: (x, y, meshBounds, centerOffsetX, centerOffsetY) ->

        if not meshBounds

            return false

        # Mesh bounds in build plate coordinates.
        minX = meshBounds.min.x + centerOffsetX
        maxX = meshBounds.max.x + centerOffsetX
        minY = meshBounds.min.y + centerOffsetY
        maxY = meshBounds.max.y + centerOffsetY

        return x >= minX and x <= maxX and y >= minY and y <= maxY
