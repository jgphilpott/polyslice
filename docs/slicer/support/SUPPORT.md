# Support Structures

The support module handles automatic generation of support structures for overhanging geometry.

## Overview

Support structures are temporary scaffolding printed beneath overhanging parts of a model. They prevent drooping and ensure proper printing of features that would otherwise print in mid-air.

## Usage

```javascript
const { Polyslice } = require("@jgphilpott/polyslice");

const slicer = new Polyslice({
    supportEnabled: true,           // Enable support generation
    supportType: "normal",          // "normal" or "tree"
    supportPlacement: "buildPlate", // Where supports originate
    supportThreshold: 45,           // Overhang angle threshold in degrees
    supportGap: 0.2,                // Air gap between support and object (mm)
    supportDensity: 50,             // Normal support grid density (%)
    // Tree-specific options:
    supportRootsEnabled: true,      // Generate roots at trunk base
    supportRootCount: 4,            // Number of radial roots (1-8)
    supportBranchAngle: 45,         // Branch rise angle (degrees)
    supportTwigAngle: 45,           // Twig rise angle (degrees)
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

Type: String | Default: `"normal"` | Options: `"normal"`, `"tree"`

The type of support structure to generate.

- **normal** - Region-based grid pattern supports. Each grouped overhang region receives a coordinated alternating X/Y grid.
- **tree** - Tree-like branching supports that grow upward from a single trunk, splitting into branches and fine twig tips that contact the overhang surface. Roots spread outward from the trunk base.

```javascript
slicer.setSupportType("normal");
slicer.setSupportType("tree");
const type = slicer.getSupportType(); // "tree"
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

Type: Number | Default: `55` | Range: 0-90 degrees

The overhang angle threshold. Faces angled beyond this threshold from vertical will receive support.

- **55°** - Default, suitable for most printers
- **Lower values** (30-45°) - More aggressive support generation
- **Higher values** (60-75°) - Less support, may cause sagging

```javascript
slicer.setSupportThreshold(55);
const threshold = slicer.getSupportThreshold(); // 55
```

### `supportGap`

Type: Number (mm) | Default: `0.2`

The air gap between the top of the support structure and the underside of the printed object. A larger gap makes supports easier to remove but may reduce surface quality at the overhang.

```javascript
slicer.setSupportGap(0.3);
const gap = slicer.getSupportGap(); // 0.3
```

### `supportDensity`

Type: Number (%) | Default: `50` | Range: 0-100 | Applies to: `"normal"` support type

The fill density of the normal support grid as a percentage. Higher values create denser supports with better overhang quality but use more material and are harder to remove.

- **0** - No support lines generated for this region
- **25** - Sparse grid, minimal material
- **50** - Default, good balance
- **100** - Maximum density

```javascript
slicer.setSupportDensity(30);
const density = slicer.getSupportDensity(); // 30
```

### `supportRootsEnabled`

Type: Boolean | Default: `true` | Applies to: `"tree"` support type

Enable or disable root structures that spread radially outward from the base of the tree trunk. Roots increase the footprint of the support, improving stability especially on smooth or slippery build surfaces.

```javascript
slicer.setSupportRootsEnabled(false);
const rootsEnabled = slicer.getSupportRootsEnabled(); // false
```

### `supportRootCount`

Type: Number | Default: `4` | Range: 1-8 | Applies to: `"tree"` support type

The number of roots spreading radially outward from the trunk base. More roots provide a wider, more stable footprint.

```javascript
slicer.setSupportRootCount(6);
const count = slicer.getSupportRootCount(); // 6
```

### `supportBranchAngle`

Type: Number (degrees) | Default: `45` | Range: 0-90 (exclusive) | Applies to: `"tree"` support type

The angle at which branches rise from the trunk toward the overhang contact area. Steeper angles (closer to 90°) create more vertical branches; shallower angles (closer to 0°) create wider-spreading branches.

```javascript
slicer.setSupportBranchAngle(60);
const angle = slicer.getSupportBranchAngle(); // 60
```

### `supportTwigAngle`

Type: Number (degrees) | Default: `45` | Range: 0-90 (exclusive) | Applies to: `"tree"` support type

The angle at which twig segments rise from branch nodes to contact the overhang surface. Controls how steeply the fine tips approach the model.

```javascript
slicer.setSupportTwigAngle(40);
const angle = slicer.getSupportTwigAngle(); // 40
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

## Normal Support Generation

### Overhang Regions

Once overhangs are detected, adjacent faces sharing edges are grouped into unified regions using a union-find algorithm:

```javascript
overhangRegion = {
    faces: [...],    // All grouped faces
    vertices: [...], // All vertices in group
    minX, maxX,      // Collective bounding box
    minY, maxY,
    minZ, maxZ,
    centerX, centerY
}
```

### Grid Pattern

For each grouped region a coordinated alternating grid is generated:

1. **Interface gap** - Leave 1.5× layer height gap between support and model
2. **Support gap** - Shrink region bounds by `supportGap` on all sides
3. **Line spacing** - Derived from `supportDensity`: `nozzleDiameter / (density / 100)`
4. **Alternating direction** - X-direction lines on even layers, Y-direction on odd layers
5. **Thinner lines** - Support uses 80% of normal line width for easier removal
6. **Slower speed** - Support prints at 50% of perimeter speed

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

## Tree Support Generation

Tree supports grow upward from a single trunk column, splitting into angled branches and fine twig tips that contact the overhang surface. Roots spread outward from the trunk base for stability.

### Structure Layers

```
  [contact tips]   ← twig endpoints, spaced contactSpacing apart
      ╱╲╱╲         ← twig segments (rise at supportTwigAngle)
    [branch nodes] ← one node per cluster of tips
      ╲╱           ← branch segments (rise at supportBranchAngle)
    [trunk]        ← single vertical column
    ╱|╲            ← root segments spreading outward
