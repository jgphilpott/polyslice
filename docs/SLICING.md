# Slicing Functionality

This document describes the slicing functionality implemented in Polyslice.

## Overview

Polyslice now includes a complete slicing engine that can convert three.js meshes into G-code for 3D printing. The implementation uses a layer-by-layer approach to generate perimeter paths with proper extrusion calculations.

## Features

- **Layer-by-layer slicing**: Automatically calculates the number of layers based on mesh height and layer height
- **Perimeter generation**: Extracts 2D contours at each Z-height by intersecting triangles with horizontal planes
- **Path optimization**: Connects edge segments into closed paths for each layer
- **Proper G-code initialization**: Includes autohome, workspace plane, heating sequences, and fan control
- **Extrusion calculation**: Automatically calculates extrusion amounts based on distance, layer height, nozzle diameter, and filament diameter
- **Scene support**: Can slice individual meshes or extract meshes from three.js Scene objects

## Usage

### Basic Example

```javascript
const Polyslice = require('@jgphilpott/polyslice');
const THREE = require('three');

// Create a 1cm cube
const geometry = new THREE.BoxGeometry(10, 10, 10);
const material = new THREE.MeshBasicMaterial();
const cube = new THREE.Mesh(geometry, material);

// Position cube so bottom is at Z=0
cube.position.set(0, 0, 5);
cube.updateMatrixWorld();

// Create slicer
const slicer = new Polyslice({
  layerHeight: 0.2,
  nozzleTemperature: 200,
  bedTemperature: 60,
  fanSpeed: 100,
  nozzleDiameter: 0.4,
  filamentDiameter: 1.75,
  perimeterSpeed: 1200,
  travelSpeed: 3000
});

// Slice the mesh
const gcode = slicer.slice(cube);

// Save or send to printer
fs.writeFileSync('output.gcode', gcode);
```

### Slicing from a Scene

```javascript
const scene = new THREE.Scene();
const mesh = new THREE.Mesh(geometry, material);
scene.add(mesh);

// Slice directly from scene
const gcode = slicer.slice(scene);
```

## Implementation Details

### Slicing Algorithm

1. **Mesh Extraction**: Extract the first mesh from the scene or use the mesh directly
2. **Bounding Box Calculation**: Calculate the mesh bounding box to determine Z-range
3. **Layer Generation**: Uses Polytree's `sliceIntoLayers()` for all layers:
   - Performs optimized triangle-plane intersection
   - Returns Line3 segments for each layer
   - Connect segments into closed paths
   - Generate G-code for perimeter printing with build plate centering

### Polytree Integration

Uses Polytree's optimized spatial queries:
1. `sliceIntoLayers(mesh, layerHeight, minZ, maxZ)` - Slices all layers efficiently
2. Returns arrays of Line3 objects (line segments) for each layer
3. Significantly faster than custom triangle iteration

### Path Connection

1. Convert Polytree's Line3 segments to simple edge format
2. Start with an unused edge segment
3. Find connecting edges by matching endpoints (within epsilon tolerance)
4. Continue until path is closed or no more connecting edges exist
5. Only keep paths with at least 3 points

### Build Plate Centering

All coordinates are automatically centered on the build plate:
- Calculates center offset based on build plate dimensions
- Default: 220mm x 220mm build plate (center at X110, Y110)
- Applied during G-code generation, not during slicing

### G-code Generation

For each layer:
1. Travel to start of path (G0)
2. Print perimeter with calculated extrusion (G1 with E parameter)
3. Close the path by returning to start

## Configuration Options

Key parameters affecting slicing:

- `layerHeight`: Height of each layer in mm (default: 0.2)
- `nozzleDiameter`: Nozzle diameter for extrusion calculations (default: 0.4)
- `filamentDiameter`: Filament diameter in mm (default: 1.75)
- `perimeterSpeed`: Speed for printing perimeters in mm/min (default: 1800)
- `travelSpeed`: Speed for non-printing moves in mm/min (default: 3000)
- `extrusionMultiplier`: Multiplier for extrusion amount (default: 1.0)

## Output Format

Generated G-code includes:

```gcode
M117 Starting print...
G28                      ; Autohome
G17                      ; XY workspace plane
G21                      ; Millimeters
M190 R60                 ; Wait for bed temperature
M109 R200                ; Wait for nozzle temperature
M106 S255                ; Fan on
M117 Printing 50 layers...
M117 Layer 1/50
G0 X5 Y5 Z0.2 F3000     ; Travel move
G1 X-5 Y5 Z0.2 E0.326 F1200  ; Print with extrusion
...
M117 Print completed!
M107                     ; Fan off
M104 S0                  ; Nozzle off
M140 S0                  ; Bed off
G28                      ; Home
M117 Ready for next print
```

## Limitations and Future Enhancements

### Current Limitations

1. **No infill generation**: Currently only generates perimeters
2. **No support structures**: Overhangs are not supported
3. **No adaptive layer heights**: Uses constant layer height throughout
4. **Basic path optimization**: Paths are not optimized for print time

### Planned Enhancements

1. **Polytree integration**: Use @jgphilpott/polytree for spatial queries when sliceIntoLayers API becomes available
2. **Infill patterns**: Grid, lines, honeycomb, gyroid patterns
3. **Support generation**: Automatic support structure creation for overhangs
4. **Multiple perimeters**: Shell thickness control
5. **Retraction**: Retraction/unretraction between paths
6. **First layer handling**: Special handling for bed adhesion
7. **Bridge detection**: Special handling for bridges and overhangs

## Testing

Comprehensive test suite covers:

- Basic slicing with autohome
- Cube slicing with proper G-code structure
- Scene extraction
- Layer height variations
- Temperature configuration
- Edge cases (empty scenes, null scenes)

Run tests:
```bash
npm test -- src/slicer/slice.test.js
```

## Examples

See the `examples/scripts/` directory for complete examples:

- `slice-cube.js`: Slicing a simple 1cm cube created in three.js

## Performance

Slicing a 1cm cube with 0.2mm layer height:
- **Time**: ~10-15ms
- **Layers**: 50
- **G-code lines**: ~515
- **Movement commands**: ~450

## References

- [Marlin G-code Documentation](https://marlinfw.org/docs/gcode/)
- [three.js Documentation](https://threejs.org/docs/)
- [Polytree Spatial Queries](https://github.com/jgphilpott/polytree)
