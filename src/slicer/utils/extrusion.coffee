# Extrusion calculation utilities for Polyslice.
# Used for calculating filament extrusion amounts.

module.exports =

    # Calculate extrusion amount based on distance, layer height, and settings.
    calculateExtrusion: (slicer, distance, lineWidth = null) ->

        if typeof distance isnt "number" or distance <= 0

            return 0

        # Use nozzle diameter as default line width if not specified.
        width = if lineWidth isnt null then lineWidth else slicer.getNozzleDiameter()

        layerHeight = slicer.getLayerHeight()
        filamentRadius = slicer.getFilamentDiameter() / 2
        extrusionMultiplier = slicer.getExtrusionMultiplier()

        # Calculate cross-sectional area of the extruded line.
        lineArea = width * layerHeight

        # Calculate cross-sectional area of the filament.
        filamentArea = Math.PI * filamentRadius * filamentRadius

        # Calculate extrusion length.
        extrusionLength = (lineArea * distance * extrusionMultiplier) / filamentArea

        return extrusionLength
