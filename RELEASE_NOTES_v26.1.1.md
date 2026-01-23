# Release v26.1.1

**Release Date:** January 23, 2026  
**Version:** 26.1.1 (Second release of January 2026)

## Highlights

This release introduces several major enhancements to Polyslice, focusing on improving print quality, adding comprehensive adhesion support, and optimizing travel paths for more efficient printing.

## New Features

### Smart Wipe Nozzle

A new intelligent wipe nozzle feature that prevents marks and filament threads on finished parts:

- **Intelligent Path Calculation**: Analyzes the mesh bounding box to find the shortest path away from the print boundaries
- **Built-in Retraction**: Includes retraction during the wipe move to prevent oozing
- **Configurable**: Control via the `smartWipeNozzle` option (enabled by default when `wipeNozzle` is true)
- **Automatic Backoff**: Adds 3mm safety backoff beyond mesh boundaries

Traditional wipe implementations simply move X+5, Y+5 in relative coordinates, which can cause the nozzle to land on the print itself. The smart wipe calculates the optimal direction to move perpendicular to the nearest boundary.

### Complete Adhesion Module

A comprehensive adhesion system with three distinct adhesion types:

#### Skirt
- **Circular Mode**: Perfect circles around the model for simple nozzle priming
- **Shape Mode**: Follows the actual first layer outline for precise boundary visualization
- **Configurable Distance**: Set distance from model edge (default: 5mm)
- **Line Count**: Control number of loops (default: 3)

#### Brim
- **Attached Support**: Directly attaches to model edge for maximum warping prevention
- **Minimal Gap**: Configurable gap from model (default: 0mm for full attachment)
- **Wide Support**: 8 lines by default for strong hold

#### Raft
- **Three-Layer System**: Base layer, interface layers, and air gap
- **Configurable Thickness**: Independent control of base and interface layer heights
- **Air Gap**: Adjustable gap between raft and model for easy removal
- **Line Spacing**: Control raft density for optimal bed adhesion

All adhesion types include:
- Modular architecture with separate sub-modules
- Boundary checking to warn if extending beyond build plate
- Integration with verbose mode for detailed G-code annotations
- Example scripts demonstrating usage

### Travel Path Optimization

Significant improvements to travel move efficiency:

- **Nearest-Neighbor Algorithm**: Objects are processed in order of proximity to minimize travel distance
- **Sequential Completion**: For independent objects, each is fully completed (walls → skin → infill) before moving to the next
- **Home Position Start**: First layer sorting starts from printer home position (0,0)
- **Intelligent Application**: Optimization applies when exposure detection is disabled for simple multi-object prints

This can dramatically reduce print time for prints with multiple independent objects by eliminating zigzag patterns across the build plate.

### Development Tools

- **Release Agent**: New specialized agent for managing calendar-based version releases
- **CHANGELOG.md**: Formal changelog following Keep a Changelog conventions
- **Example Scripts**: New slice-pillars example generating pillar arrays from 1x1 to 5x5

## Improvements

### Module Organization

- Reorganized adhesion module into clean subdirectories (`skirt/`, `brim/`, `raft/`, `helpers/`)
- Each adhesion type now has its own dedicated module with clear separation of concerns
- Improved code maintainability and testability

### Travel Efficiency

- Travel paths now use nearest-neighbor sorting throughout the slicing process
- Better handling of independent objects vs complex geometries with holes
- Reduced unnecessary travel moves between features

## Bug Fixes

- **Test Output**: Cleaned up test output to suppress expected console warnings
- **Travel Optimization**: Fixed incorrect application when exposure detection was enabled
- **Home Position**: Proper handling of printer home position (0,0) as starting point for first layer sorting

## Breaking Changes

### Removed

- **Deprecated `outline` Setting**: The `outline` configuration option has been removed. This feature was deprecated and unused in the codebase.

## Dependencies

No dependency updates in this release. Current major dependencies:
- three.js: ^0.182.0
- @jgphilpott/polytree: ^0.1.6
- @jgphilpott/polyconvert: ^1.0.5
- polygon-clipping: ^0.15.7
- three-subdivide: ^1.1.5

## Documentation

- Added comprehensive CHANGELOG.md
- Updated adhesion module documentation
- Added smart wipe implementation guide
- Documented travel optimization strategies

## Testing

All tests pass (651 tests):
- Unit tests for all new features
- Integration tests for adhesion types
- Smart wipe calculation tests
- Travel optimization validation

## Migration Guide

### From v26.1.0 to v26.1.1

No breaking API changes. All existing code will continue to work.

If you were using the `outline` setting (unlikely as it was deprecated), simply remove it from your configuration:

```javascript
// Before
const slicer = new Polyslice({
  outline: true,  // Remove this
  // ... other settings
});

// After
const slicer = new Polyslice({
  // ... other settings
});
```

### New Optional Features

To use the new features, simply enable them in your configuration:

```javascript
const slicer = new Polyslice({
  // Smart wipe nozzle (enabled by default when wipeNozzle is true)
  wipeNozzle: true,
  smartWipeNozzle: true,
  
  // Adhesion
  adhesionEnabled: true,
  adhesionType: 'skirt',  // or 'brim' or 'raft'
  skirtDistance: 5,
  skirtLineCount: 3,
  
  // Travel optimization (automatic for independent objects)
  exposureDetection: false,  // Enable optimization
});
```

## Known Issues

None reported for this release.

## Installation

### npm

```bash
npm install @jgphilpott/polyslice
```

### Browser CDN

```html
<script src="https://unpkg.com/@jgphilpott/polyslice@26.1.1/dist/index.browser.min.js"></script>
```

## Verification

To verify the installation:

```javascript
const Polyslice = require('@jgphilpott/polyslice');
console.log(Polyslice.version); // Should output "26.1.1"
```

## Next Steps

After merging this PR:

1. **Push Tags**: `git push origin main --tags` to push the v26.1.1 tag
2. **GitHub Release**: Create a GitHub release using these notes
3. **npm Publish**: Run `npm publish` to publish to npm registry
4. **Verification**: 
   - Check `npm view @jgphilpott/polyslice version`
   - Test installation in a clean directory
   - Verify unpkg CDN updates

## Thanks

Thanks to all contributors and users who have provided feedback and helped improve Polyslice!

---

**Full Changelog**: https://github.com/jgphilpott/polyslice/compare/v26.1.0...v26.1.1
