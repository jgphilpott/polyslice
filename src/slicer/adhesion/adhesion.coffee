# Adhesion generation module for Polyslice.

skirtModule = require('./skirt/skirt')
brimModule = require('./brim/brim')
raftModule = require('./raft/raft')

module.exports =

    # Generate G-code for build plate adhesion (skirt, brim, or raft).
    generateAdhesionGCode: (slicer, mesh, centerOffsetX, centerOffsetY, boundingBox) ->

        return unless slicer.getAdhesionEnabled()

        adhesionType = slicer.getAdhesionType()
        verbose = slicer.getVerbose()

        # Dispatch to appropriate adhesion sub-module.
        switch adhesionType

            when 'skirt'

                if verbose then slicer.gcode += "; TYPE: SKIRT" + slicer.newline

                @generateSkirt(slicer, mesh, centerOffsetX, centerOffsetY, boundingBox)

            when 'brim'

                if verbose then slicer.gcode += "; TYPE: BRIM" + slicer.newline

                brimModule.generateBrim(slicer, mesh, centerOffsetX, centerOffsetY, boundingBox)

            when 'raft'

                if verbose then slicer.gcode += "; TYPE: RAFT" + slicer.newline

                raftModule.generateRaft(slicer, mesh, centerOffsetX, centerOffsetY, boundingBox)

        return

    # Generate skirt adhesion (dispatches to circular or shape-based).
    generateSkirt: (slicer, mesh, centerOffsetX, centerOffsetY, boundingBox) ->

        # Get skirt type configuration (default to 'circular').
        skirtType = slicer.getAdhesionSkirtType?() or 'circular'

        switch skirtType

            when 'circular'

                skirtModule.generateCircularSkirt(slicer, mesh, centerOffsetX, centerOffsetY, boundingBox)

            when 'shape'

                skirtModule.generateShapeSkirt(slicer, mesh, centerOffsetX, centerOffsetY, boundingBox)

            else

                # Default to circular if invalid type.
                skirtModule.generateCircularSkirt(slicer, mesh, centerOffsetX, centerOffsetY, boundingBox)

        return

