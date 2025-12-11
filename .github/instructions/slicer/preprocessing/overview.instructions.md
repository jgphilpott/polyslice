---
applyTo: 'src/slicer/preprocessing/**/*.coffee'
---

# Preprocessing Module Overview

The preprocessing module prepares meshes for slicing. Located in `src/slicer/preprocessing/`.

## Purpose

- Analyze mesh geometry density
- Subdivide sparse meshes for better slicing quality
- Extract mesh objects from scene hierarchies

**Note**: The main slicing process (in `slice.coffee`) handles mesh cloning to preserve the original object. The preprocessing module receives a mesh that is already a clone, so any transformations here do not affect the original mesh in the user's scene.

## Mesh Preprocessing

### preprocessMesh

Main entry point that analyzes and conditionally subdivides geometry:

```coffeescript
preprocessMesh: (mesh) ->
    geometry = mesh.geometry

    return mesh if not geometry or not geometry.isBufferGeometry

    needsSubdivision = @analyzeGeometryDensity(geometry)

    if needsSubdivision
        subdividedGeometry = @subdivideGeometry(geometry)
        subdividedMesh = new THREE.Mesh(subdividedGeometry, mesh.material)
        # Copy transforms
        subdividedMesh.position.copy(mesh.position)
        subdividedMesh.rotation.copy(mesh.rotation)
        subdividedMesh.scale.copy(mesh.scale)
        subdividedMesh.updateMatrixWorld()
        return subdividedMesh

    return mesh
```

## Geometry Density Analysis

### analyzeGeometryDensity

Determines if a mesh has too few triangles for its volume:

```coffeescript
analyzeGeometryDensity: (geometry) ->
    # Get position attribute
    positionAttribute = geometry.getAttribute('position')

    # Compute bounding box
    geometry.computeBoundingBox()
    bbox = geometry.boundingBox

    # Calculate volume
    size = new THREE.Vector3()
    bbox.getSize(size)
    volume = size.x * size.y * size.z

    # Count triangles
    triangleCount = if geometry.index
        Math.floor(geometry.index.count / 3)
    else
        Math.floor(positionAttribute.count / 3)

    # Calculate density
    density = triangleCount / volume

    # Density threshold: 5 triangles per cubic mm
    DENSITY_THRESHOLD = 5
    return density < DENSITY_THRESHOLD
```

### Density Threshold

The threshold of 5 triangles/mm³ was chosen because:
- Lower density meshes may have large flat faces spanning multiple layers
- Slicing large triangles can result in incomplete layer boundaries
- Subdivision creates more uniform triangle sizes

### Examples

| Mesh | Volume | Triangles | Density | Needs Subdivision |
|------|--------|-----------|---------|-------------------|
| 10mm cube | 1000 mm³ | 12 | 0.012 | Yes |
| 10mm sphere | ~524 mm³ | 1280 | ~2.4 | Yes |
| 10mm sphere (fine) | ~524 mm³ | 5120 | ~9.8 | No |

## Loop Subdivision

### subdivideGeometry

Uses the Loop subdivision algorithm to increase triangle count:

```coffeescript
subdivideGeometry: (geometry) ->
    params = {
        split: true           # Split edges
        uvSmooth: false       # Don't smooth UVs
        preserveEdges: false  # Don't preserve sharp edges
        flatOnly: false       # Allow curved surfaces
        maxTriangles: Infinity
    }

    return LoopSubdivision.modify(geometry, 1, params)
```

### Subdivision Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `split` | `true` | Enable edge splitting |
| `uvSmooth` | `false` | Don't modify UV coordinates |
| `preserveEdges` | `false` | Smooth all edges |
| `flatOnly` | `false` | Allow surface smoothing |
| `maxTriangles` | `Infinity` | No triangle limit |

### Iteration Count

Currently uses 1 iteration of subdivision, which:
- Quadruples triangle count (each triangle → 4 triangles)
- Smooths surface geometry
- Maintains overall shape

## Mesh Extraction

### extractMesh

Extracts a mesh from various scene object types:

```coffeescript
extractMesh: (scene) ->
    return null if not scene

    # Direct mesh
    if scene.isMesh then return scene

    # Scene with children
    if scene.children and scene.children.length > 0
        for child in scene.children
            if child.isMesh then return child

    # Object with mesh property
    if scene.mesh and scene.mesh.isMesh
        return scene.mesh

    return null
```

### Supported Input Types

| Input | Handling |
|-------|----------|
| `THREE.Mesh` | Returned directly |
| `THREE.Scene` | First mesh child extracted |
| `THREE.Group` | First mesh child extracted |
| `{ mesh: THREE.Mesh }` | Mesh property extracted |
| Other | Returns `null` |

## Dependencies

- `three-subdivide` - Loop subdivision implementation

```coffeescript
LoopSubdivision = require('three-subdivide').LoopSubdivision
```

## Usage in Slicing Pipeline

Preprocessing is automatically applied during slicing:

```coffeescript
# In slice.coffee
mesh = preprocessing.extractMesh(scene)
mesh = preprocessing.preprocessMesh(mesh)
# Continue with slicing...
```

## Important Conventions

1. **Non-destructive**: Original mesh is preserved; new mesh created if subdivided
2. **Transform preservation**: Position, rotation, scale copied to new mesh
3. **Matrix update**: `updateMatrixWorld()` called after transform copy
4. **BufferGeometry only**: Only processes BufferGeometry (not legacy Geometry)
5. **First mesh only**: `extractMesh` returns first mesh found, not all meshes
