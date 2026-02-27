# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to a calendar-based versioning scheme (YY.M.N).

## [Unreleased]

## [26.2.2] - 2026-02-27

### Added
- **Tree Support Type** - Fully functional tree support as an alternative to normal grid supports (PR #151)
  - Convergence algorithm: dense contact points near the overhang thin into sparse trunk columns toward the build plate
  - Two zones per point using barycentric interpolation of overhang face Z:
    - **Branch zone** (within 8mm of overhang): fine 1.5× nozzle diameter spacing
    - **Trunk zone** (>8mm from overhang): coarse 4× nozzle diameter spacing, convergence snapping
  - Reuses `isPointInSupportWedge` and `canGenerateSupportAt` from normal module for collision detection
  - Uses less material and creates smaller contact footprints for easier removal
- **Visualizer: Model Rotation Controls** - Added full rotation control to the visualizer slicing GUI (PR #162)
  - New **Model Rotation** folder in the Slicer panel with X, Y, Z sliders (−180° to +180°, 1° steps)
  - Rotation values are persisted to localStorage and restored on reload
  - Three.js `TransformControls` gizmo in rotate mode for interactive in-viewport rotation
    - Click on a loaded mesh to reveal the arc-handle gizmo
    - Drag any arc handle to rotate the mesh; GUI sliders stay in sync in real time
    - Click anywhere off the mesh to dismiss the gizmo
    - `OrbitControls` are automatically paused while dragging the gizmo to prevent conflicts
  - Bidirectional sync: moving a slider updates the gizmo, dragging the gizmo updates the sliders
  - Gizmo is detached/hidden when G-code is displayed, on mesh clear, and on Reset
- **Visualizer: Extended Slicer Settings** - Added Adhesion, Support, and additional print settings to the GUI (PR #159)
  - Adhesion type and all skirt/brim/raft settings
  - Support type, placement, and threshold settings
  - Nozzle temperature, bed temperature, and fan speed sliders
  - Shell wall and skin thickness controls moved to top of Slicer Settings section
  - All 7 infill patterns now selectable
- **Adhesion Examples** - Added torus and arch geometries to `slice-adhesion.js` example script (PR #150)
  - G-code output files for all 4 adhesion types × 4 geometries

### Changed
- **Visualizer: UI Layout** - Collapsed `Adhesion` and `Support` GUI folders by default to reduce visual clutter; both can still be expanded by clicking their headers (PR #162)
- **Visualizer: Camera Behaviour** - Camera no longer refocuses on every file upload; refocuses only on the first upload per type (model or G-code), and resets when Slice is clicked (PR #159)
- **Visualizer: Slider Events** - Numeric sliders use `onFinishChange` instead of `onChange` to avoid excessive localStorage writes while dragging (PR #159)

### Fixed
- **Support: First-Layer Blocking** - Support structures no longer generated on layer 0 when solid geometry blocks the position; `canGenerateSupportAt` now includes the current layer in the blocking check (`<=` instead of `<`) (PR #148)
- **Support: Wedge-Shaped Overhang Fill** - Support generation now uses barycentric interpolation (`isPointInSupportWedge`) to restrict fill to the actual overhang wedge, preventing support on the wrong side of slanted surfaces (PR #149)
- **Walls/Infill: C-Shaped Cross-Sections** - Fixed missing `WALL-INNER` and `FILL`/`SKIN` on all layers of C-shaped cross-sections (e.g. sideways dome); removed incorrect `testInsetPath` guard in `slice.coffee` and fixed `createInsetPath` near-tangent divergence (PR #152)
- **Skin: Infill Lines Crossing Wall Boundary** - Fixed skin and regular infill lines extending outside the inner wall boundary; reduced `clipLineToPolygon` default epsilon from `0.3` to `0.001` (PR #153, PR #155)
- **Skin: Redundant G0 Travel Moves** - Added `isAlreadyAtStartPoint` guard in `skin.coffee` to skip G0 generation when the nozzle is already within 0.001mm of the infill segment start (PR #153)
- **Skin: Spurious Walls on Flipped Arch** - Fixed extra skin walls on arch transition layers; `identifyFullyCoveredRegions` in `cavity.coffee` now skips covering regions whose bounding box extends to or beyond the current path boundary (PR #154)
- **Infill: Global Centering Coverage** - Fixed missing infill lines when using `infillPatternCentering: 'global'` for grid, triangles, and spiral patterns; `numLinesUp` now computed from boundary corner extents relative to the pattern center rather than the bounding box diagonal (PR #156)
- **Walls: Jagged Inner Wall Spikes** - Fixed spike vertices in inner wall G-code at arc-rectangle junctions (sideways dome); `createInsetPath` backtracking-vertex removal is now an iterative index-scan loop that handles cascading near-reversal vertices (PR #158)
- **Walls: Endpoints Extending Beyond Boundary** - Fixed wall endpoints extending past expected positions at concave arc junctions; `createInsetPath` now applies a `removeBacktrackingVertices` post-processing pass on its output (PR #160)
- **Skin: Spurious Skin Patches After Infill** - Fixed skin-wall-only blocks generated for degenerate ribbon polygons on sideways dome layers 14–18 and 108–112; `generateSkinGCode` now pre-checks infill boundary feasibility before emitting `; TYPE: SKIN` (PR #161)

## [26.2.1] - 2026-02-19

### Changed
- **Support Generation Architecture** - Completely revamped support generation system
  - Reorganized into sub-module architecture (normal/tree support types)
  - Proper dispatcher pattern with clean separation of concerns
  - Main module delegates to specialized sub-modules
  - Normal support module: 499 lines of focused grid-based support logic
  - Tree support module: Template for future implementation
- **Support Algorithm** - Switched from point-based to face-based grouping
  - Adjacent overhang faces sharing edges are pooled into unified regions
  - Union-find algorithm groups connected faces efficiently
  - Coordinated grid patterns cover entire grouped areas
  - Collective bounding box calculated from all vertices in group

### Fixed
- **Support Extrusion** - Fixed over-extrusion in support structures
  - Now uses `supportLineWidth` (0.8× nozzle diameter) instead of full nozzle diameter
  - Eliminates 25% over-extrusion that made supports difficult to remove
  - Correct material flow for easier support removal
- **Support Coverage** - Improved coverage for complex geometries
  - Arch geometry: Complete overhang coverage (grouped adjacent bottom faces)
  - Dome geometry: Unified coordinated structure (no overlapping pillars)
  - Face-based approach accounts for entire face area, not just centers
- **Support Visualization** - Added TYPE comments on every layer
  - Support segments properly labeled with `; TYPE: SUPPORT` comment
  - Enables correct color coding in G-code visualizers
  - Consistent with other feature type annotations
- **Support Gap** - Proper clearance between support and printed part
  - Uses `nozzleDiameter / 2` gap to prevent overlap
  - Support region bounds shrunk inward (minX + gap, maxX - gap)
  - Follows same gap convention as infill

### Removed
- **Dead Code Cleanup** - Removed unused support generation code
  - Deleted 640 lines of duplicate code from main module
  - Removed never-called `clusterOverhangRegions` method
  - Cleaned up old point-based clustering implementation

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

[Unreleased]: https://github.com/jgphilpott/polyslice/compare/v26.2.2...HEAD
[26.2.2]: https://github.com/jgphilpott/polyslice/compare/v26.2.1...v26.2.2
[26.2.1]: https://github.com/jgphilpott/polyslice/compare/v26.2.0...v26.2.1
[26.2.0]: https://github.com/jgphilpott/polyslice/compare/v26.1.2...v26.2.0
[26.1.2]: https://github.com/jgphilpott/polyslice/compare/v26.1.1...v26.1.2
[26.1.1]: https://github.com/jgphilpott/polyslice/compare/v26.1.0...v26.1.1
[26.1.0]: https://github.com/jgphilpott/polyslice/releases/tag/v26.1.0
