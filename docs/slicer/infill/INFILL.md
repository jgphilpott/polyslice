# Infill Patterns

The infill module generates interior fill patterns for 3D printed parts. Infill provides structural strength while using less material than solid fills.

## Overview

Polyslice supports seven infill patterns:

- **Grid**: Crosshatch pattern at ±45° angles
- **Triangles**: Tessellation of equilateral triangles
- **Hexagons**: Honeycomb pattern for optimal strength-to-weight ratio
- **Concentric**: Inward-spiraling contours following the part shape
- **Gyroid**: Wavy TPMS structure for excellent strength and isotropy
- **Spiral**: Outward-spiraling Archimedean spiral from center
- **Lightning**: Tree-like branching structure for fast, minimal material infill

## Usage

```javascript
const Polyslice = require("@jgphilpott/polyslice");

const slicer = new Polyslice({
    infillDensity: 20,       // 20% infill
    infillPattern: "grid",   // Pattern type
    nozzleTemperature: 200,
    bedTemperature: 60
});

// Slice a mesh - infill is generated automatically
const gcode = slicer.slice(mesh);
```

### Configuration Options

```javascript
const slicer = new Polyslice({
    // Infill density (0-100%)
    // 0 = hollow, 100 = solid
    infillDensity: 20,

    // Infill pattern type
    // Options: "grid", "triangles", "hexagons", "concentric", "gyroid", "spiral", "lightning"
    infillPattern: "grid",

    // Pattern centering mode
    // Options: "object" (center on object boundary) or "global" (center on build plate)
    infillPatternCentering: "object",

    // Infill speed in mm/s
    infillSpeed: 60,

    // Nozzle diameter affects line spacing
    nozzleDiameter: 0.4
});
```

### Pattern Centering Modes

Polyslice provides two modes for centering infill patterns:

**Object Centering** (default, `"object"`):
- Each object has its own pattern center
- Patterns are centered on each object's boundary
- Good for ensuring consistent infill within each part
- Best for most prints

**Global Centering** (`"global"`):
- All objects share the same pattern grid
- Pattern is centered on the build plate center
- Good for multi-object prints where pattern alignment across parts matters
- May result in incomplete pattern coverage at object edges depending on position

```javascript
// Object centering (default)
slicer.setInfillPatternCentering("object");

// Global centering
slicer.setInfillPatternCentering("global");
```

**When to use object centering:**
- Single object prints
- Multi-object prints where each part should have complete pattern coverage
- When you want consistent infill regardless of object position

**When to use global centering:**
- Multi-object prints where pattern alignment across parts is important
- When printing parts that will be assembled and you want matching infill phases
- When you want a consistent grid across the entire build plate

## Available Patterns

### Grid Pattern

The grid pattern creates a crosshatch fill using two sets of lines at +45° and -45° angles.

```
    ╲ ╱ ╲ ╱ ╲ ╱
     ╳   ╳   ╳
    ╱ ╲ ╱ ╲ ╱ ╲
   ╳   ╳   ╳   ╳
    ╲ ╱ ╲ ╱ ╲ ╱
```

**Characteristics:**
- Simple and fast to print
- Good for general-purpose parts
- Equal strength in X and Y directions
- Lines intersect at 90° angles

**Best for:**
- Prototypes
- Non-structural parts
- Quick prints where strength is not critical

**Line Spacing Formula:**
```
spacing = (nozzleDiameter / (density / 100)) * 2
```

For example, at 20% density with 0.4mm nozzle:
- spacing = (0.4 / 0.2) * 2 = 4.0mm per direction
- Each direction provides 10% density, totaling 20%

### Triangles Pattern

The triangles pattern creates a tessellation of equilateral triangles using three line sets spaced 60° apart. The baseline runs at 45°, with additional lines at +60° (105°) and -60° (-15°) from the baseline.

```
      /\    /\
     /  \  /  \
    /    \/    \
    \    /\    /
     \  /  \  /
      \/    \/
```

**Characteristics:**
- Strong in all directions (isotropic)
- Better load distribution than grid
- Slightly slower print time
- Three line sets create equilateral triangles

**Best for:**
- Parts requiring uniform strength
- Load-bearing components
- Structural prototypes

