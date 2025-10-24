# Infill generation module for Polyslice.

coders = require('../gcode/coders')
helpers = require('../geometry/helpers')

gridPattern = require('./patterns/grid')
trianglesPattern = require('./patterns/triangles')
hexagonsPattern = require('./patterns/hexagons')

module.exports =

    # Generate G-code for infill (interior fill with variable density).
    # holeInnerWalls: Array of hole inner wall paths to exclude from infill.
    generateInfillGCode: (slicer, boundaryPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint = null, holeInnerWalls = []) ->

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
        infillBoundary = helpers.createInsetPath(boundaryPath, infillGap)

        # Debug logging for layer 17 (Z around 3.4).
        if z >= 3.35 and z <= 3.45
            console.log("[LAYER 17 DEBUG] boundaryPath.length=#{boundaryPath.length}, infillBoundary.length=#{infillBoundary.length}")
            
            # Calculate bounding box of infill boundary.
            minX = Infinity
            maxX = -Infinity
            minY = Infinity
            maxY = -Infinity
            
            for point in infillBoundary
                if point.x < minX then minX = point.x
                if point.x > maxX then maxX = point.x
                if point.y < minY then minY = point.y
                if point.y > maxY then maxY = point.y
            
            width = maxX - minX
            height = maxY - minY
            
            console.log("[LAYER 17 DEBUG] Infill boundary width=#{width.toFixed(3)}, height=#{height.toFixed(3)}")
            console.log("[LAYER 17 DEBUG] First 3 points:", JSON.stringify(infillBoundary.slice(0, 3)))

        # If infill boundary is too small (empty or invalid), skip infill generation entirely.
        # This prevents printing "; TYPE: FILL" markers without any actual infill lines.
        if infillBoundary.length < 3
            console.log("[DEBUG] Skipping infill at Z=#{z}, infillBoundary.length=#{infillBoundary.length}") if process?.env?.DEBUG
            return

        if verbose then slicer.gcode += "; TYPE: FILL" + slicer.newline

        # Create inset versions of hole inner walls to maintain the same gap.
        # For holes, we want to shrink them (outset from the hole's perspective) by the same infill gap.
        # This ensures infill maintains a consistent gap from all walls, including hole walls.
        holeInnerWallsWithGap = []

        for holeWall in holeInnerWalls

            if holeWall.length >= 3

                # Create outset path for the hole (isHole=true means it will shrink the hole).
                holeWallWithGap = helpers.createInsetPath(holeWall, infillGap, true)

                if holeWallWithGap.length >= 3

                    holeInnerWallsWithGap.push(holeWallWithGap)

        # Calculate line spacing based on infill density.
        # Different patterns require different spacing multipliers:
        # - Grid (2 directions): multiply by 2
        # - Triangles (3 directions): multiply by 3
        # - Hexagons (3 directions): multiply by 3
        baseSpacing = nozzleDiameter / (infillDensity / 100.0)

        if infillPattern is 'grid'

            # Grid uses +45° and -45° lines (2 directions).
            # Formula: spacing = (nozzleDiameter / (density / 100)) * 2
            # For example: 20% density → spacing = (0.4 / 0.2) * 2 = 4.0mm per direction
            # This gives 10% in each direction, totaling 20% combined.
            lineSpacing = baseSpacing * 2.0

            gridPattern.generateGridInfill(slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint, holeInnerWallsWithGap)

        else if infillPattern is 'triangles'

            # Triangles uses 45°, 105° (45°+60°), and -15° (45°-60°) lines (3 directions).
            # Formula: spacing = (nozzleDiameter / (density / 100)) * 3
            # For example: 20% density → spacing = (0.4 / 0.2) * 3 = 6.0mm per direction
            # This gives ~6.67% in each direction, totaling 20% combined.
            lineSpacing = baseSpacing * 3.0

            trianglesPattern.generateTrianglesInfill(slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint, holeInnerWallsWithGap)

        else if infillPattern is 'hexagons'

            # Hexagons uses 0° (horizontal), 60°, and 120° (-60°) lines (3 directions).
            # Formula: spacing = (nozzleDiameter / (density / 100)) * 3
            # For example: 20% density → spacing = (0.4 / 0.2) * 3 = 6.0mm per direction
            # This gives ~6.67% in each direction, totaling 20% combined.
            lineSpacing = baseSpacing * 3.0

            hexagonsPattern.generateHexagonsInfill(slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint, holeInnerWallsWithGap)
