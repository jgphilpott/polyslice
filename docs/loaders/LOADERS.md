# File Loader

The Loader module provides a unified interface for loading 3D models from various file formats commonly used in 3D printing and modeling.

## Features

- **Format Support**: Load STL, OBJ, 3MF, AMF, PLY, GLTF/GLB, and Collada (DAE) files
- **Auto-Detection**: Automatically detect format from file extension
- **Custom Materials**: Apply custom THREE.js materials to loaded models
- **Cross-Platform**: Works in both Node.js and browser environments
- **Local File Loading**: In Node.js, automatically reads local files using `fs.readFileSync()`
- **Async API**: All methods return Promises for easy integration
- **Smart Returns**: Returns single mesh or array based on file contents

## Usage

### Node.js - Local File Loading

```javascript
const { Loader } = require('@jgphilpott/polyslice');

// Auto-detect format from extension
const mesh = await Loader.load('/path/to/model.stl');

// Or use format-specific loaders
const stlMesh = await Loader.loadSTL('/path/to/model.stl');
const objMeshes = await Loader.loadOBJ('/path/to/model.obj');
const plyMesh = await Loader.loadPLY('/path/to/scan.ply');
```

In Node.js, the loader automatically:
1. Detects if the path is a local file (not a URL)
2. Reads the file using `fs.readFileSync()`
3. Parses the content using the appropriate three.js loader's `parse()` method
4. Returns a THREE.Mesh object ready for slicing

### Browser - URL Loading

```html
<script src="https://unpkg.com/three@0.180.0/build/three.min.js"></script>
<script src="https://unpkg.com/@jgphilpott/polyslice/dist/index.browser.min.js"></script>
<script>
  // Load from URL
  const mesh = await PolysliceLoader.loadSTL('https://example.com/model.stl');
</script>
```

In browser environments, the loader uses the three.js loader's `load()` method which fetches files via HTTP/HTTPS.

### Custom Materials

```javascript
const THREE = require('three');

// Create custom material
const material = new THREE.MeshPhongMaterial({
    color: 0xff0000,
    shininess: 100
});

// Load with custom material
const mesh = await Loader.loadSTL('model.stl', material);
```

### Multiple Objects

Some formats (OBJ, GLTF, 3MF) can contain multiple objects:

```javascript
// Returns array if multiple objects, single mesh if one object
const result = await Loader.loadOBJ('scene.obj');

// Handle both cases
const meshes = Array.isArray(result) ? result : [result];
meshes.forEach(mesh => {
    console.log('Loaded mesh:', mesh.name);
});
```

## Supported Formats

| Format | Extension | Method | Material Support | Description |
|--------|-----------|--------|------------------|-------------|
| STL | .stl | `loadSTL(path, material?)` | ✓ | Stereolithography - most common 3D printing format |
| OBJ | .obj | `loadOBJ(path, material?)` | ✓ | Wavefront Object - ubiquitous 3D modeling format |
| PLY | .ply | `loadPLY(path, material?)` | ✓ | Polygon File Format - common for 3D scans |
| 3MF | .3mf | `load3MF(path)` | ✗ | 3D Manufacturing Format - modern format with color/material |
| AMF | .amf | `loadAMF(path)` | ✗ | Additive Manufacturing File - XML-based format |
| GLTF/GLB | .gltf, .glb | `loadGLTF(path)` | ✗ | GL Transmission Format - modern 3D asset format |
| Collada | .dae | `loadCollada(path)` | ✗ | Digital Asset Exchange - common 3D exchange format |

**Note:** Formats marked with ✗ use materials defined in the file and cannot accept custom materials.

## API Reference

### `initialize()`

Initialize the loader (automatically called on first use).

**Returns:** void

### `isLocalPath(path)`

Check if a path is a local file path (not a URL). Used internally in Node.js to determine loading method.

**Parameters:**
- `path` (string): Path to check

**Returns:** boolean - `true` for local paths, `false` for URLs

### `load(path, options)`

