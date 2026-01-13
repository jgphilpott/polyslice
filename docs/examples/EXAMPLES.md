# Examples

This document provides practical examples for using Polyslice.

## Basic Usage

```javascript
const Polyslice = require('@jgphilpott/polyslice');

const slicer = new Polyslice({
  nozzleTemperature: 210,
  bedTemperature: 60,
  fanSpeed: 80
});

// Print a simple square.
let gcode = '';
gcode += slicer.codeAutohome();
gcode += slicer.codeNozzleTemperature(210, true);
gcode += slicer.codeBedTemperature(60, true);

// Draw square perimeter.
gcode += slicer.codeLinearMovement(0, 0, 0.2, null, 3000);  // Move to start.
gcode += slicer.codeLinearMovement(10, 0, 0.2, 0.5, 1200);  // Bottom edge.
gcode += slicer.codeLinearMovement(10, 10, 0.2, 0.5, 1200); // Right edge.
gcode += slicer.codeLinearMovement(0, 10, 0.2, 0.5, 1200);  // Top edge.
gcode += slicer.codeLinearMovement(0, 0, 0.2, 0.5, 1200);   // Left edge.

gcode += slicer.codeAutohome();

console.log(gcode);
```

## Using Printer Configurations

```javascript
const { Polyslice, Printer } = require('@jgphilpott/polyslice');

// Create a printer instance with your printer model.
const printer = new Printer('Ender3');

// Access printer specifications.
console.log(`Build volume: ${printer.getSizeX()} x ${printer.getSizeY()} x ${printer.getSizeZ()} mm`);
console.log(`Nozzle diameter: ${printer.getNozzle(0).diameter} mm`);
console.log(`Filament diameter: ${printer.getNozzle(0).filament} mm`);

// Customize printer settings if needed.
printer.setSizeZ(300);  // Modify build height.

// Create a slicer instance with automatic printer configuration.
const slicer = new Polyslice({
  printer: printer,
  nozzleTemperature: 210,
  bedTemperature: 60
});

// Or update printer at runtime
slicer.setPrinter(new Printer('CR10'));  // Automatically updates build plate dimensions

console.log('Slicer configured for:', slicer.getPrinter().getModel());
```

## Using Printer and Filament Configurations

```javascript
const { Polyslice, Printer, Filament } = require('@jgphilpott/polyslice');

// Create printer and filament instances.
const printer = new Printer('Ender3');
const filament = new Filament('PrusamentPLA');

// Automatic configuration - just pass printer and filament!
const slicer = new Polyslice({
  printer: printer,
  filament: filament
});

// All settings automatically configured:
console.log('Build plate:', slicer.getBuildPlateWidth(), 'x', slicer.getBuildPlateLength(), 'mm');
console.log('Nozzle temp:', slicer.getNozzleTemperature() + '°C');
console.log('Bed temp:', slicer.getBedTemperature() + '°C');
console.log('Nozzle diameter:', slicer.getNozzleDiameter(), 'mm');
console.log('Filament diameter:', slicer.getFilamentDiameter(), 'mm');
console.log('Retraction:', slicer.getRetractionDistance(), 'mm');

// Override specific settings if needed
const customSlicer = new Polyslice({
  printer: new Printer('Ender3'),
  filament: new Filament('GenericPLA'),
  bedTemperature: 0,  // Override for broken bed heater
  nozzleTemperature: 210  // Override for personal preference
});

// Update printer/filament at runtime
slicer.setPrinter(new Printer('CR10'));  // Updates build volume
slicer.setFilament(new Filament('GenericPETG'));  // Updates temperatures

console.log('Slicer ready with optimized settings!');
```

## Three.js Integration

```javascript
const THREE = require('three');
const Polyslice = require('@jgphilpott/polyslice');

// Create three.js scene.
const scene = new THREE.Scene();
const geometry = new THREE.BoxGeometry(20, 20, 5);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const cube = new THREE.Mesh(geometry, material);
scene.add(cube);

// Create slicer and generate G-code.
const slicer = new Polyslice({
  nozzleTemperature: 210,
  bedTemperature: 60
});

// Slice the mesh
const gcode = slicer.slice(cube);

console.log(gcode);
```

## File Loading

Polyslice includes built-in support for loading 3D models from various file formats.

### Supported Formats

- **STL** (Stereolithography) - Most common 3D printing format
- **OBJ** (Wavefront Object) - Common 3D modeling format
- **3MF** (3D Manufacturing Format) - Modern format with color/material support
- **AMF** (Additive Manufacturing File) - XML-based format
- **PLY** (Polygon File Format) - Often used for 3D scanning
- **GLTF/GLB** (GL Transmission Format) - Modern 3D asset format
- **DAE** (Collada) - Common 3D asset exchange format

