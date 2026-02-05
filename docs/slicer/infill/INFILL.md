# Infill Patterns

The infill module generates interior fill patterns for 3D printed parts. Infill provides structural strength while using less material than solid fills.

## Overview

Polyslice supports three infill patterns:

- **Grid**: Crosshatch pattern at ±45° angles
- **Triangles**: Tessellation of equilateral triangles
- **Hexagons**: Honeycomb pattern for optimal strength-to-weight ratio

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
    // Options: "grid", "triangles", "hexagons"
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

| Feature | Grid | Triangles | Hexagons |
|---------|------|-----------|----------|
| Print Speed | ★★★★★ | ★★★★ | ★★★ |
| X/Y Strength | ★★★ | ★★★★ | ★★★★ |
| Compression | ★★★ | ★★★★ | ★★★★★ |
| Material Use | ★★★ | ★★★ | ★★★★ |
| Complexity | ★ | ★★ | ★★★ |

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
├── infill.coffee          # Main infill coordination
├── infill.test.coffee     # Infill tests
└── patterns/
    ├── grid.coffee        # Grid pattern implementation
    ├── grid.test.coffee
    ├── triangles.coffee   # Triangles pattern implementation
    ├── triangles.test.coffee
    ├── hexagons.coffee    # Hexagons pattern implementation
    └── hexagons.test.coffee
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
- **Concentric**: Inward spiraling fill
- **Cubic**: 3D interlocking cubes
- **Gyroid**: TPMS (triply periodic minimal surface)
- **Lightning**: Tree-like support structure

## Tips

1. **Start with 20% grid** for most prints - it's fast and adequate for non-structural parts

2. **Use hexagons** for parts that need to be strong but lightweight

3. **Increase density** for functional parts that will bear loads

4. **Consider print time**: Grid is fastest, hexagons is slowest

5. **Test your material**: Some materials (like TPU) may require higher infill for flexibility

6. **Top/bottom layers**: Solid skin layers cover the infill pattern on visible surfaces
