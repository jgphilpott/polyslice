# Infill generation module for Polyslice.

coders = require('../gcode/coders')
clipping = require('../utils/clipping')
paths = require('../utils/paths')

gridPattern = require('./patterns/grid')
trianglesPattern = require('./patterns/triangles')
hexagonsPattern = require('./patterns/hexagons')

module.exports =

    # Generate G-code for infill (interior fill with variable density).
    # holeInnerWalls: Array of hole inner wall paths to exclude from infill (for clipping).
    # holeOuterWalls: Array of hole outer wall paths to avoid in travel (for travel optimization).
    # skinAreas: Array of skin area paths to exclude from infill (prevents overlap with adaptive skin patches).
    generateInfillGCode: (slicer, boundaryPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint = null, holeInnerWalls = [], holeOuterWalls = [], skinAreas = []) ->

        return if boundaryPath.length < 3

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()
        infillDensity = slicer.getInfillDensity()
        infillPattern = slicer.getInfillPattern()

        # Skip if no infill density configured.
        return if infillDensity <= 0

        # Only process grid, triangles, and hexagons patterns for now.
        # Other patterns (lines, cubic, gyroid, honeycomb) not yet implemented.
        return if infillPattern isnt 'grid' and infillPattern isnt 'triangles' and infillPattern isnt 'hexagons'

        # Create inset boundary for infill area (half nozzle diameter gap from innermost wall).
        infillGap = nozzleDiameter / 2
        infillBoundary = paths.createInsetPath(boundaryPath, infillGap)

        # If infill boundary is too small (empty or invalid), skip infill generation entirely.
        # This prevents printing "; TYPE: FILL" markers without any actual infill lines.
        return if infillBoundary.length < 3

        # If skin areas are provided (adaptive/intermediary skin patches), subtract them from infill boundary.
        # This prevents regular infill from overlapping with skin patches on mixed layers.
        infillBoundaries = []

        if skinAreas.length > 0

            # Use polygon-clipping to subtract skin areas from infill boundary.
            infillBoundaries = clipping.subtractSkinAreasFromInfill(infillBoundary, skinAreas)

            # If all infill was excluded by skin areas, skip infill generation.
            return if infillBoundaries.length is 0

        else

            # No skin areas to exclude - use original infill boundary.
            infillBoundaries = [infillBoundary]

        if verbose then slicer.gcode += "; TYPE: FILL" + slicer.newline

        # Create inset versions of hole inner walls to maintain the same gap.
        # For holes, we want to shrink them (outset from the hole's perspective) by the same infill gap.
        # This ensures infill maintains a consistent gap from all walls, including hole walls.
        holeInnerWallsWithGap = []

        for holeWall in holeInnerWalls

            if holeWall.length >= 3

                holeWallWithGap = paths.createInsetPath(holeWall, infillGap, true)

                if holeWallWithGap.length >= 3

                    holeInnerWallsWithGap.push(holeWallWithGap)

        # Calculate line spacing based on infill density and pattern direction count.
        baseSpacing = nozzleDiameter / (infillDensity / 100.0)

        for currentBoundary in infillBoundaries

            continue if currentBoundary.length < 3

            if infillPattern is 'grid'

                # Grid: 2 directions at ±45°.
                lineSpacing = baseSpacing * 2.0

                gridPattern.generateGridInfill(slicer, currentBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint, holeInnerWallsWithGap, holeOuterWalls)

            else if infillPattern is 'triangles'

                # Triangles: 3 directions at 45°, 105°, and -15°.
                lineSpacing = baseSpacing * 3.0

                trianglesPattern.generateTrianglesInfill(slicer, currentBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint, holeInnerWallsWithGap, holeOuterWalls)

            else if infillPattern is 'hexagons'

                # Hexagons: 3 directions at 0°, 60°, and 120°.
                lineSpacing = baseSpacing * 3.0

                hexagonsPattern.generateHexagonsInfill(slicer, currentBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint, holeInnerWallsWithGap, holeOuterWalls)
