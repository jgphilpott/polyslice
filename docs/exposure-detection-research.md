# Exposure Detection Algorithm Research & Recommendations

## Executive Summary

This document provides comprehensive research findings on exposure detection algorithms used in modern 3D printing slicers (Cura and PrusaSlicer), along with specific recommendations for revamping the exposure detection algorithm in Polyslice.

**Goal:** Enable detection of horizontal exposure in middle layers to generate appropriate skin for parts of the print other than the absolute top and bottom layers.

## Current State in Polyslice

### Existing Implementation (Lines 616-709 in `src/slicer/slice.coffee`)

The current algorithm is **disabled** due to false positives with curved surfaces like torus and sphere geometries. Key features of the disabled code:

- Coverage threshold of 0.1 (10%)
- Checks layers within `skinLayerCount` range above and below
- Uses helper functions: `calculateRegionCoverage()` and `calculateExposedAreas()`
- Separates top exposure (from above) and bottom exposure (from below)
- Applies skin to exposed regions within range

### Existing Helper Functions (Already Implemented)

1. **`calculateRegionCoverage(testRegion, coveringRegions, sampleCount)`**
   - Location: `src/slicer/geometry/helpers.coffee` (line 810)
   - Generates grid of sample points across test region
   - Returns coverage ratio (0.0 to 1.0)
   - Well-tested with multiple test cases

2. **`calculateExposedAreas(testRegion, coveringRegions, sampleCount)`**
   - Location: `src/slicer/geometry/helpers.coffee` (line 867)
   - Uses dense sampling (81 points by default)
   - Groups exposed points into regions
   - Returns array of exposed polygons
   - Handles cases where no coverage exists

### Problems with Current Algorithm

1. **False positives on curved surfaces**: Torus and sphere geometries trigger exposure detection when they shouldn't
2. **Fixed threshold**: 0.1 (10%) coverage threshold may not be appropriate for all geometries
3. **No adaptation to geometry complexity**: Same algorithm applied to all shapes
4. **Sampling limitations**: Grid-based sampling may miss complex coverage patterns

## Research: Modern Slicer Algorithms

### Cura (CuraEngine)

**Implementation Details:**
- **Source location**: `src/skin.cpp` and `src/FffPolygonGenerator.cpp`
- **Data structures**: `SkinPart`, `SliceLayerPart`, `SliceLayer`
- **Algorithm approach**: Polygon-based comparison (not sample-based)

**Key Techniques:**

1. **Polygon Intersection Method**
   - Direct polygon-to-polygon comparison between layers
   - Uses computational geometry (polygon overlap/subtraction)
   - More accurate than sampling for complex shapes
   - Computationally efficient with proper data structures

2. **Exposure Detection Logic**
   - For **top skin**: Check if current layer regions have no material in layers above
   - For **bottom skin**: Check if current layer regions have no material in layers below
   - Absence of overlapping polygons = exposure

3. **Expansion/Shrinkage**
   - Apply small offset based on nozzle diameter
   - Prevents tiny "islands" that are hard to print
   - Ensures proper adhesion between layers

4. **Limitation**
   - Only applies "top skin" settings to absolute top surface
   - Intermediate exposed surfaces use standard top/bottom layer settings
   - No native support for treating all horizontal exposures as skin

**Advantages:**
- Precise geometric calculation
- No sampling artifacts
- Handles complex polygons well
- Fast with optimized polygon operations

**Disadvantages:**
- More complex implementation
- Requires robust polygon clipping library
- Edge cases with self-intersecting polygons

### PrusaSlicer/Slic3r

**Implementation Details:**
- **Source location**: `BridgeDetector` class
- **Algorithm approach**: Geometric analysis with medial axis transformation
- **Focus**: Bridge detection (horizontal spans over gaps)

**Key Techniques:**

1. **Bridge vs. Overhang Distinction**
   - **Bridge**: Supported at both ends (spanning gap)
   - **Overhang**: Supported at one end only
   - Different print parameters for each

2. **Horizontal Exposure Handling**
   - Analyzes gap width beneath layer
   - Adjusts flow ratio and speed based on exposure
   - Special "bridge flow ratio" setting (typically reduced)
   - Lower flow helps "pull" filament taut across gaps

3. **Medial Axis Transformation**
   - Used for thin walls and bridge detection
   - Identifies centerlines of regions
   - Helps optimize path direction for bridges

4. **Adaptive Parameters**
   - Reduced material flow for bridges
   - Slower print speeds for stability
   - Can detect and apply settings per-region

