# Polyslice Documentation

This directory contains detailed documentation for the Polyslice slicer library. The documentation is organized to mirror the source code structure in `/src` for easy navigation.

## Quick Links

- [Main README](../README.md) - Installation and quick start
- [API Reference](api/API.md) - Complete API documentation
- [Examples](examples/EXAMPLES.md) - Practical usage examples

## Documentation Structure

```
docs/
├── README.md                           # This file
├── api/
│   └── API.md                          # Complete API reference
├── examples/
│   └── EXAMPLES.md                     # Usage examples
├── development/
│   └── DEVELOPMENT.md                  # Development guide
├── tools/
│   └── TOOLS.md                        # G-code visualizer and sender
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
    ├── adhesion/
    │   └── ADHESION.md                 # Build plate adhesion (skirt, brim, raft)
    ├── utils/
    │   └── UTILS.md                    # Utility functions
    └── walls/
        └── WALLS.md                    # Wall perimeter generation
```

## Getting Started

- [API Reference](api/API.md) - Complete API documentation with all options and methods
- [Examples](examples/EXAMPLES.md) - Practical usage examples for Node.js and browser
- [Development Guide](development/DEVELOPMENT.md) - Setting up for development and contributing

## Tools

- [Tools](tools/TOOLS.md) - G-code visualizer and web G-code sender

## File I/O

- [Loaders](loaders/LOADERS.md) - Loading 3D models (STL, OBJ, 3MF, PLY, GLTF, DAE, AMF)
- [Exporters](exporters/EXPORTERS.md) - Saving G-code files and serial port streaming

## Configuration

- [Printer](config/PRINTER.md) - Pre-configured 3D printer profiles (44 printers)
- [Filament](config/FILAMENT.md) - Pre-configured filament profiles (35 materials)

## Slicer Documentation

### Core Slicing

- [Slicing](slicer/SLICING.md) - Main slicing functionality, usage examples, and configuration options
- [Implementation Summary](slicer/IMPLEMENTATION_SUMMARY.md) - Implementation details, file structure, and architecture overview
- [Polytree Integration](slicer/POLYTREE_INTEGRATION.md) - Polytree spatial query integration for optimized slicing

### G-code Generation

- [G-code](slicer/gcode/GCODE.md) - G-code generation methods and Marlin command reference

### Geometry

- [Geometry Helpers](slicer/geometry/GEOMETRY_HELPERS.md) - Geometry helper functions and Polytree contribution analysis
- [Combing](slicer/geometry/COMBING.md) - Travel path optimization to avoid crossing holes

### Infill

- [Infill](slicer/infill/INFILL.md) - Infill patterns (grid, triangles, hexagons) and density settings

### Preprocessing

- [Preprocessing](slicer/preprocessing/PREPROCESSING.md) - Mesh analysis and subdivision for sparse geometries

### Skin Layers

- [Skin](slicer/skin/SKIN.md) - Solid fill generation for top and bottom surfaces
- [Exposure Detection](slicer/skin/EXPOSURE_DETECTION.md) - Adaptive skin layer generation for exposed surfaces

### Support Structures

- [Support](slicer/support/SUPPORT.md) - Automatic support generation for overhanging geometry

### Build Plate Adhesion

- [Adhesion](slicer/adhesion/ADHESION.md) - Build plate adhesion structures (skirt, brim, raft)

### Utilities

- [Utils](slicer/utils/UTILS.md) - Core utility functions (bounds, clipping, paths, extrusion)

### Walls

- [Walls](slicer/walls/WALLS.md) - Wall perimeter generation and travel optimization

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
