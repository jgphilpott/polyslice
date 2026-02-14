# Release v26.2.0 - February 2026

**Release Date:** February 14, 2026  
**Previous Release:** v26.1.2 (January 28, 2026)

## 🎉 Highlights

This release brings **major infill pattern improvements** to Polyslice! We've added four new infill patterns, fixed critical issues with existing patterns, and introduced a new pattern centering system for better control over infill placement.

### Key Improvements
- **4 New Infill Patterns:** Concentric, Gyroid, Spiral, and Lightning
- **Gyroid Pattern Completely Revised:** Single rotating direction for better performance and layer adhesion
- **Concentric Pattern Fixed:** Proper wall gaps and hole detection
- **Pattern Centering Control:** Choose between object-centered or globally-centered patterns

## ✨ New Features

### New Infill Patterns

Polyslice now supports **7 total infill patterns** (previously 3):

#### 1. **Concentric Pattern** 🎯
Inward-spiraling contours that follow the natural boundary shape.

**Best for:**
- Curved shapes and organic forms
- Cylindrical cross-sections
- Parts where following the boundary is beneficial

**Characteristics:**
- Continuous paths minimize travel moves
- Natural fit for circular geometries
- Each layer independently follows the boundary shape

#### 2. **Gyroid Pattern** 🌊
Triply periodic minimal surface (TPMS) with wavy interlocking structure.

**Best for:**
- Parts requiring maximum strength-to-weight ratio
- Isotropic strength requirements
- Aesthetic wavy patterns

**Characteristics:**
- Single rotating direction per layer (0° to 90° over 8 layers)
- 3D interlocking structure across layers
- Excellent strength comparable to hexagons
- Smooth gradual transitions between layers

#### 3. **Spiral Pattern** 🌀
Archimedean spiral from center outward in one continuous path.

**Best for:**
- Circular or cylindrical parts
- Smooth continuous motion printing
- Parts where radial structure is beneficial

**Characteristics:**
- Single continuous spiral from center
- No direction changes within a layer
- Natural fit for cylindrical geometries
- Efficient for circular cross-sections

#### 4. **Lightning Pattern** ⚡
Tree-like branching structure for fast printing with minimal material.

**Best for:**
- Draft prints and prototypes
- Parts where speed is prioritized
- Internal support structure
- Low-density infill requirements

**Characteristics:**
- Tree-like branching from boundary inward
- 45° fork angles for natural appearance
- Minimal material usage
- Fast printing speed
- Adequate support for top surfaces

### Infill Pattern Centering

New configuration option `infillPatternCentering` gives you control over pattern alignment:

```javascript
// Object-centered (default) - centers on each object's boundaries
slicer.setInfillPatternCentering('object');

// Global-centered - centers on build plate center (0,0)
slicer.setInfillPatternCentering('global');
```

**Affected patterns:** Grid, Triangles, Hexagons, Gyroid, Spiral, Lightning  
**Not affected:** Concentric (inherently follows boundary)

**Use cases:**
- **Object mode:** Best for most prints, centers patterns naturally on each object
- **Global mode:** Consistent pattern alignment across multiple prints, easier visual comparison

## 🔧 Major Changes

### Gyroid Pattern Algorithm Revision

The gyroid pattern has been completely rewritten for better performance and quality:

**Before:**
- Generated two sets of wavy lines per layer (X and Y directions)
- ~170 lines per layer
- Abrupt direction changes between layers

**After:**
- Single set of wavy lines per layer
- Gradual rotation from 0° to 90° over 8-layer cycle
- Consistent ~85-100 lines per layer
- Smooth transitions for better layer adhesion
- Better performance and material usage

**Example layer sequence:**
- Layer 0: 0° (horizontal wavy lines) - ~92 lines
- Layer 4: 45° (diagonal) - ~98 lines
- Layer 7: ~79° (near vertical) - ~88 lines
- Layer 8: Cycle repeats

This change results in:
- ✅ Better layer-to-layer adhesion
- ✅ More consistent material usage
- ✅ Improved performance (fewer lines to generate)
- ✅ Smoother interlocking 3D structure

## 🐛 Bug Fixes

### Concentric Infill Issues Fixed

**Problem:** Concentric infill had multiple issues:
1. First loop too close to walls (no gap)
2. Infill generated inside holes (torus example showed 33% points in holes)

**Solution:**
- Added proper `lineSpacing` gap before first infill loop
- Implemented hole detection using majority voting on 8 sample points per loop
- Loop skipped only if more than half the sample points are inside holes

