# Exposure Detection

Polyslice includes an adaptive skin layer generation algorithm that can intelligently detect exposed surfaces on your model and apply skin layers only where needed. This feature is enabled by default for optimized prints.

## What It Does

- Analyzes each layer to detect exposed surfaces (top and bottom surfaces within the skin layer range)
- Automatically generates skin layers only on exposed regions instead of solid layers
- Reduces print time and material usage while maintaining surface quality
- Uses coverage sampling to determine which areas need skin reinforcement

## When to Use It

**Use exposure detection for:**
- Complex geometries with varying surface exposure throughout the print
- Models with overhangs, bridges, or varying cross-sections
- When you want to optimize material usage without compromising surface quality

**Disable exposure detection for:**
- Simple geometries (cubes, cylinders) where standard top/bottom skin layers are sufficient
- When print time is not a concern and you prefer consistent solid top/bottom layers
- Very fast slicing where the small optimization isn't worth the processing time

## Configuration

### Basic Usage

```javascript
const slicer = new Polyslice({
  nozzleTemperature: 210,
  bedTemperature: 60,
  exposureDetection: true,  // Enabled by default
  exposureDetectionResolution: 961  // 31×31 grid (default)
});

// Disable if needed
slicer.setExposureDetection(false);
```

### Resolution Settings

The `exposureDetectionResolution` parameter controls the sampling grid density used to detect exposed areas. Higher values provide more accurate detection but take longer to process.

```javascript
// Adjust resolution at runtime for finer detail
slicer.setExposureDetectionResolution(2500);  // 50×50 grid for very fine details

// Use lower resolution for faster processing
slicer.setExposureDetectionResolution(625);  // 25×25 grid

// Check current resolution
console.log(slicer.getExposureDetectionResolution());  // 961
```

**Recommended Resolutions:**

| Resolution | Grid Size | Use Case | Performance Impact |
|------------|-----------|----------|-------------------|
| 400 | 20×20 | Fast processing, simple geometries | Baseline |
| 625 | 25×25 | Good balance for most prints | 1.5× slower |
| 961 | 31×31 | **Default** - Excellent accuracy | 2.4× slower |
| 1600 | 40×40 | High detail, fine features | 4× slower |
| 2500 | 50×50 | Maximum detail, sub-mm features | 6.25× slower |

## Technical Details

### Algorithm Overview

The exposure detection algorithm uses the following approach:

1. **Sampling**: Creates a grid of N sample points (default 961 = 31×31) across each layer
2. **Coverage Analysis**: Checks which sample points are NOT covered by the layer exactly `skinLayerCount` steps ahead/behind
3. **Contour Tracing**: Uses marching squares algorithm to trace smooth contours around exposed regions
4. **Smoothing**: Applies Chaikin curve smoothing (1 iteration, 0.5 ratio) for natural-looking contours
5. **Independent Processing**: Each layer independently calculates its exposure without influence from other layers

### Marching Squares Algorithm

The marching squares algorithm identifies edge cells (cells in exposed regions with at least one non-exposed neighbor) and traces them to create smooth boundary polygons:

- Creates polygons that follow the actual shape of exposed regions
- Much more accurate than simple rectangular bounding boxes
- Expands boundaries slightly (0.6× cell size) to ensure proper coverage

### Adaptive Skin Generation

The algorithm generates skin patches that:
- **Grow/shrink naturally** as geometry changes (e.g., arch widening)
- **Detect transitions** automatically (e.g., when a U-shape splits into two pillars)
- **Filter small areas** that are too small to reinforce effectively
- **Preserve surface quality** while minimizing material usage

## Performance Considerations

Performance scales as O(n²) with sample count. The default 961 samples (31×31 grid) provides:
- Excellent accuracy for detecting features down to ~1mm
- Smooth, natural contours
- Reasonable processing time for typical FDM printing
- ~2.4× slower than 20×20 grid, but significantly better quality

For production workflows, consider:
- Using lower resolution (625 or 400) for simple geometries
- Using higher resolution (1600 or 2500) for intricate details
- Caching sliced models when printing duplicates
- Disabling entirely for basic shapes (cubes, cylinders)

## Examples

### Complex Geometry (Recommended)

```javascript
const slicer = new Polyslice({
  exposureDetection: true,
  exposureDetectionResolution: 961  // Default
});

// Slice an arch or bridge structure
const gcode = slicer.slice(complexMesh);
```

### High-Detail Model

```javascript
const slicer = new Polyslice({
  exposureDetection: true,
  exposureDetectionResolution: 1600  // 40×40 for fine details
});

const gcode = slicer.slice(detailedMesh);
```

### Simple Geometry (Fast Processing)

```javascript
const slicer = new Polyslice({
  exposureDetection: false  // Not needed for simple shapes
});

const gcode = slicer.slice(cube);
```

## Testing

The exposure detection algorithm includes comprehensive test coverage in `src/slicer/skin/exposure/exposure.test.coffee`:

- Parameter configuration tests
- Geometry-specific tests (U-arch, stepped, cylinder, cone)
- Resolution impact comparison
- Performance validation
- Edge case handling
- Enabled vs disabled behavior verification

All tests ensure the algorithm behaves correctly across various geometries and configurations.
