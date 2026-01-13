# Tests for brim adhesion generation module.

Polyslice = require('../../../index')
THREE = require('three')
brimModule = require('./brim')

describe 'Brim Module', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Brim Generation', ->

        test 'should add not implemented message when verbose', ->

            slicer.setVerbose(true)
            slicer.gcode = ""

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            brimModule.generateBrim(slicer, mesh, 0, 0, boundingBox)

            # Should contain message about not yet implemented.
            expect(slicer.gcode).toContain('Brim generation not yet implemented')

        test 'should not add message when verbose disabled', ->

            slicer.setVerbose(false)
            slicer.gcode = ""

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            brimModule.generateBrim(slicer, mesh, 0, 0, boundingBox)

            # Should not contain any G-code.
            expect(slicer.gcode).toBe("")
