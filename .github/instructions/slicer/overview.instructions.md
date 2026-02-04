---
applyTo: 'src/slicer/**/*.coffee'
---

# Slicer Module Overview

The slicer module is the core of Polyslice, responsible for converting 3D mesh geometry into layered G-code instructions for FDM 3D printers.

## Purpose

The slicer takes a three.js mesh object and:
1. Slices it into horizontal layers at the configured layer height
2. Generates walls (perimeters) for each layer
3. Fills interior regions with infill patterns
4. Creates solid top/bottom surfaces (skin)
5. Outputs G-code commands for the printer

## Main Entry Point

The slicing process is orchestrated by `src/slicer/slice.coffee`, which:

1. **Extracts the mesh** from the scene using preprocessing utilities
2. **Clones the mesh** to preserve the original object (position, rotation, scale remain unchanged)
   - Uses `mesh.clone(true)` for recursive cloning of child objects
   - Explicitly clones geometry to prevent shared state modification
3. **Generates pre-print sequence** (heating, homing, test strip)
4. **Calculates centering offsets** based on mesh bounding box to center on build plate
5. **Slices the mesh** using Polytree library into layer segments
6. **Processes each layer** by:
   - Converting segments to closed paths
   - Detecting holes (paths contained within other paths)
   - Generating walls from outer to inner
   - Generating skin for exposed surfaces
   - Generating infill for interior regions
7. **Generates post-print sequence** (cooling, homing, shutdown)

## Important Behavior

**Mesh Preservation**: The slicing process does NOT modify the original mesh object. A clone is created internally before any transformations (such as adjusting Z position for the build plate). This ensures that:
- The original mesh position, rotation, and scale remain unchanged
- The original mesh geometry remains unchanged (bounding box not computed)
- The mesh can be used in a scene visualization while slicing
- Multiple slicing operations can be performed on the same mesh

**Build Plate Centering**: The slicing process automatically centers meshes on the build plate by:
- Calculating the mesh's bounding box center in the XY plane
- Computing offsets to map the mesh center to the build plate center
- Ensuring prints are properly centered regardless of the mesh's world position

## Key Concepts

### Layer Processing Pipeline

The slicer uses sequential completion with depth-first processing for optimal travel paths:

**Sequential Completion (used for all geometries):**

```
Mesh → Polytree.sliceIntoLayers() → Line Segments → Closed Paths
                                                         ↓
                                        Hole Detection (point-in-polygon)
                                                         ↓
                                        Nearest-Neighbor Sorting
                                        (starting from home position)
                                                         ↓
                                        For Each Top-Level Structure:
                                        - Walls (outer → inner)
                                        - Skin/Infill (if applicable)
                                        - Process Direct Child Holes:
                                          * Walls (outer → inner)
                                          * Skin (if applicable)
                                          * Recursively Process Nested Structures
                                                         ↓
                                        Phase 2 (Fallback for Non-Top-Level):
                                        - Process any remaining structures
```

**Two-Phase Processing (legacy fallback):**

Only used for structures that weren't completed during sequential processing (rare edge cases).

### Coordinate System

- All internal calculations use local mesh coordinates
- Mesh is automatically centered on build plate based on its bounding box center
- `centerOffsetX = (buildPlateWidth / 2) - meshCenterX` centers mesh in X
- `centerOffsetY = (buildPlateLength / 2) - meshCenterY` centers mesh in Y
- Z coordinate is calculated as `adjustedMinZ + layerIndex * layerHeight`
- A small epsilon (0.001mm) offsets the starting Z to avoid boundary issues

### Path Types

- **Outer Boundaries**: External perimeter of the model or independent objects
- **Holes**: Paths contained within other paths (detected via point-in-polygon)
- **Innermost Walls**: The final wall before infill area
- **Independent Objects**: Separate outer boundaries with no holes (optimized for sequential completion)
- **Nested Objects**: Structures inside holes (matryoshka pattern - processed depth-first)

### Travel Path Optimization

Polyslice uses intelligent travel path optimization to minimize print time:

#### Sequential Completion (All Geometries)

1. **Home Position Start**: On the first layer, starts from printer home position (0, 0)
2. **Nearest-Neighbor Sorting**: Top-level structures sorted by proximity to last position
3. **Depth-First Processing**:
   - Complete structure (walls → skin → infill)
   - Process direct child holes (walls → skin if needed)
   - Recursively complete nested structures inside holes
   - Move to next top-level structure

#### Benefits

- **Independent Objects** (no holes):
  - Each object fully completed before moving to next
  - Minimizes travel distance between objects
  - Prevents zigzag patterns across build plate

- **Nested Objects** (with holes):
  - Parent structure completed before processing children
  - Short, efficient travels between parent and child structures
  - Intuitive depth-first print order (like matryoshka dolls)
  - Reduces stringing and oozing

#### Nesting-Aware Features

- **Hole Filtering**: Only direct children (nesting level + 1) affect each structure
- **Travel Optimization**: Combing paths avoid crossing holes
- **Recursive Processing**: Nested structures processed depth-first for efficiency

The optimization is automatic - no configuration needed.

### Wall Count Calculation

```coffeescript
wallCount = Math.floor((shellWallThickness / nozzleDiameter) + 0.0001)
```

The epsilon (0.0001) handles floating point precision (e.g., 1.2/0.4 = 2.9999... → 3).

### Skin Layer Detection

Skin (solid infill) is generated when:
- Layer is within `skinLayerCount` of top or bottom
- Exposure detection finds uncovered areas on middle layers

### Extrusion Tracking

Uses cumulative extrusion in absolute mode:
```coffeescript
slicer.cumulativeE += extrusionDelta
```

## Module Dependencies

```
slice.coffee
├── gcode/coders.coffee       # G-code command generation
├── utils/primitives.coffee   # Point/line operations
├── utils/paths.coffee        # Path manipulation
├── utils/clipping.coffee     # Polygon clipping
├── geometry/coverage.coffee  # Area coverage detection
├── infill/infill.coffee      # Infill pattern generation
├── skin/skin.coffee          # Skin generation
├── walls/walls.coffee        # Wall generation
├── support/support.coffee    # Support structure generation
├── skin/exposure/exposure.coffee   # Exposure detection
└── preprocessing/preprocessing.coffee  # Mesh preprocessing
```

## Configuration Parameters

Key slicer settings that affect slicing:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `layerHeight` | 0.2mm | Height of each layer |
| `nozzleDiameter` | 0.4mm | Nozzle width |
| `shellWallThickness` | 0.8mm | Total wall thickness |
| `shellSkinThickness` | 0.8mm | Top/bottom solid thickness |
| `infillDensity` | 20% | Interior fill percentage |
| `infillPattern` | 'grid' | Pattern type |
| `exposureDetection` | false | Adaptive skin detection |

## Important Conventions

1. **Nearest-neighbor sorting**: Applied to both independent objects (outer boundaries) and holes to minimize travel distance
2. **Home position initialization**: First layer starts from printer home (0, 0) in build plate coordinates, converted to mesh coordinates
3. **Sequential object completion**: For independent objects without exposure detection, complete each object (walls + skin/infill) before moving to next
4. **Two-phase processing**: For complex geometries with holes or exposure detection enabled, use Phase 1 (walls) → Phase 2 (skin/infill) approach
5. **Spacing Validation**: Skip inner walls/skin when paths are too close together
6. **Travel Optimization**: Use combing paths to avoid crossing holes
7. **Cumulative State**: Track `lastLayerEndPoint` for cross-layer combing