**Impact:** Torus example now shows 0% erroneous points (down from 33%)

### Cylinder Bottom Layer Fixed

**Problem:** Cylinders had incomplete walls on the bottom layer

**Solution:** Increased `SLICE_EPSILON` from 0.001mm to `layerHeight/2` to avoid geometric boundary issues

**Impact:** All cylinder slicing now produces complete walls on every layer

### Spiral Pattern LastEndPoint Tracking

**Problem:** Spiral pattern updated `lastEndPoint` unconditionally, causing incorrect combing calculations

**Solution:** Only update `lastEndPoint` when actual movement is generated (distance > 0.001mm)

**Impact:** More accurate travel path optimization in spiral infill

### Skin Generation for Nested Structures

**Problem:** Travel moves between skin areas in nested structures were incorrect

**Solution:** Proper handling of travel moves when generating skin for complex nested geometries

**Impact:** Cleaner G-code with better travel optimization

### CI Pipeline Dependency Conflicts

**Problem:** CI pipeline failed due to eslint-plugin-jest conflicts with eslint 10.x

**Solution:** Removed unused eslint-plugin-jest from devDependencies

**Impact:** CI pipeline now runs successfully with latest eslint 10.0.0

## 📊 Pattern Comparison

| Pattern | Directions | Speed | Strength | Use Case |
|---------|-----------|--------|----------|----------|
| Grid | 2 (±45°) | Medium | Good | General purpose |
| Triangles | 3 (45°, 105°, -15°) | Medium | Better | Structural parts |
| Hexagons | Honeycomb | Slower | Best | Maximum strength |
| Concentric | Spiraling | Fast | Good | Curved/circular parts |
| Gyroid | Wavy TPMS | Medium | Excellent | Isotropic strength |
| Spiral | Radial | Fast | Good | Circular parts |
| Lightning | Branching | Fastest | Adequate | Draft/prototype |

## 📚 Documentation Updates

- Updated all instruction files for new infill patterns
- Added comprehensive API documentation for new patterns
- Updated README with pattern comparison table
- Added example scripts demonstrating all patterns
- Documented infill pattern centering feature

## 🔬 Testing

All new features include comprehensive test coverage:
- Concentric pattern: 11 tests
- Gyroid pattern: 13 tests
- Spiral pattern: 11 tests
- Lightning pattern: 11 tests
- Pattern centering: Integration tests

## 🙏 Acknowledgments

Special thanks to the GitHub Copilot team for assisting with:
- Complex gyroid algorithm implementation
- Concentric infill hole detection logic
- Lightning pattern tree structure
- Comprehensive documentation updates

## 🔗 Links

- **GitHub Release:** https://github.com/jgphilpott/polyslice/releases/tag/v26.2.0
- **npm Package:** https://www.npmjs.com/package/@jgphilpott/polyslice
- **Documentation:** https://github.com/jgphilpott/polyslice#readme
- **Changelog:** https://github.com/jgphilpott/polyslice/blob/main/CHANGELOG.md

## 📦 Installation

```bash
npm install @jgphilpott/polyslice
```

Or via CDN (browser):
```html
<script src="https://unpkg.com/@jgphilpott/polyslice@26.2.0/dist/index.browser.min.js"></script>
```

## 🚀 Upgrade Guide

Upgrading from v26.1.2 is straightforward - all changes are additive:

```bash
npm update @jgphilpott/polyslice
```

**New API Methods:**
```javascript
// Use new infill patterns
slicer.setInfillPattern('concentric');
slicer.setInfillPattern('gyroid');
slicer.setInfillPattern('spiral');
slicer.setInfillPattern('lightning');

// Configure pattern centering
slicer.setInfillPatternCentering('object'); // Default
slicer.setInfillPatternCentering('global');
```

**Breaking Changes:** None - all existing code continues to work

**Behavior Changes:**
- Gyroid pattern now generates different output (single rotating direction)
- Concentric pattern now properly respects holes
- Cylinder slicing may produce slightly different output due to SLICE_EPSILON fix

## 📈 Statistics

**Since v26.1.2:**
- 80+ commits merged
- 7 major pull requests (4 for new patterns, 3 for fixes)
- 4 new infill patterns added
- 25 new tests added
- 200+ documentation updates
- 15+ bug fixes and improvements

---

**Full Changelog:** https://github.com/jgphilpott/polyslice/blob/main/CHANGELOG.md
