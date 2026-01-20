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

        test 'should respect skirtType setting', ->

            slicer.setAdhesionEnabled(true)
            slicer.setAdhesionType('skirt')
            slicer.setSkirtType('circular')

            expect(slicer.getSkirtType()).toBe('circular')

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
            slicer.setSkirtType('shape')
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

        test 'setSkirtType should validate type', ->

            slicer.setSkirtType('circular')
            expect(slicer.getSkirtType()).toBe('circular')

            slicer.setSkirtType('shape')
            expect(slicer.getSkirtType()).toBe('shape')

            # Should reject invalid types.
            slicer.setSkirtType('invalid')
            expect(slicer.getSkirtType()).toBe('shape')

        test 'setSkirtDistance should validate number', ->

            slicer.setSkirtDistance(10)
            expect(slicer.getSkirtDistance()).toBe(10)

            slicer.setSkirtDistance(5)
            expect(slicer.getSkirtDistance()).toBe(5)

            # Should ignore negative values.
            slicer.setSkirtDistance(-5)
            expect(slicer.getSkirtDistance()).toBe(5)

        test 'setSkirtLineCount should validate number', ->

            slicer.setSkirtLineCount(5)
            expect(slicer.getSkirtLineCount()).toBe(5)

            slicer.setSkirtLineCount(3)
            expect(slicer.getSkirtLineCount()).toBe(3)

            # Should ignore negative values.
            slicer.setSkirtLineCount(-1)
            expect(slicer.getSkirtLineCount()).toBe(3)

        test 'setBrimDistance should validate number', ->

            slicer.setBrimDistance(2)
            expect(slicer.getBrimDistance()).toBe(2)

            slicer.setBrimDistance(0)
            expect(slicer.getBrimDistance()).toBe(0)

            # Should ignore negative values.
            slicer.setBrimDistance(-1)
            expect(slicer.getBrimDistance()).toBe(0)

        test 'setBrimLineCount should validate number', ->

            slicer.setBrimLineCount(10)
            expect(slicer.getBrimLineCount()).toBe(10)

            slicer.setBrimLineCount(5)
            expect(slicer.getBrimLineCount()).toBe(5)

            # Should ignore negative values.
            slicer.setBrimLineCount(-1)
            expect(slicer.getBrimLineCount()).toBe(5)

        test 'should support method chaining', ->

            result = slicer
                .setAdhesionEnabled(true)
                .setAdhesionType('skirt')
                .setSkirtDistance(8)
                .setSkirtLineCount(4)
                .setBrimDistance(1)
                .setBrimLineCount(6)

            expect(result).toBe(slicer)
            expect(slicer.getAdhesionEnabled()).toBe(true)
            expect(slicer.getAdhesionType()).toBe('skirt')
            expect(slicer.getSkirtDistance()).toBe(8)
            expect(slicer.getSkirtLineCount()).toBe(4)
            expect(slicer.getBrimDistance()).toBe(1)
            expect(slicer.getBrimLineCount()).toBe(6)

    slicer = null

    beforeEach ->

        slicer = new Polyslice()
