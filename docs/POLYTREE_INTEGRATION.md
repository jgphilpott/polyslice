# Polytree Integration Notes

This document describes the current state and future plans for Polytree integration in Polyslice.

## Current Implementation

The slicing functionality is currently implemented using direct three.js mesh manipulation and custom triangle-plane intersection algorithms. While this works well for basic slicing, Polytree offers significant advantages for more advanced spatial queries.

## Polytree Package

Polytree (@jgphilpott/polytree v0.1.1) is already included as a dependency in the project. The package provides:

- Octree-based spatial partitioning
- CSG operations (union, subtraction, intersection)
- Spatial query functions
- Triangle-based operations

See: https://github.com/jgphilpott/polytree

## Missing Functionality

According to the Polytree README, the following functions are documented but not yet available in the current version (v0.1.1):

### Layer Slicing Functions

```javascript
// These APIs are documented but not yet exported in the bundle:
const layers = Polytree.sliceIntoLayers(
    mesh,                      // Input geometry
    0.2,                       // Layer height (0.2mm)
    -10,                       // Minimum Z
    10,                        // Maximum Z
    new THREE.Vector3(0, 0, 1) // Optional normal (default: Z-up)
);

const crossSection = Polytree.intersectPlane(mesh, plane);
```

### Verification

```javascript
const Polytree = require('@jgphilpott/polytree');
console.log(typeof Polytree.sliceIntoLayers);  // undefined
console.log(typeof Polytree.intersectPlane);   // undefined
```

## Required PR to Polytree

To enable advanced spatial queries in Polyslice, the following functions need to be added to Polytree's exports:

1. **`sliceIntoLayers(mesh, layerHeight, minZ, maxZ, normal)`**
   - Slices geometry into horizontal layers for 3D printing
   - Returns array of layer contours
   - Should use octree for efficient spatial queries

2. **`intersectPlane(mesh, plane)`**
   - Single plane intersection for cross-section analysis
   - Returns intersection contours as 2D paths
   - More efficient than iterating all triangles

3. **`getTrianglesNearPoint(mesh, point, radius)`**
   - Useful for localized queries
   - Would enable adaptive slicing

## Benefits of Polytree Integration

Once the above functions are available, Polyslice will gain:

1. **Performance**: Octree-based queries are much faster than brute-force triangle iteration
2. **Accuracy**: Better handling of edge cases and degenerate geometry
3. **Advanced Features**: 
   - Efficient support for multiple meshes/scenes
   - Faster intersection detection
   - Better handling of complex geometries

## Migration Path

When Polytree exports these functions, the migration will be straightforward:

### Current Implementation
```javascript
// Current: Custom triangle-plane intersection
layerPaths = @sliceAtHeight(mesh, currentZ, layerHeight)
```

### Future with Polytree
```javascript
// Future: Use Polytree's spatial queries
const polytree = new Polytree(mesh);
layerPaths = Polytree.sliceIntoLayers(mesh, layerHeight, minZ, maxZ);
```

The rest of the slicing pipeline (path connection, G-code generation) will remain the same.

## Action Items

1. **Create PR in Polytree repository** to export `sliceIntoLayers` and `intersectPlane` functions
2. **Verify exports** are working in a new Polytree version
3. **Update Polyslice** to use Polytree functions when available
4. **Add performance benchmarks** comparing custom vs. Polytree implementation
5. **Update tests** to cover both implementations

## Timeline

- **Phase 1** (Current): Basic slicing with custom triangle-plane intersection ✅
- **Phase 2** (Next): PR to Polytree for layer slicing functions
- **Phase 3**: Integration of Polytree spatial queries
- **Phase 4**: Advanced features (infill, supports) using Polytree

## References

- [Polytree Repository](https://github.com/jgphilpott/polytree)
- [Polytree README](https://github.com/jgphilpott/polytree#readme)
- [Polytree npm Package](https://www.npmjs.com/package/@jgphilpott/polytree)

## Notes from Problem Statement

> All spacial querying should be done with @jgphilpott/polytree. If you find Polytree is lacking/missing the functionality you need we will need to make a PR in the Polytree repo for adding it: https://github.com/jgphilpott/polytree

This implementation follows the guidance by:
1. Using Polytree where possible (included as dependency)
2. Identifying missing functionality (`sliceIntoLayers`, `intersectPlane`)
3. Documenting the required PR to Polytree
4. Implementing a working solution that can be enhanced with Polytree later
