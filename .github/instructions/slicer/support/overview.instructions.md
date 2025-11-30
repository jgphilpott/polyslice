---
applyTo: 'src/slicer/support/**/*.coffee'
---

# Support Generation Overview

The support module generates support structures for overhanging regions. Located in `src/slicer/support/`.

## Purpose

- Detect overhanging faces that need support
- Generate support columns from build plate to overhang regions
- Provide configurable support threshold angle

## Support Types

Currently supported:

| Type | Description |
|------|-------------|
| `'normal'` | Standard support structures |

Planned for future:

| Type | Description |
|------|-------------|
| `'tree'` | Tree-like branching supports |
| `'organic'` | Smooth organic supports |

## Support Placement

| Placement | Description |
|-----------|-------------|
| `'buildPlate'` | Supports only from build plate |
| `'everywhere'` | Supports from any surface (planned) |

## Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `supportEnabled` | `false` | Enable/disable support generation |
| `supportType` | `'normal'` | Type of support structure |
| `supportPlacement` | `'buildPlate'` | Where supports can originate |
| `supportThreshold` | `45` | Angle in degrees requiring support |

## Overhang Detection Algorithm

### Face Normal Analysis

The algorithm examines each face's normal vector to determine if it's overhanging:

```coffeescript
detectOverhangs: (mesh, thresholdAngle, buildPlateZ = 0) ->
    # For each face:
    # 1. Calculate face normal from vertices
    # 2. Check if normal points downward (normal.z < 0)
    # 3. Calculate angle from horizontal
    # 4. Compare against support threshold
```

### Normal Calculation

```coffeescript
# Get three vertices of face
v0 = new THREE.Vector3(positions.getX(i0), ...)
v1 = new THREE.Vector3(positions.getX(i1), ...)
v2 = new THREE.Vector3(positions.getX(i2), ...)

# Apply mesh transformation
v0.applyMatrix4(mesh.matrixWorld)
v1.applyMatrix4(mesh.matrixWorld)
v2.applyMatrix4(mesh.matrixWorld)

# Calculate face normal
edge1 = new THREE.Vector3().subVectors(v1, v0)
edge2 = new THREE.Vector3().subVectors(v2, v0)
normal = new THREE.Vector3().crossVectors(edge1, edge2).normalize()
```

### Overhang Criteria

A face is considered overhanging if:

1. **Normal points downward**: `normal.z < 0`
2. **Angle exceeds threshold**: `angleFromHorizontal < (90 - thresholdAngle)`
3. **Above build plate**: `centerZ > buildPlateZ + 0.5`

```coffeescript
angleFromHorizontal = Math.acos(Math.abs(normal.z))
angleFromHorizontalDeg = angleFromHorizontal * 180 / Math.PI
supportAngleLimit = 90 - thresholdAngle

if angleFromHorizontalDeg < supportAngleLimit
    # This face needs support
```

### Overhang Region Data

```coffeescript
overhangRegions.push({
    x: centerX      # Face center X
    y: centerY      # Face center Y
    z: centerZ      # Face center Z (height where support ends)
    angle: angleFromHorizontalDeg
})
```

## Support Column Generation

### Column Structure

Each support column is a simple cross pattern:

```coffeescript
generateSupportColumn: (slicer, region, currentZ, centerOffsetX, centerOffsetY, nozzleDiameter) ->
    patchSize = supportLineWidth * 2

    # Horizontal line (X direction)
    move to (offsetX - patchSize, offsetY)
    extrude to (offsetX + patchSize, offsetY)

    # Vertical line (Y direction)
    move to (offsetX, offsetY - patchSize)
    extrude to (offsetX, offsetY + patchSize)
```

### Support Parameters

```coffeescript
supportLineWidth = nozzleDiameter * 0.8  # Thinner than normal
supportSpacing = nozzleDiameter * 2      # Space between support lines
supportSpeed = slicer.getPerimeterSpeed() * 60 * 0.5  # Half speed
```

### Interface Gap

Supports stop short of the actual overhang to allow easy removal:

```coffeescript
interfaceGap = layerHeight * 1.5

# Only generate support if region is above current layer + gap
if region.z > (z + interfaceGap)
    @generateSupportColumn(...)
```

## G-code Generation Flow

1. **Check if enabled**: `return unless slicer.getSupportEnabled()`
2. **Validate settings**: Check `supportType` and `supportPlacement`
3. **Detect overhangs**: Run once, cache in `slicer._overhangRegions`
4. **Generate per layer**: For each overhang region above current Z + gap
5. **Add type annotation**: `"; TYPE: SUPPORT"` when verbose

## Caching

Overhang detection runs once and results are cached:

```coffeescript
if not slicer._overhangRegions?
    slicer._overhangRegions = @detectOverhangs(mesh, supportThreshold, minZ)

overhangRegions = slicer._overhangRegions
```

## Usage

```coffeescript
slicer = new Polyslice({
    supportEnabled: true
    supportType: 'normal'
    supportPlacement: 'buildPlate'
    supportThreshold: 45  # degrees
})

gcode = slicer.slice(mesh)
```

## Important Conventions

1. **Threshold interpretation**: 45° means faces more than 45° from vertical need support
2. **Interface gap**: 1.5× layer height gap for easy removal
3. **Line width**: 0.8× nozzle diameter for easier breakaway
4. **Speed**: 50% of perimeter speed for better adhesion
5. **Cross pattern**: Simple X pattern for each support point