**Line Spacing Formula:**
```
spacing = (nozzleDiameter / (density / 100)) * 3
```

For example, at 20% density with 0.4mm nozzle:
- spacing = (0.4 / 0.2) * 3 = 6.0mm per direction
- Each of three directions provides ~6.67% density, totaling 20%

### Hexagons Pattern

The hexagons pattern creates a honeycomb-like structure with actual hexagonal cells.

```
    ___     ___
   /   \___/   \
   \___/   \___/
   /   \___/   \
   \___/   \___/
```

**Characteristics:**
- Excellent strength-to-weight ratio
- Natural structural efficiency (like bee honeycombs)
- Optimal for compression loads
- More complex path planning

**Best for:**
- Lightweight structural parts
- Aerospace and automotive applications
- Parts requiring high strength with minimum material
- Load-bearing surfaces

**Cell Sizing:**
The hexagon size is derived from line spacing:
```
hexagonSide = lineSpacing / sqrt(3)
horizontalSpacing = hexagonSide * sqrt(3)
verticalSpacing = hexagonSide * 1.5
```

### Concentric Pattern

The concentric pattern creates inward-spiraling contours that follow the natural shape of the part.

```
    __________
   /          \
  /  ________  \
 / /          \ \
| |  ______  | |
| | |      | | |
| | |______| | |
 \ \________/ /
  \__________/
```

**Characteristics:**
- Follows the natural contour of the part
- Each layer independently adapts to the shape
- Continuous extrusion paths (minimal retractions)
- Excellent for cylindrical or curved parts

**Best for:**
- Parts with circular or curved cross-sections
- Cylinders, tubes, and rounded shapes
- When you want the infill to follow the part geometry
- Decorative patterns where concentric lines are desired

**Line Spacing Formula:**
```
spacing = nozzleDiameter / (density / 100)
```

For example, at 20% density with 0.4mm nozzle:
- spacing = 0.4 / 0.2 = 2.0mm between loops
- Creates concentric loops at 2mm intervals

**Pattern Generation:**
The concentric pattern works by repeatedly insetting (offsetting inward) the boundary:
1. Start at the infill boundary
2. Generate a contour loop
3. Inset by line spacing
4. Repeat until the center is reached

> Note: The `infillPatternCentering` setting does not affect the concentric pattern.
> Concentric infill always follows the part's boundary contours rather than a fixed grid,
> so it will conform to the model shape regardless of the configured centering mode.

### Gyroid Pattern

The gyroid pattern creates a wavy structure that approximates a triply periodic minimal surface (TPMS). This results in excellent strength-to-weight ratio with isotropic properties.

```
    ~~~  ~~~  ~~~
   ~  ~~  ~~  ~~
  ~  ~  ~~  ~~  ~
 ~~  ~~  ~~  ~~
~~~  ~~~  ~~~
```

**Characteristics:**
- Wavy lines create smooth 3D structure
- Excellent strength in all directions (isotropic)
- Better load distribution than grid
- Comparable to hexagons for structural efficiency
- Natural appearance with organic flowing lines
- More G-code commands than straight-line patterns (due to wavy paths)
- Gradual direction transition over 8-layer cycles for improved interlayer adhesion

**Best for:**
- High-performance functional parts
- Parts requiring uniform strength in all directions
- Aerospace and engineering applications
- Structural components with compression and tension loads
- Parts where strength-to-weight ratio is critical

**Line Spacing Formula:**
```
spacing = (nozzleDiameter / (density / 100)) * 1.5
```

For example, at 20% density with 0.4mm nozzle:
- spacing = (0.4 / 0.2) * 1.5 = 3.0mm
- Wave amplitude is 40% of line spacing
- Direction gradually transitions over 8 layers

**Pattern Generation:**
The gyroid pattern uses mathematical wave functions based on the gyroid minimal surface equation:
1. Calculate phase offset based on Z height
2. Calculate blend ratio for gradual direction transition (8-layer cycle)
3. Generate X-direction wavy lines when blend ratio < 1
4. Generate Y-direction wavy lines when blend ratio > 0
5. Apply sine/cosine functions for wave displacement
6. Create 3D interlocking structure across layers

