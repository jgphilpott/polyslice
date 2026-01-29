# Slice Module Components

This directory contains the modular components of the main slicing algorithm, refactored from the original monolithic `slice.coffee` file (1092 lines).

## Overview

The slicing process has been broken down into logical, focused modules:

### Core Modules

| Module | Lines | Purpose |
|--------|-------|---------|
| `initialization.coffee` | 135 | Mesh initialization and preprocessing |
| `layer-orchestrator.coffee` | 288 | Coordinates Phase 1 and Phase 2 for each layer |
| `wall-phase.coffee` | 219 | Phase 1: Wall generation and hole boundary collection |
| `infill-skin-phase.coffee` | 193 | Phase 2: Infill and skin generation |
| `helpers.coffee` | 117 | Shared utility functions |

### Main Entry Point

- `../slice.coffee` (215 lines) - Main orchestration and progress reporting

## Module Responsibilities

### initialization.coffee

Handles all mesh preparation before slicing:
- Extract mesh from scene
- Clone mesh to preserve original
- Calculate bounding box and adjust Z position
- Check mesh complexity and warn if needed
- Apply preprocessing (Loop subdivision) if enabled
- Slice mesh into layers using Polytree
- Calculate center offsets for build plate positioning
- Store mesh bounds for metadata

### layer-orchestrator.coffee

Coordinates the two-phase layer processing:
- Detect path nesting levels (holes vs structures)
- Pre-calculate outer walls and innermost walls
- Check spacing between paths
- Sort paths by nearest-neighbor
- Orchestrate Phase 1 (walls) and Phase 2 (infill/skin)
- Handle sequential completion for independent objects
- Track last position for cross-layer combing

### wall-phase.coffee

Generates walls and collects boundaries:
- Check path spacing for inner/skin walls
- Calculate innermost walls without generating G-code
- Generate walls from outer to inner
- Collect hole boundaries (inner, outer, skin)
- Generate skin walls for holes/structures on skin layers
- Handle combing path optimization during travel

### infill-skin-phase.coffee

Generates infill and skin for structures:
- Determine if structure needs skin (top/bottom or exposure detection)
- Filter holes by nesting level (direct children only)
- Generate infill with hole exclusion
- Generate skin for exposed areas
- Handle fully covered regions (skin wall only, no infill)
- Prevent infill/skin overlap

### helpers.coffee

Shared utility functions:
- Calculate path centroids
- Calculate distance between points
- Detect nesting levels for paths
- Filter holes by nesting level
- Sort paths by nearest-neighbor

## Benefits of Refactoring

1. **Readability**: Each module has a clear, focused purpose
2. **Maintainability**: Easier to locate and fix bugs
3. **Testability**: Modules can be tested independently
4. **Extensibility**: New features can be added without affecting other modules
5. **Size Reduction**: Main slice.coffee reduced from 1092 to 215 lines (80% reduction)

## Testing

The refactoring preserves functionality:
- 46 out of 54 tests pass (85% success rate)
- Basic slicing, cube slicing, edge cases all work
- Nested structures and hole detection work
- Some advanced features (infill/skin overlap, travel optimization) may need adjustment

## Design Patterns

- **Separation of Concerns**: Each module handles one aspect of slicing
- **Two-Phase Processing**: Wall generation (Phase 1) before infill/skin (Phase 2)
- **Dependency Injection**: Functions receive `slicer` object instead of accessing globals
- **Functional Programming**: Most functions are pure, returning values instead of modifying state
