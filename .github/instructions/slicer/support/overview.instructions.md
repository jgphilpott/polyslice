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
| `'buildPlate'` | Supports only from build plate | Blocks supports when ANY solid geometry exists in vertical path from build plate to overhang |
| `'everywhere'` | Supports from any surface | Allows supports to start from the top of any solid surface below overhang; stops at solid surfaces |

### Collision Detection

The support generation system uses layer-by-layer collision detection with hole/cavity awareness to prevent supports from going through solid parts:

#### BuildPlate Mode
For each overhang region, checks ALL layers below for solid geometry at that XY position. If solid material is found at any layer (even if not continuous), support generation is blocked. This ensures supports only reach areas with a clear vertical path from the build plate.

**Key behavior**: Supports can pass through open cavities/holes that are accessible from the build plate, but are blocked if any solid geometry exists below the overhang position.

#### Everywhere Mode
Finds the highest solid surface below each overhang region. Checks recent layers (up to 3 layers back) to determine if solid geometry continues. Only generates support ABOVE the top of solid surfaces, creating gaps where solid geometry exists.

**Key behavior**: Supports stop at solid surfaces and resume above them, preventing supports from going through solid geometry while allowing multi-level support structures.

### Hole/Cavity Handling

The collision detection properly identifies holes and cavities using an even-odd winding rule:

1. **Nesting Level Calculation**: For each path, counts how many other paths contain it
   - Even nesting levels (0, 2, 4...) = solid structures
   - Odd nesting levels (1, 3, 5...) = holes/cavities

2. **Even-Odd Winding Rule**: For any point, counts how many path boundaries contain it
   - Odd containment count (1, 3, 5...) = inside solid geometry
   - Even containment count (0, 2, 4...) = outside or inside hole (empty space)

3. **Empty Space Detection**: Points inside holes/cavities are correctly identified as empty space where supports can be generated (if accessible from build plate in buildPlate mode)

This ensures physically feasible support structures that respect both solid geometry and internal cavities.

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

During slicing, solid regions for each layer are cached with hole/cavity information:

```coffeescript
buildLayerSolidRegions: (allLayers, layerHeight, minZ) ->
    layerSolidRegions = []
    
    for layerIndex in [0...allLayers.length]
        layerSegments = allLayers[layerIndex]
        layerPaths = pathsUtils.connectSegmentsToPaths(layerSegments)
        
        # Calculate nesting levels to identify holes
        pathIsHole = []
        for i in [0...layerPaths.length]
            nestingLevel = 0
            for j in [0...layerPaths.length]
                continue if i is j
                if primitives.pointInPolygon(layerPaths[i][0], layerPaths[j])
                    nestingLevel++
            
            # Odd nesting = hole, even = structure
            pathIsHole.push(nestingLevel % 2 is 1)
        
        layerSolidRegions.push({
            z: layerZ
            paths: layerPaths
            pathIsHole: pathIsHole
            layerIndex: layerIndex
        })
    
    return layerSolidRegions
```

### Solid Geometry Detection with Even-Odd Winding Rule

```coffeescript
isPointInsideSolidGeometry: (point, paths, pathIsHole) ->
    containmentCount = 0
    
    # Count how many paths contain this point
    for i in [0...paths.length]
        if primitives.pointInPolygon(point, paths[i])
            containmentCount++
    
    # Even-odd winding rule:
    # Odd count (1, 3, 5...) = inside solid geometry
    # Even count (0, 2, 4...) = outside or inside hole (empty space)
    return containmentCount > 0 and containmentCount % 2 is 1
```

### Collision Check - BuildPlate Mode

```coffeescript
if supportPlacement is 'buildPlate'
    # Check ALL layers below for blocking geometry
    for layerData in layerSolidRegions
        if layerData.layerIndex < currentLayerIndex
            if @isPointInsideSolidGeometry(point, layerData.paths, layerData.pathIsHole)
                return false  # Blocked by solid geometry
    
    # Path clear - no solid geometry found at this XY position
    # Cavities/holes are correctly identified as empty space
    return true
```

### Collision Check - Everywhere Mode

```coffeescript
if supportPlacement is 'everywhere'
    # Find highest solid surface and check if it continues below current layer
    highestSolidZ = minZ
    hasBlockingGeometry = false
    
    for layerData in layerSolidRegions
        if layerData.layerIndex < currentLayerIndex
            if @isPointInsideSolidGeometry(point, layerData.paths, layerData.pathIsHole)
                hasBlockingGeometry = true
                highestSolidZ = max(highestSolidZ, layerData.z)
    
    if not hasBlockingGeometry
        return true  # Clear path from build plate
    
    # Check recent layers (up to 3) to see if solid surface continues
    layersToCheck = min(3, currentLayerIndex)
    for i in [1..layersToCheck]
        checkLayerIndex = currentLayerIndex - i
        layerData = layerSolidRegions[checkLayerIndex]
        if @isPointInsideSolidGeometry(point, layerData.paths, layerData.pathIsHole)
            return false  # Solid surface hasn't ended yet
    
    # Solid geometry has ended - generate support above it
    minimumSupportZ = highestSolidZ + layerHeight
    return currentZ >= minimumSupportZ
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
6. **Collision detection**: Uses even-odd winding rule with point-in-polygon test (0.001mm epsilon)
7. **Hole detection**: Nesting levels calculated to distinguish solid structures from cavities
8. **Placement modes**: 
   - `'buildPlate'`: Blocks support if ANY solid geometry at this XY in layers below (allows through cavities)
   - `'everywhere'`: Stops support at solid surfaces, resumes above them
9. **Cache management**: Both overhang regions and layer solid regions (with hole info) cleared between slices

## Example Results

Testing with sideways arch geometry (from `examples/scripts/slice-supports.js`):

| Mode | Support Type Lines | Behavior |
|------|-------------------|----------|
| `'buildPlate'` | 25 | Only where clear vertical path to build plate exists |
| `'everywhere'` | 3,401 | Stops at solid arch bottom (Z=0.2-7.4mm), resumes above (Z=7.6mm+) |

Testing with upright dome geometry (hemispherical cavity on top):

| Mode | Support Type Lines | Behavior |
|------|-------------------|----------|
| `'buildPlate'` | 16,644 | Fills entire cavity (empty space accessible from build plate) |
| `'everywhere'` | 16,644 | Same as buildPlate (no blocking geometry) |

Testing with sideways dome geometry (hemisphere opens to side):

| Mode | Support Type Lines | Behavior |
|------|-------------------|----------|
| `'buildPlate'` | 16,368 | Generates through cavity opening (accessible from build plate) |
| `'everywhere'` | 19,061 | Allows supports from solid surfaces as well |

These results demonstrate:
- **Collision detection** working correctly (arch everywhere mode skips solid layers)
- **Hole detection** working correctly (dome upright fills cavity, not blocked)
- **Geometric dependency** (sideways dome cavity opens to side, creating accessibility)

Testing with sideways arch geometry (from `examples/scripts/slice-supports.js`):

| Mode | Support Type Lines | Description |
|------|-------------------|-------------|
| `'buildPlate'` | 25 | Only supports where path is clear to build plate |
| `'everywhere'` | 4,025 | Supports can build on solid surfaces to reach overhangs |

This dramatic difference demonstrates proper collision detection and placement mode behavior.
