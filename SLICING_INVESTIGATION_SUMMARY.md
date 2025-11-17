# Investigation: Polytree sliceIntoLayers Replacement

## Executive Summary

After comprehensive research into existing npm packages for mesh slicing functionality, **no suitable production-ready package was found** that can replace Polytree's `sliceIntoLayers` method for 3D printing applications.

**Recommendation**: Implement a custom mesh slicing algorithm within polyslice.

---

## Background

### The Problem

From [PR #69](https://github.com/jgphilpott/polyslice/pull/69), we identified that Polytree's `sliceIntoLayers` method has critical issues:

- **Incomplete segment data** on complex models (Benchy test case)
- **Missing segments** for edges nearly parallel to the slice plane (<1° angle)
- **0.60mm gaps** in layer contours that should be closed
- **Two failed fix attempts** in Polytree (PRs #38 and #39)
- **Cross-repo debugging challenges** making fixes difficult

### What We Need

A robust mesh slicing solution that:
1. Takes a Three.js mesh and slice plane
2. Computes plane-triangle intersections
3. Returns connected 2D line segments (contours) for each layer
4. Handles edge cases: coplanar vertices, degenerate triangles, floating-point precision
5. Works reliably on complex geometries (e.g., Benchy with 225,706 triangles)

---

## Research Findings

### Packages Evaluated

#### 1. `@dgreenheck/three-pinata` ❌
- **Purpose**: Real-time mesh fracturing and fragmentation
- **Why Not Suitable**: 
  - Creates 3D mesh fragments, not 2D contour lines
  - Designed for destruction/physics simulations
  - Does NOT provide slice plane intersection segments
  - Cannot extract 2D paths for G-code generation
- **NPM**: [@dgreenheck/three-pinata](https://www.npmjs.com/package/@dgreenheck/three-pinata)

#### 2. `threejs-slice-geometry` ❌
- **Purpose**: Legacy Three.js geometry slicing
- **Why Not Suitable**:
  - Uses deprecated THREE.Geometry (removed in r125+)
  - Not maintained for modern THREE.BufferGeometry
  - Would require significant updates/rewrites
  - Community reports issues with BufferGeometry compatibility
- **GitHub**: [tdhooper/threejs-slice-geometry](https://github.com/tdhooper/threejs-slice-geometry)

#### 3. `three-mesh-bvh` ❌
- **Purpose**: Bounding Volume Hierarchy for raycasting acceleration
- **Why Not Suitable**:
  - Focused on raycasting performance optimization
  - No built-in mesh slicing functionality
  - Spatial queries (distance, intersection tests), not contour extraction
- **Already in devDependencies**
- **NPM**: [three-mesh-bvh](https://www.npmjs.com/package/three-mesh-bvh)

#### 4. `three-bvh-csg` ❌
- **Purpose**: Constructive Solid Geometry (CSG) operations
- **Why Not Suitable**:
  - Designed for boolean operations (union, subtract, intersect)
  - Does NOT provide plane slicing to extract contours
  - Focused on mesh-to-mesh operations, not mesh-to-plane
- **Already in devDependencies**
- **NPM**: [three-bvh-csg](https://www.npmjs.com/package/three-bvh-csg)

### Community Solutions Researched

#### Stack Overflow Approaches
- [Plane-Mesh Intersection Algorithm](https://stackoverflow.com/questions/42348495/three-js-find-all-points-where-a-mesh-intersects-a-plane)
  - Provides algorithmic approach but not a package
  - Requires custom implementation of:
    - Edge-plane intersection detection
    - Segment collection and ordering
    - Contour reconstruction

#### Three.js Forum Discussions
- [Build Mesh from Clipping Plane](https://discourse.threejs.org/t/build-new-mesh-from-clipping-plane-intersection-vertices/65756)
  - Community-shared code snippets
  - No maintained package
  - Each implementation has edge case issues

#### Python Alternative: trimesh
- **Purpose**: Robust computational geometry library (Python)
- **Capability**: Has robust slicing via `trimesh.intersections`
- **Why Not Suitable**: 
  - Python-only, not JavaScript/Node
  - Would require Python subprocess calls or port to JS
  - Adds significant complexity and dependencies

---

## Why No Suitable Package Exists

The specific requirement of **extracting 2D contours from 3D mesh slicing for G-code generation** is a niche use case. Most packages focus on:

1. **Visualization**: Mesh clipping for rendering (WebGL clipping planes)
2. **Physics/Games**: Mesh fracturing for destruction effects  
3. **CAD Operations**: Boolean operations between solid meshes
4. **General Geometry**: Raycasting, collision detection, spatial queries

**3D printing slicing** requires:
- Precise 2D contour extraction (not 3D fragments)
- Robust handling of edge cases (parallel edges, coplanar vertices)
- Segment chaining into closed paths
- High reliability on complex geometries

These requirements are specialized enough that most general-purpose Three.js packages don't address them.

---

## Recommended Solution: Custom Implementation

### Rationale

1. **No Suitable Package Available**: Extensive research found no production-ready solution
2. **Polytree Cross-Repo Issues**: Two failed fix attempts show debugging challenges
3. **Single Method Usage**: Only `sliceIntoLayers` is used in production from Polytree
4. **Full Control**: Custom implementation enables optimization for 3D printing workflow
5. **Easier Debugging**: All code in one repository

### Implementation Scope

Estimated **500-1000 lines of code** with comprehensive testing:

#### Core Algorithm Components

1. **Plane-Triangle Intersection**
   ```javascript
   // For each triangle:
   // - Calculate signed distances of vertices to plane
   // - Detect intersection cases (0, 1, or 2 edge intersections)
   // - Compute intersection points using linear interpolation
   // - Handle edge cases: coplanar vertices, degenerate triangles
   ```

2. **Segment Collection**
   ```javascript
   // Collect all intersection segments from triangles
   // - Store as [start_point, end_point] pairs
   // - Use adaptive epsilon for floating-point comparisons
   // - Handle near-parallel edges with scaled tolerance
   ```

3. **Segment Chaining**
   ```javascript
   // Connect segments into closed contour paths
   // - Use spatial hashing for efficient neighbor lookup
   // - Apply leftmost-turn heuristic for boundary following
   // - Detect and separate outer boundaries from holes
   ```

4. **Edge Case Handling**
   ```javascript
   // - Coplanar vertices (vertex exactly on slice plane)
   // - Degenerate triangles (zero-area or collinear vertices)
   // - Near-parallel edges (angle < 1° to plane)
   // - Floating-point precision issues
   // - Multiple disconnected contours per layer
   ```

#### Testing Strategy

1. **Unit Tests**: Each algorithm component independently
2. **Integration Tests**: Full slicing of standard shapes (cube, sphere, torus)
3. **Regression Tests**: Benchy model (225,706 triangles) against Cura output
4. **Edge Case Tests**: Degenerate geometries, coplanar vertices
5. **Performance Tests**: Large models (1M+ triangles)

#### Performance Considerations

- **Spatial Hashing**: O(1) segment neighbor lookup vs O(n²) naive search
- **Early Exit**: Skip triangles far from slice plane using bounding box tests  
- **Vectorization**: Use typed arrays (Float32Array) for performance
- **Incremental Processing**: Process layers incrementally to manage memory

### Benefits

✅ **Full Control**: Optimize specifically for 3D printing workflow  
✅ **Easier Debugging**: All code in polyslice repository  
✅ **No External Dependencies**: Eliminate Polytree dependency  
✅ **Better Reliability**: Handle all edge cases discovered in Benchy testing  
✅ **Performance**: Optimize for target use cases  
✅ **Maintainability**: Single codebase, clear ownership  

### Risks

⚠️ **Development Time**: 2-3 days for implementation and testing  
⚠️ **Edge Cases**: May discover new edge cases during testing  
⚠️ **Numerical Stability**: Floating-point precision requires careful handling  

### Mitigation

- Use proven computational geometry algorithms (from academic literature)
- Extensive testing with known-good reference outputs (Cura)
- Adaptive epsilon scaling based on geometry characteristics
- Comprehensive edge case test suite

---

## Alternative Approach: Continue Fixing Polytree

### Pros
- Leverage existing library
- Community maintenance and bug fixes
- Less initial implementation effort

### Cons
- Two fix attempts already failed (PRs #38, #39)
- Cross-repo debugging is slow and difficult
- Limited control over implementation details
- Dependency on external maintainer responsiveness
- Only using one method from entire library

**Verdict**: Given the failed fix attempts and cross-repo challenges, continuing with Polytree is not recommended.

---

## Conclusion

After comprehensive research and evaluation:

1. ✅ **Research Complete**: Evaluated all viable npm packages
2. ❌ **No Suitable Package Found**: None meet 3D printing slicing requirements
3. ✅ **Custom Implementation Recommended**: Best path forward for reliability and control
4. ✅ **Scope Defined**: Clear implementation plan with ~500-1000 LOC
5. ✅ **Testing Strategy**: Comprehensive approach including Benchy regression tests

### Next Steps

1. Implement custom `sliceIntoLayers` function in polyslice
2. Add comprehensive test suite with Benchy model
3. Validate against Cura reference output
4. Update Polytree to devDependency only
5. Document the implementation and algorithm

---

## References

### NPM Packages Researched
- [@dgreenheck/three-pinata](https://www.npmjs.com/package/@dgreenheck/three-pinata) - Mesh fracturing
- [threejs-slice-geometry](https://github.com/tdhooper/threejs-slice-geometry) - Legacy slicing
- [three-mesh-bvh](https://www.npmjs.com/package/three-mesh-bvh) - Raycasting acceleration
- [three-bvh-csg](https://www.npmjs.com/package/three-bvh-csg) - CSG operations

### Community Resources
- [Stack Overflow: Plane-Mesh Intersection](https://stackoverflow.com/questions/42348495/three-js-find-all-points-where-a-mesh-intersects-a-plane)
- [Three.js Forum: Clipping Plane Vertices](https://discourse.threejs.org/t/build-new-mesh-from-clipping-plane-intersection-vertices/65756)
- [Three.js Forum: Geometry Slicing](https://discourse.threejs.org/t/geometry-slicing/32396)

### Related Issues
- [PR #69: Slicing Investigation](https://github.com/jgphilpott/polyslice/pull/69)
- [Polytree PR #38: Edge-on-Plane Fix](https://github.com/jgphilpott/polytree/pull/38)
- [Polytree PR #39: Adaptive Epsilon](https://github.com/jgphilpott/polytree/pull/39)

---

**Document Version**: 1.0  
**Date**: November 17, 2025  
**Author**: GitHub Copilot Investigation  
**Status**: Complete - Recommendation Ready
