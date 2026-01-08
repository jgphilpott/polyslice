# Tests for adhesion generation module.

Polyslice = require('../../index')

THREE = require('three')

adhesionModule = require('./adhesion')

describe 'Adhesion Module', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Configuration', ->

        test 'should respect adhesionEnabled flag', ->

            # Adhesion generation should not occur when disabled.
            slicer.setAdhesionEnabled(false)

            expect(slicer.getAdhesionEnabled()).toBe(false)

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Call adhesion generation (should return early).
            result = adhesionModule.generateAdhesionGCode(slicer, mesh, 0, 0, boundingBox)

            expect(result).toBeUndefined()

        test 'should generate when adhesionEnabled is true', ->

            slicer.setAdhesionEnabled(true)

            expect(slicer.getAdhesionEnabled()).toBe(true)

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            # Call adhesion generation.
            adhesionModule.generateAdhesionGCode(slicer, mesh, 0, 0, boundingBox)

            # Should generate some G-code.
            expect(slicer.gcode.length).toBeGreaterThan(0)

        test 'should respect adhesionType setting', ->

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('skirt')

            expect(slicer.getAdhesionType()).toBe('skirt')

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            # Skirt should generate G-code.
            adhesionModule.generateAdhesionGCode(slicer, mesh, 0, 0, boundingBox)

            expect(slicer.gcode.length).toBeGreaterThan(0)

            # Test with brim (not yet implemented, should return early).
            slicer.setAdhesionType('brim')
            slicer.gcode = ""

            adhesionModule.generateAdhesionGCode(slicer, mesh, 0, 0, boundingBox)

            expect(slicer.gcode.length).toBe(0)

        test 'should use adhesionDistance setting', ->

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionDistance(10)

            expect(slicer.getAdhesionDistance()).toBe(10)

        test 'should use adhesionLineCount setting', ->

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionLineCount(5)

            expect(slicer.getAdhesionLineCount()).toBe(5)

    describe 'Skirt Generation', ->

        test 'should generate skirt with TYPE comment when verbose', ->

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('skirt')
            slicer.setVerbose(true)

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            adhesionModule.generateAdhesionGCode(slicer, mesh, 0, 0, boundingBox)

            expect(slicer.gcode).toContain('; TYPE: SKIRT')

        test 'should generate circular path around model', ->

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('skirt')
            slicer.setAdhesionLineCount(1)

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            adhesionModule.generateAdhesionGCode(slicer, mesh, 0, 0, boundingBox)

            # Should contain G1 commands (linear movement with extrusion).
            expect(slicer.gcode).toMatch(/G1.*E/)

        test 'should generate multiple loops based on adhesionLineCount', ->

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('skirt')
            slicer.setAdhesionLineCount(3)

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            adhesionModule.generateAdhesionGCode(slicer, mesh, 0, 0, boundingBox)

            # Count G1 commands with extrusion.
            g1Count = (slicer.gcode.match(/G1.*E/g) || []).length

            # Should have multiple extrusion moves (at least 64 * 3 loops).
            expect(g1Count).toBeGreaterThan(100)

        test 'should increase cumulative extrusion', ->

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('skirt')
            slicer.setAdhesionLineCount(1)

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            initialE = slicer.cumulativeE

            adhesionModule.generateAdhesionGCode(slicer, mesh, 0, 0, boundingBox)

            # Extrusion should have increased.
            expect(slicer.cumulativeE).toBeGreaterThan(initialE)

    describe 'Getter/Setter Tests', ->

        test 'setAdhesionEnabled should validate boolean', ->

            slicer.setAdhesionEnabled(true)
            expect(slicer.getAdhesionEnabled()).toBe(true)

            slicer.setAdhesionEnabled(false)
            expect(slicer.getAdhesionEnabled()).toBe(false)

            # Should coerce to boolean.
            slicer.setAdhesionEnabled(1)
            expect(slicer.getAdhesionEnabled()).toBe(true)

            slicer.setAdhesionEnabled(0)
            expect(slicer.getAdhesionEnabled()).toBe(false)

        test 'setAdhesionType should validate type', ->

            slicer.setAdhesionType('skirt')
            expect(slicer.getAdhesionType()).toBe('skirt')

            slicer.setAdhesionType('brim')
            expect(slicer.getAdhesionType()).toBe('brim')

            slicer.setAdhesionType('raft')
            expect(slicer.getAdhesionType()).toBe('raft')

            # Should reject invalid types.
            slicer.setAdhesionType('invalid')
            expect(slicer.getAdhesionType()).toBe('raft')

        test 'setAdhesionDistance should validate number', ->

            slicer.setAdhesionDistance(5)
            expect(slicer.getAdhesionDistance()).toBe(5)

            slicer.setAdhesionDistance(10)
            expect(slicer.getAdhesionDistance()).toBe(10)

            # Should reject negative values.
            slicer.setAdhesionDistance(-5)
            expect(slicer.getAdhesionDistance()).toBe(10)

        test 'setAdhesionLineCount should validate number', ->

            slicer.setAdhesionLineCount(1)
            expect(slicer.getAdhesionLineCount()).toBe(1)

            slicer.setAdhesionLineCount(5)
            expect(slicer.getAdhesionLineCount()).toBe(5)

            # Should reject negative values.
            slicer.setAdhesionLineCount(-1)
            expect(slicer.getAdhesionLineCount()).toBe(5)

        test 'should support method chaining', ->

            result = slicer
                .setAdhesionEnabled(true)
                .setAdhesionType('skirt')
                .setAdhesionDistance(8)
                .setAdhesionLineCount(4)

            expect(result).toBe(slicer)
            expect(slicer.getAdhesionEnabled()).toBe(true)
            expect(slicer.getAdhesionType()).toBe('skirt')
            expect(slicer.getAdhesionDistance()).toBe(8)
            expect(slicer.getAdhesionLineCount()).toBe(4)
