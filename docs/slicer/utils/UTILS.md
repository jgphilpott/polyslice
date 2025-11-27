# Slicer Utilities

The utils module provides core utility functions for geometry operations, path manipulation, clipping, and extrusion calculations.

## Overview

The slicer utilities are organized into several modules:

| Module | Description |
|--------|-------------|
| `bounds` | Bounding box calculations and overlap detection |
| `clipping` | Polygon clipping and line-to-polygon operations |
| `extrusion` | Filament extrusion amount calculations |
| `paths` | Path manipulation and segment connection |
| `primitives` | Basic geometry operations (points, lines) |

## Bounds Module

### `isWithinBounds(slicer, x, y)`

Check if coordinates are within build plate bounds.

```javascript
const bounds = require("./utils/bounds");

// Check if point is on build plate
const valid = bounds.isWithinBounds(slicer, 100, 100);
```

### `calculatePathBounds(path)`

Calculate the bounding box of a path.

```javascript
const bbox = bounds.calculatePathBounds(path);
// Returns: { minX, maxX, minY, maxY }
```

### `boundsOverlap(bounds1, bounds2, tolerance)`

Check if two bounding boxes overlap.

```javascript
const overlaps = bounds.boundsOverlap(bbox1, bbox2, 0.1);
```

## Clipping Module

