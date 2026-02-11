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
| `gyroid` | Wavy TPMS | Triply periodic minimal surface for optimal strength |
| `spiral` | Outward spiraling | Archimedean spiral from center outward |
| `lightning` | Tree-like branching | Fast, minimal material tree structure |

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
gyroidSpacing = baseSpacing * 1.5      # Wavy TPMS structure
spiralSpacing = baseSpacing * 1.0      # Single direction (spiral)
lightningSpacing = baseSpacing * 2.0   # Tree branching structure
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

1. **Pattern centering**: Grid, triangles, hexagons, gyroid, and spiral patterns can center on object boundaries (`infillPatternCentering='object'`, default) or build plate center (`infillPatternCentering='global'`). Object centering uses `(minX + maxX) / 2` and `(minY + maxY) / 2`. Global centering uses origin (0,0) in local coordinates, which maps to build plate center. Note: The concentric pattern inherently follows the boundary shape, so the `infillPatternCentering` setting does not apply to it.
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

## Gyroid Pattern

Located in `src/slicer/infill/patterns/gyroid.coffee`.

### Algorithm

Creates a wavy infill pattern that approximates the gyroid triply periodic minimal surface (TPMS):

1. Determine pattern center based on `infillPatternCentering` setting
2. Calculate Z-phase based on current layer height
3. Generate wavy lines alternating between X and Y directions based on layer
4. Use sine/cosine functions to create the characteristic gyroid wave pattern
5. Clip wavy line segments to infill boundary
6. Render segments in nearest-neighbor order with combing

### Gyroid Equation

```coffeescript
# Gyroid TPMS equation: sin(x)cos(y) + sin(y)cos(z) + sin(z)cos(x) = 0
# For 2D slice at height z, approximate with:
frequency = (2 * Math.PI) / lineSpacing
zPhase = (z / lineSpacing) * 2 * Math.PI
amplitude = lineSpacing * 0.4

# X-direction waves
yOffset = amplitude * Math.sin(frequency * (xPos - centerX) + zPhase)

# Y-direction waves (with phase shift)
xOffset = amplitude * Math.cos(frequency * (yPos - centerY) + zPhase + Math.PI / 2)
```

### Characteristics

- **3D structure**: Wave pattern changes across layers creating interlocking structure
- **Excellent strength**: Comparable to hexagons but with better isotropy
- **Smooth paths**: Wavy lines create gradual transitions
- **Alternating directions**: X-direction on even layers, Y-direction on odd layers

### Wave Generation

For each layer, generate wavy lines:

```coffeescript
# Determine direction based on layer
useXDirection = (Math.floor(z / layerHeight) % 2) is 0

if useXDirection
    # Generate horizontal wavy lines with vertical offset
    for each horizontal position
        yOffset = amplitude * sin(frequency * x + zPhase)
else
    # Generate vertical wavy lines with horizontal offset
    for each vertical position
        xOffset = amplitude * cos(frequency * y + zPhase + π/2)
```

### Line Spacing Formula

```coffeescript
lineSpacing = baseSpacing * 1.5
```

The 1.5 multiplier accounts for the wavy nature and overlap between X and Y direction passes.

## Spiral Pattern

Located in `src/slicer/infill/patterns/spiral.coffee`.

### Algorithm

Creates an Archimedean spiral from center outward:

1. Determine pattern center based on `infillPatternCentering` setting
2. Calculate maximum radius needed to cover entire boundary
3. Generate spiral path using parametric equations
4. Clip spiral segments to infill boundary
5. Exclude hole areas via clipping
6. Render segments in order (continuous spiral, no reordering)

### Spiral Equation

```coffeescript
# Archimedean spiral: r = a * theta
# For lineSpacing between successive turns: a = lineSpacing / (2 * PI)
spiralConstant = lineSpacing / (2 * Math.PI)

# Parametric equations
radius = spiralConstant * theta
x = centerX + radius * Math.cos(theta)
y = centerY + radius * Math.sin(theta)

# Angular step (approximately 10 degrees)
thetaStep = 10 * Math.PI / 180
```

### Characteristics

- **Continuous path**: Starts from center and spirals outward
- **Smooth circular motion**: Follows natural spiral curve
- **Single direction**: Each layer is one continuous spiral
- **Pattern centering**: Supports both object and global centering modes
- **Efficient for circular parts**: Natural fit for cylindrical geometries

### Pattern Generation

For each layer, generate spiral path:

```coffeescript
# Start from center
theta = 0

# Generate points along spiral until reaching boundary
while theta <= maxTheta
    radius = spiralConstant * theta
    x = centerX + radius * Math.cos(theta)
    y = centerY + radius * Math.sin(theta)

    spiralPoints.push({ x, y })
    theta += thetaStep
```

### Line Spacing Formula

```coffeescript
lineSpacing = baseSpacing
```

No multiplier needed since it's a single-direction continuous pattern.

## Lightning Pattern

Located in `src/slicer/infill/patterns/lightning.coffee`.

### Algorithm

Creates a tree-like branching structure from boundary inward:

1. Determine pattern center based on `infillPatternCentering` setting
2. Calculate branch starting points along the boundary perimeter
3. Direct main branches toward center with angle variation
4. Create forking sub-branches at midpoints
5. Clip branches to infill boundary
6. Exclude hole areas via clipping
7. Render branches in nearest-neighbor order with combing

### Branch Generation

```coffeescript
# Branch spacing along perimeter
branchSpacing = lineSpacing * 2.5

# Maximum branch length (80% of smaller dimension)
branchLength = Math.min(width, height) * 0.8

# Angle variation for natural look (±45°)
branchAngleVariation = Math.PI / 4

# Calculate number of branches based on perimeter
numBranches = Math.max(3, Math.floor(totalPerimeter / branchSpacing))
```

### Branching Structure

For each main branch:
1. Start from boundary point
2. Direct toward center with angle variation
3. At midpoint, create two sub-branches
4. Sub-branches fork at 45° from main direction
5. Sub-branch length is 40% of main branch

### Characteristics

- **Fast printing**: Minimal material and continuous paths
- **Tree-like appearance**: Natural organic branching structure
- **Adequate support**: Branches provide support for top surfaces
- **Efficient material use**: Uses less material than traditional patterns
- **Pattern centering**: Supports both object and global centering modes

### Pattern Generation

```coffeescript
# Generate branches from boundary
for each starting point on perimeter
    # Calculate direction toward center
    dirX = centerX - startX
    dirY = centerY - startY

    # Add angle variation
    angleOffset = sin(position) * branchAngleVariation

    # Create main branch
    endX = startX + dirX * branchLength
    endY = startY + dirY * branchLength

    # Create sub-branches at midpoint
    for side in [-1, 1]
        # Equal blend of main and perpendicular for 45° fork angle
        subBranchDir = mainDir + perpDir * side
        subEndX = midX + subBranchDir * subBranchLength
```

### Line Spacing Formula

```coffeescript
lineSpacing = baseSpacing * 2.0
```

The 2.0 multiplier accounts for the branching structure providing distributed support.
