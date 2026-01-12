# Integration tests for adhesion generation module dispatcher.

Polyslice = require('../../index')
THREE = require('three')
adhesionModule = require('./adhesion')

describe 'Adhesion Module Integration', ->

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

            # Test with brim (not yet implemented, should add comment).
            slicer.setAdhesionType('brim')
            slicer.gcode = ""

            adhesionModule.generateAdhesionGCode(slicer, mesh, 0, 0, boundingBox)

            # Brim comment should be present even if not fully implemented.
            expect(slicer.gcode.length).toBeGreaterThan(0)

        test 'should respect adhesionSkirtType setting', ->

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('skirt')
            slicer.setAdhesionSkirtType('circular')

            expect(slicer.getAdhesionSkirtType()).toBe('circular')

            # Create a simple geometry for testing.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry)

            boundingBox = new THREE.Box3().setFromObject(mesh)

            # Reset gcode.
            slicer.gcode = ""
            slicer.cumulativeE = 0

            # Circular skirt should generate G-code.
            adhesionModule.generateAdhesionGCode(slicer, mesh, 0, 0, boundingBox)

            expect(slicer.gcode.length).toBeGreaterThan(0)

            # Test with shape type (falls back to circular for now).
            slicer.setAdhesionSkirtType('shape')
            slicer.gcode = ""
            slicer.cumulativeE = 0

            adhesionModule.generateAdhesionGCode(slicer, mesh, 0, 0, boundingBox)

            expect(slicer.gcode.length).toBeGreaterThan(0)

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

        test 'setAdhesionSkirtType should validate type', ->

            slicer.setAdhesionSkirtType('circular')
            expect(slicer.getAdhesionSkirtType()).toBe('circular')

            slicer.setAdhesionSkirtType('shape')
            expect(slicer.getAdhesionSkirtType()).toBe('shape')

            # Should reject invalid types.
            slicer.setAdhesionSkirtType('invalid')
            expect(slicer.getAdhesionSkirtType()).toBe('shape')

        test 'setAdhesionDistance should validate number', ->

            slicer.setAdhesionDistance(10)
            expect(slicer.getAdhesionDistance()).toBe(10)

            slicer.setAdhesionDistance(5)
            expect(slicer.getAdhesionDistance()).toBe(5)

            # Should ignore negative values.
            slicer.setAdhesionDistance(-5)
            expect(slicer.getAdhesionDistance()).toBe(5)

        test 'setAdhesionLineCount should validate number', ->

            slicer.setAdhesionLineCount(5)
            expect(slicer.getAdhesionLineCount()).toBe(5)

            slicer.setAdhesionLineCount(3)
            expect(slicer.getAdhesionLineCount()).toBe(3)

            # Should ignore negative values.
            slicer.setAdhesionLineCount(-1)
            expect(slicer.getAdhesionLineCount()).toBe(3)

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


    slicer = null

    beforeEach ->

        slicer = new Polyslice()