### Basic File Loading

```javascript
const { Loader } = require('@jgphilpott/polyslice');

// Load an STL file
const mesh = await Loader.loadSTL('model.stl');

// Load an OBJ file (may return multiple meshes)
const meshes = await Loader.loadOBJ('model.obj');

// Load a 3MF file
const meshes = await Loader.load3MF('model.3mf');

// Load a GLTF file
const meshes = await Loader.loadGLTF('model.gltf');

// Generic loader (auto-detects format from extension)
const mesh = await Loader.load('model.stl');
```

### Custom Materials

```javascript
const THREE = require('three');
const { Loader } = require('@jgphilpott/polyslice');

// Create a custom material
const material = new THREE.MeshPhongMaterial({
  color: 0xff0000,
  specular: 0x111111,
  shininess: 200
});

// Load with custom material
const mesh = await Loader.loadSTL('model.stl', material);
```

### Complete Workflow

```javascript
const Polyslice = require('@jgphilpott/polyslice');
const { Loader, Printer, Filament } = require('@jgphilpott/polyslice');

// Load a 3D model from file
const mesh = await Loader.loadSTL('model.stl');

// Create a slicer instance with printer and filament
const slicer = new Polyslice({
  printer: new Printer('Ender3'),
  filament: new Filament('PrusamentPLA')
});

// Generate G-code from the loaded mesh
const gcode = slicer.slice(mesh);

console.log(gcode);
```

## Browser Integration

```html
<!DOCTYPE html>
<html>
    <head>
        <title>Polyslice Browser Example</title>
        <script src="https://unpkg.com/three@0.180.0/build/three.min.js"></script>
        <script src="https://unpkg.com/@jgphilpott/polyslice/dist/index.browser.min.js"></script>
    </head>
    <body>
        <script>

            // Create three.js scene.
            const scene = new THREE.Scene();
            const geometry = new THREE.BoxGeometry(20, 20, 5);
            const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
            const cube = new THREE.Mesh(geometry, material);
            scene.add(cube);

            // Create slicer instance.
            const slicer = new Polyslice({
                nozzleTemperature: 210,
                bedTemperature: 60,
                fanSpeed: 100
            });

            // Generate G-code.
            let gcode = '';
            gcode += slicer.codeAutohome();
            gcode += slicer.codeNozzleTemperature(210, true);
            gcode += slicer.codeBedTemperature(60, true);

            // Simple square print.
            gcode += slicer.codeLinearMovement(0, 0, 0.2, null, 3000);
            gcode += slicer.codeLinearMovement(20, 0, 0.2, 1, 1200);
            gcode += slicer.codeLinearMovement(20, 20, 0.2, 1, 1200);
            gcode += slicer.codeLinearMovement(0, 20, 0.2, 1, 1200);
            gcode += slicer.codeLinearMovement(0, 0, 0.2, 1, 1200);

            console.log('Generated G-code:', gcode);

        </script>
    </body>
</html>
```

## Browser File Loading

```html
<!DOCTYPE html>
<html>
  <head>
    <title>Polyslice File Loading Example</title>

    <!-- Include three.js -->
    <script src="https://unpkg.com/three@0.180.0/build/three.min.js"></script>

    <!-- Include three.js loaders you need -->
    <script type="module">
      import { STLLoader } from 'https://unpkg.com/three@0.180.0/examples/jsm/loaders/STLLoader.js';
      import { OBJLoader } from 'https://unpkg.com/three@0.180.0/examples/jsm/loaders/OBJLoader.js';

      // Make loaders available globally
      window.THREE.STLLoader = STLLoader;
      window.THREE.OBJLoader = OBJLoader;
    </script>

    <!-- Include Polyslice -->
    <script src="https://unpkg.com/@jgphilpott/polyslice/dist/index.browser.min.js"></script>
  </head>
  <body>
    <input type="file" id="fileInput" accept=".stl,.obj,.gltf,.glb">

    <script>
      document.getElementById('fileInput').addEventListener('change', async (e) => {
        const file = e.target.files[0];
        const url = URL.createObjectURL(file);

        // Load the file
        const mesh = await PolysliceLoader.load(url);

        console.log('Loaded mesh:', mesh);

        // Clean up
        URL.revokeObjectURL(url);
      });
    </script>
  </body>
</html>
```

## Example Scripts

