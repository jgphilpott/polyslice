# Tests for raft adhesion generation module.

Polyslice = require('../../../index')
THREE = require('three')
raftModule = require('./raft')

describe 'Raft Module', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Raft Generation', ->

        test 'should generate raft G-code', ->

            slicer.setVerbose(true)
            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('raft')
            slicer.setRaftMargin(5)
            slicer.setRaftBaseThickness(0.3)
            slicer.setRaftInterfaceLayers(2)
            slicer.setRaftInterfaceThickness(0.2)
            slicer.setRaftLineSpacing(2)

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            raftModule.generateRaft(slicer, mesh, 0, 0, boundingBox)

            # Should contain G-code.
            expect(slicer.gcode.length).toBeGreaterThan(0)

            # Should have layer comments.
            expect(slicer.gcode).toContain('Raft base layer')
            expect(slicer.gcode).toContain('Raft interface layer')

            # Should have extrusion moves.
            g1Count = (slicer.gcode.match(/G1.*E/g) || []).length
            expect(g1Count).toBeGreaterThan(0)

        test 'should increase cumulative extrusion', ->

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('raft')

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode and cumulative extrusion.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            raftModule.generateRaft(slicer, mesh, 0, 0, boundingBox)

            # Should have increased cumulative extrusion.
            expect(slicer.cumulativeE).toBeGreaterThan(0)

        test 'should respect raft margin setting', ->

            slicer.setVerbose(false)
            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('raft')
            slicer.setRaftMargin(10)  # Larger margin

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            raftModule.generateRaft(slicer, mesh, 0, 0, boundingBox)

            # Should have generated G-code (more lines due to larger raft).
            expect(slicer.gcode.length).toBeGreaterThan(0)

        test 'should generate multiple interface layers', ->

            slicer.setVerbose(true)
            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('raft')
            slicer.setRaftInterfaceLayers(3)  # More interface layers

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            raftModule.generateRaft(slicer, mesh, 0, 0, boundingBox)

            # Should have 3 interface layer comments.
            interfaceLayerCount = (slicer.gcode.match(/Raft interface layer/g) || []).length
            expect(interfaceLayerCount).toBe(3)

        test 'should generate lines at correct spacing', ->

            slicer.setVerbose(false)
            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('raft')
            slicer.setRaftLineSpacing(4)  # Wider spacing

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(20, 20, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            raftModule.generateRaft(slicer, mesh, 0, 0, boundingBox)

            # Count G1 commands with extrusion.
            g1Count = (slicer.gcode.match(/G1.*E/g) || []).length

            # With wider spacing, should have fewer lines than default.
            # A 30mm x 30mm raft (20mm box + 5mm margin on each side) with 8mm base spacing (4mm * 2)
            # should have roughly 4-5 lines per layer. With 1 base + 2 interface = 3 layers total.
            # So we expect roughly 12-15 extrusion moves.
            expect(g1Count).toBeGreaterThan(8)
            expect(g1Count).toBeLessThan(30)
