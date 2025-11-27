# Polyslice Documentation

This directory contains detailed documentation for the Polyslice slicer library. The documentation is organized to mirror the source code structure in `/src` for easy navigation.

## Quick Links

- [Main README](../README.md) - Installation, quick start, and API reference
- [Loaders README](../src/loaders/README.md) - File loading API documentation
- [Exporters README](../src/exporters/README.md) - G-code export API documentation

## Documentation Structure

```
docs/
├── README.md                           # This file
└── slicer/                             # Slicing engine documentation
    ├── SLICING.md                      # Main slicing functionality
    ├── IMPLEMENTATION_SUMMARY.md       # Implementation details and architecture
    ├── POLYTREE_INTEGRATION.md         # Polytree spatial query integration
    ├── geometry/                       # Geometry utilities
    │   ├── GEOMETRY_HELPERS.md         # Helper functions analysis
    │   └── COMBING.md                  # Travel path optimization
    ├── infill/                         # Infill patterns (future docs)
    └── skin/                           # Skin layer generation
        └── EXPOSURE_DETECTION.md       # Adaptive skin layer algorithm
```

## Slicer Documentation

### Core Slicing

| Document | Description |
|----------|-------------|
| [SLICING.md](slicer/SLICING.md) | Main slicing functionality, usage examples, and configuration options |
| [IMPLEMENTATION_SUMMARY.md](slicer/IMPLEMENTATION_SUMMARY.md) | Implementation details, file structure, and architecture overview |
| [POLYTREE_INTEGRATION.md](slicer/POLYTREE_INTEGRATION.md) | Polytree spatial query integration for optimized slicing |

### Geometry

| Document | Description |
|----------|-------------|
| [GEOMETRY_HELPERS.md](slicer/geometry/GEOMETRY_HELPERS.md) | Geometry helper functions and Polytree contribution analysis |
| [COMBING.md](slicer/geometry/COMBING.md) | Travel path optimization to avoid crossing holes |

### Skin Layers

| Document | Description |
|----------|-------------|
| [EXPOSURE_DETECTION.md](slicer/skin/EXPOSURE_DETECTION.md) | Adaptive skin layer generation for exposed surfaces |

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
