# Skin Generation

The skin module generates solid fill patterns for top and bottom surfaces of a print.

## Overview

Skin layers are the fully-filled surfaces at the top and bottom of a print. Unlike infill (which uses patterns like grid or hexagons), skin is printed as solid diagonal lines to create a smooth, continuous surface.

## Features

- **Solid diagonal fill** - 45° alternating lines for strength
- **Skin wall perimeter** - Single perimeter around skin area
- **Hole avoidance** - Proper handling of holes in skin regions
- **Combing integration** - Optimized travel paths between lines
- **Adaptive skin detection** - See [EXPOSURE_DETECTION.md](EXPOSURE_DETECTION.md)

## Usage

Skin generation is automatic during slicing:

```javascript
const { Polyslice } = require("@jgphilpott/polyslice");

const slicer = new Polyslice({
    skinLayerCount: 3,     // Number of solid top/bottom layers
    infillSpeed: 60,       // Speed for skin infill lines
    perimeterSpeed: 45,    // Speed for skin perimeter
    nozzleDiameter: 0.4,   // Line spacing equals nozzle diameter
    nozzleTemperature: 200,
    bedTemperature: 60
});

const gcode = slicer.slice(mesh);
```

## Configuration Options

### `skinLayerCount`

Type: Number | Default: `3` | Range: 1-10

Number of solid layers at top and bottom surfaces.

- **1-2 layers** - Thin skin, may show infill pattern through
- **3 layers** - Good balance (default)
- **4+ layers** - Very solid, better for functional parts

```javascript
slicer.setSkinLayerCount(4);
const count = slicer.getSkinLayerCount(); // 4
```

## Skin Generation Process

### 1. Skin Wall (Perimeter)

A single perimeter is drawn around the skin boundary first:

```javascript
// Create inset path for skin wall
skinWallPath = createInsetPath(boundaryPath, nozzleDiameter);

// Generate perimeter around skin area
for (point in skinWallPath) {
    // Calculate extrusion and generate G-code
}
```

### 2. Diagonal Infill

Solid diagonal lines fill the skin area:

```javascript
// Generate 45° lines with nozzle-diameter spacing
// Alternates between +45° and -45° per layer
useNegativeSlope = (layerIndex % 2) === 1;

// Generate lines across the skin area
// Clip to boundary and avoid holes
```

### 3. Line Pattern

- **Even layers** - +45° diagonal lines (y = x + offset)
- **Odd layers** - -45° diagonal lines (y = -x + offset)
- **Spacing** - Equal to nozzle diameter (solid fill)

## Function Reference

### `generateSkinGCode(slicer, boundaryPath, z, centerOffsetX, centerOffsetY, layerIndex, lastWallPoint, isHole, generateInfill, holeSkinWalls, holeOuterWalls, coveredAreaSkinWalls, isCoveredArea)`

Main skin generation function.

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `slicer` | Object | Polyslice slicer instance |
| `boundaryPath` | Array | Skin boundary points |
| `z` | Number | Z-coordinate for layer |
| `centerOffsetX` | Number | X offset for centering |
| `centerOffsetY` | Number | Y offset for centering |
| `layerIndex` | Number | Current layer index |
| `lastWallPoint` | Object | Last position for combing |
| `isHole` | Boolean | Is this a hole boundary? |
| `generateInfill` | Boolean | Generate diagonal infill? |
| `holeSkinWalls` | Array | Hole boundaries to exclude |
| `holeOuterWalls` | Array | Holes for travel avoidance |
| `coveredAreaSkinWalls` | Array | Covered areas to exclude |
| `isCoveredArea` | Boolean | Is this a covered area? |

**Returns:** Object - Last endpoint for combing tracking

## G-code Output

Skin sections are marked in the G-code:

