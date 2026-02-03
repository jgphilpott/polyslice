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

Type: String | Default: `"buildPlate"` | Options: `"buildPlate"`, `"everywhere"`

Where support structures can originate from and how they interact with solid geometry.

- **buildPlate** - Supports only from build plate. Blocks support generation if ANY solid geometry exists in the vertical path from build plate to overhang. Allows supports through open cavities/holes that are accessible from the build plate.

- **everywhere** - Supports can start from any solid surface below the overhang. Supports stop at solid surfaces and resume above them, creating gaps where solid geometry exists. Useful for complex geometries with internal structures.

```javascript
slicer.setSupportPlacement("buildPlate");  // Default
const placement = slicer.getSupportPlacement(); // "buildPlate"

slicer.setSupportPlacement("everywhere");  // Allow supports from any surface
```

#### Mode Comparison

| Aspect | buildPlate | everywhere |
|--------|-----------|------------|
| Origin | Build plate only | Build plate OR solid surfaces |
| Blocking | Any solid below blocks | Stops at solid, resumes above |
| Cavities | Supports through open cavities | Supports through open cavities |
| Use case | Simple overhangs | Complex multi-level overhangs |

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

For each overhang region, a support column is generated from the build plate (or solid surface in 'everywhere' mode) up to just below the overhang:

1. **Interface gap** - Leave 1.5× layer height gap between support and model
2. **Cross pattern** - Generate a small cross pattern for stability
3. **Thinner lines** - Support uses 80% of normal line width for easier removal
4. **Slower speed** - Support prints at 50% of perimeter speed

### Collision Detection

The support system uses intelligent collision detection to prevent supports from going through solid geometry:

#### Layer Caching
- Solid regions for each layer are cached with hole/cavity information
- Nesting levels calculated to distinguish solid structures from empty cavities
- Cache built once per mesh, cleared between slices

#### Even-Odd Winding Rule
For any point, counts how many path boundaries contain it:
- **Odd count (1, 3, 5...)** = inside solid geometry (support blocked)
- **Even count (0, 2, 4...)** = outside or inside hole/cavity (support allowed if accessible)

#### BuildPlate Mode Behavior
- Checks ALL layers below overhang for solid geometry at the XY position
- Blocks support if solid found at ANY layer (even if not continuous)
- Allows supports through open cavities accessible from build plate

#### Everywhere Mode Behavior
- Finds highest solid surface below overhang
- Checks recent layers (up to 3) to see if solid continues
- Only generates support ABOVE solid surfaces, creating gaps where solid exists
- Allows multi-level support structures

### Example Scenarios

**Sideways Arch** (cylindrical tunnel):
- buildPlate: 25 supports (only near tunnel edges)
- everywhere: 3,401 supports (stops at solid bottom Z=0.2-7.4mm, resumes above)

**Upright Dome** (hemisphere cavity on top):
- buildPlate: 16,644 supports (fills cavity from build plate)
- everywhere: 16,644 supports (same, no blocking geometry)

**Sideways Dome** (hemisphere opens to side):
- buildPlate: 16,368 supports (through side opening)
- everywhere: 19,061 supports (includes supports on solid surfaces)

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
| `buildLayerSolidRegions(...)` | Build cache of solid regions with hole info |
| `canGenerateSupportAt(...)` | Check if support can be generated (collision detection) |
| `isPointInsideSolidGeometry(...)` | Check if point is in solid using even-odd winding rule |

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

Current implementation limitations:

1. **Normal type only** - Only columnar supports are implemented (tree and organic are planned)
2. **Basic cross pattern** - Simple cross pattern, not optimized for minimal material
3. **Fixed parameters** - Support line width and speed are calculated from base parameters

Future enhancements planned:
- Tree-like supports for reduced material usage
- Organic supports for minimal scarring
- Optimized support patterns
- Customizable support parameters
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
