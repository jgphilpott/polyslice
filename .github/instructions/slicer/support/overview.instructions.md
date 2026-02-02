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

Support placement determines where supports can originate and how they interact with solid geometry.

| Placement | Description | Collision Detection |
|-----------|-------------|---------------------|
| `'buildPlate'` | Supports only from build plate | Blocks supports when solid geometry is between build plate and overhang |
| `'everywhere'` | Supports from any surface | Allows supports to start from any solid surface below overhang |

### Collision Detection

The support generation system uses layer-by-layer collision detection to prevent supports from going through solid parts:

- **buildPlate mode**: For each overhang region, checks all layers below for solid geometry. If any layer contains solid material at that XY position, support generation is blocked.
- **everywhere mode**: Finds the highest solid surface below each overhang region and generates support from that surface upward.

This ensures physically feasible support structures that respect the model's solid geometry.

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

## Collision Detection Implementation

### Layer Solid Regions Cache

During slicing, solid regions for each layer are cached for collision detection:

```coffeescript
buildLayerSolidRegions: (allLayers, layerHeight, minZ) ->
    layerSolidRegions = []
    
    for layerIndex in [0...allLayers.length]
        layerSegments = allLayers[layerIndex]
        layerPaths = pathsUtils.connectSegmentsToPaths(layerSegments)
        
        layerSolidRegions.push({
            z: layerZ
            paths: layerPaths
            layerIndex: layerIndex
        })
    
    return layerSolidRegions
```

### Collision Check

For each support position, check if solid geometry blocks the path:

```coffeescript
canGenerateSupportAt: (region, currentZ, currentLayerIndex, layerSolidRegions, supportPlacement) ->
    point = { x: region.x, y: region.y }
    
    if supportPlacement is 'buildPlate'
        # Check all layers below for blocking geometry
        for layerData in layerSolidRegions
            if layerData.layerIndex < currentLayerIndex
                for path in layerData.paths
                    if @isPointInsideSolidRegion(point, path)
                        return false  # Blocked by solid geometry
        return true  # Path clear to build plate
    
    else if supportPlacement is 'everywhere'
        # Find highest solid surface below overhang
        highestSolidZ = minZ
        for layerData in layerSolidRegions
            if layerData.layerIndex < currentLayerIndex
                for path in layerData.paths
                    if @isPointInsideSolidRegion(point, path)
                        highestSolidZ = max(highestSolidZ, layerData.z)
        
        return currentZ >= highestSolidZ + layerHeight
```

## G-code Generation Flow

1. **Check if enabled**: `return unless slicer.getSupportEnabled()`
2. **Validate settings**: Check `supportType` and `supportPlacement`
3. **Build layer cache**: Cache solid regions for all layers (first layer only)
4. **Detect overhangs**: Run once, cache in `slicer._overhangRegions`
5. **Generate per layer**: For each overhang region above current Z + gap
   - Check collision with `canGenerateSupportAt()`
   - Only generate if path is valid for placement mode
6. **Add type annotation**: `"; TYPE: SUPPORT"` when verbose

## Caching

Two caches are maintained during slicing:

```coffeescript
# Overhang regions (detected once per mesh)
if not slicer._overhangRegions?
    slicer._overhangRegions = @detectOverhangs(mesh, supportThreshold, minZ)

# Layer solid regions (built once per mesh)
if not slicer._layerSolidRegions?
    slicer._layerSolidRegions = @buildLayerSolidRegions(allLayers, layerHeight, minZ)
```

Both caches are cleared at the start of each slice operation.

## Usage

```coffeescript
slicer = new Polyslice({
    supportEnabled: true
    supportType: 'normal'
    supportPlacement: 'buildPlate'  # or 'everywhere'
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
6. **Collision detection**: Uses point-in-polygon test with 0.001mm epsilon tolerance
7. **Placement modes**: 
   - `'buildPlate'`: Supports blocked by any solid geometry below overhang
   - `'everywhere'`: Supports can start from any solid surface below overhang
8. **Cache management**: Both overhang regions and layer solid regions caches are cleared between slice operations

## Example Results

Testing with sideways arch geometry (from `examples/scripts/slice-supports.js`):

| Mode | Support Type Lines | Description |
|------|-------------------|-------------|
| `'buildPlate'` | 25 | Only supports where path is clear to build plate |
| `'everywhere'` | 4,025 | Supports can build on solid surfaces to reach overhangs |

This dramatic difference demonstrates proper collision detection and placement mode behavior.
