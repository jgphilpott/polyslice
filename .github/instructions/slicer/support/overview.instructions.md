---
applyTo: 'src/slicer/support/**/*.coffee'
---

# Support Generation Overview

The support module generates support structures for overhanging regions. Located in `src/slicer/support/`.

## Purpose

- Detect overhanging faces that need support
- Group adjacent faces that share edges into unified regions
- Generate coordinated support grid patterns covering entire grouped areas
- Provide configurable support threshold angle
- Support both buildPlate and everywhere placement modes

## Algorithm Overview

The support generation uses a **face-based grouping approach** with coordinated grid patterns:

1. **Detect Overhangs**: Analyze mesh faces to find downward-facing surfaces, storing complete face data (vertices)
2. **Group Adjacent Faces**: Pool faces that share edges using union-find algorithm
3. **Calculate Collective Area**: Determine bounding box from all vertices in grouped faces
4. **Generate Grids**: Create coordinated grid patterns covering entire grouped area
5. **Alternate Directions**: Use X-direction on even layers, Y-direction on odd layers

This approach ensures support structures account for the **entire area** of overhang faces, not just individual face centers.

## Module Architecture

The support generation system is organized into sub-modules for maintainability and extensibility:

### Main Module (`support.coffee`)

The main module acts as a dispatcher and contains shared utilities:

- **`generateSupport()`**: Entry point that dispatches to appropriate sub-module based on `supportType`
- **`buildLayerSolidRegions()`**: Shared utility that caches solid geometry for collision detection
- Manages `_overhangFaces` and `_supportRegions` caches
- Clears all support caches between slices

### Normal Support Sub-Module (`normal/normal.coffee`)

Implements grid-based support generation:

- **`detectOverhangs()`**: Analyzes mesh faces to find overhanging surfaces
- **`groupAdjacentFaces()`**: Pools adjacent faces using union-find algorithm
- **`generateRegionSupportPattern()`**: Creates coordinated grid patterns
- **`canGenerateSupportAt()`**: Collision detection for support placement
- **`isPointInsideSolidGeometry()`**: Even-odd winding rule for solid detection
- Tests: `normal.test.coffee` (5 tests)

### Tree Support Sub-Module (`tree/tree.coffee`)

Template for future tree support implementation:

- **`generateTreeSupport()`**: Placeholder method (NOT YET IMPLEMENTED)
- Will implement: branch generation, path optimization, converging structures
- Tests: `tree.test.coffee` (2 basic tests)

### File Structure

```
src/slicer/support/
├── support.coffee          # Main dispatcher + shared utilities
├── support.test.coffee     # Main support tests (19 tests)
├── normal/
│   ├── normal.coffee       # Normal support implementation
│   └── normal.test.coffee  # Normal support tests (5 tests)
└── tree/
    ├── tree.coffee         # Tree support template
    └── tree.test.coffee    # Tree support tests (2 tests)
```

## Support Types

Currently supported:

| Type | Description |
|------|-------------|
| `'normal'` | Region-based grid pattern supports |

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
4. **Detect overhangs**: Run once, cache in `slicer._overhangFaces`
5. **Group adjacent faces**: Pool faces that share edges, cache in `slicer._supportRegions`
6. **Generate per layer**: For each support region above current Z + gap
   - Generate grid pattern covering entire region area
   - Alternate X/Y direction based on layer parity
   - Check collision for each grid point
   - Render continuous lines
7. **Add type annotation**: `"; TYPE: SUPPORT"` when verbose

## Caching

Three caches are maintained during slicing:

```coffeescript
# Overhang faces (detected once per mesh)
if not slicer._overhangFaces?
    slicer._overhangFaces = @detectOverhangs(mesh, supportThreshold, minZ, supportPlacement)

# Support regions (grouped once per mesh)
if not slicer._supportRegions?
    slicer._supportRegions = @groupAdjacentFaces(slicer._overhangFaces)

# Layer solid regions (built once per mesh)
if not slicer._layerSolidRegions?
    slicer._layerSolidRegions = @buildLayerSolidRegions(allLayers, layerHeight, minZ)
```

All caches are cleared at the start of each slice operation.

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

## Face Grouping Algorithm

The `groupAdjacentFaces()` function pools overhang faces that share edges:

### Edge Matching

```coffeescript
edgesMatch = (v1a, v1b, v2a, v2b, tolerance = 0.001) ->
    # Check if edge (v1a, v1b) matches edge (v2a, v2b)
    # in either direction (forward or reverse)
    # Returns true if vertices match within tolerance
```

### Adjacency Detection

