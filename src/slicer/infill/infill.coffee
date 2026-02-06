# Infill generation module for Polyslice.

coders = require('../gcode/coders')
clipping = require('../utils/clipping')
paths = require('../utils/paths')

gridPattern = require('./patterns/grid')
trianglesPattern = require('./patterns/triangles')
hexagonsPattern = require('./patterns/hexagons')
concentricPattern = require('./patterns/concentric')
gyroidPattern = require('./patterns/gyroid')

module.exports =

    # Generate G-code for infill (interior fill with variable density).
    generateInfillGCode: (slicer, boundaryPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint = null, holeInnerWalls = [], holeOuterWalls = [], skinAreas = []) ->

        return if boundaryPath.length < 3

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()
        infillDensity = slicer.getInfillDensity()
        infillPattern = slicer.getInfillPattern()
        infillPatternCentering = slicer.getInfillPatternCentering()

        return if infillDensity <= 0

        return if infillPattern isnt 'grid' and infillPattern isnt 'triangles' and infillPattern isnt 'hexagons' and infillPattern isnt 'concentric' and infillPattern isnt 'gyroid'

        infillGap = nozzleDiameter / 2
        infillBoundary = paths.createInsetPath(boundaryPath, infillGap)

        return if infillBoundary.length < 3

        # Subtract skin areas from infill boundary if provided.
        infillBoundaries = []

        if skinAreas.length > 0

            infillBoundaries = clipping.subtractSkinAreasFromInfill(infillBoundary, skinAreas)

            return if infillBoundaries.length is 0

        else

            infillBoundaries = [infillBoundary]

        if verbose then slicer.gcode += "; TYPE: FILL" + slicer.newline

        # Create hole inner walls with gap.
        holeInnerWallsWithGap = []

        for holeWall in holeInnerWalls

            if holeWall.length >= 3

                holeWallWithGap = paths.createInsetPath(holeWall, infillGap, true)

                if holeWallWithGap.length >= 3

                    holeInnerWallsWithGap.push(holeWallWithGap)

        # Calculate line spacing based on density and pattern.
        baseSpacing = nozzleDiameter / (infillDensity / 100.0)

        for currentBoundary in infillBoundaries

            continue if currentBoundary.length < 3

            if infillPattern is 'grid'

                lineSpacing = baseSpacing * 2.0

                gridPattern.generateGridInfill(slicer, currentBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, infillPatternCentering, lastWallPoint, holeInnerWallsWithGap, holeOuterWalls)

            else if infillPattern is 'triangles'

                lineSpacing = baseSpacing * 3.0

                trianglesPattern.generateTrianglesInfill(slicer, currentBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, infillPatternCentering, lastWallPoint, holeInnerWallsWithGap, holeOuterWalls)

            else if infillPattern is 'hexagons'

                lineSpacing = baseSpacing * 3.0

                hexagonsPattern.generateHexagonsInfill(slicer, currentBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, infillPatternCentering, lastWallPoint, holeInnerWallsWithGap, holeOuterWalls)

            else if infillPattern is 'concentric'

                lineSpacing = baseSpacing

                concentricPattern.generateConcentricInfill(slicer, currentBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, infillPatternCentering, lastWallPoint, holeInnerWallsWithGap, holeOuterWalls)

            else if infillPattern is 'gyroid'

                lineSpacing = baseSpacing * 1.5

                gyroidPattern.generateGyroidInfill(slicer, currentBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, infillPatternCentering, lastWallPoint, holeInnerWallsWithGap, holeOuterWalls)
