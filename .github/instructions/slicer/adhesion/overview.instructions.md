# Adhesion Module Overview

The adhesion module generates build plate adhesion structures for first-layer stability. Located in `src/slicer/adhesion/`.

## Purpose

- Generate adhesion structures (skirt, brim, raft) before printing the model
- Improve first layer adhesion to prevent warping and print failures
- Prime the nozzle and test extrusion flow
- Provide visual boundaries of the print area

## Module Structure

| File | Purpose |
|------|---------|
| `adhesion.coffee` | Main dispatcher module |
| `skirt/skirt.coffee` | Skirt generation (circular and shape) |
| `brim/brim.coffee` | Brim generation |
| `raft/raft.coffee` | Raft generation (base, interface, air gap) |
| `helpers/boundary.coffee` | Build plate boundary checking |

## Configuration Structure

### Top-Level Settings

Only two settings remain at the top level:

```coffeescript
@adhesionEnabled = options.adhesionEnabled ?= false # Boolean.
@adhesionType = options.adhesionType ?= "skirt" # String ['skirt', 'brim', 'raft'].
```

### Skirt Settings Section

All skirt-specific settings grouped together following raft pattern:

```coffeescript
# Skirt adhesion settings.
@skirtType = options.skirtType ?= "circular" # String ['circular', 'shape'].
@skirtDistance = conversions.lengthToInternal(options.skirtDistance ?= 5, this.lengthUnit) # Number (mm internal).
@skirtLineCount = options.skirtLineCount ?= 3 # Number.
```

### Brim Settings Section

Brim-specific settings in their own section:

```coffeescript
# Brim adhesion settings.
@brimDistance = conversions.lengthToInternal(options.brimDistance ?= 0, this.lengthUnit) # Number (mm internal).
@brimLineCount = options.brimLineCount ?= 8 # Number.
```

### Raft Settings Section

Raft settings already properly sectioned:

```coffeescript
# Raft adhesion settings.
@raftMargin = conversions.lengthToInternal(options.raftMargin ?= 5, this.lengthUnit) # Number (mm internal).
@raftBaseThickness = conversions.lengthToInternal(options.raftBaseThickness ?= 0.3, this.lengthUnit) # Number (mm internal).
@raftInterfaceLayers = options.raftInterfaceLayers ?= 2 # Number.
@raftInterfaceThickness = conversions.lengthToInternal(options.raftInterfaceThickness ?= 0.2, this.lengthUnit) # Number (mm internal).
@raftAirGap = conversions.lengthToInternal(options.raftAirGap ?= 0.2, this.lengthUnit) # Number (mm internal).
@raftLineSpacing = conversions.lengthToInternal(options.raftLineSpacing ?= 2, this.lengthUnit) # Number (mm internal).
```

## Naming Conventions

**Pattern established by raft settings**: `[type][PropertyName]`

Examples:
- `skirtType`, `skirtDistance`, `skirtLineCount`
- `brimDistance`, `brimLineCount`
- `raftMargin`, `raftBaseThickness`, `raftInterfaceLayers`

This makes it immediately clear which adhesion type each setting applies to.

## Accessor Methods

### Skirt Accessors

```coffeescript
# Getters
getSkirtType: (slicer) ->
    return slicer.skirtType

getSkirtDistance: (slicer) ->
    return conversions.lengthFromInternal(slicer.skirtDistance, slicer.lengthUnit)

getSkirtLineCount: (slicer) ->
    return slicer.skirtLineCount

# Setters
setSkirtType: (slicer, type = "circular") ->
    type = type.toLowerCase().trim()
    if ["circular", "shape"].includes type
        slicer.skirtType = String type
    return slicer

setSkirtDistance: (slicer, distance = 5) ->
    if typeof distance is "number" and distance >= 0
        slicer.skirtDistance = conversions.lengthToInternal(distance, slicer.lengthUnit)
    return slicer

setSkirtLineCount: (slicer, count = 3) ->
    if typeof count is "number" and count >= 0
        slicer.skirtLineCount = Number count
    return slicer
```

### Brim Accessors

```coffeescript
# Getters
getBrimDistance: (slicer) ->
    return conversions.lengthFromInternal(slicer.brimDistance, slicer.lengthUnit)

getBrimLineCount: (slicer) ->
    return slicer.brimLineCount

# Setters
setBrimDistance: (slicer, distance = 0) ->
    if typeof distance is "number" and distance >= 0
        slicer.brimDistance = conversions.lengthToInternal(distance, slicer.lengthUnit)
    return slicer

setBrimLineCount: (slicer, count = 8) ->
    if typeof count is "number" and count >= 0
        slicer.brimLineCount = Number count
    return slicer
```

## Adhesion Type Comparison