```gcode
; TYPE: SKIN
G0 X15.00 Y10.00 Z0.60 F9000  ; Move to skin wall
G1 X45.00 Y10.00 E1.20 F2700  ; Skin wall segment
G1 X45.00 Y40.00 E2.40 F2700  ; Skin wall segment
G1 X15.00 Y40.00 E3.60 F2700  ; Skin wall segment
G1 X15.00 Y10.00 E4.80 F2700  ; Close skin wall

; Moving to skin infill line
G0 X16.00 Y11.00 Z0.60 F9000
G1 X44.00 Y39.00 E5.90 F3600  ; Diagonal infill line
; Moving to skin infill line
G0 X16.40 Y11.40 Z0.60 F9000
G1 X43.60 Y38.60 E6.98 F3600  ; Next diagonal line
...
```

## Hole Handling

The skin module properly handles holes in skin regions:

### Hole Skin Walls

When a hole is detected in a skin layer, a skin wall is generated around it:

```javascript
// Hole detected in skin region
// Generate skin wall around hole perimeter
generateSkinGCode(slicer, holePath, z, ..., isHole=true, generateInfill=false);
```

### Hole Infill Exclusion

Skin infill lines are clipped to exclude hole areas:

```javascript
// Create gap-adjusted hole boundaries
holeSkinWallsWithGap = [];
for (holeWall in holeSkinWalls) {
    holeWithGap = createInsetPath(holeWall, infillGap, true);
    holeSkinWallsWithGap.push(holeWithGap);
}

// Clip infill lines against boundaries
clippedSegments = clipLineWithHoles(lineStart, lineEnd, boundary, holeSkinWallsWithGap);
```

## Covered Area Detection

Skin can detect and handle fully covered regions (cavities):

### What Are Covered Areas?

Areas that have solid geometry both above and below, like:
- Interior of a closed box
- Between layers of a thick section
- Areas that shouldn't get skin treatment

### Exclusion from Skin

Covered areas are excluded from skin infill to avoid over-extrusion:

```javascript
// Covered areas used directly as exclusion zones
coveredAreaSkinWallsWithGap = coveredAreaSkinWalls;  // No additional offset

// Combine with hole walls for clipping
allExclusionWalls = holeSkinWallsWithGap.concat(coveredAreaSkinWallsWithGap);
clippedSegments = clipLineWithHoles(start, end, boundary, allExclusionWalls);
```

## Travel Optimization

### Combing

Travel moves use combing to avoid crossing holes:

```javascript
combingPath = findCombingPath(lastWallPoint, targetPoint, holeOuterWalls, boundaryPath, nozzleDiameter);
```

### Nearest Neighbor

Skin lines are printed in optimal order:

1. Start from current position
2. Find nearest unprinted line endpoint
3. Print that line (possibly reversed)
4. Repeat until all lines printed

## Alternating Pattern

The diagonal pattern alternates per layer for strength:

| Layer | Pattern | Equation |
|-------|---------|----------|
| Even (0, 2, 4...) | +45° | y = x + offset |
| Odd (1, 3, 5...) | -45° | y = -x + offset |

This creates a crosshatch pattern over multiple layers.

## File Structure

```
src/slicer/skin/
├── skin.coffee           # Main skin generation
├── skin.test.coffee      # Skin tests
└── exposure/             # Exposure detection
    ├── exposure.coffee   # Exposure detection module
    ├── exposure.test.coffee
    ├── cavity.coffee     # Cavity detection
    └── cavity.test.coffee
```

## Related Documentation

- [EXPOSURE_DETECTION.md](EXPOSURE_DETECTION.md) - Adaptive skin for exposed surfaces
- [INFILL.md](../infill/INFILL.md) - Interior fill patterns
- [WALLS.md](../walls/WALLS.md) - Wall generation
- [COMBING.md](../geometry/COMBING.md) - Travel path optimization

## Best Practices

### Layer Count

| Use Case | Recommended Layers |
|----------|-------------------|
| Fast prototypes | 2 layers |
| General prints | 3 layers |
| High quality | 4-5 layers |
| Waterproof | 5+ layers |

### Quality Tips

1. **Proper overlap** - Skin should overlap slightly with walls
2. **Consistent flow** - Calibrate extrusion for solid fill
3. **Temperature** - Ensure proper layer adhesion
4. **Speed** - Slower speeds for better surface finish
