# File Loader

The Loader module provides a unified interface for loading 3D models from various file formats commonly used in 3D printing and modeling.

## Features

- **Format Support**: Load STL, OBJ, 3MF, AMF, PLY, GLTF/GLB, and Collada (DAE) files
- **Auto-Detection**: Automatically detect format from file extension
- **Custom Materials**: Apply custom THREE.js materials to loaded models
- **Cross-Platform**: Works in both Node.js and browser environments
- **Async API**: All methods return Promises for easy integration
- **Smart Returns**: Returns single mesh or array based on file contents

## Usage

### Basic Loading

```javascript
const { Loader } = require('@jgphilpott/polyslice');

// Auto-detect format from extension
const mesh = await Loader.load('model.stl');

// Or use format-specific loaders
const stlMesh = await Loader.loadSTL('model.stl');
const objMeshes = await Loader.loadOBJ('model.obj');
const plyMesh = await Loader.loadPLY('scan.ply');
```

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

### `load(path, options)`

Auto-detect format and load the file.

**Parameters:**
- `path` (string): Path to the file
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

Uses dynamic ES module imports for three.js loaders.

### Browser

Requires three.js to be loaded globally:

```html
<script src="https://unpkg.com/three@0.180.0/build/three.min.js"></script>
<script src="https://unpkg.com/@jgphilpott/polyslice/dist/index.browser.min.js"></script>
```

Loaders are expected to be available via global THREE object or script includes.

## Examples

See `examples/scripts/loader-usage.js` for complete usage examples.

## Implementation Details

- **Singleton Pattern**: Exported as a singleton instance for convenience
- **Loader Caching**: Loader instances are cached to avoid redundant initialization
- **Dynamic Imports**: In Node.js, loaders are dynamically imported from three.js
- **Error Handling**: Comprehensive error messages for missing dependencies or unsupported formats

## Notes

- File paths are relative to the current working directory in Node.js
- In browser, file loading depends on the specific loader implementation
- Some loaders may require additional three.js modules to be loaded
- Binary formats (STL, PLY) are automatically handled by the respective loaders

