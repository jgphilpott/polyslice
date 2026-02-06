---
applyTo: 'src/slicer/infill/**/*.coffee'
---

# Infill Patterns Overview

The infill module generates interior fill patterns for 3D printed parts. Located in `src/slicer/infill/`.

## Purpose

- Fill interior regions with configurable density patterns
- Provide structural support while minimizing material usage
- Optimize travel paths to avoid crossing holes

## Supported Patterns

| Pattern | Directions | Description |
|---------|------------|-------------|
| `grid` | 2 (+45°, -45°) | Crosshatch pattern, good general-purpose |
| `triangles` | 3 (45°, 105°, -15°) | Equilateral triangle tessellation |
| `hexagons` | Honeycomb cells | Optimal strength-to-weight ratio |
| `concentric` | Inward spiraling | Concentric loops from outside to inside |

## Line Spacing Formula

The line spacing calculation ensures the configured infill density is achieved:

```coffeescript
# Base spacing calculation
baseSpacing = nozzleDiameter / (infillDensity / 100.0)

# Pattern-specific multipliers
gridSpacing = baseSpacing * 2.0        # 2 directions
trianglesSpacing = baseSpacing * 3.0   # 3 directions
hexagonsSpacing = baseSpacing * 3.0    # 3 directions
concentricSpacing = baseSpacing * 1.0  # Single direction (loops)
```

### Example: 20% Infill Density

With 0.4mm nozzle and 20% density:

1. **Base spacing calculation:**
   - `baseSpacing = nozzleDiameter / (density / 100)`
   - `baseSpacing = 0.4mm / (20 / 100) = 0.4mm / 0.2 = 2.0mm`

2. **Grid pattern (2 directions):**
   - `lineSpacing = baseSpacing × 2 = 2.0mm × 2 = 4.0mm`
   - Each line set covers `nozzleDiameter / lineSpacing = 0.4mm / 4.0mm = 10%`
   - Total coverage: `10% × 2 directions = 20%`

3. **Triangles/Hexagons (3 directions):**
   - `lineSpacing = baseSpacing × 3 = 2.0mm × 3 = 6.0mm`
   - Each line set covers `nozzleDiameter / lineSpacing = 0.4mm / 6.0mm ≈ 6.67%`
   - Total coverage: `6.67% × 3 directions ≈ 20%`

## Grid Pattern

Located in `src/slicer/infill/patterns/grid.coffee`.

### Algorithm

1. Calculate bounding box diagonal span
2. Determine pattern center based on `infillPatternCentering` setting (object boundary or global origin)
3. Generate +45° lines (y = x + offset), centered at determined point
4. Generate -45° lines (y = -x + offset), centered at determined point
5. Clip lines to infill boundary
6. Exclude hole areas via clipping
7. Render lines in nearest-neighbor order with combing

### Line Generation

```coffeescript
# For 45-degree lines, spacing adjustment
offsetStep = lineSpacing * Math.sqrt(2)  # Account for diagonal angle

# Line equations
# +45°: y = x + offset
# -45°: y = -x + offset
```

### Bounding Box Intersection

For each line, calculate intersections with all four edges:
- Left edge (x = minX)
- Right edge (x = maxX)
- Bottom edge (y = minY)
- Top edge (y = maxY)

Deduplicate intersections when lines pass through corners.

## Triangles Pattern

Located in `src/slicer/infill/patterns/triangles.coffee`.

### Algorithm

Generates equilateral triangles using three line directions:
1. Determine pattern center based on `infillPatternCentering` setting
2. **45° baseline** (same as grid +45°), centered at determined point
3. **105°** (45° + 60°) with slope ≈ -3.732, centered at determined point
4. **-15°** (45° - 60°) with slope ≈ -0.268, centered at determined point

### Angle Calculations

```coffeescript
# 105° line slope
slope105 = -1 / Math.tan(15 * Math.PI / 180)  # tan(105°) = -cot(15°)

# -15° line slope
slope15 = Math.tan(-15 * Math.PI / 180)

# Spacing for each angle (perpendicular distance = lineSpacing)
offsetStep105 = lineSpacing / Math.abs(Math.cos(105 * Math.PI / 180))
offsetStep15 = lineSpacing / Math.abs(Math.cos(-15 * Math.PI / 180))
```

## Hexagons Pattern

Located in `src/slicer/infill/patterns/hexagons.coffee`.

### Algorithm

Creates honeycomb tessellation with flat-top orientation:
1. Calculate hexagon geometry (side length, spacing)
2. Determine pattern center based on `infillPatternCentering` setting
3. Generate hexagon centers in honeycomb grid relative to pattern center
4. Create vertices for each hexagon (6 vertices at 30°, 90°, 150°, 210°, 270°, 330°)
5. Deduplicate shared edges between adjacent hexagons
5. Build connectivity graph for continuous paths
6. Render edges in chains to minimize travel

