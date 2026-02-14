# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to a calendar-based versioning scheme (YY.M.N).

## [Unreleased]

## [26.2.0] - 2026-02-14

### Added
- **New Infill Patterns** - Four new infill pattern options for different use cases:
  - **Concentric** - Inward-spiraling contours that follow the boundary shape naturally, ideal for curved shapes and cylindrical cross-sections
  - **Gyroid** - Triply periodic minimal surface (TPMS) with wavy pattern that creates 3D interlocking structure across layers, offering excellent strength-to-weight ratio with single rotating direction per layer
  - **Spiral** - Archimedean spiral from center outward in a continuous path, perfect for smooth circular motion and cylindrical geometries
  - **Lightning** - Tree-like branching pattern with fast printing and minimal material usage, featuring 45° fork angles for natural appearance
- **Infill Pattern Centering** - New `infillPatternCentering` configuration option
  - Choose between 'object' (default) or 'global' centering modes
  - Affects grid, triangles, hexagons, gyroid, spiral, and lightning patterns
  - Object mode centers patterns on individual object boundaries
  - Global mode centers patterns on build plate center (0,0)

### Changed
- **Gyroid Pattern Algorithm** - Completely revised gyroid implementation
  - Uses single rotating direction per layer instead of dual directions
  - Gradual transition over 8-layer cycle (0° to 90° rotation)
  - Better layer-to-layer adhesion and more consistent material usage (~85-100 lines per layer)
  - Optimized segment count for better performance

### Fixed
- **Concentric Infill** - Fixed multiple issues with concentric pattern
  - Added proper gap (lineSpacing) between walls and first infill loop
  - Implemented hole detection using majority voting on 8 sample points
  - Fixed torus example from 33% to 0% erroneous points in holes
- **Gyroid Infill** - Fixed to use single rotating direction per layer instead of generating both X and Y directions simultaneously
  - Eliminates ~170 line generation per layer
  - Produces consistent ~85-100 lines per layer
  - Smoother transitions between layers
- **Spiral Infill** - Fixed lastEndPoint tracking to update only when movement is generated
- **Skin Generation** - Fixed travel moves for nested structures
- **Cylinder Bottom Layer** - Fixed incomplete walls by adjusting SLICE_EPSILON to layerHeight/2
- **CI Pipeline** - Resolved dependency conflicts by removing unused eslint-plugin-jest

## [26.1.2] - 2026-01-28

### Added
- G-code metadata extraction with `getGcodeMetadata()` method
  - Multi-slicer support for Polyslice, Cura, and PrusaSlicer formats
  - Automatic slicer detection based on G-code comments
  - Parses common fields: printer, filament, layer height, print time, etc.
  - Returns empty object when no metadata is present
  - Supports both `slicer.gcode` and custom G-code strings
- Configurable metadata fields (individual control over each metadata field)
  - 20+ metadata field options (version, timestamp, repository, printer, filament, temperatures, etc.)
  - Metadata fields output with proper units (temperature in °C, length in mm, etc.)
  - Bounding box coordinates tracking for prints
- Progress callback system for real-time slicing feedback
  - Default lightweight progress bar (works in Node.js and browsers)
  - Progress stages: initializing, pre-print, adhesion, slicing, post-print, complete
  - Layer-by-layer progress reporting
  - Customizable progress callback function
- Print time calculation from G-code
  - Analyzes G-code commands to estimate total print time
  - Accounts for movement distances, feedrates, and positioning modes
  - Supports arc movements (G2/G3) and relative positioning
- Enhanced metadata header generation in G-code output
  - Comprehensive print information in G-code comments
  - Configurable metadata fields for custom G-code headers
  - Improved metadata parsing to handle multiple G-code flavors

## [26.1.1] - 2026-01-23

### Added
- Release agent profile for managing version releases with calendar-based versioning
- CHANGELOG.md to track version history
- Smart wipe nozzle feature that intelligently moves away from print surface
  - Analyzes mesh bounding box to find shortest path away from boundaries
  - Includes retraction during wipe move to prevent oozing
  - Configurable via `smartWipeNozzle` option
- Adhesion module with skirt, brim, and raft support
  - Modular architecture with separate sub-modules for each adhesion type
  - Configurable adhesion distance and line count
  - Example scripts demonstrating adhesion features
- Travel path optimization using nearest-neighbor algorithm
  - Sequential object completion for independent objects
  - Minimizes travel distance between objects
  - Starts from home position (0,0) on first layer
- Slice-pillars example script generating pillar arrays from 1x1 to 5x5

### Changed
- Travel paths now use nearest-neighbor sorting for better efficiency
- Independent objects are completed sequentially (walls → skin → infill) before moving to next object
- Reorganized adhesion module into subdirectories with modular structure

### Fixed
- Test output cleanup to suppress expected console warnings
- Travel optimization now correctly applies only when exposure detection is disabled
- Proper handling of home position (0,0) as starting point for first layer

### Removed
- Deprecated `outline` configuration setting

## [26.1.0] - 2026-01-09

Initial release for January 2026. See GitHub releases and commit history for details on previous versions.

[Unreleased]: https://github.com/jgphilpott/polyslice/compare/v26.2.0...HEAD
[26.2.0]: https://github.com/jgphilpott/polyslice/compare/v26.1.2...v26.2.0
[26.1.2]: https://github.com/jgphilpott/polyslice/compare/v26.1.1...v26.1.2
[26.1.1]: https://github.com/jgphilpott/polyslice/compare/v26.1.0...v26.1.1
[26.1.0]: https://github.com/jgphilpott/polyslice/releases/tag/v26.1.0
