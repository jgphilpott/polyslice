# Wall Generation

The walls module generates perimeter (wall) G-code for each layer of a sliced model.

## Overview

Walls are the outer and inner perimeters of each layer. They define the visible surface of the printed object and provide structural integrity. The wall module generates G-code for:

- **Outer walls** - The outermost perimeter (visible surface)
- **Inner walls** - Additional perimeters inside the outer wall

## Usage

Wall generation is automatic during slicing. The wall thickness is configurable:

```javascript
const { Polyslice } = require("@jgphilpott/polyslice");

const slicer = new Polyslice({
    shellWallThickness: 0.8, // Wall thickness in mm (converted to wall count internally)
    perimeterSpeed: 45,      // Wall print speed in mm/s
    travelSpeed: 150,        // Travel speed between walls
    nozzleDiameter: 0.4,     // Affects wall spacing
    nozzleTemperature: 200,
    bedTemperature: 60
});

const gcode = slicer.slice(mesh);
```

## Configuration Options

### `shellWallThickness`

Type: Number | Default: `0.8` | Unit: mm

The total thickness of all wall perimeters. The actual number of walls is calculated internally based on nozzle diameter.

- **0.4mm** (1 wall) - Single shell, fastest but weakest
- **0.8mm** (2 walls) - Good balance of strength and speed
- **1.2mm** (3 walls) - Strong walls for functional parts
- **1.6mm+** (4+ walls) - Very strong, slower to print

```javascript
slicer.setShellWallThickness(1.2); // ~3 walls with 0.4mm nozzle
const thickness = slicer.getShellWallThickness(); // 1.2
```

### `perimeterSpeed`

Type: Number | Default: `45` | Unit: mm/s

Speed for printing wall perimeters. Slower speeds improve surface quality.

```javascript
slicer.setPerimeterSpeed(40); // Slower for better quality
slicer.setPerimeterSpeed(60); // Faster, may sacrifice quality
```

### `travelSpeed`

Type: Number | Default: `150` | Unit: mm/s

Speed for non-printing travel moves between walls.

## Wall Generation Process

### 1. Outer Wall Generation

The outer wall is generated first, directly on the layer boundary:

```javascript
// Outer wall follows the sliced boundary path
generateWallGCode(slicer, outerPath, z, offsetX, offsetY, "WALL-OUTER");
```

### 2. Inner Wall Generation

Inner walls are inset from the outer wall by the nozzle diameter:

```javascript
// Each inner wall is inset by nozzleDiameter
for (i = 1; i < wallCount; i++) {
    insetDistance = i * nozzleDiameter;
    innerPath = createInsetPath(outerPath, insetDistance);
    generateWallGCode(slicer, innerPath, z, offsetX, offsetY, "WALL-INNER");
}
```

### 3. Travel Optimization

The module uses combing to optimize travel moves between walls:

- **Combing** - Routes travel moves around holes
- **Optimal start points** - Chooses starting points to minimize travel
- **Path continuity** - Maintains consistent direction around perimeters

## Function Reference

### `generateWallGCode(slicer, path, z, centerOffsetX, centerOffsetY, wallType, lastEndPoint, holeOuterWalls, boundary)`

Generates G-code for a single wall perimeter.

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `slicer` | Object | Polyslice slicer instance |
| `path` | Array | Wall path points `[{x, y}, ...]` |
| `z` | Number | Z-coordinate for this layer |
| `centerOffsetX` | Number | X offset to center print on bed |
| `centerOffsetY` | Number | Y offset to center print on bed |
| `wallType` | String | "WALL-OUTER" or "WALL-INNER" |
| `lastEndPoint` | Object | Last position for combing |
| `holeOuterWalls` | Array | Hole paths for travel avoidance |
| `boundary` | Array | Outer boundary for combing |

**Returns:** Object - The last end point `{x, y, z}` for next wall's combing

## G-code Output

Wall sections are clearly marked in the G-code output:

```gcode
; TYPE: WALL-OUTER
G0 X10.00 Y10.00 Z0.20 F9000  ; Move to wall start
G1 X50.00 Y10.00 E1.20 F2700  ; Print wall segment
G1 X50.00 Y50.00 E2.40 F2700  ; Print wall segment
G1 X10.00 Y50.00 E3.60 F2700  ; Print wall segment
G1 X10.00 Y10.00 E4.80 F2700  ; Close wall loop

; TYPE: WALL-INNER
G0 X10.40 Y10.40 Z0.20 F9000  ; Move to inner wall
G1 X49.60 Y10.40 E5.98 F2700  ; Print inner wall segment
...
```

## Combing Integration

The walls module integrates with the combing system for optimized travel:

### Optimal Start Point Selection

When moving to a new wall, the module finds the best starting point:

```javascript
startIndex = findOptimalStartPoint(path, lastEndPoint, holeOuterWalls, boundary, nozzleDiameter);
```

This considers:
- Distance from current position
- Avoiding holes during approach
- Minimizing travel moves

### Travel Path Combing

Travel moves route around holes to prevent stringing:

```javascript
combingPath = findCombingPath(lastEndPoint, targetPoint, holeOuterWalls, boundary, nozzleDiameter);
```

See [COMBING.md](../geometry/COMBING.md) for more details.

## Wall Types in G-code

| Type | Description |
|------|-------------|
| `WALL-OUTER` | Outermost visible perimeter |
| `WALL-INNER` | Interior wall perimeters |

## Extrusion Calculation

Wall extrusion is calculated based on:

```javascript
extrusionDelta = slicer.calculateExtrusion(distance, nozzleDiameter);
slicer.cumulativeE += extrusionDelta;
```

The calculation considers:
- **Line width** - Nozzle diameter
- **Layer height** - From slicer settings
- **Filament diameter** - Typically 1.75mm
- **Extrusion multiplier** - Fine-tune material flow

## File Structure

```
src/slicer/walls/
├── walls.coffee      # Wall generation module
└── walls.test.coffee # Unit tests
```

## Dependencies

- **coders** - G-code generation functions
- **combing** - Travel path optimization

## Best Practices

### Wall Thickness Recommendations

| Use Case | Recommended Thickness | ~Walls (0.4mm nozzle) |
|----------|----------------------|----------------------|
| Decorative items | 0.8mm | 2 walls |
| General purpose | 0.8-1.2mm | 2-3 walls |
| Functional parts | 1.2-1.6mm | 3-4 walls |
| High strength | 1.6mm+ | 4+ walls |

### Speed Optimization

- **Outer wall slower** - Improve surface quality
- **Inner walls faster** - They're not visible
- Use speed overrides for specific needs

### Quality Tips

1. **Clean perimeters** - Use proper retraction settings
2. **No gaps** - Ensure wall count provides overlap with infill
3. **Consistent extrusion** - Calibrate flow rate
4. **Layer adhesion** - Proper temperature for material

## Related Documentation

- [SLICING.md](../SLICING.md) - Main slicing documentation
- [COMBING.md](../geometry/COMBING.md) - Travel path optimization
- [GCODE.md](../gcode/GCODE.md) - G-code generation reference
