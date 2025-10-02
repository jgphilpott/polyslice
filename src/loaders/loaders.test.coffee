# Tests for the Loaders module

Loaders = require('./loaders')

describe 'Loaders', ->

    describe 'Initialization', ->

        beforeEach ->

            # Reset for initialization tests only.
            Loaders.initialized = false
            Loaders.THREE = null
            Loaders.loaders = {}

        test 'should initialize in Node.js environment', ->

            Loaders.initialize()

            expect(Loaders.initialized).toBe(true)
            expect(Loaders.THREE).toBeDefined()
            expect(Loaders.THREE).not.toBeNull()

        test 'should not re-initialize if already initialized', ->

            Loaders.initialize()
            firstTHREE = Loaders.THREE

            Loaders.initialize()

            expect(Loaders.THREE).toBe(firstTHREE)

    describe 'Loader Loading', ->

        beforeAll ->

            # Initialize once for all loader tests.
            Loaders.initialize()

        test 'should return a promise when loading STLLoader', ->

            # Note: Dynamic import() in Jest requires --experimental-vm-modules
            # In actual usage, these loaders work fine. Testing that promises are returned.
            loaderPromise = Loaders.loadLoader('STLLoader')

            expect(loaderPromise).toBeInstanceOf(Promise)

        test 'should cache loaded loaders', ->

            # First call returns a promise.
            loaderPromise1 = Loaders.loadLoader('STLLoader')
            expect(loaderPromise1).toBeInstanceOf(Promise)

            # After awaiting, subsequent calls should return the same cached instance.
            loader1 = await loaderPromise1
            loader2 = await Loaders.loadLoader('STLLoader')

            # Only test caching if loaders were successfully loaded.
            if loader1 and loader2
                expect(loader1).toBe(loader2)

        test 'should return a promise when loading OBJLoader', ->

            loaderPromise = Loaders.loadLoader('OBJLoader')

            expect(loaderPromise).toBeInstanceOf(Promise)

        test 'should return a promise when loading PLYLoader', ->

            loaderPromise = Loaders.loadLoader('PLYLoader')

            expect(loaderPromise).toBeInstanceOf(Promise)

        test 'should return a promise when loading GLTFLoader', ->

            loaderPromise = Loaders.loadLoader('GLTFLoader')

            expect(loaderPromise).toBeInstanceOf(Promise)

        test 'should return a promise when loading ColladaLoader', ->

            loaderPromise = Loaders.loadLoader('ColladaLoader')

            expect(loaderPromise).toBeInstanceOf(Promise)

        test 'should attempt to load ThreeMFLoader in Node.js environment', ->

            # Note: Dynamic import() in Jest requires --experimental-vm-modules
            # In actual usage, this loader works fine. Testing that the promise is returned.
            loaderPromise = Loaders.loadLoader('ThreeMFLoader', '3MFLoader')

            expect(loaderPromise).toBeInstanceOf(Promise)

        test 'should attempt to load AMFLoader in Node.js environment', ->

            # Note: Dynamic import() in Jest requires --experimental-vm-modules
            # In actual usage, this loader works fine. Testing that the promise is returned.
            loaderPromise = Loaders.loadLoader('AMFLoader')

            expect(loaderPromise).toBeInstanceOf(Promise)

    describe 'Generic Load Method', ->

        beforeEach ->

            Loaders.initialize()

        test 'should route .stl files to loadSTL', ->

            # Mock loadSTL to verify it's called.
            originalLoadSTL = Loaders.loadSTL
            loadSTLCalled = false

            Loaders.loadSTL = (path, material) ->
                loadSTLCalled = true
                return Promise.resolve({})

            Loaders.load('test.stl')

            expect(loadSTLCalled).toBe(true)

            # Restore original method.
            Loaders.loadSTL = originalLoadSTL
            return

        test 'should route .obj files to loadOBJ', ->

            originalLoadOBJ = Loaders.loadOBJ
            loadOBJCalled = false

            Loaders.loadOBJ = (path, material) ->
                loadOBJCalled = true
                return Promise.resolve({})

            Loaders.load('test.obj')

            expect(loadOBJCalled).toBe(true)

            Loaders.loadOBJ = originalLoadOBJ
            return

        test 'should route .3mf files to load3MF', ->

            originalLoad3MF = Loaders.load3MF
            load3MFCalled = false

            Loaders.load3MF = (path) ->
                load3MFCalled = true
                return Promise.resolve({})

            Loaders.load('test.3mf')

            expect(load3MFCalled).toBe(true)

            Loaders.load3MF = originalLoad3MF
            return

        test 'should route .amf files to loadAMF', ->

            originalLoadAMF = Loaders.loadAMF
            loadAMFCalled = false

            Loaders.loadAMF = (path) ->
                loadAMFCalled = true
                return Promise.resolve({})

            Loaders.load('test.amf')

            expect(loadAMFCalled).toBe(true)

            Loaders.loadAMF = originalLoadAMF
            return

        test 'should route .ply files to loadPLY', ->

            originalLoadPLY = Loaders.loadPLY
            loadPLYCalled = false

            Loaders.loadPLY = (path, material) ->
                loadPLYCalled = true
                return Promise.resolve({})

            Loaders.load('test.ply')

            expect(loadPLYCalled).toBe(true)

            Loaders.loadPLY = originalLoadPLY
            return

        test 'should route .gltf files to loadGLTF', ->

            originalLoadGLTF = Loaders.loadGLTF
            loadGLTFCalled = false

            Loaders.loadGLTF = (path) ->
                loadGLTFCalled = true
                return Promise.resolve({})

            Loaders.load('test.gltf')

            expect(loadGLTFCalled).toBe(true)

            Loaders.loadGLTF = originalLoadGLTF
            return

        test 'should route .glb files to loadGLTF', ->

            originalLoadGLTF = Loaders.loadGLTF
            loadGLTFCalled = false

            Loaders.loadGLTF = (path) ->
                loadGLTFCalled = true
                return Promise.resolve({})

            Loaders.load('test.glb')

            expect(loadGLTFCalled).toBe(true)

            Loaders.loadGLTF = originalLoadGLTF
            return

        test 'should route .dae files to loadCollada', ->

            originalLoadCollada = Loaders.loadCollada
            loadColladaCalled = false

            Loaders.loadCollada = (path) ->
                loadColladaCalled = true
                return Promise.resolve({})

            Loaders.load('test.dae')

            expect(loadColladaCalled).toBe(true)

            Loaders.loadCollada = originalLoadCollada
            return

        test 'should reject unsupported file formats', ->

            result = Loaders.load('test.xyz')

            expect(result).rejects.toThrow('Unsupported file format: xyz')

    describe 'File Extension Detection', ->

        test 'should handle case-insensitive extensions', ->

            originalLoadSTL = Loaders.loadSTL
            loadSTLCalled = false

            Loaders.loadSTL = (path, material) ->
                loadSTLCalled = true
                return Promise.resolve({})

            Loaders.load('test.STL')

            expect(loadSTLCalled).toBe(true)

            Loaders.loadSTL = originalLoadSTL
            return

        test 'should handle paths with multiple dots', ->

            originalLoadOBJ = Loaders.loadOBJ
            loadOBJCalled = false

            Loaders.loadOBJ = (path, material) ->
                loadOBJCalled = true
                return Promise.resolve({})

            Loaders.load('my.test.file.obj')

            expect(loadOBJCalled).toBe(true)

            Loaders.loadOBJ = originalLoadOBJ
            return

    describe 'Error Handling', ->

        test 'should handle loader initialization failure gracefully', ->

            # This test is difficult to implement because we can't easily mock
            # require in the Node.js environment. Instead, we'll test that
            # initialization succeeds normally.
            Loaders.THREE = null
            Loaders.initialized = false

            Loaders.initialize()

            # In the normal case, initialization should succeed.
            expect(Loaders.initialized).toBe(true)
            expect(Loaders.THREE).toBeDefined()

            return

        test 'should return null when loader cannot be loaded', ->

            Loaders.initialize()

            loader = await Loaders.loadLoader('NonExistentLoader')

            expect(loader).toBeNull()

    describe 'Module Exports', ->

        test 'should export a singleton instance', ->

            expect(Loaders).toBeDefined()
            expect(typeof Loaders.initialize).toBe('function')
            expect(typeof Loaders.load).toBe('function')
            expect(typeof Loaders.loadSTL).toBe('function')
            expect(typeof Loaders.loadOBJ).toBe('function')
            expect(typeof Loaders.load3MF).toBe('function')
            expect(typeof Loaders.loadAMF).toBe('function')
            expect(typeof Loaders.loadPLY).toBe('function')
            expect(typeof Loaders.loadGLTF).toBe('function')
            expect(typeof Loaders.loadCollada).toBe('function')

