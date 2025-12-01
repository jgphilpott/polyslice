---
applyTo: 'src/loaders/**/*.coffee'
---

# Loaders Module Overview

The loaders module provides unified 3D file loading for Polyslice. Located in `src/loaders/`.

## Purpose

- Load 3D model files in various formats (STL, OBJ, 3MF, AMF, PLY, GLTF/GLB, Collada)
- Work in both Node.js and browser environments
- Handle local file loading in Node.js using `fs.readFileSync()` + `parse()`
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
    @fs = null
    @isNode = typeof window is 'undefined'
```

### Initialization

The loader initializes three.js and fs based on environment:

```coffeescript
initialize: ->
    return if @initialized

    if typeof window isnt 'undefined'
        # Browser - use global THREE
        @THREE = window.THREE
    else
        # Node.js - require three.js and fs
        @THREE = require('three')
        @fs = require('fs')

    @initialized = true
```

### Helper Methods

#### isLocalPath

Detects if a path is a local file (not a URL):

```coffeescript
isLocalPath: (path) ->
    return false if typeof window isnt 'undefined'
    return not (path.startsWith('http://') or path.startsWith('https://') or path.startsWith('blob:'))
```

#### toArrayBuffer

Converts Node Buffer to ArrayBuffer for binary file parsing:

```coffeescript
toArrayBuffer: (buffer) ->
    return buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength)
```

## Supported Formats

| Format | Extension | Loader Class | File Type | Notes |
|--------|-----------|--------------|-----------|-------|
| STL | `.stl` | STLLoader | Binary | Returns BufferGeometry |
| OBJ | `.obj` | OBJLoader | Text (UTF-8) | Returns Group (may contain multiple meshes) |
| 3MF | `.3mf` | ThreeMFLoader | Binary | Returns Group |
| AMF | `.amf` | AMFLoader | Binary | Returns Group |
| PLY | `.ply` | PLYLoader | Binary | Returns BufferGeometry (may have vertex colors) |
| GLTF/GLB | `.gltf`, `.glb` | GLTFLoader | Binary | Returns GLTF object with scene property |
| Collada | `.dae` | ColladaLoader | Text (UTF-8) | Returns object with scene property |

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

## Node.js Local File Loading

In Node.js, the loader automatically handles local files:

```coffeescript
loadSTL: (path, material = null) ->
    return @loadLoader('STLLoader').then (loader) =>
        return new Promise (resolve, reject) =>

            # Node.js local file loading.
            if @isLocalPath(path)
                try
                    buffer = @fs.readFileSync(path)
                    geometry = loader.parse(@toArrayBuffer(buffer))
                    mesh = new @THREE.Mesh(geometry, material or defaultMaterial)
                    resolve(mesh)
                catch error
                    reject(error)
            else
                # Browser or URL loading via fetch.
                loader.load(path, onSuccess, undefined, onError)
```

### Binary vs Text Formats

| Format | Reading Method |
|--------|----------------|
| STL, PLY, 3MF, AMF, GLTF/GLB | `fs.readFileSync(path)` → `toArrayBuffer()` |
| OBJ, DAE | `fs.readFileSync(path, 'utf8')` |

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
<script src="https://unpkg.com/three@0.180.0/build/three.min.js"></script>
<script src="https://unpkg.com/@jgphilpott/polyslice/dist/index.browser.min.js"></script>
```

For model loading, also include and attach the three.js loaders to `window.THREE`:

```javascript
import { STLLoader } from 'three/addons/loaders/STLLoader.js';
window.THREE.STLLoader = STLLoader;
```

### Node.js Requirements

Install three.js as a dependency:

```bash
npm install three
```

Loaders are automatically imported from `three/examples/jsm/loaders/`.

Local files are read using `fs.readFileSync()` and parsed using the loader's `parse()` method.

## Usage with Polyslice

### Node.js

```coffeescript
Loader = require('@jgphilpott/polyslice').Loader

Loader.loadSTL('/path/to/model.stl').then (mesh) ->
    slicer = new Polyslice()
    gcode = slicer.slice(mesh)
    console.log(gcode)
```

### Browser

```javascript
// Using PolysliceLoader global
PolysliceLoader.loadSTL('https://example.com/model.stl')
    .then(mesh => {
        const slicer = new Polyslice();
        const gcode = slicer.slice(mesh);
        console.log(gcode);
    });
```

## Error Handling

All methods return Promises and reject with descriptive errors:

```coffeescript
# Unsupported format
loader.load('model.xyz')  # Rejects: "Unsupported file format: xyz"

# Missing three.js
loader.loadSTL('model.stl')  # Rejects: "STLLoader not available"

# File not found (Node.js)
loader.loadSTL('/nonexistent.stl')  # Rejects with ENOENT error
```

## Important Conventions

1. **Promise-based API**: All load methods return Promises
2. **Material defaults**: Default materials are created if not provided
3. **Format detection**: File extension determines loader to use
4. **Local path detection**: Uses `isLocalPath()` to distinguish files from URLs
5. **Binary conversion**: Uses `toArrayBuffer()` for binary file formats
6. **Mesh extraction**: Groups are traversed to extract individual meshes
7. **Single vs array**: Returns single mesh when only one exists, array otherwise
