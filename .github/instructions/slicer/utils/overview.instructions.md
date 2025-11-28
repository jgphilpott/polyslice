---
applyTo: 'src/slicer/utils/**/*.coffee'
---

# Slicer Utilities Overview

The slicer utilities provide core functionality for path manipulation, polygon operations, and geometric calculations. Located in `src/slicer/utils/`.

## Module Structure

| File | Purpose |
|------|---------|
| `primitives.coffee` | Basic geometry operations (points, lines) |
| `paths.coffee` | Path manipulation (segments, insets) |
| `clipping.coffee` | Polygon clipping operations |
| `bounds.coffee` | Bounding box calculations |
| `extrusion.coffee` | Extrusion amount calculations |

## Primitives Module

Located in `src/slicer/utils/primitives.coffee`.

### Point Operations

```coffeescript
# Fast squared distance comparison (use in tight loops)
pointsMatch: (p1, p2, epsilon) ->
    distSq = dx * dx + dy * dy
    return distSq < epsilon * epsilon

# Actual distance comparison
pointsEqual: (p1, p2, epsilon) ->
    return Math.sqrt(dx * dx + dy * dy) < epsilon
```

### Line Intersection

```coffeescript
# Infinite line intersection
lineIntersection: (p1, p2, p3, p4) ->
    # Returns { x, y } or null if parallel

# Bounded segment intersection
lineSegmentIntersection: (p1, p2, p3, p4) ->
    # Returns { x, y } only if intersection is within both segments
```

### Point in Polygon

Standard ray casting algorithm:

```coffeescript
pointInPolygon: (point, polygon) ->
    # Cast horizontal ray, count edge intersections
    # Odd count = inside, Even count = outside
```

### Distance Calculations

```coffeescript
# Point to line segment (with projection clamping)
distanceFromPointToLineSegment: (px, py, segStart, segEnd) ->

# Manhattan distance (for A* heuristic)
manhattanDistance: (x1, y1, x2, y2) ->
    return Math.abs(x2 - x1) + Math.abs(y2 - y1)
```

### Intersection Deduplication

```coffeescript
deduplicateIntersections: (intersections, epsilon = 0.001) ->
    # Removes duplicate points (e.g., when line passes through corner)
```

## Paths Module

Located in `src/slicer/utils/paths.coffee`.

### Segment to Path Conversion

Converts Polytree line segments into closed polygon paths:

```coffeescript
connectSegmentsToPaths: (segments) ->
    # Bidirectional greedy path connection
    # Uses leftmost-turn heuristic to select best candidate
```

#### Leftmost Turn Heuristic

When multiple edges connect at a point, select the one that turns most to the left:

```coffeescript
selectBestCandidate = (candidates, prevPoint, currentPoint) ->
    # Calculate cross product: positive = left turn (CCW)
    crossProduct = currentDirX * nextDirY - currentDirY * nextDirX
    # Select candidate with highest cross product
```

### Inset Path Generation

Creates offset paths for walls and boundaries:

```coffeescript
createInsetPath: (path, insetDistance, isHole = false) ->
```

#### Algorithm Steps

1. **Simplify path**: Keep only significant corners (angle change > ~2.9°)
2. **Calculate winding order**: Determine CCW vs CW using signed area
3. **Create offset lines**: Move each edge inward by inset distance
4. **Find intersections**: Calculate intersection points of adjacent offset lines
5. **Validate result**: Ensure inset path has proper dimensions

#### Winding Order Detection

```coffeescript
signedArea = 0
for i in [0...n]
    signedArea += path[i].x * path[nextIdx].y - path[nextIdx].x * path[i].y
isCCW = signedArea > 0
```

#### Direction Correction

Tests if inset direction is correct by checking if test point lands inside/outside:

```coffeescript
testX = midX + normalX * (insetDistance * 0.5)
testY = midY + normalY * (insetDistance * 0.5)
isTestPointInside = primitives.pointInPolygon({ x: testX, y: testY }, simplifiedPath)

# Flip normal if test is on wrong side
if isTestPointInside isnt shouldBeInside
    normalX = -normalX
    normalY = -normalY
```

#### Validation Checks

```coffeescript
# Minimum dimension check
minRequiredDimension = 2 * insetDistance + insetDistance * 0.2
if originalWidth < minRequiredDimension
    return []

# Size change verification
expectedSizeChange = insetDistance * 2 * 0.1
if widthReduction < expectedSizeChange
    return []
```

### Path Distance Calculation

```coffeescript
calculateMinimumDistanceBetweenPaths: (path1, path2) ->
    # Check point-to-segment distances both ways
    # Used to detect paths that are too close for inner walls
```

## Clipping Module

Located in `src/slicer/utils/clipping.coffee`.

### Line with Holes Clipping

```coffeescript
clipLineWithHoles: (startPoint, endPoint, boundary, holeWalls) ->
    # Returns array of line segments that are:
    # - Inside the boundary
    # - Outside all hole walls
```

### Skin Area Subtraction

```coffeescript
subtractSkinAreasFromInfill: (infillBoundary, skinAreas) ->
    # Returns infill boundaries with skin areas removed
    # Used to prevent overlap between skin and infill
```

## Bounds Module

Located in `src/slicer/utils/bounds.coffee`.

### Bounding Box Calculation

```coffeescript
calculateBoundingBox: (points) ->
    # Returns { minX, maxX, minY, maxY }
```

### Point Inside Bounds

```coffeescript
isPointInsideBounds: (point, bounds) ->
    # Simple rectangular containment check
```

## Extrusion Module

Located in `src/slicer/utils/extrusion.coffee`.

### Extrusion Calculation

Calculates filament length needed for a given path segment:

```coffeescript
calculateExtrusion: (distance, nozzleDiameter) ->
    # Based on:
    # - Travel distance
    # - Nozzle diameter (line width)
    # - Layer height
    # - Filament diameter
    # - Extrusion multiplier
```

#### Formula

```
Cross-section area = nozzle_diameter × layer_height
Volume = area × distance
Filament length = volume / (π × (filament_diameter/2)²)
Adjusted length = length × extrusion_multiplier
```

## Constants

| Constant | Value | Usage |
|----------|-------|-------|
| `MIN_SIMPLIFIED_CORNERS` | 4 | Minimum corners for path simplification |
| Epsilon (point match) | 0.001mm | Tolerance for point equality |
| Angle threshold | 0.05 rad (~2.9°) | Corner detection sensitivity |

## Important Conventions

1. **Coordinate system**: All operations in local mesh coordinates
2. **Epsilon values**: Use 0.001mm for point comparison
3. **Path closure**: Paths are closed loops (last point connects to first)
4. **Hole handling**: Set `isHole=true` for hole paths (reverses inset direction)
5. **Performance**: Use `pointsMatch` instead of `pointsEqual` in loops