Polyslice includes several example scripts demonstrating advanced usage:

### Slice Pillars (`examples/scripts/slice-pillars.js`)

Demonstrates multi-object slicing by creating independent cylindrical pillars in grid patterns.

**Features:**
- Creates grids from 1x1 to 5x5 pillars (1 to 25 independent objects)
- Demonstrates travel path optimization for multiple separate objects
- Exports both STL and G-code files
- Shows mesh merging for proper slicer input

**Usage:**
```bash
npm run compile
node examples/scripts/slice-pillars.js
```

**Output:**
- G-code: `resources/gcode/wayfinding/pillars/`
- STL: `examples/output/`

**Key Concepts:**
- **Multi-object slicing**: The slicer handles multiple independent objects efficiently
- **Travel optimization**: Objects are processed using nearest-neighbor sorting starting from the printer's home position (0, 0)
- **Sequential completion**: When exposure detection is disabled, each object is fully completed (walls + skin/infill) before moving to the next, minimizing travel distance
- **Mesh merging**: Multiple three.js meshes are merged into a single mesh using `BufferGeometryUtils.mergeGeometries()`

**Example Configuration:**
```javascript
const slicer = new Polyslice({
  printer: printer,
  filament: filament,
  shellSkinThickness: 0.4,
  shellWallThickness: 0.8,
  infillPattern: 'grid',
  infillDensity: 50,
  layerHeight: 0.2,
  exposureDetection: false  // Disable for simple objects (faster, sequential completion)
});
```

### Slice Holes (`examples/scripts/slice-holes.js`)

Demonstrates slicing sheets with holes punched in them using CSG operations.

**Features:**
- Creates thin sheets with configurable hole patterns
- Uses CSG (Constructive Solid Geometry) to subtract holes from base geometry
- Tests the slicer's hole detection and avoidance algorithms
- Exports both STL and G-code files

**Usage:**
```bash
npm run compile
node examples/scripts/slice-holes.js
```

**Output:**
- G-code: `resources/gcode/wayfinding/holes/`
- STL: `examples/output/`

**Key Concepts:**
- **Hole detection**: The slicer automatically detects holes using point-in-polygon testing
- **Travel combing**: Travel moves avoid crossing holes to prevent stringing
- **Nested structures**: Handles complex nesting levels (holes within structures within holes)

## Travel Path Optimization

Polyslice includes intelligent travel path optimization to minimize print time and improve quality:

### Independent Objects (Multiple Separate Parts)

When slicing multiple independent objects on the same layer:

1. **Nearest-neighbor sorting**: Objects are processed in order of proximity to minimize travel distance
2. **Home position start**: On the first layer, sorting starts from the printer's home position (0, 0), converting to mesh coordinates
3. **Sequential completion** (when exposure detection is disabled):
   - Each object is fully completed (walls → skin/infill) before moving to the next
   - Minimizes travel moves between objects
   - Prevents zigzag patterns across the build plate

Example: For a 3x3 grid of pillars, the slicer will:
- Start at the pillar closest to home position (0, 0)
- Complete all walls, skin, and infill for that pillar
- Move to the nearest unprocessed pillar
- Repeat until all pillars are complete

### Complex Geometries (Parts with Holes)

When slicing parts with holes or when exposure detection is enabled:

1. **Two-phase processing**:
   - **Phase 1**: Generate walls for all paths (outer boundaries and holes)
   - **Phase 2**: Generate skin and infill using collected hole boundaries for accurate coverage analysis
2. **Hole avoidance**: Travel paths use combing algorithm to avoid crossing holes
3. **Nesting-aware exclusion**: Properly handles nested structures (holes within structures within holes)

### Configuration Impact

The `exposureDetection` setting affects optimization strategy:

```javascript
// For simple independent objects (faster, sequential completion)
const slicer = new Polyslice({
  exposureDetection: false  // Completes each object before moving to next
});

// For complex parts or adaptive skin (accurate, two-phase processing)
const slicer = new Polyslice({
  exposureDetection: true  // Full Phase 2 processing for coverage analysis
});
```

## Related Documentation

- [API Reference](../api/API.md) - Complete API reference
- [File Loading](../loaders/LOADERS.md) - Detailed loader documentation
- [G-code Export](../exporters/EXPORTERS.md) - Saving and streaming G-code
- [Printer Configuration](../config/PRINTER.md) - Available printer profiles
- [Filament Configuration](../config/FILAMENT.md) - Available filament profiles
- [Slicing Algorithm](../slicer/SLICING.md) - Detailed slicing algorithm documentation
