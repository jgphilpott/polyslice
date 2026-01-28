# Mesh Complexity

Polyslice uses a path connection algorithm with O(n³) complexity, which means slicing time grows cubically with mesh detail and can increase very rapidly for highly detailed meshes. Very detailed meshes may take several minutes to slice or appear to hang.

## Performance Guidelines

| Complexity Score* | Expected Time | Recommendation |
|------------------|---------------|----------------|
| < 1M | Fast (< 10s) | ✅ Optimal |
| 1M - 5M | Moderate (10s - 2min) | ⚠️ Consider simplification |
| > 5M | Slow (> 2min) | 🚫 Reduce mesh detail |

**Complexity Score = Triangles × Estimated Layers*

## How to Reduce Mesh Complexity

If you encounter performance issues:

1. **Reduce mesh detail** in your 3D modeling software
2. **Increase layer height** (e.g., from 0.1mm to 0.2mm)
3. **Simplify geometry** using tools like [MeshLab](https://www.meshlab.net/) or Blender's Decimate modifier
4. **Scale down** large models if possible

## Example Warning Output

```
    WARNING: Very high mesh complexity detected!
    Triangles: 32512, Estimated layers: 500
    Complexity score: 16256k
    Slicing may take several minutes or appear to hang.
    Consider reducing mesh detail or increasing layer height.
    See: https://github.com/jgphilpott/polyslice/blob/main/docs/slicer/MESH_COMPLEXITY.md
```

## Understanding Complexity

### What Causes High Complexity?

Complexity is determined by:
- **Triangle count**: The number of triangular faces in your mesh
- **Layer count**: The height of your model divided by layer height
- **Geometric features**: Small holes, intricate details, and complex topology increase processing time per layer

### Complexity Calculation

The slicer automatically calculates complexity before slicing:

```javascript
complexity_score = triangle_count × estimated_layers
```

For example:
- A 10mm cube with 12 triangles at 0.2mm layer height: `12 × 50 = 600` (very fast)
- A detailed 50mm sphere with 32,512 triangles at 0.2mm layer height: `32,512 × 250 = 8,128,000` (very slow)

## Flat Complex Objects

Extremely flat objects (e.g., 226mm × 125mm × 2mm) with intricate internal features create a special case:
- Few layers but each layer has thousands of segments to process
- May take longer to slice than the complexity score suggests
- Consider rotating the model 90° if the orientation allows for better slicing performance

## When Slicing Takes Too Long

If your slice operation appears to hang:

1. **Check the warning message** - It will tell you the expected time
2. **Disable exposure detection** - Set `exposureDetection: false` for faster slicing
3. **Simplify your mesh** - Use the reduction techniques above
4. **Rotate the model** - Try different orientations to find the fastest one

## Related Documentation

- [Slicing Overview](SLICING.md)
- [Path Utilities](utils/PATHS.md)
- [Performance Optimization](../development/DEVELOPMENT.md)