[build plate]
```

### Node Types and Cross-Section Radii

| Type | Radius Multiplier | Purpose |
|------|-------------------|---------|
| trunk | 3.0× nozzle | Structural stability |
| branch | 1.8× nozzle | Mid-level arms |
| twig | 0.8× nozzle | Fine tips near overhang |
| root | 2.0× nozzle | Wide base footprint |

### Angle Configuration

- **`supportBranchAngle`** controls how steeply branches rise from the trunk: `branchRootZ = nodeZ - dist / tan(branchAngle)`
- **`supportTwigAngle`** controls how steeply twigs rise from branch nodes to contact tips: `nodeZ = min(tip.z - tdist / tan(twigAngle))`
- At 45° (default) both formulas simplify to `dist` (the classic 45° rule)

### Root Configuration

When `supportRootsEnabled` is `true`, `supportRootCount` roots spread radially at the trunk base:

```
angle = i * 2π / rootCount   (i = 0 .. rootCount-1)
rootEndX = trunkX + rootHeight * cos(angle)
rootEndY = trunkY + rootHeight * sin(angle)
```

In `everywhere` mode, roots that point into empty space beyond the model surface are automatically omitted.

### Trunk Placement

For `buildPlate` support, if the computed trunk centroid is blocked by solid geometry, an accessible nearby position is found by searching outward in axis-aligned then diagonal directions.

## G-code Output

Support structures are marked in G-code comments:

```gcode
; TYPE: SUPPORT
G0 X8.50 Y25.30 Z5.00 F3000       ; Move to support start
G1 X12.50 Y25.30 Z5.00 E0.15 F900 ; Draw support line
```

## API Reference

### Support Module Functions

| Function | Description |
|----------|-------------|
| `generateSupportGCode(...)` | Main support generation dispatcher |
| `detectOverhangs(mesh, threshold, minZ)` | Detect overhang regions |
| `groupAdjacentFaces(faces)` | Group adjacent overhang faces |
| `generateRegionSupportPattern(...)` | Generate normal grid pattern |
| `buildLayerSolidRegions(...)` | Build cache of solid regions |
| `canGenerateSupportAt(...)` | Collision detection check |
| `isPointInsideSolidGeometry(...)` | Even-odd winding rule check |
| `buildTreeStructure(...)` | Pre-compute tree segments |
| `generateTreePattern(...)` | Generate tree support G-code |

### Slicer Methods

| Method | Description |
|--------|-------------|
| `getSupportEnabled()` / `setSupportEnabled(bool)` | Enable/disable support |
| `getSupportType()` / `setSupportType(type)` | Support type (`"normal"` or `"tree"`) |
| `getSupportPlacement()` / `setSupportPlacement(placement)` | Origin placement |
| `getSupportThreshold()` / `setSupportThreshold(degrees)` | Overhang threshold |
| `getSupportGap()` / `setSupportGap(mm)` | Air gap between support and object |
| `getSupportDensity()` / `setSupportDensity(percent)` | Normal grid density (0–100) |
| `getSupportRootsEnabled()` / `setSupportRootsEnabled(bool)` | Tree root structures toggle |
| `getSupportRootCount()` / `setSupportRootCount(count)` | Number of roots (1–8) |
| `getSupportBranchAngle()` / `setSupportBranchAngle(degrees)` | Tree branch rise angle |
| `getSupportTwigAngle()` / `setSupportTwigAngle(degrees)` | Tree twig rise angle |

## File Structure

```
src/slicer/support/
├── support.coffee          # Main dispatcher + shared utilities
├── support.test.coffee     # Main support tests
├── normal/
│   ├── normal.coffee       # Normal support implementation
│   └── normal.test.coffee  # Normal support tests
└── tree/
    ├── tree.coffee         # Tree support implementation
    └── tree.test.coffee    # Tree support tests
```

## Best Practices

### When to Use Support

- Overhangs greater than 45-55° from vertical
- Bridges longer than 10-15mm
- Floating features with no connection to build plate

### Choosing a Support Type

- **normal** - Faster to slice, predictable grid structure, good for simple overhangs
- **tree** - Less material, easier removal, better for organic shapes and tall overhangs

### Minimizing Support

- Orient models to minimize overhangs
- Adjust `supportThreshold` to match your printer's bridging capability
- Increase `supportGap` for easier removal (at the cost of surface finish)
- Reduce `supportDensity` for less material usage

### Removal Tips

- Use a larger `supportGap` (0.3–0.4mm) for materials prone to bonding (ABS, PETG)
- Allow prints to cool before removing supports
- Tree supports generally remove more cleanly than normal supports

## Future Enhancements

Planned features for future versions:

1. **Support interfaces** - Dense layers for smooth model surface
2. **Support blockers** - Exclude specific regions from support
3. **Organic supports** - Smooth, curved supports for minimal scarring
4. **Optimized pathing** - Better travel moves between support regions