```coffeescript
facesAreAdjacent = (face1, face2) ->
    # Check all 3 edges of face1 against all 3 edges of face2
    # Returns true if any edge pair matches
    for i in [0...3]
        for j in [0...3]
            if edgesMatch(face1.vertices[i], face1.vertices[(i+1)%3],
                         face2.vertices[j], face2.vertices[(j+1)%3])
                return true
```

### Union-Find Grouping

```coffeescript
# Initialize each face in its own group
parent = {}
for i in [0...faces.length]
    parent[i] = i

# Find all adjacent pairs and union them
for i in [0...faces.length]
    for j in [i+1...faces.length]
        if facesAreAdjacent(faces[i], faces[j])
            union(i, j)

# Group faces by root parent
groups = {}
for i in [0...faces.length]
    root = find(i)
    groups[root].push(faces[i])
```

### Collective Area Calculation

```coffeescript
# For each group, calculate bounding box from ALL vertices
for root, faces of groups
    allVertices = []
    for face in faces
        for vertex in face.vertices
            allVertices.push(vertex)
            minX = Math.min(minX, vertex.x)
            maxX = Math.max(maxX, vertex.x)
            # ... accumulate bounds

    supportRegions.push({
        faces: faces                    # All faces in group
        vertices: allVertices           # All unique vertices
        minX, maxX, minY, maxY          # Collective bounding box
        minZ, maxZ                      # Z range
        centerX: (minX + maxX) / 2
        centerY: (minY + maxY) / 2
    })
```

## Grid Pattern Generation

The `generateRegionSupportPattern()` function creates coordinated support grids:

### Grid Parameters

```coffeescript
supportSpacing = nozzleDiameter * 2.0    # Grid line spacing
supportGap = nozzleDiameter / 2          # Gap between support and object
supportLineWidth = nozzleDiameter * 0.8  # Thinner for easier removal
```

### Pattern Generation

1. **Shrink bounds** with gap to prevent touching object:
   ```coffeescript
   supportGap = nozzleDiameter / 2
   minX = region.minX + supportGap  # Shrink inward
   maxX = region.maxX - supportGap  # Shrink inward
   # Similar for Y
   ```

2. **Determine direction** based on layer:
   ```coffeescript
   useXDirection = layerIndex % 2 is 0
   # Even layers: horizontal lines (X-direction)
   # Odd layers: vertical lines (Y-direction)
   ```

3. **Generate grid points**:
   - For X-direction: iterate Y positions, then X positions per row
   - For Y-direction: iterate X positions, then Y positions per column
   - Check collision at each point using `canGenerateSupportAt()`

4. **Group into continuous lines**:
   - X-direction: group by Y coordinate → horizontal lines
   - Y-direction: group by X coordinate → vertical lines

5. **Generate G-code**:
   - Add `; TYPE: SUPPORT` comment on every layer for visualizer
   - Travel to start of each line
   - Extrude through all points in line
   - Proper extrusion calculation based on distance

### Example Grid Pattern

Layer 0 (even - X-direction):
```
---o---o---o---   Y=maxY (shrunk by gap)
---o---o---o---   Y=...
---o---o---o---   Y=minY (shrunk by gap)
```

Layer 1 (odd - Y-direction):
```
| | | | | | |
o o o o o o o
```

### Gap Between Support and Object

The support gap ensures supports don't touch the printed part:

```coffeescript
supportGap = nozzleDiameter / 2  # e.g., 0.2mm with 0.4mm nozzle
```

- Follows same convention as infill gap
- Creates clearance for easy support removal
- Prevents adhesion between support and object
- Support region is SMALLER than overhang region by gap amount on all sides

## Comparison: Old vs New Algorithm

### Old Algorithm (Point-Based Clustering)

```coffeescript
# For each overhang face:
detectOverhangs:
    # Store only face center point
    overhangPoints.push({ x: centerX, y: centerY, z: centerZ })

# Cluster nearby points
clusterOverhangRegions:
    # Group points within proximity distance
    # Generate support at cluster center

# Problem: One structure per face center, doesn't account for face area
```

**Issues:**
- Arch: 50 faces → 50 clusters → insufficient coverage (face area ignored)
- Dome: 376 faces → 376 clusters → overlapping (no face pooling)

### New Algorithm (Face-Based Grouping)

```coffeescript
# For each overhang face:
detectOverhangs:
    # Store complete face data
    overhangFaces.push({
        vertices: [v0, v1, v2]
        centerX, centerY, centerZ
    })

# Group adjacent faces
groupAdjacentFaces:
    # Find faces that share edges
    # Pool connected faces together
    # Calculate collective bounding box

# Generate grid covering entire grouped area
generateRegionSupportPattern:
    # Cover full bounding box of ALL faces in group
    for y in [minY..maxY] step supportSpacing:
        for x in [minX..maxX] step supportSpacing:
            if canGenerateSupport(x, y):
                add_to_grid()
```

