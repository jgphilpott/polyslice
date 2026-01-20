# Tests for brim adhesion generation module.

Polyslice = require('../../../index')
THREE = require('three')
brimModule = require('./brim')

describe 'Brim Module', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Brim Generation', ->

        test 'should generate brim when firstLayerPaths provided', ->

            Polytree = require('@jgphilpott/polytree')
            pathsUtils = require('../../utils/paths')

            slicer.setVerbose(true)
            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('brim')
            slicer.setBrimLineCount(2)

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Slice the mesh to get first layer paths.
            layerHeight = slicer.getLayerHeight()
            minZ = boundingBox.min.z
            maxZ = boundingBox.max.z
            adjustedMinZ = minZ + 0.001

            allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, adjustedMinZ, maxZ)
            firstLayerSegments = allLayers[0]
            firstLayerPaths = pathsUtils.connectSegmentsToPaths(firstLayerSegments)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            brimModule.generateBrim(slicer, mesh, 0, 0, boundingBox, firstLayerPaths)

            # Should contain G-code.
            expect(slicer.gcode.length).toBeGreaterThan(0)

            # Should have extrusion moves.
            g1Count = (slicer.gcode.match(/G1.*E/g) || []).length
            expect(g1Count).toBeGreaterThan(0)

        test 'should generate multiple loops based on adhesionLineCount', ->

            Polytree = require('@jgphilpott/polytree')
            pathsUtils = require('../../utils/paths')

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('brim')
            slicer.setBrimLineCount(3)

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Slice the mesh to get first layer paths.
            layerHeight = slicer.getLayerHeight()
            minZ = boundingBox.min.z
            maxZ = boundingBox.max.z
            adjustedMinZ = minZ + 0.001

            allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, adjustedMinZ, maxZ)
            firstLayerSegments = allLayers[0]
            firstLayerPaths = pathsUtils.connectSegmentsToPaths(firstLayerSegments)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            brimModule.generateBrim(slicer, mesh, 0, 0, boundingBox, firstLayerPaths)

            # Count G1 commands with extrusion.
            g1Count = (slicer.gcode.match(/G1.*E/g) || []).length

            # Should have multiple extrusion moves (3 loops around the shape).
            # A box has 4 sides, so we expect at least 12 moves (4 sides * 3 loops).
            expect(g1Count).toBeGreaterThan(10)

        test 'should increase cumulative extrusion', ->

            Polytree = require('@jgphilpott/polytree')
            pathsUtils = require('../../utils/paths')

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('brim')
            slicer.setBrimLineCount(1)

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Slice the mesh to get first layer paths.
            layerHeight = slicer.getLayerHeight()
            minZ = boundingBox.min.z
            maxZ = boundingBox.max.z
            adjustedMinZ = minZ + 0.001

            allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, adjustedMinZ, maxZ)
            firstLayerSegments = allLayers[0]
            firstLayerPaths = pathsUtils.connectSegmentsToPaths(firstLayerSegments)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            initialE = slicer.cumulativeE

            brimModule.generateBrim(slicer, mesh, 0, 0, boundingBox, firstLayerPaths)

            # Extrusion should have increased.
            expect(slicer.cumulativeE).toBeGreaterThan(initialE)

        test 'should skip generation when no firstLayerPaths', ->

            slicer.setVerbose(true)
            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('brim')

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            # Call without firstLayerPaths.
            brimModule.generateBrim(slicer, mesh, 0, 0, boundingBox, null)

            # Should contain message about no paths.
            expect(slicer.gcode).toContain('No first layer paths available')

        test 'should warn when brim extends beyond build plate', ->

            Polytree = require('@jgphilpott/polytree')
            pathsUtils = require('../../utils/paths')

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('brim')
            slicer.setVerbose(true)
            slicer.setBrimLineCount(3)

            # Create a large geometry that will cause brim to exceed build plate.
            # Build plate is 220x220mm by default, create geometry that is 210mm.
            geometry = new THREE.BoxGeometry(210, 210, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Slice the mesh to get first layer paths.
            layerHeight = slicer.getLayerHeight()
            minZ = boundingBox.min.z
            maxZ = boundingBox.max.z
            adjustedMinZ = minZ + 0.001

            allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, adjustedMinZ, maxZ)
            firstLayerSegments = allLayers[0]
            firstLayerPaths = pathsUtils.connectSegmentsToPaths(firstLayerSegments)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            brimModule.generateBrim(slicer, mesh, 0, 0, boundingBox, firstLayerPaths)

            # Should contain warning about build plate boundaries.
            expect(slicer.gcode).toContain('WARNING: Brim extends beyond build plate boundaries')
