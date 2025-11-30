---
applyTo: 'src/slicer/skin/**/*.coffee'
---

# Skin Generation Overview

The skin module generates solid infill for top and bottom surfaces. Located in `src/slicer/skin/`.

## Purpose

- Create solid surfaces on exposed top/bottom layers
- Generate adaptive skin for overhangs and cavities (when exposure detection enabled)
- Produce clean exterior surfaces by covering infill patterns

## Skin vs Infill

| Aspect | Skin | Infill |
|--------|------|--------|
| Density | 100% solid | Configurable (0-100%) |
| Location | Top/bottom surfaces | Interior regions |
| Pattern | Diagonal lines (45°) | Grid/triangles/hexagons |
| Purpose | Exterior quality | Structural support |

## Skin Components

### Skin Wall

A perimeter pass around the skin boundary:

```coffeescript
skinWallInset = nozzleDiameter  # Full nozzle width offset
skinWallPath = paths.createInsetPath(boundaryPath, skinWallInset, offsetDirection)
```

### Skin Infill

Diagonal lines at 45° angle, alternating direction per layer:

```coffeescript
# Odd layers: -45° (y = -x + offset)
# Even layers: +45° (y = x + offset)
useNegativeSlope = (layerIndex % 2) is 1
```

## Skin Layer Detection

### Absolute Top/Bottom Layers

```coffeescript
skinLayerCount = Math.floor((shellSkinThickness / layerHeight) + 0.0001)

# Bottom layers
if layerIndex < skinLayerCount
    needsSkin = true

# Top layers
if layerIndex >= totalLayers - skinLayerCount
    needsSkin = true
```

### Adaptive Skin (Exposure Detection)

When `exposureDetection` is enabled, middle layers can also have skin for:
- Overhangs (exposed from below)
- Cavities (exposed from above)

## Exposure Detection Module

Located in `src/slicer/skin/exposure/exposure.coffee`.

### Algorithm

1. Check layer N ± `skinLayerCount` for covering geometry
2. Calculate which areas are exposed (not covered)
3. Generate skin only for exposed regions

```coffeescript
calculateExposedAreasForLayer: (currentPath, layerIndex, skinLayerCount, totalLayers, allLayers, resolution) ->
    # Check layer ahead (above)
    checkIdxAbove = layerIndex + skinLayerCount

    # Check layer behind (below)
    checkIdxBelow = layerIndex - skinLayerCount

    return { exposedAreas, coveringRegionsAbove, coveringRegionsBelow }
```

### Hole Exposure Detection

For holes on middle layers:

```coffeescript
shouldGenerateHoleSkinWalls: (path, layerIndex, skinLayerCount, totalLayers, allLayers) ->
    holeExposedAbove = @isHoleExposedAbove(...)
    holeExposedBelow = @isHoleExposedBelow(...)
    return holeExposedAbove or holeExposedBelow
```

A hole is exposed if:
- Near top of model (within skinLayerCount)
- Near bottom of model (within skinLayerCount)
- No corresponding hole exists in the check layer

## Cavity Detection

Located in `src/slicer/skin/exposure/cavity.coffee`.

### Fully Covered Regions

Areas that have geometry both above AND below don't need skin infill:

```coffeescript
identifyFullyCoveredRegions: (currentPath, coveringRegionsAbove, coveringRegionsBelow) ->
    # Find intersection of coverage from both directions
    # These areas need only skin wall, not skin infill
```

### Mixed Layer Strategy

On layers with partial exposure:

1. **Generate infill first** (entire layer)
2. **Generate skin second** (exposed areas only)

This allows skin to cover infill pattern on exposed surfaces.

## Skin Generation Parameters

### Offset Directions

```coffeescript
# For covered areas (isCoveredArea=true): inset inward
# For real holes (isHole=true): outset outward (shrink hole)
# For normal skin boundaries: inset inward
offsetDirection = if isCoveredArea then false else isHole
```

### Gaps and Spacing

```coffeescript
infillGap = nozzleDiameter / 2  # Gap between skin wall and infill
infillInset = skinWallInset + infillGap  # Total: 1.5 * nozzleDiameter from boundary
lineSpacing = nozzleDiameter  # 100% density for solid fill
```

## Diagonal Infill Generation

### Line Equations

```coffeescript
if useNegativeSlope
    # y = -x + offset
    offset = minY + minX - diagonalSpan
    maxOffset = maxY + maxX
else
    # y = x + offset
    offset = minY - maxX - diagonalSpan
    maxOffset = maxY - minX

# Spacing for 45° lines
offsetStep = lineSpacing * Math.sqrt(2)
```

### Bounding Box Intersection

Calculate intersections with all four edges, then clip to actual boundary:

```coffeescript
clippedSegments = clipping.clipLineWithHoles(
    intersections[0],
    intersections[1],
    infillBoundary,
    allExclusionWalls  # Includes hole walls and covered area boundaries
)
```

## Travel Optimization

### Nearest-Neighbor Rendering

```coffeescript
while allSkinLines.length > 0
    # Find line with endpoint closest to current position
    # Can flip line direction for efficiency
    # Use combing for travel moves
```

### Combing for Skin

```coffeescript
combingPath = combing.findCombingPath(
    lastEndPoint or startPoint,
    startPoint,
    holeOuterWalls,
    infillBoundary,
    nozzleDiameter
)
```

## Hole Skin Walls

Holes on skin layers need additional skin walls:

```coffeescript
if isHole and generateSkinWalls and currentPath.length >= 3
    # Calculate skin wall path (inset from innermost wall)
    skinWallPath = paths.createInsetPath(currentPath, nozzleDiameter, isHole)
    holeSkinWalls.push(skinWallPath)
```

## Return Value

The `generateSkinGCode` function returns the last endpoint for tracking:

```coffeescript
if lastEndPoint?
    return lastEndPoint
else if skinWallPath? and skinWallPath.length > 0
    return { x: skinWallPath[0].x, y: skinWallPath[0].y, z: z }
else
    return null
```

## Important Conventions

1. **Type annotation**: Add `; TYPE: SKIN` comment when verbose mode enabled
2. **Layer alternation**: Flip diagonal direction each layer for strength
3. **Hole handling**: Exclude hole skin walls with infill gap offset
4. **Covered areas**: Use boundaries as-is (no additional offset) for exclusion
5. **Start point optimization**: Rotate path to start closest to last position
