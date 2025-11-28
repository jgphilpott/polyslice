---
applyTo: 'src/slicer/geometry/**/*.coffee'
---

# Geometry Algorithms Overview

The geometry module provides algorithms for travel path optimization (combing) and coverage detection.

## Purpose

- Optimize travel moves to avoid crossing holes
- Detect covered vs exposed areas for skin generation
- Provide wayfinding through complex layer geometry

## Combing (Travel Path Optimization)

Located in `src/slicer/geometry/combing.coffee`.

### What is Combing?

Combing is the process of finding travel paths that avoid crossing through holes in the layer. This prevents stringing and oozing artifacts on the printed part.

### Algorithm Strategy

1. **Direct Path Check**: First, check if the straight-line path crosses any holes
2. **Back-off Strategy**: Move endpoints away from nearby hole boundaries
3. **Simple Heuristic**: Try single-waypoint detours perpendicular to the travel direction
4. **A* Wayfinding**: Use grid-based A* algorithm for complex cases
5. **Boundary Fallback**: Use corner waypoints along the outer boundary

### Back-off Strategy

```coffeescript
BACKOFF_MULTIPLIER = 3.0
backOffDistance = nozzleDiameter * BACKOFF_MULTIPLIER  # e.g., 3.0 * 0.4mm = 1.2mm
```

Points near holes are pushed away to create clearance before pathfinding.

### Hole Crossing Detection

```coffeescript
travelPathCrossesHoles: (startPoint, endPoint, holePolygons) ->
```

Checks three conditions:
1. Start or end point is inside a hole (point-in-polygon test)
2. Travel path intersects any hole edge (line segment intersection)
3. Travel path passes too close to hole center (distance < avgRadius + margin)

### A* Wayfinding

```coffeescript
findAStarCombingPath: (start, end, holePolygons, boundary) ->
```

Grid-based pathfinding:
- **Grid size**: 2.0mm cells
- **Max iterations**: 2000 (prevents infinite loops)
- **Heuristic**: Manhattan distance
- **Neighbors**: 8-directional (including diagonals)
- **Diagonal cost**: 1.414 (√2)

### Cell Validity

A grid cell is valid if:
- Inside the outer boundary (if provided)
- Not inside any hole polygon
- Not within margin (0.5mm) of any hole center

### Path Simplification

After A* finds a path, unnecessary waypoints are removed:

```coffeescript
simplifyPath: (path, holePolygons) ->
    # Remove waypoint if direct path to next point doesn't cross holes
```

### Optimal Start Point Selection

For closed paths (walls), find the best starting point to minimize travel:

```coffeescript
findOptimalStartPoint: (path, fromPoint, holePolygons, boundary, nozzleDiameter) ->
```

Considers:
- Distance from current position
- Whether travel path crosses holes
- Total combing path length if crossing occurs

## Coverage Detection

Located in `src/slicer/geometry/coverage.coffee`.

### Purpose

Determine which areas are covered by geometry in adjacent layers. Used for:
- Detecting exposed surfaces that need skin
- Identifying fully covered regions that only need infill

### Key Functions

```coffeescript
# Check if a hole exists in the target layer at approximately the same location
doesHoleExistInLayer: (holePath, targetLayerPaths) ->

# Calculate the percentage of an area covered by other polygons
calculateCoveragePercentage: (testArea, coveringPolygons) ->

# Check if an area is completely inside any hole wall
isAreaInsideAnyHoleWall: (area, holeSkinWalls, holeInnerWalls, holeOuterWalls) ->

# Calculate which parts of a boundary are exposed (not covered)
calculateExposedAreas: (currentPath, coveringPaths, resolution) ->
```

### Coverage Sampling

Uses grid-based sampling to estimate coverage:

```coffeescript
resolution = slicer.getExposureDetectionResolution()  # Default: 961 samples
```

Higher resolution = more accurate but slower detection.

## Primitives (Basic Operations)

Located in `src/slicer/utils/primitives.coffee`.

### Point Comparison

```coffeescript
# Fast comparison using squared distance (no sqrt)
pointsMatch: (p1, p2, epsilon) ->
    distSq = dx * dx + dy * dy
    return distSq < epsilon * epsilon

# Exact distance comparison
pointsEqual: (p1, p2, epsilon) ->
    return Math.sqrt(dx * dx + dy * dy) < epsilon
```

### Line Intersection

```coffeescript
# Infinite line intersection
lineIntersection: (p1, p2, p3, p4) ->

# Bounded segment intersection (with t,u parameter checks)
lineSegmentIntersection: (p1, p2, p3, p4) ->
```

Uses parametric line equations:
- `t` = parameter for first line segment [0,1]
- `u` = parameter for second line segment [0,1]
- Intersection valid only if both t and u are in [0,1]

### Point in Polygon (Ray Casting)

```coffeescript
pointInPolygon: (point, polygon) ->
```

Standard ray casting algorithm:
1. Cast horizontal ray from point to infinity
2. Count intersections with polygon edges
3. Odd count = inside, Even count = outside

### Distance Calculations

```coffeescript
# Point to line segment distance
distanceFromPointToLineSegment: (px, py, segStart, segEnd) ->
    # Projects point onto segment, clamps to [0,1], returns distance

# Manhattan distance (for A* heuristic)
manhattanDistance: (x1, y1, x2, y2) ->
    return Math.abs(x2 - x1) + Math.abs(y2 - y1)
```

### Intersection Deduplication

```coffeescript
deduplicateIntersections: (intersections, epsilon = 0.001) ->
```

Removes duplicate points that occur when lines pass through polygon corners.

## Important Conventions

1. **Epsilon tolerances**: Use 0.001mm for point comparison, 0.0001 for parallel line detection
2. **Margin values**: 0.5mm margin for hole avoidance in travel paths
3. **Performance**: Use `pointsMatch` (squared distance) in tight loops, `pointsEqual` when precision matters
4. **Coordinate system**: All calculations in local mesh coordinates before center offset is applied