**Transition Behavior:**
- Layer 0 (ratio=0.000): Pure X-direction (horizontal wavy lines)
- Layers 1-6 (ratio=0.125-0.750): Both X and Y directions (diagonal weave)
- Layer 7 (ratio=0.875): Mostly Y-direction (vertical wavy lines)
- Layer 8: Cycle repeats

This gradual transition creates smoother layer-to-layer bonding compared to abrupt 90° alternation.

### Spiral Pattern

The spiral pattern creates a continuous Archimedean spiral from the center outward.

```
      ___---~~~
    /          \
   |    ____    |
   |  /    \    |
   | |  •   |   |
   |  \____/    |
    \          /
     ~~~---___
```

**Characteristics:**
- Continuous single path from center to edge
- Smooth circular motion following spiral curve
- Consistent spacing between turns
- Natural fit for cylindrical or circular parts
- Minimal travel moves (continuous extrusion)
- Simple and predictable pattern

**Best for:**
- Cylindrical parts (tubes, bottles, cups)
- Circular cross-sections
- Parts where continuous extrusion is desired
- Decorative pieces with spiral aesthetic
- Fast printing with minimal retractions

**Line Spacing Formula:**
```
spacing = nozzleDiameter / (density / 100)
```

For example, at 20% density with 0.4mm nozzle:
- spacing = 0.4 / 0.2 = 2.0mm between spiral turns
- Creates smooth Archimedean spiral with consistent spacing

**Pattern Generation:**
The spiral pattern uses parametric equations of an Archimedean spiral:
1. Calculate maximum radius needed to cover boundary
2. Generate spiral path: r = (spacing / 2π) × θ
3. Convert to Cartesian coordinates: x = r × cos(θ), y = r × sin(θ)
4. Clip spiral segments to infill boundary

### Lightning Pattern

The lightning pattern creates a tree-like branching structure for fast printing with minimal material usage.

```
    \  |  /     \  |  /
     \ | /       \ | /
      \|/         \|/
       |           |
       |           |
━━━━━━━━━━━━━━━━━━━━━
```

**Characteristics:**
- Tree-like branches extending from boundary inward
- Each branch forks into sub-branches for support
- Very fast printing (minimal material)
- Adequate support for top layers
- Natural, organic appearance
- Branches directed toward center with angle variation

**Best for:**
- Prototypes where speed is critical
- Non-structural decorative parts
- Quick test prints
- Models where minimal infill is acceptable
- Parts where top surface quality is more important than strength

**Line Spacing Formula:**
```
spacing = (nozzleDiameter / (density / 100)) * 2.0
```

For example, at 20% density with 0.4mm nozzle:
- `lineSpacing` = (0.4 / 0.2) * 2.0 = 4.0mm
- `branchSpacing` = lineSpacing * 2.5 = 10.0mm between branch starting points
- Branches extend approximately 80% of the smaller dimension
- Sub-branches fork at 40% of main branch length at 45° angles

**Pattern Generation:**
The lightning pattern algorithm:
1. Calculate branch starting points along the boundary perimeter (spaced by `lineSpacing * 2.5`)
2. Direct main branches toward the center with angle variation
3. Create forking sub-branches at midpoints (45° from main direction)
4. Clip all branches to stay within the infill boundary
5. Avoid hole regions using clipping algorithm

## Density Guide

| Density | Use Case |
|---------|----------|
| 0% | Hollow - vases, decorative items |
| 5-10% | Light structural support |
| 15-20% | Standard - most prints (recommended) |
| 25-35% | Functional parts with moderate stress |
| 40-60% | High-strength mechanical parts |
| 70-90% | Near-solid for maximum strength |
| 100% | Solid - heavy-duty applications |

## Pattern Comparison

| Feature | Grid | Triangles | Hexagons | Concentric | Gyroid | Spiral | Lightning |
|---------|------|-----------|----------|------------|--------|--------|-----------|
| Print Speed | ★★★★★ | ★★★★ | ★★★ | ★★★★ | ★★★ | ★★★★★ | ★★★★★ |
| X/Y Strength | ★★★ | ★★★★ | ★★★★ | ★★★ | ★★★★★ | ★★ | ★★ |
| Compression | ★★★ | ★★★★ | ★★★★★ | ★★★ | ★★★★★ | ★★ | ★ |
| Material Use | ★★★ | ★★★ | ★★★★ | ★★★★ | ★★★★ | ★★★★ | ★★★★★ |
| Complexity | ★ | ★★ | ★★★ | ★ | ★★ | ★ | ★★ |
| Curved Parts | ★★ | ★★ | ★★ | ★★★★★ | ★★★ | ★★★★★ | ★★★ |
| Isotropy | ★★ | ★★★★ | ★★★★ | ★★ | ★★★★★ | ★ | ★ |

