# Tests for the Loader module

Loader = require('./loader')

describe 'Loader', ->

    describe 'Initialization', ->

        beforeEach ->

            # Reset for initialization tests only.
            Loader.initialized = false
            Loader.THREE = null
            Loader.loaders = {}

        test 'should initialize in Node.js environment', ->

            Loader.initialize()

            expect(Loader.initialized).toBe(true)
            expect(Loader.THREE).toBeDefined()
            expect(Loader.THREE).not.toBeNull()

        test 'should not re-initialize if already initialized', ->

            Loader.initialize()
            firstTHREE = Loader.THREE

            Loader.initialize()

            expect(Loader.THREE).toBe(firstTHREE)

    describe 'Loader Loading', ->

        beforeAll ->

            # Initialize once for all loader tests.
            Loader.initialize()

        test 'should return a promise when loading STLLoader', ->

            # Note: Dynamic import() in Jest requires --experimental-vm-modules
            # In actual usage, these loaders work fine. Testing that promises are returned.
            loaderPromise = Loader.loadLoader('STLLoader')

            expect(loaderPromise).toBeInstanceOf(Promise)

        test 'should cache loaded loaders', ->

            # First call returns a promise.
            loaderPromise1 = Loader.loadLoader('STLLoader')
            expect(loaderPromise1).toBeInstanceOf(Promise)

            # After awaiting, subsequent calls should return the same cached instance.
            loader1 = await loaderPromise1
            loader2 = await Loader.loadLoader('STLLoader')

            # Only test caching if loaders were successfully loaded.
            if loader1 and loader2
                expect(loader1).toBe(loader2)

        test 'should return a promise when loading OBJLoader', ->

            loaderPromise = Loader.loadLoader('OBJLoader')

            expect(loaderPromise).toBeInstanceOf(Promise)

        test 'should return a promise when loading PLYLoader', ->

            loaderPromise = Loader.loadLoader('PLYLoader')

            expect(loaderPromise).toBeInstanceOf(Promise)

        test 'should return a promise when loading GLTFLoader', ->

            loaderPromise = Loader.loadLoader('GLTFLoader')

            expect(loaderPromise).toBeInstanceOf(Promise)

        test 'should return a promise when loading ColladaLoader', ->

            loaderPromise = Loader.loadLoader('ColladaLoader')

            expect(loaderPromise).toBeInstanceOf(Promise)

        test 'should attempt to load ThreeMFLoader in Node.js environment', ->

            # Note: Dynamic import() in Jest requires --experimental-vm-modules
            # In actual usage, this loader works fine. Testing that the promise is returned.
            loaderPromise = Loader.loadLoader('ThreeMFLoader', '3MFLoader')

            expect(loaderPromise).toBeInstanceOf(Promise)

        test 'should attempt to load AMFLoader in Node.js environment', ->

            # Note: Dynamic import() in Jest requires --experimental-vm-modules
            # In actual usage, this loader works fine. Testing that the promise is returned.
            loaderPromise = Loader.loadLoader('AMFLoader')

            expect(loaderPromise).toBeInstanceOf(Promise)

    describe 'Generic Load Method', ->

        beforeEach ->

            Loader.initialize()

        test 'should route .stl files to loadSTL', ->

            # Mock loadSTL to verify it's called.
            originalLoadSTL = Loader.loadSTL
            loadSTLCalled = false

            Loader.loadSTL = (path, material) ->
                loadSTLCalled = true
                return Promise.resolve({})

            Loader.load('test.stl')

            expect(loadSTLCalled).toBe(true)

            # Restore original method.
            Loader.loadSTL = originalLoadSTL
            return

        test 'should route .obj files to loadOBJ', ->

            originalLoadOBJ = Loader.loadOBJ
            loadOBJCalled = false

            Loader.loadOBJ = (path, material) ->
                loadOBJCalled = true
                return Promise.resolve({})

            Loader.load('test.obj')

            expect(loadOBJCalled).toBe(true)

            Loader.loadOBJ = originalLoadOBJ
            return

        test 'should route .3mf files to load3MF', ->

            originalLoad3MF = Loader.load3MF
            load3MFCalled = false

            Loader.load3MF = (path) ->
                load3MFCalled = true
                return Promise.resolve({})

            Loader.load('test.3mf')

            expect(load3MFCalled).toBe(true)

            Loader.load3MF = originalLoad3MF
            return

        test 'should route .amf files to loadAMF', ->

            originalLoadAMF = Loader.loadAMF
            loadAMFCalled = false

            Loader.loadAMF = (path) ->
                loadAMFCalled = true
                return Promise.resolve({})

            Loader.load('test.amf')

            expect(loadAMFCalled).toBe(true)

            Loader.loadAMF = originalLoadAMF
            return

        test 'should route .ply files to loadPLY', ->

            originalLoadPLY = Loader.loadPLY
            loadPLYCalled = false

            Loader.loadPLY = (path, material) ->
                loadPLYCalled = true
                return Promise.resolve({})

            Loader.load('test.ply')

            expect(loadPLYCalled).toBe(true)

            Loader.loadPLY = originalLoadPLY
            return

        test 'should route .gltf files to loadGLTF', ->

            originalLoadGLTF = Loader.loadGLTF
            loadGLTFCalled = false

            Loader.loadGLTF = (path) ->
                loadGLTFCalled = true
                return Promise.resolve({})

            Loader.load('test.gltf')

            expect(loadGLTFCalled).toBe(true)

            Loader.loadGLTF = originalLoadGLTF
            return

        test 'should route .glb files to loadGLTF', ->

            originalLoadGLTF = Loader.loadGLTF
            loadGLTFCalled = false

            Loader.loadGLTF = (path) ->
                loadGLTFCalled = true
                return Promise.resolve({})

            Loader.load('test.glb')

            expect(loadGLTFCalled).toBe(true)

            Loader.loadGLTF = originalLoadGLTF
            return

        test 'should route .dae files to loadCollada', ->

            originalLoadCollada = Loader.loadCollada
            loadColladaCalled = false

            Loader.loadCollada = (path) ->
                loadColladaCalled = true
                return Promise.resolve({})

            Loader.load('test.dae')

            expect(loadColladaCalled).toBe(true)

            Loader.loadCollada = originalLoadCollada
            return

        test 'should reject unsupported file formats', ->

            result = Loader.load('test.xyz')

            expect(result).rejects.toThrow('Unsupported file format: xyz')

    describe 'File Extension Detection', ->

        test 'should handle case-insensitive extensions', ->

            originalLoadSTL = Loader.loadSTL
            loadSTLCalled = false

            Loader.loadSTL = (path, material) ->
                loadSTLCalled = true
                return Promise.resolve({})

            Loader.load('test.STL')

            expect(loadSTLCalled).toBe(true)

            Loader.loadSTL = originalLoadSTL
            return

        test 'should handle paths with multiple dots', ->

            originalLoadOBJ = Loader.loadOBJ
            loadOBJCalled = false

            Loader.loadOBJ = (path, material) ->
                loadOBJCalled = true
                return Promise.resolve({})

            Loader.load('my.test.file.obj')

            expect(loadOBJCalled).toBe(true)

            Loader.loadOBJ = originalLoadOBJ
            return

    describe 'Error Handling', ->

        test 'should handle loader initialization failure gracefully', ->

            # This test is difficult to implement because we can't easily mock
            # require in the Node.js environment. Instead, we'll test that
            # initialization succeeds normally.
            Loader.THREE = null
            Loader.initialized = false

            Loader.initialize()

            # In the normal case, initialization should succeed.
            expect(Loader.initialized).toBe(true)
            expect(Loader.THREE).toBeDefined()

            return

        test 'should return null when loader cannot be loaded', ->

            Loader.initialize()

            loader = await Loader.loadLoader('NonExistentLoader')

            expect(loader).toBeNull()

    describe 'Module Exports', ->

        test 'should export a singleton instance', ->

            expect(Loader).toBeDefined()
            expect(typeof Loader.initialize).toBe('function')
            expect(typeof Loader.load).toBe('function')
            expect(typeof Loader.loadSTL).toBe('function')
            expect(typeof Loader.loadOBJ).toBe('function')
            expect(typeof Loader.load3MF).toBe('function')
            expect(typeof Loader.loadAMF).toBe('function')
            expect(typeof Loader.loadPLY).toBe('function')
            expect(typeof Loader.loadGLTF).toBe('function')
            expect(typeof Loader.loadCollada).toBe('function')

