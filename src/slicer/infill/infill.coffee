# Infill generation module for Polyslice.

coders = require('../gcode/coders')
helpers = require('../geometry/helpers')

gridPattern = require('./patterns/grid')
cubicPattern = require('./patterns/cubic')

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

        # Only process grid and cubic patterns for now.
        # Other patterns (lines, triangles, gyroid, honeycomb) not yet implemented.
        return if infillPattern not in ['grid', 'cubic']

        if verbose then slicer.gcode += "; TYPE: FILL" + slicer.newline

        # Create inset boundary for infill area (half nozzle diameter gap from innermost wall).
        infillGap = nozzleDiameter / 2
        infillBoundary = helpers.createInsetPath(boundaryPath, infillGap)

        return if infillBoundary.length < 3

        # Calculate line spacing based on infill density.
        # For grid pattern: we generate BOTH +45° and -45° lines (crosshatch), so double spacing.
        # For cubic pattern: we generate lines across 3 layers to form a 3D cubic structure,
        # using less material per layer cycle.
        baseSpacing = nozzleDiameter / (infillDensity / 100.0)

        if infillPattern is 'grid'

            # Grid uses both directions on every layer, so double the spacing.
            # Formula: spacing = (nozzleDiameter / (density / 100)) * 2
            # For example: 20% density → spacing = (0.4 / 0.2) * 2 = 4.0mm per direction
            # This gives 10% in each direction, totaling 20% combined.
            lineSpacing = baseSpacing * 2.0

        else if infillPattern is 'cubic'

            # Cubic uses one direction on layers 1 and 2, both on layer 0.
            # Over 3 layers, we have 4 sets of lines total (2 + 1 + 1).
            # To use less material (efficiency of 3D structure), we increase spacing.
            # Multiply by 2.4 to achieve ~70% of grid's material usage at same density.
            lineSpacing = baseSpacing * 2.4

        # Delegate to pattern-specific generator.
        if infillPattern is 'grid'

            gridPattern.generateGridInfill(slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint)

        else if infillPattern is 'cubic'

            cubicPattern.generateCubicInfill(slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint, layerIndex)