### Hexagon Geometry

```coffeescript
# For a regular hexagon with side length 's':
hexagonSide = lineSpacing / Math.sqrt(3)
horizontalSpacing = hexagonSide * Math.sqrt(3)  # Between centers
verticalSpacing = 1.5 * hexagonSide             # Between rows

# Row offset for honeycomb pattern
if row % 2 != 0
    centerX += horizontalSpacing / 2
```

### Edge Deduplication

Uses edge keys with consistent point ordering:

```coffeescript
createEdgeKey = (x1, y1, x2, y2) ->
    # Round to 0.01mm precision
    # Order points to ensure (A,B) = (B,A)
    if rx1 < rx2 or (rx1 is rx2 and ry1 < ry2)
        return "#{rx1},#{ry1}-#{rx2},#{ry2}"
    else
        return "#{rx2},#{ry2}-#{rx1},#{ry1}"
```

### Chain Building

Hexagon edges are connected into chains for continuous extrusion:

```coffeescript
# Build connectivity graph
pointToEdges = {}  # Map point key → list of edge indices

# Follow connected edges until dead end
while currentIdx isnt -1 and not drawnEdges[currentIdx]
    # Add edge to chain
    # Find connected undrawn edge at current endpoint
```

## Hole Handling

### Inner Walls for Clipping

Hole inner walls are inset by infill gap to maintain clearance:

```coffeescript
infillGap = nozzleDiameter / 2
holeWallWithGap = paths.createInsetPath(holeWall, infillGap, true)  # isHole=true
```

### Line Clipping

```coffeescript
clippedSegments = clipping.clipLineWithHoles(
    intersections[0],
    intersections[1],
    infillBoundary,
    holeInnerWalls
)
```

## Travel Optimization

### Nearest-Neighbor Selection

Lines are rendered in order of proximity to minimize travel:

```coffeescript
for line, idx in allInfillLines
    distSq0 = (line.start.x - lastEndPoint.x) ** 2 + (line.start.y - lastEndPoint.y) ** 2
    distSq1 = (line.end.x - lastEndPoint.x) ** 2 + (line.end.y - lastEndPoint.y) ** 2
    # Select closest endpoint, optionally flip line direction
```

### Combing During Travel

```coffeescript
combingPath = combing.findCombingPath(
    lastEndPoint or startPoint,
    startPoint,
    holeOuterWalls,
    infillBoundary,
    nozzleDiameter
)
```

## Extrusion Calculation

```coffeescript
distance = Math.sqrt(dx * dx + dy * dy)
if distance > 0.001  # Skip negligible moves
    extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
    slicer.cumulativeE += extrusionDelta
```

## Important Conventions

1. **Pattern centering**: Grid, triangles, and hexagons patterns can center on object boundaries (`infillPatternCentering='object'`, default) or build plate center (`infillPatternCentering='global'`). Object centering uses `(minX + maxX) / 2` and `(minY + maxY) / 2`. Global centering uses origin (0,0) in local coordinates, which maps to build plate center. Note: The concentric pattern inherently follows the boundary shape, so the `infillPatternCentering` setting does not apply to it.
2. **Gap consistency**: Use `nozzleDiameter / 2` gap between infill and walls
3. **Line validation**: Skip segments shorter than 0.001mm
4. **Travel speeds**: Use `getTravelSpeed() * 60` for mm/min conversion
5. **Type annotation**: Add `; TYPE: FILL` comment when verbose mode enabled

## Concentric Pattern

Located in `src/slicer/infill/patterns/concentric.coffee`.

### Algorithm

Creates inward-spiraling contours by repeatedly insetting the boundary:

1. Start with the infill boundary
2. Generate a contour at the current boundary
3. Create an inset path (offset inward by lineSpacing)
4. Repeat until the path becomes too small (< 3 points)
5. Render loops from outermost to innermost

### Loop Generation

```coffeescript
# Generate concentric loops
concentricLoops = []
currentPath = infillBoundary

while currentPath.length >= 3
    concentricLoops.push(currentPath)
    nextPath = paths.createInsetPath(currentPath, lineSpacing, false)
    break if nextPath.length < 3
    currentPath = nextPath
```

### Characteristics

- **Natural for curved shapes**: Follows the natural contour of the part
- **No pattern alignment**: Each layer independently follows the boundary shape
- **Continuous paths**: Each loop is a continuous extrusion path
- **Efficient for cylinders**: Minimal travel for circular cross-sections

### Start Point Optimization

For each loop, find the closest point to the last position:

```coffeescript
if lastEndPoint?
    minDistSq = Infinity
    for i in [0...currentLoop.length]
        point = currentLoop[i]
        distSq = (point.x - lastEndPoint.x) ** 2 + (point.y - lastEndPoint.y) ** 2
        if distSq < minDistSq
            minDistSq = distSq
            startIndex = i
```

This minimizes travel distance between loops.
