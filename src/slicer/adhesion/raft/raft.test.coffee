# Tests for raft adhesion generation module.

Polyslice = require('../../../index')
THREE = require('three')
raftModule = require('./raft')

describe 'Raft Module', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice({progressCallback: null})

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
            # A 26mm x 26mm raft (20mm box + 3mm margin on each side) with 8mm base spacing (4mm * 2)
            # should have roughly 3-4 lines per layer. With 1 base + 2 interface = 3 layers total.
            # So we expect roughly 10-20 extrusion moves.
            expect(g1Count).toBeGreaterThan(8)
            expect(g1Count).toBeLessThan(30)

    describe 'calculateRaftRegions', ->

        boundingBox = {
            min: { x: -10, y: -10 }
            max: { x: 10, y: 10 }
        }

        test 'should return single region from bounding box when no firstLayerPaths', ->

            regions = raftModule.calculateRaftRegions(boundingBox, null, 3)

            expect(regions.length).toBe(1)
            expect(regions[0].minX).toBeCloseTo(-13)
            expect(regions[0].maxX).toBeCloseTo(13)
            expect(regions[0].minY).toBeCloseTo(-13)
            expect(regions[0].maxY).toBeCloseTo(13)

        test 'should return single region from bounding box when firstLayerPaths is empty', ->

            regions = raftModule.calculateRaftRegions(boundingBox, [], 3)

            expect(regions.length).toBe(1)
            expect(regions[0].minX).toBeCloseTo(-13)

        test 'should return one region per separate outer path', ->

            # Simulate two separate contact regions (like arch feet) far apart.
            leftFoot = [
                { x: -20, y: -3 }
                { x: -15, y: -3 }
                { x: -15, y: 3 }
                { x: -20, y: 3 }
            ]

            rightFoot = [
                { x: 15, y: -3 }
                { x: 20, y: -3 }
                { x: 20, y: 3 }
                { x: 15, y: 3 }
            ]

            regions = raftModule.calculateRaftRegions(boundingBox, [leftFoot, rightFoot], 2)

            # Should create two separate regions, one for each foot.
            expect(regions.length).toBe(2)

        test 'separate regions should be smaller than a single bounding box raft', ->

            # Two small separate contact regions far apart (arch-like).
            leftFoot = [
                { x: -20, y: -3 }
                { x: -15, y: -3 }
                { x: -15, y: 3 }
                { x: -20, y: 3 }
            ]

            rightFoot = [
                { x: 15, y: -3 }
                { x: 20, y: -3 }
                { x: 20, y: 3 }
                { x: 15, y: 3 }
            ]

            singleRegion = raftModule.calculateRaftRegions(boundingBox, null, 2)
            twoRegions = raftModule.calculateRaftRegions(boundingBox, [leftFoot, rightFoot], 2)

            # Combined area of two separate regions should be smaller than single bounding box region.
            singleArea = (singleRegion[0].maxX - singleRegion[0].minX) * (singleRegion[0].maxY - singleRegion[0].minY)

            twoRegionArea = twoRegions.reduce((total, r) ->
                total + (r.maxX - r.minX) * (r.maxY - r.minY)
            , 0)

            expect(twoRegionArea).toBeLessThan(singleArea)

        test 'should exclude hole paths from raft regions', ->

            # Outer boundary.
            outerPath = [
                { x: -10, y: -10 }
                { x: 10, y: -10 }
                { x: 10, y: 10 }
                { x: -10, y: 10 }
            ]

            # Inner hole (inside the outer boundary).
            holePath = [
                { x: -5, y: -5 }
                { x: 5, y: -5 }
                { x: 5, y: 5 }
                { x: -5, y: 5 }
            ]

            regions = raftModule.calculateRaftRegions(boundingBox, [outerPath, holePath], 2)

            # Should only generate one region for the outer path, not for the hole.
            expect(regions.length).toBe(1)

        test 'should apply raft margin to each per-path region', ->

            # A small path.
            smallPath = [
                { x: 0, y: 0 }
                { x: 5, y: 0 }
                { x: 5, y: 5 }
                { x: 0, y: 5 }
            ]

            margin = 4
            regions = raftModule.calculateRaftRegions(boundingBox, [smallPath], margin)

            expect(regions.length).toBe(1)
            expect(regions[0].minX).toBeCloseTo(-4)
            expect(regions[0].maxX).toBeCloseTo(9)
            expect(regions[0].minY).toBeCloseTo(-4)
            expect(regions[0].maxY).toBeCloseTo(9)
