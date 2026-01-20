# Adhesion Module

The adhesion module generates build plate adhesion structures to improve first-layer stability and prevent warping. Located in `src/slicer/adhesion/`.

## Purpose

- Generate adhesion structures before printing the actual model
- Improve first layer adhesion to the build plate
- Prevent warping and lifting of prints during the printing process
- Provide different adhesion strategies based on model and material requirements

## Adhesion Types

Polyslice supports three types of build plate adhesion:

| Type | Description | Use Case |
|------|-------------|----------|
| **Skirt** | Single or multiple outlines printed around the model at a distance | Test extrusion, prime nozzle, visualize print area |
| **Brim** | Single or multiple outlines attached directly to the model base | Small footprints, prevent corner lifting, improve adhesion |
| **Raft** | Multi-layer platform printed below the model | Large prints, difficult materials, uneven build plates |

## Configuration

### Top-Level Settings

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `adhesionEnabled` | Boolean | `false` | Enable/disable adhesion generation |
| `adhesionType` | String | `'skirt'` | Type of adhesion: `'skirt'`, `'brim'`, or `'raft'` |

### Skirt Settings

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `skirtType` | String | `'circular'` | Skirt shape: `'circular'` or `'shape'` |
| `skirtDistance` | Number | `5` mm | Distance from model to skirt |
| `skirtLineCount` | Number | `3` | Number of skirt loops |

#### Skirt Types

- **Circular**: Simple circular skirt around the model bounding box
- **Shape**: Follows the actual shape of the first layer outline

### Brim Settings

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `brimDistance` | Number | `0` mm | Distance from model edge (0 = attached) |
| `brimLineCount` | Number | `8` | Number of brim loops |

### Raft Settings

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `raftMargin` | Number | `5` mm | Extra margin around model |
| `raftBaseThickness` | Number | `0.3` mm | Base layer thickness |
| `raftInterfaceLayers` | Number | `2` | Number of interface layers |
| `raftInterfaceThickness` | Number | `0.2` mm | Interface layer thickness |
| `raftAirGap` | Number | `0.2` mm | Gap between raft and model |
| `raftLineSpacing` | Number | `2` mm | Line spacing in raft layers |

## Usage Examples

### Basic Skirt

```javascript
const slicer = new Polyslice({
  adhesionEnabled: true,
  adhesionType: 'skirt',
  skirtDistance: 5,        // 5mm from model
  skirtLineCount: 3        // 3 loops
});
```

### Shape-Following Skirt

```javascript
const slicer = new Polyslice({
  adhesionEnabled: true,
  adhesionType: 'skirt',
  skirtType: 'shape',      // Follow model outline
  skirtDistance: 8,
  skirtLineCount: 2
});
```

### Brim for Small Parts

```javascript
const slicer = new Polyslice({
  adhesionEnabled: true,
  adhesionType: 'brim',
  brimDistance: 0,         // Attached to model
  brimLineCount: 10        // Wide brim for stability
});
```

### Raft for Difficult Prints

```javascript
const slicer = new Polyslice({
  adhesionEnabled: true,
  adhesionType: 'raft',
  raftMargin: 8,           // Extra space around model
  raftBaseThickness: 0.4,  // Thick base layer
  raftInterfaceLayers: 3,  // More interface layers
  raftAirGap: 0.15         // Tight gap for better adhesion
});
```

## API Methods

### Getters

```javascript
slicer.getAdhesionEnabled()    // → Boolean
slicer.getAdhesionType()       // → String

// Skirt
slicer.getSkirtType()          // → String
slicer.getSkirtDistance()      // → Number (in configured units)
slicer.getSkirtLineCount()     // → Number

// Brim
slicer.getBrimDistance()       // → Number (in configured units)
slicer.getBrimLineCount()      // → Number

// Raft
slicer.getRaftMargin()         // → Number (in configured units)
slicer.getRaftBaseThickness()  // → Number (in configured units)
// ... (see Raft Settings table for full list)
```

### Setters

All setters support method chaining:

```javascript
slicer
  .setAdhesionEnabled(true)
  .setAdhesionType('brim')
  .setBrimDistance(0)
  .setBrimLineCount(8);
```

## Module Structure

