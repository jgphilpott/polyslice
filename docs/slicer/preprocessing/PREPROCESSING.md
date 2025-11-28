# Mesh Preprocessing

The preprocessing module handles mesh analysis and subdivision to improve slicing quality for sparse meshes.

## Overview

Some 3D models have regions with low triangle density that can cause gaps or missing segments during slicing. The preprocessing module analyzes mesh geometry and applies Loop subdivision to improve triangle density where needed.

## Usage

Preprocessing is automatically applied during the slicing process. You can also use it directly:

```javascript
const { Polyslice } = require("@jgphilpott/polyslice");
const preprocessing = require("@jgphilpott/polyslice/src/slicer/preprocessing/preprocessing");

// Analyze and optionally subdivide a mesh
const processedMesh = preprocessing.preprocessMesh(mesh);

// Or check if subdivision is needed first
const needsSubdivision = preprocessing.analyzeGeometryDensity(mesh.geometry);
```

## Functions

### `preprocessMesh(mesh)`

Main entry point for mesh preprocessing. Analyzes geometry density and applies subdivision if needed.

**Parameters:**
- `mesh` (THREE.Mesh): The mesh to preprocess

**Returns:** THREE.Mesh - The preprocessed mesh (original or subdivided)

**Behavior:**
1. Checks if the mesh has valid BufferGeometry
2. Analyzes triangle density distribution
3. If density is below threshold, applies Loop subdivision
4. Creates new mesh with subdivided geometry while preserving transforms

```javascript
const processedMesh = preprocessing.preprocessMesh(mesh);
// processedMesh will have higher triangle density if original was sparse
```

### `analyzeGeometryDensity(geometry)`

Analyzes geometry to determine if it needs subdivision based on triangle density.

**Parameters:**
- `geometry` (THREE.BufferGeometry): The geometry to analyze

**Returns:** Boolean - True if subdivision is recommended

**Algorithm:**
1. Calculates bounding box volume
2. Counts triangles in the geometry
3. Computes triangle density (triangles per cubic unit)
4. Returns true if density < 5 triangles/mm³

```javascript
const needsSubdivision = preprocessing.analyzeGeometryDensity(mesh.geometry);
if (needsSubdivision) {
    console.log("Mesh has sparse regions that may benefit from subdivision");
}
```

### `subdivideGeometry(geometry)`

Applies Loop subdivision algorithm to increase triangle density.

**Parameters:**
- `geometry` (THREE.BufferGeometry): The geometry to subdivide

**Returns:** THREE.BufferGeometry - Subdivided geometry

**Details:**
- Uses the [three-subdivide](https://www.npmjs.com/package/three-subdivide) library
- Applies 1 iteration of Loop subdivision (4x triangle count)
- Preserves overall shape while adding detail
- Parameters optimized for 3D printing:
  - `split: true` - Uniform subdivision across coplanar faces
  - `uvSmooth: false` - Prevents UV coordinate tearing
  - `preserveEdges: false` - Allows smooth subdivision
  - `flatOnly: false` - Subdivides all faces

### `extractMesh(scene)`

Utility function to extract a mesh from a scene object.

**Parameters:**
- `scene` (Object): Scene or mesh object

**Returns:** THREE.Mesh | null - The extracted mesh or null

**Behavior:**
- If `scene` is already a mesh, returns it directly
- If `scene` has children, returns the first mesh found
- If `scene` has a `mesh` property, returns that
- Otherwise returns null

## When Is Preprocessing Applied?

The preprocessing module uses a conservative threshold of 5 triangles per cubic millimeter. This threshold was chosen to:

- Only apply to very sparse meshes (like the 3DBenchy)
- Avoid unnecessary subdivision of well-designed models
- Most test geometries have 100-1000+ triangles/mm³

### Example Meshes

| Mesh | Triangle Density | Subdivision Applied |
|------|------------------|---------------------|
| 3DBenchy | ~5 triangles/mm³ | Yes |
| Simple test cube | ~1000 triangles/mm³ | No |
| Properly designed STL | ~100+ triangles/mm³ | No |

## Loop Subdivision Details

Loop subdivision is a smooth subdivision scheme that:

1. **Splits each triangle into 4 smaller triangles** - Increases resolution
2. **Repositions vertices** - Smooths the mesh surface
3. **Maintains overall shape** - Preserves the model's appearance

One iteration provides a good balance:
- 4x triangle count (e.g., 225k → 900k for 3DBenchy)
- Significant improvement in sparse regions
- Reasonable computation time

## Integration with Slicing

The preprocessing step is called automatically before slicing begins:

```javascript
// Inside the slice() method:
// 1. Extract mesh from scene
mesh = preprocessing.extractMesh(mesh);

// 2. Preprocess if needed
mesh = preprocessing.preprocessMesh(mesh);

// 3. Apply world transformation
mesh.updateMatrixWorld(true);

// 4. Proceed with slicing...
```

## File Structure

```
src/slicer/preprocessing/
├── preprocessing.coffee      # Main preprocessing module
└── preprocessing.test.coffee # Unit tests
```

## Dependencies

- **three** - Three.js for mesh manipulation
- **three-subdivide** - Loop subdivision algorithm

## Notes

- Preprocessing only runs when triangle density is below threshold
- Original mesh is not modified; a new mesh is created if subdivision is applied
- Transform properties (position, rotation, scale) are preserved
- The algorithm is designed to be conservative to avoid unnecessary overhead
