# Polytree Integration

This document describes the Polytree integration in Polyslice for optimized spatial queries.

## Overview

The slicing functionality uses Polytree's `sliceIntoLayers()` function for efficient spatial queries. This provides significant performance improvements over custom triangle-plane intersection algorithms.

## Polytree Package

Polytree (@jgphilpott/polytree) is included as a dependency in the project. The package provides:

- Octree-based spatial partitioning
- CSG operations (union, subtraction, intersection)
- Spatial query functions
- Triangle-based operations

See: https://github.com/jgphilpott/polytree

## Available Functionality

The following Polytree functions are exported and in use:

### Layer Slicing Functions

```javascript
// Slice mesh into layers
const layers = Polytree.sliceIntoLayers(
    mesh,                      // Input geometry
    0.2,                       // Layer height (0.2mm)
    minZ,                      // Minimum Z from bounding box
    maxZ,                      // Maximum Z from bounding box
    new THREE.Vector3(0, 0, 1) // Optional normal (default: Z-up)
);

// Single plane intersection
const crossSection = Polytree.intersectPlane(mesh, plane);
```

### Current Integration

✅ **`sliceIntoLayers(mesh, layerHeight, minZ, maxZ, normal)`**
   - Slices geometry into horizontal layers for 3D printing
   - Returns array of Line3 segments for each layer
   - Uses octree for efficient spatial queries
   - **Currently used** in Polyslice

✅ **`intersectPlane(mesh, plane)`**
   - Single plane intersection for cross-section analysis
   - Returns intersection segments as Line3 objects
   - **Available** for future use

## Benefits of Polytree Integration

Polyslice gains:

1. **Performance**: Octree-based queries are much faster than brute-force triangle iteration
2. **Accuracy**: Better handling of edge cases and degenerate geometry
3. **Advanced Features**:
   - Efficient support for multiple meshes/scenes
   - Faster intersection detection
   - Better handling of complex geometries

## Implementation

The integration is complete:

```coffeescript
# Using Polytree's spatial queries
allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ, maxZ)

# Convert Line3 segments to closed paths
for layerIndex in [0...allLayers.length]
    layerSegments = allLayers[layerIndex]
    layerPaths = pathsUtils.connectSegmentsToPaths(layerSegments)
    @generateLayerGCode(slicer, layerPaths, currentZ, ...)
```

The slicing pipeline:
1. Uses Polytree for efficient layer slicing
2. Connects Line3 segments into closed paths
3. Generates walls, infill, and skin
4. Centers coordinates on build plate
5. Generates G-code with proper extrusion

## Status

✅ **Completed:**
1. Polytree exports `sliceIntoLayers` and `intersectPlane` functions
2. Polyslice integrated with Polytree's spatial queries
3. All tests passing with new implementation
4. Documentation updated

**Future Enhancements:**
1. Explore additional Polytree functions for advanced features
2. Add performance benchmarks
3. Implement support structure generation using Polytree

## References

- [Polytree Repository](https://github.com/jgphilpott/polytree)
- [Polytree npm Package](https://www.npmjs.com/package/@jgphilpott/polytree)
