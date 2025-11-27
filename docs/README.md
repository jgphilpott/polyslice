# Polyslice Documentation

This directory contains detailed documentation for the Polyslice slicer library. The documentation is organized to mirror the source code structure in `/src` for easy navigation.

## Quick Links

- [Main README](../README.md) - Installation, quick start, and API reference

## Documentation Structure

```
docs/
├── README.md                           # This file
├── loaders/
│   └── LOADERS.md                      # File loading API
├── exporters/
│   └── EXPORTERS.md                    # G-code export API
├── config/
│   ├── PRINTER.md                      # Printer configuration
│   └── FILAMENT.md                     # Filament configuration
└── slicer/                             # Slicing engine documentation
    ├── SLICING.md                      # Main slicing functionality
    ├── IMPLEMENTATION_SUMMARY.md       # Implementation details and architecture
    ├── POLYTREE_INTEGRATION.md         # Polytree spatial query integration
    ├── gcode/
    │   └── GCODE.md                    # G-code generation methods
    ├── geometry/                       # Geometry utilities
    │   ├── GEOMETRY_HELPERS.md         # Helper functions analysis
    │   └── COMBING.md                  # Travel path optimization
    ├── infill/
    │   └── INFILL.md                   # Infill patterns
    ├── preprocessing/
    │   └── PREPROCESSING.md            # Mesh preprocessing and subdivision
    ├── skin/                           # Skin layer generation
    │   ├── SKIN.md                     # Main skin generation
    │   └── EXPOSURE_DETECTION.md       # Adaptive skin layer algorithm
    ├── support/
    │   └── SUPPORT.md                  # Support structure generation
    ├── utils/
    │   └── UTILS.md                    # Utility functions
    └── walls/
        └── WALLS.md                    # Wall perimeter generation
```

## File I/O

| Document | Description |
|----------|-------------|
| [LOADERS.md](loaders/LOADERS.md) | Loading 3D models (STL, OBJ, 3MF, PLY, GLTF, DAE, AMF) |
| [EXPORTERS.md](exporters/EXPORTERS.md) | Saving G-code files and serial port streaming |

## Configuration

| Document | Description |
|----------|-------------|
| [PRINTER.md](config/PRINTER.md) | Pre-configured 3D printer profiles (44 printers) |
| [FILAMENT.md](config/FILAMENT.md) | Pre-configured filament profiles (35 materials) |

## Slicer Documentation

### Core Slicing

| Document | Description |
|----------|-------------|
| [SLICING.md](slicer/SLICING.md) | Main slicing functionality, usage examples, and configuration options |
| [IMPLEMENTATION_SUMMARY.md](slicer/IMPLEMENTATION_SUMMARY.md) | Implementation details, file structure, and architecture overview |
| [POLYTREE_INTEGRATION.md](slicer/POLYTREE_INTEGRATION.md) | Polytree spatial query integration for optimized slicing |

### G-code Generation

| Document | Description |
|----------|-------------|
| [GCODE.md](slicer/gcode/GCODE.md) | G-code generation methods and Marlin command reference |

### Geometry

| Document | Description |
|----------|-------------|
| [GEOMETRY_HELPERS.md](slicer/geometry/GEOMETRY_HELPERS.md) | Geometry helper functions and Polytree contribution analysis |
| [COMBING.md](slicer/geometry/COMBING.md) | Travel path optimization to avoid crossing holes |

### Infill

| Document | Description |
|----------|-------------|
| [INFILL.md](slicer/infill/INFILL.md) | Infill patterns (grid, triangles, hexagons) and density settings |

### Preprocessing

| Document | Description |
|----------|-------------|
| [PREPROCESSING.md](slicer/preprocessing/PREPROCESSING.md) | Mesh analysis and subdivision for sparse geometries |

### Skin Layers

| Document | Description |
|----------|-------------|
| [SKIN.md](slicer/skin/SKIN.md) | Solid fill generation for top and bottom surfaces |
| [EXPOSURE_DETECTION.md](slicer/skin/EXPOSURE_DETECTION.md) | Adaptive skin layer generation for exposed surfaces |

### Support Structures

| Document | Description |
|----------|-------------|
| [SUPPORT.md](slicer/support/SUPPORT.md) | Automatic support generation for overhanging geometry |

### Utilities

| Document | Description |
|----------|-------------|
| [UTILS.md](slicer/utils/UTILS.md) | Core utility functions (bounds, clipping, paths, extrusion) |

### Walls

| Document | Description |
|----------|-------------|
| [WALLS.md](slicer/walls/WALLS.md) | Wall perimeter generation and travel optimization |

## External References

- [Marlin G-code Documentation](https://marlinfw.org/docs/gcode/) - G-code command reference
- [three.js Documentation](https://threejs.org/docs/) - three.js mesh and geometry API
- [Polytree Repository](https://github.com/jgphilpott/polytree) - Spatial query library

## Contributing

When adding new documentation:

1. Place files in the appropriate subdirectory matching the source code structure
2. Update this README with links to new documentation
3. Follow existing documentation style and formatting conventions
4. Include code examples that are tested and working
5. Reference Marlin G-code documentation when documenting G-code commands