Auto-detect format and load the file.

**Parameters:**
- `path` (string): Path to the file (local path in Node.js, URL in browser)
- `options` (object, optional): Options object (can include `material` for supported formats)

**Returns:** Promise<Mesh | Mesh[]>

### Format-Specific Loaders

#### `loadSTL(path, material?)`

Load STL (Stereolithography) file.

**Parameters:**
- `path` (string): Path to STL file
- `material` (THREE.Material, optional): Custom material to apply

**Returns:** Promise<Mesh>

#### `loadOBJ(path, material?)`

Load OBJ (Wavefront Object) file.

**Parameters:**
- `path` (string): Path to OBJ file
- `material` (THREE.Material, optional): Custom material to apply

**Returns:** Promise<Mesh | Mesh[]>

#### `loadPLY(path, material?)`

Load PLY (Polygon File Format) file.

**Parameters:**
- `path` (string): Path to PLY file
- `material` (THREE.Material, optional): Custom material to apply

**Returns:** Promise<Mesh>

#### `load3MF(path)`

Load 3MF (3D Manufacturing Format) file.

**Parameters:**
- `path` (string): Path to 3MF file

**Returns:** Promise<Mesh | Mesh[]>

#### `loadAMF(path)`

Load AMF (Additive Manufacturing File) file.

**Parameters:**
- `path` (string): Path to AMF file

**Returns:** Promise<Mesh | Mesh[]>

#### `loadGLTF(path)`

Load GLTF or GLB file.

**Parameters:**
- `path` (string): Path to GLTF/GLB file

**Returns:** Promise<Mesh | Mesh[]>

#### `loadCollada(path)`

Load Collada (DAE) file.

**Parameters:**
- `path` (string): Path to DAE file

**Returns:** Promise<Mesh | Mesh[]>

## Environment Compatibility

### Node.js

Requires `three` package:

```bash
npm install three
```

**Local File Loading:** The loader automatically detects local file paths and reads them using `fs.readFileSync()`. It then parses the content using the three.js loader's `parse()` method.

- STL, PLY, 3MF, AMF, GLTF/GLB files are read as binary (Buffer → ArrayBuffer)
- OBJ, DAE files are read as UTF-8 text

**URL Loading:** For HTTP/HTTPS URLs, the loader uses the standard three.js fetch-based loading.

### Browser

Requires three.js to be loaded globally:

```html
<script src="https://unpkg.com/three@0.180.0/build/three.min.js"></script>
<script src="https://unpkg.com/@jgphilpott/polyslice/dist/index.browser.min.js"></script>
```

For loading 3D models, you also need to include the respective three.js loaders and attach them to `window.THREE`:

```javascript
import { STLLoader } from 'three/addons/loaders/STLLoader.js';
import { OBJLoader } from 'three/addons/loaders/OBJLoader.js';
// ... other loaders

window.THREE.STLLoader = STLLoader;
window.THREE.OBJLoader = OBJLoader;
// ... attach other loaders
```

## Examples

See `examples/scripts/loader-usage.js` for complete Node.js usage examples.

## Implementation Details

- **Singleton Pattern**: Exported as a singleton instance for convenience
- **Loader Caching**: Loader instances are cached to avoid redundant initialization
- **Dynamic Imports**: In Node.js, loaders are dynamically imported from three.js
- **Local Path Detection**: Uses `isLocalPath()` to distinguish local files from URLs
- **Buffer Conversion**: Uses `toArrayBuffer()` to convert Node Buffers to ArrayBuffers
- **Error Handling**: Comprehensive error messages for missing dependencies or unsupported formats

## Notes

- In Node.js, local file paths are relative to the current working directory
- URLs (http://, https://, blob:) are loaded using the three.js loader's fetch-based method
- Binary formats (STL, PLY, 3MF, AMF, GLTF/GLB) are read as Buffers and converted to ArrayBuffers
- Text formats (OBJ, DAE) are read as UTF-8 strings
- Some loaders may require additional three.js modules to be loaded

