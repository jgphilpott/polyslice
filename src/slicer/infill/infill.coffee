# Infill generation module for Polyslice.

coders = require('../coders/coders')

geometryHelpers = require('../geometry/helpers')

gridPattern = require('./patterns/grid')

module.exports =

    # Generate G-code for infill (interior fill with variable density).
    generateInfillGCode: (slicer, boundaryPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint = null) ->

        return if boundaryPath.length < 3

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()
        infillDensity = slicer.getInfillDensity()
        infillPattern = slicer.getInfillPattern()

        # Skip if no infill density configured.
        return if infillDensity <= 0

        # Only process grid pattern for now.
        # Other patterns (lines, triangles, cubic, gyroid, honeycomb) not yet implemented.
        return if infillPattern isnt 'grid'

        if verbose then slicer.gcode += "; TYPE: FILL" + slicer.newline

        # Create inset boundary for infill area (half nozzle diameter gap from innermost wall).
        infillGap = nozzleDiameter / 2
        infillBoundary = geometryHelpers.createInsetPath(boundaryPath, infillGap)

        return if infillBoundary.length < 3

        # Calculate line spacing based on infill density.
        # Since we generate BOTH +45° and -45° lines (crosshatch), we need to double
        # the spacing to achieve the target density. Each direction contributes half.
        # Formula: spacing = (nozzleDiameter / (density / 100)) * 2
        # For example: 20% density → spacing = (0.4 / 0.2) * 2 = 4.0mm per direction
        # This gives 10% in each direction, totaling 20% combined.
        baseSpacing = nozzleDiameter / (infillDensity / 100.0)
        lineSpacing = baseSpacing * 2.0  # Double for grid pattern (both directions).

        # Delegate to pattern-specific generator.
        if infillPattern is 'grid'

            gridPattern.generateGridInfill(slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint)
