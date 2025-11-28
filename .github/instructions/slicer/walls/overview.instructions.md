---
applyTo: 'src/slicer/walls/**/*.coffee'
---

# Wall Generation Overview

The walls module generates perimeter passes for each layer. Located in `src/slicer/walls/walls.coffee`.

## Purpose

- Create outer and inner walls (perimeters) for each layer
- Define the boundary of the printed part
- Optimize travel paths to avoid crossing holes

## Wall Types

| Type | Description | G-code Annotation |
|------|-------------|-------------------|
| `WALL-OUTER` | First wall, outermost perimeter | `;TYPE: WALL-OUTER` |
| `WALL-INNER` | Subsequent walls, inner perimeters | `;TYPE: WALL-INNER` |

## Wall Count Calculation

Number of walls is determined by shell thickness and nozzle diameter:

```coffeescript
# In slice.coffee
wallCount = Math.max(1, Math.floor((shellWallThickness / nozzleDiameter) + 0.0001))
```

The epsilon (0.0001) handles floating point precision issues.

### Example

- Shell wall thickness: 0.8mm
- Nozzle diameter: 0.4mm
- Wall count: `floor(0.8 / 0.4 + 0.0001) = 2` walls

## Wall Generation Algorithm

### 1. Initial Outer Wall Offset

```coffeescript
# Offset by half nozzle diameter so print matches design dimensions
outerWallOffset = nozzleDiameter / 2
currentPath = paths.createInsetPath(path, outerWallOffset, isHole)
```

For outer boundaries: inset shrinks the boundary inward
For holes: outset enlarges the hole path outward

### 2. Wall Loop Generation

From outer to inner walls:

```coffeescript
for wallIndex in [0...wallCount]
    # Determine wall type
    if wallIndex is 0
        wallType = "WALL-OUTER"
    else
        wallType = "WALL-INNER"
    
    # Generate this wall
    wallsModule.generateWallGCode(...)
    
    # Create inset for next wall
    if wallIndex < wallCount - 1
        currentPath = paths.createInsetPath(currentPath, nozzleDiameter, isHole)
```

### 3. Spacing Validation

Before generating inner walls, check if there's enough space:

```coffeescript
# Check if this path was flagged as having insufficient spacing
if pathsWithInsufficientSpacingForInnerWalls[pathIndex]
    break

# Check if inset would be degenerate
testInsetPath = paths.createInsetPath(currentPath, nozzleDiameter, isHole)
if testInsetPath.length < 3
    break  # No room for more walls
```

## generateWallGCode Function

### Parameters

```coffeescript
generateWallGCode: (slicer, path, z, centerOffsetX, centerOffsetY, wallType, lastEndPoint, holeOuterWalls, boundary) ->
```

| Parameter | Description |
|-----------|-------------|
| `path` | Wall path to generate |
| `z` | Z-coordinate for this layer |
| `centerOffsetX/Y` | Offsets to center on build plate |
| `wallType` | Type annotation for comments |
| `lastEndPoint` | Previous position for combing |
| `holeOuterWalls` | Holes to avoid during travel |
| `boundary` | Outer boundary constraint |

### Returns

The last end point of the wall for next combing calculation:

```coffeescript
return { x: prevPoint.x, y: prevPoint.y, z: z }
```

## Start Point Optimization

For closed paths, find the optimal starting point:

```coffeescript
if lastEndPoint? and holeOuterWalls.length > 0
    startIndex = combing.findOptimalStartPoint(path, lastEndPoint, holeOuterWalls, boundary, nozzleDiameter)
```

This minimizes travel distance and avoids complex combing paths.

## Travel Move Generation

### With Combing

```coffeescript
if lastEndPoint? and holeOuterWalls.length > 0
    combingPath = combing.findCombingPath(lastEndPoint, targetPoint, holeOuterWalls, boundary, nozzleDiameter)
    
    for i in [0...combingPath.length - 1]
        waypoint = combingPath[i + 1]
        offsetX = waypoint.x + centerOffsetX
        offsetY = waypoint.y + centerOffsetY
        slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeedMmMin)
```

### Without Combing

```coffeescript
else
    offsetX = firstPoint.x + centerOffsetX
    offsetY = firstPoint.y + centerOffsetY
    slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, null, travelSpeedMmMin)
```

## Wall Printing Loop

Prints the complete closed path starting from the optimal point:

```coffeescript
prevPoint = path[startIndex]
perimeterSpeedMmMin = slicer.getPerimeterSpeed() * 60

# Print from startIndex+1 to end, then 0 to startIndex (full loop)
for i in [1..path.length]
    currentIndex = (startIndex + i) % path.length
    point = path[currentIndex]
    
    # Calculate distance for extrusion
    distance = Math.sqrt(dx * dx + dy * dy)
    
    # Skip negligible movements
    if distance >= 0.001
        extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter)
        slicer.cumulativeE += extrusionDelta
        
        offsetX = point.x + centerOffsetX
        offsetY = point.y + centerOffsetY
        
        slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY, z, slicer.cumulativeE, perimeterSpeedMmMin)
    
    prevPoint = point
```

## Hole Processing

### Processing Order

Holes are sorted by nearest-neighbor to minimize travel:

```coffeescript
# In slice.coffee
while remainingHoleIndices.length > 0
    # Find nearest hole to last position
    for holeIdx in remainingHoleIndices
        holeCentroid = calculatePathCentroid(holePath)
        distance = calculateDistance(lastPathEndPoint, holeCentroid)
        if distance < nearestDistance
            nearestIndex = holeIdx
```

### Hole Combing Exclusion

When traveling to a hole, exclude that hole from collision detection:

```coffeescript
if isHole and pathToHoleIndex[pathIndex]?
    currentHoleIdx = pathToHoleIndex[pathIndex]
    combingHoleWalls = holeOuterWalls[0...currentHoleIdx].concat(holeOuterWalls[currentHoleIdx+1...])
```

## Spacing Between Paths

The slice module checks if outer walls are too close together:

```coffeescript
for pathIndex1 in [0...paths.length]
    for pathIndex2 in [pathIndex1+1...paths.length]
        minDistance = pathsUtils.calculateMinimumDistanceBetweenPaths(outerWall1, outerWall2)
        
        if minDistance < nozzleDiameter
            pathsWithInsufficientSpacingForInnerWalls[pathIndex1] = true
            pathsWithInsufficientSpacingForInnerWalls[pathIndex2] = true
```

## Important Conventions

1. **Speed units**: Convert mm/s to mm/min for G-code (`* 60`)
2. **Minimum distance**: Skip segments shorter than 0.001mm
3. **Cumulative extrusion**: Use `slicer.cumulativeE` in absolute mode
4. **Type annotations**: Add wall type comments when verbose mode enabled
5. **Path closing**: Wall loops are closed by iterating `[1..path.length]` with modulo
