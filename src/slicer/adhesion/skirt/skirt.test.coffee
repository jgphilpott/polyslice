# Tests for skirt adhesion generation module.

Polyslice = require('../../../index')
THREE = require('three')
skirtModule = require('./skirt')

describe 'Skirt Module', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice({progressCallback: null})

    describe 'Circular Skirt Generation', ->

        test 'should generate circular skirt with TYPE comment when verbose', ->

            slicer.setVerbose(true)
            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('skirt')
            slicer.setSkirtType('circular')

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            skirtModule.generateCircularSkirt(slicer, mesh, 0, 0, boundingBox)

            # Should contain G-code.
            expect(slicer.gcode.length).toBeGreaterThan(0)

        test 'should generate circular path around model', ->

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('skirt')
            slicer.setSkirtType('circular')
            slicer.setSkirtLineCount(1)

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            skirtModule.generateCircularSkirt(slicer, mesh, 0, 0, boundingBox)

            # Should generate a circular path (64 segments).
            g1Count = (slicer.gcode.match(/G1.*E/g) || []).length

            # Should have at least 64 moves for one loop.
            expect(g1Count).toBeGreaterThan(60)

        test 'should generate multiple loops based on adhesionLineCount', ->

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('skirt')
            slicer.setSkirtLineCount(3)

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            skirtModule.generateCircularSkirt(slicer, mesh, 0, 0, boundingBox)

            # Count G1 commands with extrusion.
            g1Count = (slicer.gcode.match(/G1.*E/g) || []).length

            # Should have multiple extrusion moves (at least 64 * 3 loops).
            expect(g1Count).toBeGreaterThan(180)

        test 'should increase cumulative extrusion', ->

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('skirt')
            slicer.setSkirtLineCount(1)

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            initialE = slicer.cumulativeE

            skirtModule.generateCircularSkirt(slicer, mesh, 0, 0, boundingBox)

            # Extrusion should have increased.
            expect(slicer.cumulativeE).toBeGreaterThan(initialE)

        test 'should warn when skirt extends beyond build plate', ->

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('skirt')
            slicer.setSkirtType('circular')
            slicer.setVerbose(true)

            # Create a large geometry that will cause skirt to exceed build plate.
            # Build plate is 220x220mm by default, create geometry that is 200mm.
            geometry = new THREE.BoxGeometry(200, 200, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            skirtModule.generateCircularSkirt(slicer, mesh, 0, 0, boundingBox)

            # Should contain warning about build plate boundaries.
            expect(slicer.gcode).toContain('WARNING: Skirt extends beyond build plate boundaries')

    describe 'Shape-based Skirt Generation', ->

        test 'should generate shape-based skirt when firstLayerPaths provided', ->

            Polytree = require('@jgphilpott/polytree')
            pathsUtils = require('../../utils/paths')

            slicer.setVerbose(true)
            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('skirt')
            slicer.setSkirtType('shape')
            slicer.setSkirtLineCount(2)

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

            skirtModule.generateShapeSkirt(slicer, mesh, 0, 0, boundingBox, firstLayerPaths)

            # Should contain G-code.
            expect(slicer.gcode.length).toBeGreaterThan(0)

            # Should have extrusion moves.
            g1Count = (slicer.gcode.match(/G1.*E/g) || []).length
            expect(g1Count).toBeGreaterThan(0)

            # Should NOT contain fallback message.
            expect(slicer.gcode).not.toContain('not yet implemented')
            expect(slicer.gcode).not.toContain('using circular skirt')

        test 'should fall back to circular skirt when no firstLayerPaths', ->

            slicer.setVerbose(true)
            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('skirt')
            slicer.setSkirtType('shape')

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            # Call without firstLayerPaths.
            skirtModule.generateShapeSkirt(slicer, mesh, 0, 0, boundingBox, null)

            # Should contain message about fallback.
            expect(slicer.gcode).toContain('using circular skirt')

            # Should still generate some G-code (from fallback).
            expect(slicer.gcode.length).toBeGreaterThan(100)

        test 'should generate multiple loops based on adhesionLineCount', ->

            Polytree = require('@jgphilpott/polytree')
            pathsUtils = require('../../utils/paths')

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('skirt')
            slicer.setSkirtType('shape')
            slicer.setSkirtLineCount(3)

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

            skirtModule.generateShapeSkirt(slicer, mesh, 0, 0, boundingBox, firstLayerPaths)

            # Count G1 commands with extrusion.
            g1Count = (slicer.gcode.match(/G1.*E/g) || []).length

            # Should have multiple extrusion moves (3 loops around the shape).
            # A box has 4 sides, so we expect at least 12 moves (4 sides * 3 loops).
            expect(g1Count).toBeGreaterThan(10)

        test 'should increase cumulative extrusion', ->

            Polytree = require('@jgphilpott/polytree')
            pathsUtils = require('../../utils/paths')

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('skirt')
            slicer.setSkirtType('shape')
            slicer.setSkirtLineCount(1)

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

            skirtModule.generateShapeSkirt(slicer, mesh, 0, 0, boundingBox, firstLayerPaths)

            # Extrusion should have increased.
            expect(slicer.cumulativeE).toBeGreaterThan(initialE)