## Technical Details

### Infill Generation Process

1. **Boundary Calculation**: Create an inset from the innermost wall (half nozzle gap)
2. **Hole Exclusion**: Subtract hole regions from infill area
3. **Skin Exclusion**: On mixed layers, exclude skin areas from infill
4. **Pattern Generation**: Generate line segments based on selected pattern
5. **Clipping**: Clip lines against boundary polygon
6. **Travel Optimization**: Use combing to avoid crossing holes

### Combing Integration

All infill patterns use travel path optimization (combing) to avoid crossing holes:

- Lines are sorted by position to minimize travel distance
- Travel moves route around holes using waypoints
- This prevents stringing artifacts in printed holes

See [COMBING.md](../geometry/COMBING.md) for details on travel path optimization.

### Skin Interaction

On layers with adaptive skin (exposed surfaces):

1. Skin areas are subtracted from the infill boundary
2. Infill is generated in non-skin regions
3. Skin is printed after infill (so skin covers infill pattern)

See [EXPOSURE_DETECTION.md](../skin/EXPOSURE_DETECTION.md) for adaptive skin details.

## File Structure

```
src/slicer/infill/
├── infill.coffee            # Main infill coordination
├── infill.test.coffee       # Infill tests
└── patterns/
    ├── grid.coffee          # Grid pattern implementation
    ├── grid.test.coffee
    ├── triangles.coffee     # Triangles pattern implementation
    ├── triangles.test.coffee
    ├── hexagons.coffee      # Hexagons pattern implementation
    ├── hexagons.test.coffee
    ├── concentric.coffee    # Concentric pattern implementation
    ├── concentric.test.coffee
    ├── gyroid.coffee        # Gyroid pattern implementation
    ├── gyroid.test.coffee
    ├── spiral.coffee        # Spiral pattern implementation
    ├── spiral.test.coffee
    ├── lightning.coffee     # Lightning pattern implementation
    └── lightning.test.coffee
```

## API Reference

### Slicer Configuration

```javascript
// Get/set infill density (0-100)
slicer.setInfillDensity(20);
const density = slicer.getInfillDensity();

// Get/set infill pattern
slicer.setInfillPattern("hexagons");
const pattern = slicer.getInfillPattern();

// Get/set pattern centering mode
slicer.setInfillPatternCentering("object"); // or "global"
const centering = slicer.getInfillPatternCentering();

// Get/set infill speed (mm/s)
slicer.setInfillSpeed(60);
const speed = slicer.getInfillSpeed();
```

### Pattern Values

```javascript
// Valid pattern values
"grid"       // Crosshatch at ±45°
"triangles"  // Equilateral triangle tessellation
"hexagons"   // Honeycomb pattern
"concentric" // Inward-spiraling contours
"gyroid"     // Wavy TPMS structure
"spiral"     // Outward-spiraling from center
"lightning"  // Tree-like branching structure
```

### Centering Values

```javascript
// Valid centering values
"object"     // Center pattern on each object's boundary (default)
"global"     // Center pattern on build plate center
```

## Future Patterns

The following patterns may be added in future versions:

- **Lines**: Single direction linear fill
- **Cubic**: 3D interlocking cubes

## Tips

1. **Start with 20% grid** for most prints - it's fast and adequate for non-structural parts

2. **Use hexagons** for parts that need to be strong but lightweight

3. **Use lightning** for rapid prototyping and test prints where speed is critical

4. **Increase density** for functional parts that will bear loads

5. **Consider print time**: Grid and lightning are fastest, hexagons is slowest

6. **Test your material**: Some materials (like TPU) may require higher infill for flexibility

7. **Top/bottom layers**: Solid skin layers cover the infill pattern on visible surfaces
