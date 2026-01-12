# Build plate boundary checking helper for adhesion module.

module.exports =

    # Check if adhesion geometry extends beyond build plate boundaries.
    # Returns an object with warning information if boundaries are exceeded.
    checkBuildPlateBoundaries: (slicer, boundingBox, centerOffsetX, centerOffsetY) ->

        buildPlateWidth = slicer.getBuildPlateWidth()
        buildPlateLength = slicer.getBuildPlateLength()

        # Get the bounds from the bounding box.
        minX = boundingBox.min.x + centerOffsetX
        maxX = boundingBox.max.x + centerOffsetX
        minY = boundingBox.min.y + centerOffsetY
        maxY = boundingBox.max.y + centerOffsetY

        # Check if any boundary is exceeded.
        exceedsBoundaries = minX < 0 or maxX > buildPlateWidth or minY < 0 or maxY > buildPlateLength

        return {
            exceeds: exceedsBoundaries
            minX: minX
            maxX: maxX
            minY: minY
            maxY: maxY
            buildPlateWidth: buildPlateWidth
            buildPlateLength: buildPlateLength
        }

    # Add warning comment to G-code if boundaries are exceeded.
    addBoundaryWarning: (slicer, boundaryInfo, adhesionType = 'adhesion') ->

        return unless boundaryInfo.exceeds

        verbose = slicer.getVerbose()

        return unless verbose

        slicer.gcode += "; WARNING: #{adhesionType} extends beyond build plate boundaries" + slicer.newline
        slicer.gcode += "; #{adhesionType} bounds: X(#{boundaryInfo.minX.toFixed(2)}, #{boundaryInfo.maxX.toFixed(2)}) Y(#{boundaryInfo.minY.toFixed(2)}, #{boundaryInfo.maxY.toFixed(2)})" + slicer.newline
        slicer.gcode += "; Build plate: X(0, #{boundaryInfo.buildPlateWidth}) Y(0, #{boundaryInfo.buildPlateLength})" + slicer.newline

        return

    # Calculate bounding box for circular skirt.
    calculateCircularSkirtBounds: (modelCenterX, modelCenterY, maxRadius) ->

        return {
            min: {
                x: modelCenterX - maxRadius
                y: modelCenterY - maxRadius
            }
            max: {
                x: modelCenterX + maxRadius
                y: modelCenterY + maxRadius
            }
        }

    # Calculate bounding box for shape-based skirt (path-based).
    calculatePathBounds: (path, offset = 0) ->

        return null unless path and path.length > 0

        minX = Infinity
        maxX = -Infinity
        minY = Infinity
        maxY = -Infinity

        for point in path

            minX = Math.min(minX, point.x - offset)
            maxX = Math.max(maxX, point.x + offset)
            minY = Math.min(minY, point.y - offset)
            maxY = Math.max(maxY, point.y + offset)

        return {
            min: { x: minX, y: minY }
            max: { x: maxX, y: maxY }
        }
