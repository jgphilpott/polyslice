# Smart Wipe Nozzle Implementation

## Overview

The smart wipe nozzle feature intelligently moves the nozzle away from the print surface at the end of a print, preventing marks or filament threads on the finished part.

## Purpose

Traditional wipe nozzle implementations simply move the nozzle a fixed distance (e.g., X+5, Y+5) in relative coordinates. However, this can cause issues when:

1. The print ends on a large flat top surface - the wipe move may land on another part of the print
2. The print has overhanging edges near the final position - the wipe may scrape across the print
3. The nozzle oozes during the wipe move, leaving a mark on the surface

The smart wipe feature solves these problems by:
- Analyzing the mesh bounding box and last print position
- Finding the shortest path away from the mesh boundaries
- Moving beyond the mesh boundary before raising Z
- Including retraction during the wipe move to prevent oozing

## Implementation Details

### Module Location

- **Main logic**: `src/slicer/utils/wipe.coffee`
- **Integration**: `src/slicer/gcode/coders.coffee` in `codePostPrint()` method
- **Configuration**: Added to `src/polyslice.coffee` constructor options

### Data Flow

1. **During Slicing** (`src/slicer/slice.coffee`):
   - Mesh bounding box is calculated and stored in `slicer.meshBounds`
   - Center offsets are stored in `slicer.centerOffsetX` and `slicer.centerOffsetY`
   - Last print position is tracked in `slicer.lastLayerEndPoint`

2. **During Post-Print** (`src/slicer/gcode/coders.coffee`):
   - Checks if smart wipe is enabled and data is available
   - Calls `wipeUtils.calculateSmartWipeDirection()` to compute wipe vector
   - Generates G-code with retraction during wipe move
   - Adjusts subsequent Z-raise to avoid double retraction

### Algorithm (`calculateSmartWipeDirection`)

```coffeescript
# Converts last position to build plate coordinates
currentX = lastPosition.x + centerOffsetX
currentY = lastPosition.y + centerOffsetY

# Calculates distances to each mesh boundary
distToLeft = currentX - minX
distToRight = maxX - currentX
distToBottom = currentY - minY
distToTop = maxY - currentY

# Finds closest boundary
minDist = Math.min(distToLeft, distToRight, distToBottom, distToTop)

# Moves in that direction plus 3mm backoff
distanceToMove = minDist + backoffDistance
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `wipeNozzle` | Boolean | `true` | Enable/disable wipe feature |
| `smartWipeNozzle` | Boolean | `true` | Use smart wipe vs simple X+5, Y+5 |

### G-code Output Comparison

**With Smart Wipe:**
```gcode
G91                    ; Relative positioning
G1 X0 Y4.2 E-1 F3000  ; Smart wipe with retraction
G1 Z10 F2400          ; Raise Z (no additional retraction)
G90                    ; Absolute positioning
```

**With Simple Wipe:**
```gcode
G91                    ; Relative positioning
G0 X5 Y5 F3000        ; Simple wipe (no retraction)
G1 Z10 E-2 F2400      ; Retract and raise Z
G90                    ; Absolute positioning
```

## Key Differences from Simple Wipe

1. **Direction**: Smart wipe moves perpendicular to the nearest boundary, simple wipe always moves diagonally (X+5, Y+5)
2. **Distance**: Smart wipe calculates exact distance to clear the mesh, simple wipe uses fixed 5mm
3. **Retraction**: Smart wipe retracts during the wipe move, simple wipe retracts during Z-raise
4. **Backoff**: Smart wipe adds 3mm backoff beyond the boundary for safety

## Fallback Behavior

Smart wipe falls back to simple wipe when:
- `smartWipeNozzle` is set to `false`
- `lastLayerEndPoint` is not available (no mesh was sliced)
- `meshBounds` is not available
- `centerOffsetX` or `centerOffsetY` is not available

This ensures the feature is robust and always produces valid G-code.

## Testing

### Unit Tests

- 9 tests in `src/slicer/utils/wipe.test.coffee` test the smart wipe calculation logic
- 5 tests in `src/slicer/gcode/coders.test.coffee` test the integration with post-print sequence

### Integration Tests

- Manual test script `test-smart-wipe.js` validates end-to-end behavior
- Tests verify:
  - Smart wipe direction is correct for different positions
  - Retraction is included in wipe move
  - Fallback to simple wipe works when needed
  - Mesh bounds and last position are properly tracked

## Future Enhancements

Potential improvements for the smart wipe feature:

1. **Collision Detection**: Check if the calculated wipe path crosses any holes in the top layer
2. **Multi-Directional**: Try multiple angles if the straight path is blocked
3. **User-Configurable**: Allow users to set custom backoff distance and wipe speed
4. **Visual Preview**: Show the planned wipe path in a visualization tool
5. **Adaptive Speed**: Slow down during wipe for better retraction effectiveness

## Related Files

- `src/slicer/utils/wipe.coffee` - Smart wipe calculation utilities
- `src/slicer/utils/wipe.test.coffee` - Unit tests for wipe utilities
- `src/slicer/gcode/coders.coffee` - Post-print G-code generation
- `src/slicer/gcode/coders.test.coffee` - Post-print tests
- `src/slicer/slice.coffee` - Mesh bounds tracking during slicing
- `src/polyslice.coffee` - Configuration options
- `src/utils/accessors.coffee` - Getter/setter methods
- `docs/api/API.md` - API documentation
- `docs/slicer/gcode/GCODE.md` - G-code generation documentation
