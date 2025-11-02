# Exposure Detection Algorithm - Quick Reference

## TL;DR

**Current Status**: Disabled due to false positives on curved surfaces (torus, sphere)  
**Root Cause**: Fixed 0.1 coverage threshold + grid sampling limitations  
**Recommended Fix**: Adaptive thresholds + multi-layer analysis + area filtering  
**Implementation Time**: Phase 1 improvements can be done in 1-2 weeks

## Problem Statement

The exposure detection algorithm (lines 616-709 in `src/slicer/slice.coffee`) needs to:
- Detect horizontal exposure in middle layers (not just top/bottom)
- Generate appropriate skin for exposed regions
- Avoid false positives on curved surfaces
- Handle complex geometries like torus, sphere, cylinder

## How Modern Slicers Solve This

### Cura Approach: Polygon Comparison
```
Current Layer Polygon - Above Layer Polygon = Exposed Areas
```
- Direct geometric calculation (no sampling)
- Exact results for complex shapes
- Requires polygon clipping library

### PrusaSlicer Approach: Bridge Detection
```
if (supportedAtBothEnds && hasGapBelow) {
    bridge = true;
    adjustFlow(gapWidth);
    adjustSpeed(gapWidth);
}
```
- Focuses on bridging scenarios
- Adaptive parameters based on gap width
- Uses medial axis transformation

## Polyslice Solution (3-Phase Plan)

### Phase 1: Quick Wins (1-2 weeks) ✅ RECOMMENDED START

**1. Adaptive Threshold**
```coffeescript
# Instead of fixed 0.1
threshold = 0.1 + (geometryComplexity * 0.2)  # Range: 0.1 to 0.3
```

**2. Area Filtering**
```coffeescript
minimumArea = nozzleDiameter² × 4
if exposedArea < minimumArea then skip
```

**3. Multi-Layer Analysis**
```coffeescript
# Check coverage trend over 5 layers
# Curves show gradual change, exposures show sustained low coverage
coverageTrend = [layer-2, layer-1, layer, layer+1, layer+2]
```

### Phase 2: Better Detection (1-2 months)

**4. Polygon-Based Detection (optional)**
- Replace sampling with exact geometric calculation
- Use polygon clipping library (clipper-lib, martinez)
- More accurate, no sampling artifacts

**5. Bridge Detection**
- Detect regions with gaps below
- Adjust flow and speed for bridging
- Better print quality for horizontal spans

### Phase 3: Advanced Features (3+ months)

**6. Configuration Options**
```javascript
new Polyslice({
    exposureDetectionEnabled: true,
    exposureCoverageThreshold: 0.15,
    exposureAdaptiveThreshold: true,
    exposureBridgeDetection: false
})
```

**7. Diagnostics & Logging**
```gcode
; Layer 15 exposure: 2 regions
; Coverage: 8.5%
; Threshold: 12.3%
```

## Existing Code Assets ✅

**Already Implemented & Working:**

1. `calculateRegionCoverage(testRegion, coveringRegions, sampleCount)`
   - Grid-based sampling
   - Returns 0.0 to 1.0 coverage ratio
   - Well-tested

2. `calculateExposedAreas(testRegion, coveringRegions, sampleCount)`
   - Dense sampling (81 points)
   - Returns array of exposed polygons
   - Handles edge cases

3. Test suite for both functions
   - Multiple test scenarios
   - Edge case coverage
   - Performance validated

## Implementation Checklist

### Immediate (Week 1)
- [ ] Implement `calculateGeometryComplexity()` helper
- [ ] Add adaptive threshold calculation
- [ ] Implement area-based filtering
- [ ] Re-enable exposure detection with new improvements

### Testing (Week 2)
- [ ] Test with torus geometry (primary failure case)
- [ ] Test with sphere geometry (secondary failure case)
- [ ] Test with cylinder (vertical transitions)
- [ ] Validate no false positives
- [ ] Ensure genuine exposures detected

### Documentation (Week 2)
- [ ] Update API documentation
- [ ] Add usage examples
- [ ] Document configuration parameters
- [ ] Create troubleshooting guide

## Test Geometries

| Geometry | Challenge | Expected Result |
|----------|-----------|----------------|
| Torus | Curved surface transitions | No false positives |
| Sphere | Gradual curvature | No false positives |
| Cube with hole | Horizontal exposure | Detect and add skin |
| Stepped pyramid | Multiple levels | Detect each level |
| Bridge model | Gap spanning | Detect and optimize |

## Success Metrics

✅ **No false positives** on curved surfaces  
✅ **Detect genuine exposures** on horizontal features  
✅ **Consistent results** across multiple runs  
✅ **Performance impact** < 10% slicing time increase  
✅ **User control** via configuration options

## Quick Start Code

### Conservative Settings (Recommended Default)
```javascript
const slicer = new Polyslice({
    exposureDetectionEnabled: true,
    exposureCoverageThreshold: 0.15,      // Lenient
    exposureAdaptiveThreshold: true,      // Adapt to geometry
});
```

### Aggressive Settings (High Quality)
```javascript
const slicer = new Polyslice({
    exposureDetectionEnabled: true,
    exposureCoverageThreshold: 0.05,      // Sensitive
    exposureAdaptiveThreshold: false,     // Fixed
    exposureBridgeDetection: true         // Enable bridges
});
```

### Disabled (Performance Priority)
```javascript
const slicer = new Polyslice({
    exposureDetectionEnabled: false
});
```

## References

- **Full Research Document**: `docs/exposure-detection-research.md`
- **Current Code**: `src/slicer/slice.coffee` (lines 616-709)
- **Helper Functions**: `src/slicer/geometry/helpers.coffee` (lines 810-920)
- **Tests**: `src/slicer/geometry/helpers.test.coffee` (lines 421-567)

## Questions?

See the full research document for:
- Detailed algorithm explanations
- Code examples with CoffeeScript syntax
- Performance optimization strategies
- Advanced configuration scenarios
- Complete implementation roadmap

---

*Last Updated: 2025-11-02*  
*Status: Research Complete - Ready for Implementation*
