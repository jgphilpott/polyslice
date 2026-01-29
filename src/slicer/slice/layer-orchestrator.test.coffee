# Tests for layer orchestrator module

layerOrchestrator = require('./layer-orchestrator')

describe 'Layer Orchestrator', ->

    describe 'generateLayerGCode', ->

        test 'should be defined and callable', ->

            expect(layerOrchestrator.generateLayerGCode).toBeDefined()
            expect(typeof layerOrchestrator.generateLayerGCode).toBe('function')

        test 'should return early for empty paths', ->

            # Minimal mock slicer
            slicer = {
                gcode: ''
                cumulativeE: 0
            }
            paths = []
            z = 0.2
            layerIndex = 0

            layerOrchestrator.generateLayerGCode(slicer, paths, z, layerIndex, 0, 0, 10, [], [])

            # Should not throw error and gcode should remain empty
            expect(slicer.gcode).toBe('')

        test 'should handle empty slicer state correctly', ->

            # Minimal mock slicer without cumulativeE
            slicer = {
                gcode: ''
            }
            paths = []
            z = 0.2
            layerIndex = 0

            # Function returns early for empty paths
            layerOrchestrator.generateLayerGCode(slicer, paths, z, layerIndex, 0, 0, 10, [], [])

            # Verify no errors occur with empty paths
            expect(slicer.gcode).toBe('')
