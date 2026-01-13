# Tests for raft adhesion generation module.

Polyslice = require('../../../index')
THREE = require('three')
raftModule = require('./raft')

describe 'Raft Module', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Raft Generation', ->

        test 'should add not implemented message when verbose', ->

            slicer.setVerbose(true)
            slicer.gcode = ""

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            raftModule.generateRaft(slicer, mesh, 0, 0, boundingBox)

            # Should contain message about not yet implemented.
            expect(slicer.gcode).toContain('Raft generation not yet implemented')

        test 'should not add message when verbose disabled', ->

            slicer.setVerbose(false)
            slicer.gcode = ""

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            raftModule.generateRaft(slicer, mesh, 0, 0, boundingBox)

            # Should not contain any G-code.
            expect(slicer.gcode).toBe("")