**Advantages:**
- Excellent for bridging scenarios
- Adaptive parameter adjustment
- Good handling of varying gap widths

**Disadvantages:**
- Complex implementation
- Primarily focused on bridges, not general skin
- May not detect all exposure types

## Recommended Improvements for Polyslice

### Phase 1: Algorithm Refinements (Immediate)

#### 1.1 Adaptive Coverage Threshold

**Problem**: Fixed 0.1 threshold causes false positives on curved surfaces.

**Solution**: Make threshold adaptive based on layer geometry characteristics.

```coffeescript
# Calculate geometric complexity metric
calculateGeometryComplexity: (path) ->
    # Measure curvature, number of vertices, area changes
    # Return complexity score (0.0 to 1.0)
    
# Adjust threshold based on complexity
baseThreshold = 0.1
geometryComplexity = calculateGeometryComplexity(currentPath)
adaptiveThreshold = baseThreshold + (geometryComplexity * 0.2) # Range: 0.1 to 0.3
```

**Benefits**:
- Reduces false positives on curved surfaces
- More lenient on complex geometries (torus, sphere)
- Maintains sensitivity for simple geometries

#### 1.2 Multi-Layer Coverage Analysis

**Problem**: Current algorithm checks only immediate adjacent layer.

**Solution**: Analyze coverage trends across multiple layers to distinguish genuine exposure from gradual transitions.

```coffeescript
# Check coverage trend over multiple layers
coverageHistory = []
for checkIdx in [layerIndex-2..layerIndex+2]
    coverage = calculateRegionCoverage(...)
    coverageHistory.push(coverage)

# Genuine exposure shows sustained low coverage
# Curved surfaces show gradual coverage changes
isGenuineExposure = detectSustainedLowCoverage(coverageHistory)
```

**Benefits**:
- Distinguishes intentional horizontal surfaces from curved transitions
- More robust against geometry artifacts
- Reduces false positives significantly

#### 1.3 Area-Based Filtering

**Problem**: Small exposed areas may not need skin (noise/artifacts).

**Solution**: Add minimum area threshold for exposed regions.

```coffeescript
# Calculate area of exposed regions
for exposedArea in exposedAreas
    area = calculatePolygonArea(exposedArea)
    minimumArea = nozzleDiameter * nozzleDiameter * 4 # e.g., 4 nozzle widths squared
    if area >= minimumArea
        validExposedAreas.push(exposedArea)
```

**Benefits**:
- Filters out sampling artifacts
- Ignores tiny regions that don't need skin
- Reduces G-code bloat

### Phase 2: Enhanced Detection (Medium-term)

#### 2.1 Polygon-Based Detection (Optional Upgrade)

**Approach**: Migrate from sampling-based to polygon intersection for higher precision.

**Implementation Strategy**:
1. Research JavaScript polygon clipping libraries (e.g., `clipper-lib`, `martinez-polygon-clipping`)
2. Implement polygon difference operation: `currentLayer - aboveLayer`
3. Result polygons represent exposed areas
4. More accurate than grid sampling

**Benefits**:
- Exact geometric calculation
- No sampling artifacts
- Better handling of complex shapes

**Challenges**:
- Requires new dependency
- More complex implementation
- Need to handle polygon operation edge cases

#### 2.2 Bridge Detection Integration

**Approach**: Add special handling for bridging regions (similar to PrusaSlicer).

**Implementation**:
```coffeescript
detectBridges: (currentPath, belowPaths) ->
    # Find regions with support at both ends
    # Calculate gap width
    # Return bridge regions with gap widths
    
# Apply adaptive flow and speed based on bridge width
if isBridge
    flowMultiplier = calculateBridgeFlowMultiplier(gapWidth)
    speedMultiplier = calculateBridgeSpeedMultiplier(gapWidth)
```

**Benefits**:
- Better print quality for horizontal spans
- Prevents sagging on bridges
- More professional results

### Phase 3: Configuration & Control (Future)

#### 3.1 User-Configurable Parameters

Add slicer options for exposure detection:

```coffeescript
# New slicer parameters
@exposureDetectionEnabled = options.exposureDetectionEnabled ?= true
@exposureCoverageThreshold = options.exposureCoverageThreshold ?= 0.1
@exposureMinimumArea = options.exposureMinimumArea ?= null # Auto-calculate
@exposureAdaptiveThreshold = options.exposureAdaptiveThreshold ?= true
@exposureBridgeDetection = options.exposureBridgeDetection ?= false
```

