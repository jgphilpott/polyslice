# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to a calendar-based versioning scheme (YY.M.N).

## [Unreleased]

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

[Unreleased]: https://github.com/jgphilpott/polyslice/compare/v26.1.1...HEAD
[26.1.1]: https://github.com/jgphilpott/polyslice/compare/v26.1.0...v26.1.1
[26.1.0]: https://github.com/jgphilpott/polyslice/releases/tag/v26.1.0