| Feature | Skirt | Brim | Raft |
|---------|-------|------|------|
| **Contact with model** | No (distance away) | Yes (attached) | Below model (air gap) |
| **Distance setting** | `skirtDistance` (5mm) | `brimDistance` (0mm) | `raftMargin` (5mm) |
| **Line count** | `skirtLineCount` (3) | `brimLineCount` (8) | Multiple layers |
| **Primary purpose** | Prime nozzle | Prevent warping | Level/stabilize |
| **Material usage** | Minimal | Low | High |
| **Removal difficulty** | N/A (not attached) | Easy | Moderate |

## Skirt Module

Located in `src/slicer/adhesion/skirt/skirt.coffee`.

### Circular Skirt

Generates perfect circles around model:

```coffeescript
baseRadius = Math.sqrt((modelWidth / 2) ** 2 + (modelHeight / 2) ** 2) + skirtDistance

for loopIndex in [0...skirtLineCount]
    radius = baseRadius + (loopIndex * nozzleDiameter)
    # Generate 64-segment circle at this radius
```

### Shape Skirt

Follows actual first layer outline:

1. Extract outer paths (filter holes using point-in-polygon)
2. Create outset paths using polygon offset algorithm
3. Generate multiple loops at `nozzleDiameter` spacing
4. Start at `skirtDistance` from model edge

## Brim Module

Located in `src/slicer/adhesion/brim/brim.coffee`.

### Key Difference from Skirt

Brim attaches to the model by starting very close to the edge:

```coffeescript
# First loop starts at brimDistance + nozzleDiameter/2
offsetDistance = brimDistance + (nozzleDiameter / 2) + (loopIndex * nozzleDiameter)
```

Default `brimDistance = 0` means first loop is at `nozzleDiameter/2` from edge (half nozzle width).

### Brim Distance Setting

The `brimDistance` setting allows fine-tuning the gap between model and brim:
- `0` (default): Attached directly, first line at `nozzleDiameter/2` offset
- `> 0`: Creates small gap for easier removal while still providing support
- Typically kept at 0 for maximum adhesion benefit

## Raft Module

Located in `src/slicer/adhesion/raft/raft.coffee`.

Raft settings already follow proper naming convention and don't need changes.

## Polygon Offset Algorithm

Both skirt and brim use a custom offset algorithm to avoid external dependencies:

```coffeescript
createOutsetPath = (path, outsetDistance) ->
    # 1. Calculate winding order (CCW vs CW)
    signedArea = 0
    for i in [0...n]
        nextIdx = if i is n - 1 then 0 else i + 1
        signedArea += path[i].x * path[nextIdx].y - path[nextIdx].x * path[i].y
    isCCW = signedArea > 0

    # 2. Generate perpendicular normals for each edge
    for i in [0...n]
        edgeX = p2.x - p1.x
        edgeY = p2.y - p1.y
        # Normalize and get perpendicular
        normalX = if isCCW then edgeY else -edgeY
        normalY = if isCCW then -edgeX else edgeX

    # 3. Offset edges and find intersections
    intersection = primitives.lineIntersection(...)
```

This algorithm works well for the simple, near-convex shapes typical of first layers.

## Boundary Checking

The `helpers/boundary.coffee` module checks if adhesion extends beyond build plate:

```coffeescript
checkBuildPlateBoundaries: (slicer, bounds, centerOffsetX, centerOffsetY) ->
    buildPlateMinX = -buildPlateWidth / 2
    buildPlateMaxX = buildPlateWidth / 2
    # Compare bounds to build plate dimensions
    # Return warning info if exceeded
```

Warnings are added to G-code in verbose mode:

```gcode
; WARNING: Skirt extends beyond build plate boundaries
```

## G-code Generation Flow

1. Main `adhesion.coffee` dispatcher checks `adhesionEnabled`
2. Dispatches to appropriate sub-module based on `adhesionType`
3. Sub-module retrieves its specific settings via getters
4. Generates G-code with travel moves and extrusion
5. Adds type annotation comment if verbose

## Important Conventions

1. **Setting naming**: `[type][PropertyName]` pattern (e.g., `skirtDistance`)
2. **Unit conversion**: All distance settings use length conversion (mm internal)
3. **Validation**: Setters validate type and range (>= 0 for distances/counts)
4. **Method chaining**: All setters return `slicer` for chaining
5. **Defaults**: Sensible defaults for each adhesion type
   - Skirt: 3 loops at 5mm distance
   - Brim: 8 loops at 0mm distance (attached)
   - Raft: 5mm margin, 2 interface layers

## Testing Conventions

Tests should cover:
1. Configuration getter/setter validation
2. Type validation (circular/shape for skirt)
3. Distance and count validation (>= 0)
4. Method chaining
5. G-code generation for each type
6. Boundary checking warnings
7. Integration with slicing pipeline

## Future Enhancements

Potential additions for adhesion module:

1. **Smart brim width**: Auto-calculate `brimLineCount` based on model size
2. **Hybrid adhesion**: Combine skirt + brim for extra stability
3. **Variable brim width**: Wider brim on corners, narrower on edges
4. **Material-specific presets**: Auto-configure for PLA/ABS/PETG
5. **Raft top layer pattern**: Different infill patterns for raft top surface