#### 3.2 Per-Layer Diagnostics

Add verbose logging for debugging:

```coffeescript
if verbose and exposureDetectionEnabled
    slicer.gcode += "; Layer #{layerIndex} exposure: #{exposedAreas.length} regions"
    slicer.gcode += "; Coverage: #{(coverage * 100).toFixed(1)}%"
    slicer.gcode += "; Threshold: #{(threshold * 100).toFixed(1)}%"
```

## Implementation Roadmap

### Immediate Actions (Week 1-2)

1. **Re-enable with improvements**
   - Implement adaptive threshold (1.1)
   - Add area-based filtering (1.3)
   - Test with torus and sphere models

2. **Enhanced testing**
   - Create comprehensive test suite
   - Test with problematic geometries (torus, sphere, cylinder)
   - Validate skin generation quality

3. **Documentation**
   - Document algorithm parameters
   - Add usage examples
   - Create troubleshooting guide

### Near-term Enhancements (Month 1-2)

1. **Multi-layer analysis** (1.2)
   - Implement coverage trend detection
   - Add configuration parameters
   - Validate against false positives

2. **Performance optimization**
   - Profile algorithm performance
   - Optimize sample counts
   - Cache calculations where possible

### Long-term Goals (Month 3+)

1. **Polygon-based detection** (2.1)
   - Research and select polygon library
   - Implement polygon intersection
   - Comprehensive testing

2. **Bridge detection** (2.2)
   - Implement bridge detection algorithm
   - Add adaptive flow/speed
   - Test with bridging models

## Testing Strategy

### Test Geometries

1. **Simple shapes** (baseline):
   - Cube with horizontal hole
   - Stepped pyramid
   - Multi-level platform

2. **Curved surfaces** (challenge cases):
   - Sphere (gradual curvature)
   - Torus (complex topology)
   - Cylinder (vertical transitions)

3. **Complex features**:
   - Overhangs
   - Bridges
   - Mixed geometry

### Success Criteria

1. **No false positives**: Curved surfaces don't trigger exposure
2. **Detect genuine exposure**: Horizontal features get proper skin
3. **Consistent results**: Same geometry produces same detection
4. **Performance**: Detection adds < 10% to slicing time

## Configuration Examples

### Conservative (Default)

```javascript
const slicer = new Polyslice({
    exposureDetectionEnabled: true,
    exposureCoverageThreshold: 0.15,  // More lenient
    exposureAdaptiveThreshold: true,   // Adapt to geometry
    exposureMinimumArea: null          // Auto-calculate
});
```

### Aggressive (High Quality)

```javascript
const slicer = new Polyslice({
    exposureDetectionEnabled: true,
    exposureCoverageThreshold: 0.05,   // More sensitive
    exposureAdaptiveThreshold: false,  // Fixed threshold
    exposureBridgeDetection: true      // Enable bridge handling
});
```

### Disabled (Performance)

```javascript
const slicer = new Polyslice({
    exposureDetectionEnabled: false    // Skip exposure detection
});
```

## Conclusion

The exposure detection algorithm in Polyslice can be significantly improved by:

1. **Immediate fixes**: Adaptive thresholds and area filtering
2. **Medium-term**: Multi-layer analysis and bridge detection
3. **Long-term**: Polygon-based detection for ultimate precision

The existing helper functions (`calculateRegionCoverage`, `calculateExposedAreas`) provide a solid foundation. The key improvements focus on reducing false positives while maintaining sensitivity to genuine horizontal exposures.

**Recommended next step**: Implement Phase 1 improvements (adaptive threshold + area filtering) and test with problematic geometries before proceeding to more complex enhancements.

## References

1. **CuraEngine**: 
   - Source: https://github.com/Ultimaker/CuraEngine
   - Key files: `src/skin.cpp`, `src/FffPolygonGenerator.cpp`

2. **PrusaSlicer**:
   - Source: https://github.com/prusa3d/PrusaSlicer
   - Key class: `BridgeDetector`

3. **Polyslice Existing Code**:
   - `src/slicer/slice.coffee` (lines 616-709)
   - `src/slicer/geometry/helpers.coffee` (lines 810-920)
   - `src/slicer/geometry/helpers.test.coffee` (lines 421-567)

---

*Document created: 2025-11-02*  
*Author: GitHub Copilot Research Agent*  
*Purpose: Guidance for revamping exposure detection algorithm in Polyslice*
