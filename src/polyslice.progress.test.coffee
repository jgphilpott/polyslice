# Tests for progress callback functionality in Polyslice.

Polyslice = require('./index')
THREE = require('three')

describe 'Polyslice Progress Callback', ->

    slicer = null
    progressEvents = null

    beforeEach ->

        progressEvents = []

        slicer = new Polyslice({
            onProgress: (progressInfo) ->
                progressEvents.push(progressInfo)
        })

    describe 'Progress Callback Configuration', ->

        test 'should accept onProgress callback in constructor', ->

            customSlicer = new Polyslice({
                onProgress: (info) -> console.log(info)
            })

            expect(customSlicer.getOnProgress()).toBeInstanceOf(Function)

        test 'should default to null when no callback provided', ->

            defaultSlicer = new Polyslice()

            expect(defaultSlicer.getOnProgress()).toBe(null)

        test 'should allow setting callback via setter', ->

            callback = (info) -> console.log(info)

            slicer.setOnProgress(callback)

            expect(slicer.getOnProgress()).toBe(callback)

        test 'should allow clearing callback by setting to null', ->

            slicer.setOnProgress(null)

            expect(slicer.getOnProgress()).toBe(null)

        test 'should reject non-function values', ->

            slicer.setOnProgress("not a function")

            expect(slicer.getOnProgress()).toBeInstanceOf(Function) # Should keep original callback

    describe 'Progress Information Structure', ->

        test 'should provide correct progress info structure', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial({ color: 0x00ff00 })
            cube = new THREE.Mesh(geometry, material)

            slicer.slice(cube)

            expect(progressEvents.length).toBeGreaterThan(0)

            # Check first event structure
            firstEvent = progressEvents[0]

            expect(firstEvent).toHaveProperty('stage')
            expect(firstEvent).toHaveProperty('percent')
            expect(firstEvent).toHaveProperty('currentLayer')
            expect(firstEvent).toHaveProperty('totalLayers')
            expect(firstEvent).toHaveProperty('message')

        test 'should have valid stage names', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial({ color: 0x00ff00 })
            cube = new THREE.Mesh(geometry, material)

            slicer.slice(cube)

            validStages = ['initializing', 'pre-print', 'adhesion', 'slicing', 'post-print', 'complete']
            stages = progressEvents.map((e) -> e.stage)

            for stage in stages
                expect(validStages).toContain(stage)

            return

        test 'should have increasing percent values', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial({ color: 0x00ff00 })
            cube = new THREE.Mesh(geometry, material)

            slicer.slice(cube)

            # Check that percent values are generally increasing (with some tolerance for stage changes)
            lastPercent = -1

            for event in progressEvents

                expect(event.percent).toBeGreaterThanOrEqual(0)
                expect(event.percent).toBeLessThanOrEqual(100)

                # Allow percent to reset between major stages, but within slicing it should increase
                if event.stage is 'slicing'
                    if lastPercent > 0 and lastPercent < 90
                        expect(event.percent).toBeGreaterThanOrEqual(lastPercent - 5) # Allow small variations

                lastPercent = event.percent

            return

    describe 'Progress Stages', ->

        test 'should report initializing stage', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial({ color: 0x00ff00 })
            cube = new THREE.Mesh(geometry, material)

            slicer.slice(cube)

            initializingEvents = progressEvents.filter((e) -> e.stage is 'initializing')

            expect(initializingEvents.length).toBeGreaterThan(0)
            expect(initializingEvents[0].percent).toBe(0)

        test 'should report pre-print stage', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial({ color: 0x00ff00 })
            cube = new THREE.Mesh(geometry, material)

            slicer.slice(cube)

            prePrintEvents = progressEvents.filter((e) -> e.stage is 'pre-print')

            expect(prePrintEvents.length).toBeGreaterThan(0)

        test 'should report slicing stage with layer information', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial({ color: 0x00ff00 })
            cube = new THREE.Mesh(geometry, material)

            slicer.slice(cube)

            slicingEvents = progressEvents.filter((e) -> e.stage is 'slicing')

            expect(slicingEvents.length).toBeGreaterThan(0)

            # Check that layer information is provided
            # Filter for events that have actual layer numbers (not the initial "Processing layers..." message)
            layerEvents = slicingEvents.filter((e) -> e.currentLayer? and e.totalLayers? and e.currentLayer > 0)

            expect(layerEvents.length).toBeGreaterThan(0)

            # Verify layer numbers are valid
            for event in layerEvents
                expect(event.currentLayer).toBeGreaterThan(0)
                expect(event.currentLayer).toBeLessThanOrEqual(event.totalLayers)

            return

        test 'should report post-print stage', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial({ color: 0x00ff00 })
            cube = new THREE.Mesh(geometry, material)

            slicer.slice(cube)

            postPrintEvents = progressEvents.filter((e) -> e.stage is 'post-print')

            expect(postPrintEvents.length).toBeGreaterThan(0)

        test 'should report complete stage at 100%', ->

            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial({ color: 0x00ff00 })
            cube = new THREE.Mesh(geometry, material)

            slicer.slice(cube)

            completeEvents = progressEvents.filter((e) -> e.stage is 'complete')

            expect(completeEvents.length).toBeGreaterThan(0)
            expect(completeEvents[0].percent).toBe(100)

        test 'should report adhesion stage when adhesion is enabled', ->

            adhesionSlicer = new Polyslice({
                adhesionEnabled: true
                adhesionType: 'skirt'
                onProgress: (progressInfo) ->
                    progressEvents.push(progressInfo)
            })

            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial({ color: 0x00ff00 })
            cube = new THREE.Mesh(geometry, material)

            adhesionSlicer.slice(cube)

            adhesionEvents = progressEvents.filter((e) -> e.stage is 'adhesion')

            expect(adhesionEvents.length).toBeGreaterThan(0)

    describe 'Error Handling', ->

        test 'should handle callback errors gracefully', ->

            errorSlicer = new Polyslice({
                onProgress: (progressInfo) ->
                    throw new Error("Test error in callback")
            })

            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial({ color: 0x00ff00 })
            cube = new THREE.Mesh(geometry, material)

            # Should not throw error despite callback error
            expect(() ->
                errorSlicer.slice(cube)
            ).not.toThrow()

        test 'should continue slicing after callback error', ->

            errorSlicer = new Polyslice({
                onProgress: (progressInfo) ->
                    throw new Error("Test error in callback")
            })

            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial({ color: 0x00ff00 })
            cube = new THREE.Mesh(geometry, material)

            gcode = errorSlicer.slice(cube)

            # Should still generate G-code
            expect(gcode).toBeTruthy()
            expect(gcode.length).toBeGreaterThan(0)

    describe 'Slicing Without Callback', ->

        test 'should slice normally when no callback is set', ->

            defaultSlicer = new Polyslice()

            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial({ color: 0x00ff00 })
            cube = new THREE.Mesh(geometry, material)

            gcode = defaultSlicer.slice(cube)

            expect(gcode).toBeTruthy()
            expect(gcode.length).toBeGreaterThan(0)
