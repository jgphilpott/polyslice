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

## Related Documentation

- [API Reference](../api/API.md) - Complete API reference
- [File Loading](../loaders/LOADERS.md) - Detailed loader documentation
- [G-code Export](../exporters/EXPORTERS.md) - Saving and streaming G-code
- [Printer Configuration](../config/PRINTER.md) - Available printer profiles
- [Filament Configuration](../config/FILAMENT.md) - Available filament profiles
