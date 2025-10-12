# Infill generation module for Polyslice.

coders = require('../gcode/coders')
helpers = require('../geometry/helpers')

gridPattern = require('./patterns/grid')
trianglesPattern = require('./patterns/triangles')

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

        # Only process grid and triangles patterns for now.
        # Other patterns (lines, cubic, gyroid, honeycomb) not yet implemented.
        return if infillPattern isnt 'grid' and infillPattern isnt 'triangles'

        if verbose then slicer.gcode += "; TYPE: FILL" + slicer.newline

        # Create inset boundary for infill area (half nozzle diameter gap from innermost wall).
        infillGap = nozzleDiameter / 2
        infillBoundary = helpers.createInsetPath(boundaryPath, infillGap)

        return if infillBoundary.length < 3

        # Calculate line spacing based on infill density.
        # Different patterns require different spacing multipliers:
        # - Grid (2 directions): multiply by 2
        # - Triangles (3 directions): multiply by 3
        baseSpacing = nozzleDiameter / (infillDensity / 100.0)

        if infillPattern is 'grid'

            # Grid uses +45° and -45° lines (2 directions).
            # Formula: spacing = (nozzleDiameter / (density / 100)) * 2
            # For example: 20% density → spacing = (0.4 / 0.2) * 2 = 4.0mm per direction
            # This gives 10% in each direction, totaling 20% combined.
            lineSpacing = baseSpacing * 2.0

            gridPattern.generateGridInfill(slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint)

        else if infillPattern is 'triangles'

            # Triangles uses 45°, 105° (45°+60°), and -15° (45°-60°) lines (3 directions).
            # Formula: spacing = (nozzleDiameter / (density / 100)) * 3
            # For example: 20% density → spacing = (0.4 / 0.2) * 3 = 6.0mm per direction
            # This gives ~6.67% in each direction, totaling 20% combined.
            lineSpacing = baseSpacing * 3.0

            trianglesPattern.generateTrianglesInfill(slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint)