**Improvements:**
- Arch: Adjacent bottom faces grouped → 1-2 large regions → **full area coverage**
- Dome: Connected faces pooled → fewer unified regions → **no redundancy**
- Support accounts for **entire face area**, not just centers
- Adjacent faces generate **one coordinated structure**

## Performance Metrics

**Arch (upright):**
- Overhang points: 50
- Clusters: 50
- Moves per cluster: ~19
- Total support moves: 955
- Coverage: Full overhang region

**Dome (upright):**
- Overhang points: 376
- Clusters: 376
- Moves per cluster: ~20
- Total support moves: 7,407
- Density: Coordinated, no overlap

## Interface Gap

Supports stop short of the actual overhang to allow easy removal:

```coffeescript
interfaceGap = layerHeight * 1.5

# Only generate support if region is above current layer + gap
if cluster.maxZ > (z + interfaceGap)
    @generateClusterSupportPattern(...)
```

## G-code Generation Flow

1. **Check if enabled**: `return unless slicer.getSupportEnabled()`
2. **Validate settings**: Check `supportType` and `supportPlacement`
3. **Build layer cache**: Cache solid regions for all layers (first layer only)
4. **Detect overhangs**: Run once, cache in `slicer._overhangRegions`
5. **Cluster regions**: Group overhang points, cache in `slicer._supportClusters`
6. **Generate per layer**: For each cluster above current Z + gap
   - Generate grid pattern within cluster bounds
   - Alternate X/Y direction based on layer parity
   - Check collision for each grid point
   - Render continuous lines
7. **Add type annotation**: `"; TYPE: SUPPORT"` when verbose

## Caching

Three caches are maintained during slicing:

```coffeescript
# Overhang faces (detected once per mesh)
if not slicer._overhangFaces?
    slicer._overhangFaces = normalSupportModule.detectOverhangs(mesh, supportThreshold, minZ, supportPlacement)

# Support regions (grouped once per mesh)
if not slicer._supportRegions?
    slicer._supportRegions = normalSupportModule.groupAdjacentFaces(slicer._overhangFaces)

# Layer solid regions (built once per mesh)
if not slicer._layerSolidRegions?
    slicer._layerSolidRegions = @buildLayerSolidRegions(allLayers, layerHeight, minZ)
```

All caches are cleared at the start of each slice operation.

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
4. **Grid spacing**: 2.0× nozzle diameter for proper density
5. **Support gap**: 0.5× nozzle diameter gap from object (same as infill gap)
6. **Edge matching**: 0.001mm tolerance for shared edge detection
7. **Face grouping**: Adjacent faces (sharing edges) pooled into single region
8. **Area coverage**: Support grid covers bounding box MINUS gap on all sides
9. **Speed**: 50% of perimeter speed for better adhesion
10. **Pattern alternation**: X-direction on even layers, Y-direction on odd layers
11. **TYPE comments**: Added on every layer for visualizer compatibility
12. **Collision detection**: Uses even-odd winding rule with point-in-polygon test
13. **Hole detection**: Nesting levels calculated to distinguish solid structures from cavities
14. **Placement modes**:
    - `'buildPlate'`: Blocks support if ANY solid geometry at this XY in layers below
    - `'everywhere'`: Stops support at solid surfaces, resumes above them
15. **Cache management**: All three caches (_overhangFaces, _supportRegions, _layerSolidRegions) cleared between slices
16. **Sub-module architecture**: 
    - Main module dispatches based on `supportType` ('normal' or 'tree')
    - Normal support implementation in `normal/normal.coffee`
    - Tree support template in `tree/tree.coffee` (not yet implemented)
    - Shared utilities in main `support.coffee` module

## Example Results

Testing with arch geometry:

**Old Algorithm (Point-Based):**
- 50 overhang face centers
- 50 isolated support structures
- Point-based support (face area ignored)

**New Algorithm (Face-Based Grouping):**
- 50 overhang faces detected
- Adjacent faces grouped together (expected: 1-2 large regions)
- Grid covers entire grouped area
- **Result: Complete area coverage**

Testing with dome geometry:

**Old Algorithm (Point-Based):**
- 376 overhang face centers
- 376 isolated support structures
- Overlapping pillars

**New Algorithm (Face-Based Grouping):**
- 376 overhang faces detected
- Adjacent faces pooled by edge-sharing
- Unified support regions
- **Result: Coordinated structure, no redundancy**

These results demonstrate:
- **Improved coverage** - accounts for entire face area
- **Better grouping** - adjacent faces generate unified support
- **Coordinated structure** - one grid per grouped region

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
