# Main slicing method for Polyslice
# This module contains the core slicing logic

coders = require('./coders')

module.exports =

    # Main slicing method that generates G-code from a scene.
    slice: (slicer, scene = {}) ->

        if slicer.getAutohome()

            slicer.gcode += coders.codeAutohome(slicer)

        return slicer.gcode
