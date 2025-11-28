# Test Resources

This directory contains example 3D model files in various formats for testing the Polyslice file loaders.

## Directory Structure

```
resources/
├── stl/                            # STL format (binary)
│   ├── cube/     # Cube models
│   ├── cylinder/ # Cylinder models
│   ├── sphere/   # Sphere models
│   ├── cone/     # Cone models
│   └── torus/    # Torus models
├── obj/                            # Wavefront OBJ format
│   ├── cube/
│   ├── cylinder/
│   ├── sphere/
│   ├── cone/
│   └── torus/
├── ply/                            # PLY format (binary)
│   ├── cube/
│   ├── cylinder/
│   ├── sphere/
│   ├── cone/
│   └── torus/
├── gcode/                          # G-code output samples (stored in Git LFS)
│   └── infill/  # Infill pattern examples
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

## Usage with Polyslice Loader

These files can be used to test the Polyslice loader functionality:

```javascript
const { Loader } = require('@jgphilpott/polyslice');

// Load an STL file
const mesh = await Loader.loadSTL('resources/stl/cube/cube-1cm.stl');

// Load an OBJ file
const objMesh = await Loader.loadOBJ('resources/obj/sphere/sphere-3cm.obj');

// Load a PLY file
const plyMesh = await Loader.loadPLY('resources/ply/torus/torus-5cm.ply');

// Use with generic loader (auto-detects format)
const anyMesh = await Loader.load('resources/stl/cylinder/cylinder-1cm.stl');
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

## G-code Samples

The `gcode/` directory contains example G-code output files demonstrating different infill patterns and densities. These files are stored using [Git LFS](https://git-lfs.github.com/) to keep the repository size manageable.

### Available Samples

The `infill/` subdirectory contains 12 G-code files showcasing various infill patterns:

- **Grid pattern**: 20%, 40%, 60%, 80% density
- **Hexagon pattern**: 20%, 40%, 60%, 80% density
- **Triangle pattern**: 20%, 40%, 60%, 80% density

All samples are generated for a 1cm cube with 0.2mm layer height.

### Git LFS

These G-code files are tracked by Git LFS. When you clone the repository, Git LFS will automatically download the full files. If you don't have Git LFS installed, you'll only get small pointer files instead of the actual G-code content.

**To install Git LFS:**

```bash
# Debian/Ubuntu
sudo apt-get install git-lfs

# macOS
brew install git-lfs

# Windows
# Download from https://git-lfs.github.com/

# Initialize Git LFS
git lfs install
```

After installing Git LFS in an existing clone, fetch the actual files:

```bash
git lfs pull
```

## Testing

These models are ideal for:
- Testing file loaders in both Node.js and browser environments
- Validating mesh geometry after import
- Performance testing with different mesh complexities
- Integration testing with the Polyslice slicer
- Examining G-code output for different infill patterns and densities
