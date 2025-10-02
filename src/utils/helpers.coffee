# Helper utility methods for Polyslice.

module.exports =

    # Check if coordinates are within build plate bounds.
    isWithinBounds: (slicer, x, y) ->

        if typeof x isnt "number" or typeof y isnt "number"

            return false

        halfWidth = slicer.getBuildPlateWidth() / 2
        halfLength = slicer.getBuildPlateLength() / 2

        return x >= -halfWidth and x <= halfWidth and y >= -halfLength and y <= halfLength

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