The clipping module uses the [polygon-clipping](https://www.npmjs.com/package/polygon-clipping) library for complex polygon operations.

### `clipLineToPolygon(lineStart, lineEnd, polygon)`

Clip a line segment to a polygon boundary. Returns only the portions of the line inside the polygon.

```javascript
const clipping = require("./utils/clipping");

const segments = clipping.clipLineToPolygon(
    { x: 0, y: 0 },      // Line start
    { x: 100, y: 100 },  // Line end
    polygonPath          // Boundary polygon
);
// Returns array of { start, end } segments inside polygon
```

**Algorithm:**
1. Find all intersection points between line and polygon edges
2. Determine which line endpoints are inside the polygon
3. Sort points by parametric position along the line (t = 0 to 1)
4. Test midpoints between intersections to identify inside segments
5. Return only portions inside the polygon

### `clipLineWithHoles(lineStart, lineEnd, boundary, holes)`

Clip a line to a boundary while excluding hole regions.

```javascript
const segments = clipping.clipLineWithHoles(
    lineStart,    // Line start point
    lineEnd,      // Line end point
    boundary,     // Outer boundary polygon
    holePolygons  // Array of hole polygons to exclude
);
```

### `subtractSkinAreasFromInfill(infillBoundary, skinAreas)`

Subtract skin areas from infill boundary using polygon boolean operations.

```javascript
const infillBoundaries = clipping.subtractSkinAreasFromInfill(
    infillBoundary,  // Original infill area
    skinAreas        // Skin areas to exclude
);
// Returns array of remaining infill boundaries
```

## Extrusion Module

### `calculateExtrusion(slicer, distance, lineWidth)`

Calculate filament extrusion amount for a given distance.

```javascript
const extrusion = require("./utils/extrusion");

// Calculate extrusion for a 10mm line
const e = extrusion.calculateExtrusion(slicer, 10, 0.4);
```

**Formula:**
```
lineArea = lineWidth × layerHeight
filamentArea = π × (filamentDiameter / 2)²
extrusion = (lineArea × distance × extrusionMultiplier) / filamentArea
```

**Factors considered:**
- Line width (defaults to nozzle diameter)
- Layer height
- Filament diameter (1.75mm or 2.85mm)
- Extrusion multiplier (flow rate adjustment)

## Paths Module

### `connectSegmentsToPaths(segments)`

Convert line segments to closed paths using a leftmost-turn heuristic.

```javascript
const paths = require("./utils/paths");

// Convert Polytree segments to closed paths
const closedPaths = paths.connectSegmentsToPaths(segments);
```

**Algorithm:**
1. Convert segments to edge format
2. Build paths by following connected edges
3. Use leftmost-turn heuristic to handle branches
4. Return array of closed polygon paths

### `createInsetPath(path, distance, isHole)`

Create an inset (offset) version of a path.

```javascript
// Create inset for inner wall
const insetPath = paths.createInsetPath(outerPath, 0.4);

// Create outset for hole (shrinks the hole)
const outsetPath = paths.createInsetPath(holePath, 0.4, true);
```

**Parameters:**
- `path` - Original path points
- `distance` - Inset distance (positive = inward)
- `isHole` - If true, reverses offset direction for holes

## Primitives Module

### `pointsMatch(p1, p2, epsilon)`

Fast point comparison using squared distance (avoids sqrt).

```javascript
const primitives = require("./utils/primitives");

const match = primitives.pointsMatch(p1, p2, 0.001);
```

### `pointsEqual(p1, p2, epsilon)`

Point comparison using actual distance calculation.

```javascript
const equal = primitives.pointsEqual(p1, p2, 0.001);
```

### `lineIntersection(p1, p2, p3, p4)`

Calculate intersection point of two infinite lines.

```javascript
const intersection = primitives.lineIntersection(
    { x: 0, y: 0 }, { x: 10, y: 10 },  // Line 1
    { x: 0, y: 10 }, { x: 10, y: 0 }   // Line 2
);
// Returns { x, y } or null if parallel
```

### `lineSegmentIntersection(p1, p2, p3, p4)`

Calculate intersection of two line segments (bounded).

```javascript
const intersection = primitives.lineSegmentIntersection(
    segmentA.start, segmentA.end,
    segmentB.start, segmentB.end
);
// Returns { x, y } only if intersection is within both segments
```

### `pointInPolygon(point, polygon)`

Check if a point is inside a polygon using ray casting.

```javascript
const inside = primitives.pointInPolygon({ x: 5, y: 5 }, polygon);
```

**Algorithm:**
- Cast ray from point to the right
- Count intersections with polygon edges
- Odd count = inside, even count = outside

### `distancePointToLine(point, lineStart, lineEnd)`

Calculate minimum distance from a point to a line segment.

```javascript
const dist = primitives.distancePointToLine(
    { x: 5, y: 5 },
    { x: 0, y: 0 }, { x: 10, y: 0 }
);
```

## File Structure

```
src/slicer/utils/
├── bounds.coffee         # Bounding box operations
├── bounds.test.coffee
├── clipping.coffee       # Polygon clipping
├── clipping.test.coffee
├── extrusion.coffee      # Extrusion calculations
├── extrusion.test.coffee
├── paths.coffee          # Path manipulation
├── paths.test.coffee
├── primitives.coffee     # Basic geometry ops
└── primitives.test.coffee
```

## Dependencies

- **polygon-clipping** - Boolean polygon operations

## Usage Examples

### Calculating Infill Lines

```javascript
// Get boundary and holes
const infillBoundary = paths.createInsetPath(outerWall, nozzleDiameter / 2);
const holesWithGap = holes.map(h => paths.createInsetPath(h, nozzleDiameter / 2, true));

// Generate diagonal line
const lineStart = { x: minX, y: minY + offset };
const lineEnd = { x: maxX, y: maxY + offset };

// Clip to boundary, excluding holes
const segments = clipping.clipLineWithHoles(lineStart, lineEnd, infillBoundary, holesWithGap);

// Generate G-code for each segment
for (const segment of segments) {
    const distance = calculateDistance(segment.start, segment.end);
    const e = extrusion.calculateExtrusion(slicer, distance, nozzleDiameter);
    // ... generate G-code
}
```

### Path Processing

```javascript
// Get segments from Polytree
const segments = polytree.intersect(plane);

// Convert to closed paths
const closedPaths = paths.connectSegmentsToPaths(segments);

// Identify holes (paths inside other paths)
const outerPaths = [];
const holes = [];

for (const path of closedPaths) {
    const isHole = closedPaths.some(other => 
        other !== path && primitives.pointInPolygon(path[0], other)
    );
    if (isHole) holes.push(path);
    else outerPaths.push(path);
}
```

## Related Documentation

- [GEOMETRY_HELPERS.md](../geometry/GEOMETRY_HELPERS.md) - Additional geometry helpers
- [COMBING.md](../geometry/COMBING.md) - Travel path optimization
- [SLICING.md](../SLICING.md) - Main slicing documentation
