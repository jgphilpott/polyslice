---
applyTo: 'src/loaders/**/*.coffee'
---

# Loaders Module Overview

The loaders module provides unified 3D file loading for Polyslice. Located in `src/loaders/`.

## Purpose

- Load 3D model files in various formats (STL, OBJ, 3MF, AMF, PLY, GLTF/GLB, Collada)
- Work in both Node.js and browser environments
- Return three.js mesh objects ready for slicing
- Provide automatic format detection from file extension

## Loader Class

Located in `src/loaders/loader.coffee`.

### Singleton Pattern

The module exports a singleton instance for convenience:

```coffeescript
loader = new Loader()

# Node.js
module.exports = loader

# Browser
window.PolysliceLoader = loader
```

### Constructor

```coffeescript
constructor: ->
    @THREE = null
    @loaders = {}
    @initialized = false
```

### Initialization

The loader initializes three.js based on environment:

```coffeescript
initialize: ->
    return if @initialized

    if typeof window isnt 'undefined'
        # Browser - use global THREE
        @THREE = window.THREE
    else
        # Node.js - require three.js
        @THREE = require('three')

    @initialized = true
```

## Supported Formats

| Format | Extension | Loader Class | Notes |
|--------|-----------|--------------|-------|
| STL | `.stl` | STLLoader | Returns BufferGeometry |
| OBJ | `.obj` | OBJLoader | Returns Group (may contain multiple meshes) |
| 3MF | `.3mf` | ThreeMFLoader | Returns Group |
| AMF | `.amf` | AMFLoader | Returns Group |
| PLY | `.ply` | PLYLoader | Returns BufferGeometry (may have vertex colors) |
| GLTF/GLB | `.gltf`, `.glb` | GLTFLoader | Returns GLTF object with scene property |
| Collada | `.dae` | ColladaLoader | Returns object with scene property |

## Loading Methods

### Generic Load

Automatically detects format from file extension:

```coffeescript
loader.load('model.stl', { material: customMaterial })
    .then (mesh) -> console.log(mesh)
    .catch (error) -> console.error(error)
```

### Format-Specific Methods

```coffeescript
loader.loadSTL(path, material)     # Returns single mesh
loader.loadOBJ(path, material)     # Returns mesh or array of meshes
loader.load3MF(path)               # Returns mesh or array of meshes
loader.loadAMF(path)               # Returns mesh or array of meshes
loader.loadPLY(path, material)     # Returns single mesh
loader.loadGLTF(path)              # Returns mesh or array of meshes
loader.loadCollada(path)           # Returns mesh or array of meshes
```

### Return Values

- Single mesh file → Returns single `THREE.Mesh`
- Multiple mesh file → Returns array of `THREE.Mesh`

## Lazy Loader Loading

Loaders are loaded on-demand to minimize initial bundle size:

```coffeescript
loadLoader: (loaderName, fileName = null) ->
    return Promise.resolve(@loaders[loaderName]) if @loaders[loaderName]

    if typeof window isnt 'undefined'
        # Browser - loaders should be pre-included via script tags
        loaderClass = @THREE[loaderName]
        @loaders[loaderName] = new loaderClass()
    else
        # Node.js - dynamic import from three.js examples
        loaderPath = "three/examples/jsm/loaders/#{fileName}.js"
        return import(loaderPath).then (LoaderModule) =>
            LoaderClass = LoaderModule[loaderName]
            @loaders[loaderName] = new LoaderClass()
            return @loaders[loaderName]
```

## Environment Compatibility

### Browser Requirements

Include three.js and required loaders via script tags before using:

```html
<script src="three.min.js"></script>
<script src="STLLoader.js"></script>
<script src="polyslice.min.js"></script>
```

### Node.js Requirements

Install three.js as a dependency:

```bash
npm install three
```

Loaders are automatically imported from `three/examples/jsm/loaders/`.

## Usage with Polyslice

```coffeescript
loader = require('@jgphilpott/polyslice').loader
# or in browser: PolysliceLoader

loader.loadSTL('model.stl').then (mesh) ->
    slicer = new Polyslice()
    gcode = slicer.slice(mesh)
    console.log(gcode)
```

## Error Handling

All methods return Promises and reject with descriptive errors:

```coffeescript
# Unsupported format
loader.load('model.xyz')  # Rejects: "Unsupported file format: xyz"

# Missing three.js
loader.loadSTL('model.stl')  # Rejects: "STLLoader not available"

# File not found
loader.loadSTL('missing.stl')  # Rejects with loader error
```

## Important Conventions

1. **Promise-based API**: All load methods return Promises
2. **Material defaults**: Default materials are created if not provided
3. **Format detection**: File extension determines loader to use
4. **Mesh extraction**: Groups are traversed to extract individual meshes
5. **Single vs array**: Returns single mesh when only one exists, array otherwise