```
src/slicer/adhesion/
├── adhesion.coffee           # Main dispatcher module
├── skirt/
│   ├── skirt.coffee         # Skirt generation
│   └── skirt.test.coffee    # Skirt tests
├── brim/
│   ├── brim.coffee          # Brim generation
│   └── brim.test.coffee     # Brim tests
├── raft/
│   ├── raft.coffee          # Raft generation
│   └── raft.test.coffee     # Raft tests
└── helpers/
    ├── boundary.coffee       # Boundary checking utilities
    └── boundary.test.coffee  # Boundary tests
```

## Skirt Generation

### Circular Skirt

Generates a perfect circle around the model:

1. Calculate model bounding box diagonal
2. Add `skirtDistance` as base radius
3. Generate concentric circles spaced by `nozzleDiameter`
4. Use 64 segments for smooth circles

### Shape Skirt

Follows the actual first layer outline:

1. Extract outer paths from first layer (filter out holes)
2. Create outset paths at `skirtDistance` from each boundary
3. Generate additional loops spaced by `nozzleDiameter`
4. Use polygon offset algorithm for accurate spacing

## Brim Generation

Brims attach directly to the model base:

1. Extract outer paths from first layer
2. Start at `brimDistance + nozzleDiameter/2` from model edge
3. Generate concentric loops outward
4. Use same outset algorithm as shape skirt

**Key Difference from Skirt**: Brim starts much closer to the model (default 0mm + half nozzle width).

## Raft Generation

Rafts are printed as a multi-layer platform:

1. **Base Layer**: Thick, widely-spaced lines for adhesion
2. **Interface Layers**: Denser lines that transition to model
3. **Air Gap**: Small gap between raft and model for easy removal

Raft extends beyond model by `raftMargin` on all sides.

## Build Plate Boundary Checking

The adhesion module includes boundary checking to warn when adhesion structures extend beyond the build plate:

```javascript
// Automatic warning in verbose mode
"; WARNING: Skirt extends beyond build plate boundaries"
"; WARNING: Brim extends beyond build plate boundaries"
"; WARNING: Raft extends beyond build plate boundaries"
```

This helps prevent print failures due to adhesion structures being clipped.

## G-code Output

### Type Annotations

When `verbose` mode is enabled, adhesion G-code includes type comments:

```gcode
; TYPE: SKIRT
G0 X100 Y100 F7200
G1 X105 Y100 E0.05 F1800
...

; TYPE: BRIM
G0 X90 Y90 F7200
G1 X95 Y90 E0.05 F1800
...

; TYPE: RAFT
G0 X80 Y80 F7200
G1 X120 Y80 E0.2 F900
...
```

## Best Practices

### When to Use Skirt

- **Always recommended** as a minimum adhesion type
- Primes the nozzle before printing
- Checks extrusion flow
- Minimal material usage
- Good for most prints

### When to Use Brim

- Small contact area with build plate
- Prints with sharp corners that might lift
- Materials prone to warping (ABS, Nylon)
- Tall, narrow prints
- No heated bed available

### When to Use Raft

- Uneven or damaged build plates
- Prints with very small contact points
- Flexible materials (TPU)
- Large prints with high warping risk
- Testing new materials

## Implementation Details

### Path Generation Algorithm

Both skirt and brim use a custom polygon offset algorithm:

1. Calculate winding order (CCW vs CW) using signed area
2. Generate perpendicular normals for each edge
3. Offset edges outward by desired distance
4. Calculate intersections of adjacent offset lines
5. Handle parallel edges gracefully (use midpoint)

This avoids external dependencies while maintaining accuracy for typical first-layer geometries.

### Travel Optimization

- First loop starts from home position in mesh coordinates
- Subsequent loops minimize travel distance
- No combing needed (single layer, no obstacles yet)

### Extrusion Calculation

Uses standard extrusion formula:
```
volume = line_width × layer_height × distance
filament_length = volume / (π × (filament_diameter/2)²)
adjusted = filament_length × extrusion_multiplier
```

## Related Documentation

- [Slicing Overview](../SLICING.md)
- [G-code Generation](../gcode/GCODE.md)
- [Walls Module](../walls/WALLS.md)
- [API Reference](../../api/API.md)
