# Infill Patterns

This directory contains implementations of various infill patterns for 3D printing.

## Available Patterns

### Grid Pattern (`grid.coffee`)

A crosshatch pattern that generates both +45° and -45° diagonal lines on every layer.

**Characteristics:**
- Simple and predictable
- Good strength in all directions
- Uses more material than cubic
- Same pattern on every layer

**Use cases:**
- General purpose printing
- Models requiring uniform strength
- When material usage is not a concern

### Cubic Pattern (`cubic.coffee`)

A 3D cubic lattice structure that varies diagonal lines across layers to form a cubic pattern.

**Characteristics:**
- More efficient than grid (uses ~30-50% less material)
- Creates 3D interlocking structure
- Better strength-to-weight ratio
- Pattern repeats every 3 layers

**Layer Cycle:**
- Layer 0 (mod 3 = 0): Both +45° and -45° lines (crosshatch)
- Layer 1 (mod 3 = 1): Only +45° diagonal lines
- Layer 2 (mod 3 = 2): Only -45° diagonal lines

**Use cases:**
- Reducing print time and material usage
- Large prints where internal structure matters
- Models where weight reduction is important
- Prints requiring good strength in vertical direction

## Pattern Selection

The infill pattern can be configured when creating a Polyslice instance:

```javascript
const slicer = new Polyslice({
    infillPattern: 'cubic',  // or 'grid'
    infillDensity: 20        // 0-100%
});
```

Or changed after instantiation:

```javascript
slicer.setInfillPattern('cubic');
```

## Density Calculation

Both patterns use a base spacing calculation:

```
baseSpacing = nozzleDiameter / (density / 100.0)
```

Then apply a pattern-specific multiplier:
- **Grid**: `2.0x` (both directions on every layer)
- **Cubic**: `2.4x` (optimized for 3-layer cycle)

## Adding New Patterns

To add a new infill pattern:

1. Create a new file in this directory (e.g., `triangles.coffee`)
2. Implement the pattern generator following this signature:
   ```coffeescript
   module.exports =
       generatePatternInfill: (slicer, infillBoundary, z, centerOffsetX, centerOffsetY, lineSpacing, lastWallPoint = null, layerIndex = 0) ->
   ```
3. Update `infill.coffee` to import and delegate to your pattern
4. Add the pattern name to the valid list in `src/utils/accessors.coffee`
5. Create comprehensive tests in a `.test.coffee` file
6. Update this README with pattern characteristics

## Implementation Notes

### Travel Optimization

Both grid and cubic patterns implement travel optimization by:
1. Collecting all line segments for the layer
2. Finding the line closest to the last endpoint
3. Optionally flipping lines to minimize travel distance
4. Rendering lines in optimal order

### Line Intersection

Patterns calculate intersection points between diagonal lines and the infill boundary bounding box. This ensures lines stay within the printable area and don't extend beyond walls.

### Extrusion Calculation

All patterns use the shared `slicer.calculateExtrusion()` method to determine extrusion amounts based on line distance and nozzle diameter.

## Future Patterns

Planned patterns (not yet implemented):
- **Lines**: Simple parallel lines
- **Triangles**: Triangular lattice structure
- **Gyroid**: Mathematical surface pattern
- **Honeycomb**: Hexagonal pattern for maximum strength

## Testing

Each pattern has comprehensive tests covering:
- Basic generation with various densities
- Layer-to-layer pattern consistency
- Speed settings and performance
- Boundary handling and containment
- Comparison with other patterns
