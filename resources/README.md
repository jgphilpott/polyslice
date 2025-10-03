# Test Resources

This directory contains example 3D model files in various formats for testing the Polyslice file loaders.

## Directory Structure

```
resources/
├── stl/          # STL format (binary)
├── obj/          # Wavefront OBJ format
├── ply/          # PLY format (binary)
└── generate-models.js
```

## Available Models

Each format directory contains the same set of geometric shapes in three different sizes:

### Shapes
- **Cube** - Basic cubic geometry
- **Cylinder** - Cylindrical geometry with 32 segments
- **Sphere** - Spherical geometry with 32x32 segments
- **Cone** - Conical geometry with 32 segments
- **Torus** - Toroidal geometry with 16x32 segments

### Sizes
- **1cm** - Small models (10mm)
- **3cm** - Medium models (30mm)
- **5cm** - Large models (50mm)

## File Naming Convention

Files follow the pattern: `{shape}-{size}.{ext}`

Examples:
- `cube-1cm.stl`
- `cylinder-3cm.obj`
- `sphere-5cm.ply`

## Total Files

- **45 files** in total
- **15 files** per format (5 shapes × 3 sizes)

## Generating Models

To regenerate all model files:

```bash
node resources/generate-models.js
```

This script uses three.js exporters to generate the files programmatically.

## Formats Not Included

The following formats are not generated because they lack exporters in three.js:

- **3MF** (3D Manufacturing Format) - No exporter available
- **AMF** (Additive Manufacturing File) - No exporter available
- **Collada (DAE)** - No exporter available
- **GLTF/GLB** - Exporter requires browser APIs (FileReader, Blob) not available in Node.js

## Usage with Polyslice Loaders

These files can be used to test the Polyslice loader functionality:

```javascript
const { Loaders } = require('@jgphilpott/polyslice');

// Load an STL file
const mesh = await Loaders.loadSTL('resources/stl/cube-1cm.stl');

// Load an OBJ file
const objMesh = await Loaders.loadOBJ('resources/obj/sphere-3cm.obj');

// Load a PLY file
const plyMesh = await Loaders.loadPLY('resources/ply/torus-5cm.ply');

// Use with generic loader (auto-detects format)
const anyMesh = await Loaders.load('resources/stl/cylinder-1cm.stl');
```

## File Characteristics

### STL Files
- Binary format
- Contain triangle mesh data
- No color or material information
- Sizes: ~680B (cube) to ~97KB (sphere)

### OBJ Files
- ASCII text format
- Contain vertices and face definitions
- No color or material information in these files
- Sizes: ~936B (cube) to ~217KB (sphere)

### PLY Files
- Binary format
- Contain vertex and face data
- Support vertex colors (not used in these files)
- Sizes: ~1.2KB (cube) to ~60KB (sphere)

## Testing

These models are ideal for:
- Testing file loaders in both Node.js and browser environments
- Validating mesh geometry after import
- Performance testing with different mesh complexities
- Integration testing with the Polyslice slicer

