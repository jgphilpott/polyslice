# Unified file loader for Polyslice
# Supports STL, OBJ, 3MF, AMF, PLY, GLTF/GLB, and Collada formats
# Works in both Node.js and browser environments

class Loader

    constructor: ->

        @THREE = null
        @loaders = {}
        @initialized = false

    # Initialize three.js and loaders based on environment.
    initialize: ->

        return if @initialized

        # Detect environment and load three.js accordingly.
        if typeof window isnt 'undefined'

            # Browser environment - use global THREE.
            @THREE = window.THREE

            if not @THREE

                console.error("THREE.js is not available in browser environment. Please include three.js before Polyslice.")
                return

        else

            # Node.js environment - require three.js.
            try

                @THREE = require('three')

            catch error

                console.error("THREE.js is not available in Node.js environment. Please install it: npm install three")
                return

        @initialized = true

    # Load loaders on demand (async in Node.js environment).
    loadLoader: (loaderName, fileName = null) ->

        @initialize() if not @initialized
        return Promise.resolve(null) if not @THREE

        # Return cached loader if already loaded.
        return Promise.resolve(@loaders[loaderName]) if @loaders[loaderName]

        # Use provided fileName or default to loaderName.
        fileName = fileName or loaderName

        if typeof window isnt 'undefined'

            # Browser environment - loaders should be included separately.
            # The user needs to include them via script tags.
            loaderClass = @THREE[loaderName]

            if not loaderClass

                console.error("#{loaderName} is not available. Please include it from three.js examples.")
                return Promise.resolve(null)

            @loaders[loaderName] = new loaderClass()
            return Promise.resolve(@loaders[loaderName])

        else

            # Node.js environment - dynamically import from three.js examples (async).
            loaderPath = "three/examples/jsm/loaders/#{fileName}.js"

            return import(loaderPath)
                .then (LoaderModule) =>
                    LoaderClass = LoaderModule[loaderName] or LoaderModule.default
                    @loaders[loaderName] = new LoaderClass()
                    return @loaders[loaderName]
                .catch (error) =>
                    console.error("Failed to load #{loaderName}: #{error.message}")
                    return null

    # Load STL file and return mesh(es).
    loadSTL: (path, material = null) ->

        return @loadLoader('STLLoader').then (loader) =>

            return Promise.reject(new Error('STLLoader not available')) if not loader

            return new Promise (resolve, reject) =>

                loader.load(
                    path,
                    (geometry) =>
                        # Create material if not provided.
                        if not material
                            material = new @THREE.MeshPhongMaterial({ color: 0x808080, specular: 0x111111, shininess: 200 })

                        mesh = new @THREE.Mesh(geometry, material)
                        resolve(mesh)
                    ,
                    undefined, # onProgress
                    (error) =>
                        reject(error)
                )

    # Load OBJ file and return mesh(es).
    loadOBJ: (path, material = null) ->

        return @loadLoader('OBJLoader').then (loader) =>

            return Promise.reject(new Error('OBJLoader not available')) if not loader

            return new Promise (resolve, reject) =>

                loader.load(
                    path,
                    (object) =>
                        # OBJ loader returns a Group, which may contain multiple meshes.
                        meshes = []

                        object.traverse (child) =>
                            if child.isMesh
                                if material
                                    child.material = material
                                meshes.push(child)

                        # Return single mesh if only one, otherwise return array.
                        if meshes.length is 1
                            resolve(meshes[0])
                        else
                            resolve(meshes)
                    ,
                    undefined, # onProgress
                    (error) =>
                        reject(error)
                )

    # Load 3MF file and return mesh(es).
    load3MF: (path) ->

        return @loadLoader('ThreeMFLoader', '3MFLoader').then (loader) =>

            return Promise.reject(new Error('ThreeMFLoader not available')) if not loader

            return new Promise (resolve, reject) =>

                loader.load(
                    path,
                    (object) =>
                        # 3MF loader returns a Group.
                        meshes = []

                        object.traverse (child) =>
                            if child.isMesh
                                meshes.push(child)

                        if meshes.length is 1
                            resolve(meshes[0])
                        else
                            resolve(meshes)
                    ,
                    undefined, # onProgress
                    (error) =>
                        reject(error)
                )

    # Load AMF file and return mesh(es).
    loadAMF: (path) ->

        return @loadLoader('AMFLoader').then (loader) =>

            return Promise.reject(new Error('AMFLoader not available')) if not loader

            return new Promise (resolve, reject) =>

                loader.load(
                    path,
                    (object) =>
                        # AMF loader returns a Group.
                        meshes = []

                        object.traverse (child) =>
                            if child.isMesh
                                meshes.push(child)

                        if meshes.length is 1
                            resolve(meshes[0])
                        else
                            resolve(meshes)
                    ,
                    undefined, # onProgress
                    (error) =>
                        reject(error)
                )

    # Load PLY file and return mesh(es).
    loadPLY: (path, material = null) ->

        return @loadLoader('PLYLoader').then (loader) =>

            return Promise.reject(new Error('PLYLoader not available')) if not loader

            return new Promise (resolve, reject) =>

                loader.load(
                    path,
                    (geometry) =>
                        # Create material if not provided.
                        if not material
                            material = new @THREE.MeshPhongMaterial({ color: 0x808080, vertexColors: true })

                        mesh = new @THREE.Mesh(geometry, material)
                        resolve(mesh)
                    ,
                    undefined, # onProgress
                    (error) =>
                        reject(error)
                )

    # Load GLTF/GLB file and return mesh(es).
    loadGLTF: (path) ->

        return @loadLoader('GLTFLoader').then (loader) =>

            return Promise.reject(new Error('GLTFLoader not available')) if not loader

            return new Promise (resolve, reject) =>

                loader.load(
                    path,
                    (gltf) =>
                        # GLTF loader returns a GLTF object with scene property.
                        meshes = []

                        gltf.scene.traverse (child) =>
                            if child.isMesh
                                meshes.push(child)

                        if meshes.length is 1
                            resolve(meshes[0])
                        else
                            resolve(meshes)
                    ,
                    undefined, # onProgress
                    (error) =>
                        reject(error)
                )

    # Load Collada (DAE) file and return mesh(es).
    loadCollada: (path) ->

        return @loadLoader('ColladaLoader').then (loader) =>

            return Promise.reject(new Error('ColladaLoader not available')) if not loader

            return new Promise (resolve, reject) =>

                loader.load(
                    path,
                    (collada) =>
                        # Collada loader returns an object with scene property.
                        meshes = []

                        collada.scene.traverse (child) =>
                            if child.isMesh
                                meshes.push(child)

                        if meshes.length is 1
                            resolve(meshes[0])
                        else
                            resolve(meshes)
                    ,
                    undefined, # onProgress
                    (error) =>
                        reject(error)
                )

    # Generic load method that detects file format from extension.
    load: (path, options = {}) ->

        # Extract file extension.
        extension = path.split('.').pop().toLowerCase()

        # Load based on extension.
        switch extension
            when 'stl'
                return @loadSTL(path, options.material)
            when 'obj'
                return @loadOBJ(path, options.material)
            when '3mf'
                return @load3MF(path)
            when 'amf'
                return @loadAMF(path)
            when 'ply'
                return @loadPLY(path, options.material)
            when 'gltf', 'glb'
                return @loadGLTF(path)
            when 'dae'
                return @loadCollada(path)
            else
                return Promise.reject(new Error("Unsupported file format: #{extension}"))

# Create singleton instance.
loader = new Loader()

# Export for Node.js
if typeof module isnt 'undefined' and module.exports

    module.exports = loader

# Export for browser environments.
if typeof window isnt 'undefined'

    window.PolysliceLoader = loader

