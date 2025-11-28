# Support Structures

The support module handles automatic generation of support structures for overhanging geometry.

## Overview

Support structures are temporary scaffolding printed beneath overhanging parts of a model. They prevent drooping and ensure proper printing of features that would otherwise print in mid-air.

## Usage

```javascript
const { Polyslice } = require("@jgphilpott/polyslice");

const slicer = new Polyslice({
    supportEnabled: true,          // Enable support generation
    supportType: "normal",         // Support type (currently only "normal")
    supportPlacement: "buildPlate", // Where supports touch ("buildPlate" only)
    supportThreshold: 45,          // Overhang angle threshold in degrees
    nozzleTemperature: 200,
    bedTemperature: 60
});

const gcode = slicer.slice(mesh);
```

## Configuration Options

### `supportEnabled`

Type: Boolean | Default: `false`

Enable or disable support structure generation.

```javascript
slicer.setSupportEnabled(true);
const isEnabled = slicer.getSupportEnabled(); // true
```

### `supportType`

Type: String | Default: `"normal"` | Options: `"normal"`

The type of support structure to generate.

- **normal** - Standard columnar supports (currently the only implemented type)

Future options may include:
- **tree** - Tree-like supports that branch from a single base
- **organic** - Smooth, curved supports for minimal scarring

```javascript
slicer.setSupportType("normal");
const type = slicer.getSupportType(); // "normal"
```

### `supportPlacement`

Type: String | Default: `"buildPlate"` | Options: `"buildPlate"`

Where support structures can originate from.

- **buildPlate** - Supports only grow from the build plate (currently implemented)

Future options may include:
- **everywhere** - Supports can also grow from the model surface

```javascript
slicer.setSupportPlacement("buildPlate");
const placement = slicer.getSupportPlacement(); // "buildPlate"
```

### `supportThreshold`

Type: Number | Default: `45` | Range: 0-90 degrees

The overhang angle threshold. Faces angled beyond this threshold from vertical will receive support.

- **45°** - Default, suitable for most printers
- **Lower values** (30-40°) - More aggressive support generation
- **Higher values** (50-60°) - Less support, may cause sagging

```javascript
slicer.setSupportThreshold(45);
const threshold = slicer.getSupportThreshold(); // 45
```

## How Support Detection Works

### Overhang Detection

The support module analyzes each triangle face of the mesh:

1. **Calculate face normal** - Determine the direction the face is pointing
2. **Check Z component** - Only downward-facing surfaces (normal.z < 0) need support
3. **Calculate angle from horizontal** - Using `acos(|normal.z|)`
4. **Compare to threshold** - Support is needed if angle < (90° - threshold)

### Angle Reference

```
                 ↑ (normal.z = 1, pointing up)
                 │  No support needed
                 │
    ─────────────┼───────────── Horizontal (normal.z = 0)
                 │              No support needed
                 │
                 ↓ (normal.z = -1, pointing down)
                    Support always needed
```

For a threshold of 45°:
- Horizontal downward face (0° from horizontal) → Needs support
- 45° from horizontal → At threshold, may get support
- Vertical face (90° from horizontal) → No support needed

## Support Generation

### Overhang Regions

Once overhangs are detected, the module creates an array of overhang regions:

```javascript
overhangRegion = {
    x: centerX,      // X coordinate of face center
    y: centerY,      // Y coordinate of face center
    z: centerZ,      // Z coordinate (height of overhang)
    angle: degrees   // Angle from horizontal
}
```

### Support Columns

For each overhang region, a support column is generated from the build plate up to just below the overhang:

1. **Interface gap** - Leave 1.5× layer height gap between support and model
2. **Cross pattern** - Generate a small cross pattern for stability
3. **Thinner lines** - Support uses 80% of normal line width for easier removal
4. **Slower speed** - Support prints at 50% of perimeter speed

## G-code Output

Support structures are marked in G-code comments:

```gcode
; TYPE: SUPPORT
; Support column at (10.50, 25.30, z=15.00)
G0 X8.50 Y25.30 Z5.00 F3000      ; Move to support start
G1 X12.50 Y25.30 Z5.00 E0.15 F900 ; Draw first line
G0 X10.50 Y23.30 Z5.00 F3000      ; Move to second line
G1 X10.50 Y27.30 Z5.00 E0.30 F900 ; Draw second line
```

## API Reference

### Support Module Functions

| Function | Description |
|----------|-------------|
| `generateSupportGCode(...)` | Main support generation function |
| `detectOverhangs(mesh, threshold, minZ)` | Detect overhang regions |
| `generateSupportColumn(...)` | Generate a single support column |

### Slicer Methods

| Method | Description |
|--------|-------------|
| `getSupportEnabled()` | Check if support is enabled |
| `setSupportEnabled(bool)` | Enable/disable support |
| `getSupportType()` | Get support type |
| `setSupportType(type)` | Set support type |
| `getSupportPlacement()` | Get support placement |
| `setSupportPlacement(placement)` | Set support placement |
| `getSupportThreshold()` | Get overhang threshold |
| `setSupportThreshold(degrees)` | Set overhang threshold |

## File Structure

```
src/slicer/support/
├── support.coffee      # Support generation module
└── support.test.coffee # Unit tests
```

## Limitations

Current implementation has some limitations:

1. **Normal type only** - Only columnar supports are implemented
2. **Build plate only** - Supports only originate from build plate
3. **Basic cross pattern** - Simple cross pattern, not optimized paths
4. **No support interfaces** - No dense interface layers
5. **No support roofs** - No smooth top surface on supports

## Best Practices

### When to Use Support

- Overhangs greater than 45-50° from vertical
- Bridges longer than 10-15mm
- Floating features with no connection to build plate

### Minimizing Support

- Orient models to minimize overhangs
- Use support blockers for non-critical overhangs
- Consider splitting models for better orientation

### Removal Tips

- Use thinner support lines for easier removal
- Lower support threshold if having adhesion issues
- Allow prints to cool before removing supports

## Future Enhancements

Planned features for future versions:

1. **Tree supports** - Branching supports for better coverage
2. **Everywhere placement** - Supports from model surfaces
3. **Support interfaces** - Dense layers for smooth model surface
4. **Support blockers** - Exclude regions from support
5. **Optimized pathing** - Better travel moves between supports
