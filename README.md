<p align="center">
    <img width="321" height="321" src="./imgs/logo-lowpoly.png">
</p>

# Polyslice

An [FDM](https://en.wikipedia.org/wiki/Fused_filament_fabrication) [slicer](https://en.wikipedia.org/wiki/Slicer_(3D_printing)) designed specifically for [three.js](https://github.com/mrdoob/three.js) and inspired by the discussion on [this three.js issue](https://github.com/mrdoob/three.js/issues/17981). The idea is to be able to go straight from a mesh in a three.js scene to a machine usable [G-code](https://en.wikipedia.org/wiki/G-code), thus eliminating the need for intermediary file formats and 3rd party slicing software.

<p align="center">
  <a href="https://github.com/jgphilpott/polyslice/actions"><img src="https://github.com/jgphilpott/polyslice/actions/workflows/tests.yml/badge.svg" alt="Polyslice Tests"></a>
  <a href="https://badge.fury.io/js/@jgphilpott%2Fpolyslice"><img src="https://badge.fury.io/js/@jgphilpott%2Fpolyslice.svg" alt="npm version"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT"></a>
</p>

## Installation

### Node.js

```bash
npm install @jgphilpott/polyslice
```

### Browser

```html
<!-- Include three.js first -->
<script src="https://unpkg.com/three@0.180.0/build/three.min.js"></script>

<!-- Include Polyslice -->
<script src="https://unpkg.com/@jgphilpott/polyslice/dist/index.browser.min.js"></script>
```

## Quick Start

### Node.js

```javascript
const Polyslice = require('@jgphilpott/polyslice');

// Create a slicer instance.
const slicer = new Polyslice({
  nozzleTemperature: 200,
  bedTemperature: 60,
  fanSpeed: 100
});

// Generate some G-code.
const gcode = slicer.codeAutohome() +
              slicer.codeNozzleTemperature(200, false) +
              slicer.codeLinearMovement(10, 10, 0.2, 0.1, 1500);

console.log(gcode);
```

### Browser

```javascript
// Polyslice is available as a global variable.
const slicer = new Polyslice({
  nozzleTemperature: 200,
  bedTemperature: 60,
  fanSpeed: 100
});

// Generate some G-code.
const gcode = slicer.codeAutohome() +
              slicer.codeNozzleTemperature(200, false) +
              slicer.codeLinearMovement(10, 10, 0.2, 0.1, 1500);

console.log(gcode);
```

## Features

- 🚀 **Direct three.js integration** - Work directly with three.js meshes and scenes.
- 📝 **Comprehensive G-code generation** - Full set of G-code commands for FDM printing.
- ⚙️ **Configurable parameters** - Temperatures, speeds, units, and more.
- 🌐 **Universal compatibility** - Works in both Node.js and browser environments.
- 🧪 **Well tested** - Comprehensive test suite with Jest.
- 📦 **Multiple formats** - CommonJS, ESM, and browser builds with minification.
- 🔧 **CoffeeScript source** - Clean, readable CoffeeScript codebase.
- 🌐 **Node.js ready** - Designed specifically for Node.js environments.

## About

Currently, if you want to print something you have designed in three.js you need to first export it to an [STL](https://en.wikipedia.org/wiki/STL_(file_format)) or [OBJ](https://en.wikipedia.org/wiki/Wavefront_.obj_file) file, slice that file with another software like [Cura](https://github.com/Ultimaker/Cura) and then transfer the resulting [G-code](https://en.wikipedia.org/wiki/G-code) to your 3D printer. Ideally, you should be able to use a three.js plugin (like Polyslice) to slice the meshes in your scene and send the G-code directly to your 3D printer via [Web Serial API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API).

With this approach the design, slicing and printing process becomes much more seamless! No download or installation is required, the entire process can happen without leaving a web browser. Intermediary file formats become obsolete and G-codes become invisible for the average user.

## API Documentation

### Constructor

```javascript
const slicer = new Polyslice(options);
```

**Options:**

- `autohome` (boolean): Auto-home before slicing (default: true).
- `workspacePlane` (string): XY, XZ, or YZ (default: 'XY').
- `timeUnit` (string): 'milliseconds' or 'seconds' (default: 'milliseconds').
- `lengthUnit` (string): 'millimeters' or 'inches' (default: 'millimeters').
- `temperatureUnit` (string): 'celsius', 'fahrenheit', or 'kelvin' (default: 'celsius').
- `nozzleTemperature` (number): Nozzle temperature (default: 0).
- `bedTemperature` (number): Bed temperature (default: 0).
- `fanSpeed` (number): Fan speed percentage 0-100 (default: 100).

### G-code Generation Methods

```javascript
// Basic Setup
slicer.codeAutohome()                    // G28 - Auto-home all axes.
slicer.codeWorkspacePlane('XY')          // G17/G18/G19 - Set workspace plane.
slicer.codeLengthUnit('millimeters')     // G20/G21 - Set units.

// Temperature Control
slicer.codeNozzleTemperature(200, true)  // M109/M104 - Set nozzle temp.
slicer.codeBedTemperature(60, true)      // M190/M140 - Set bed temp.
slicer.codeFanSpeed(100)                 // M106/M107 - Control fan.

// Movement
slicer.codeLinearMovement(x, y, z, e, f) // G0/G1 - Linear movement.
slicer.codeArcMovement(...)              // G2/G3 - Arc movement.
slicer.codeBézierMovement([...])         // G5 - Bézier curves.

// Utilities
slicer.codeMessage('Hello World!')      // M117 - Display message.
slicer.codeDwell(1000)                  // G4/M0 - Pause/dwell.
slicer.codeWait()                       // M400 - Wait for moves to finish.
```

## Examples

### Basic Usage

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
gcode += slicer.codeLinearMovement(0, 0, 0.2, null, 3000);    // Move to start.
gcode += slicer.codeLinearMovement(10, 0, 0.2, 0.5, 1200);   // Bottom edge.
gcode += slicer.codeLinearMovement(10, 10, 0.2, 0.5, 1200);  // Right edge.
gcode += slicer.codeLinearMovement(0, 10, 0.2, 0.5, 1200);   // Top edge.
gcode += slicer.codeLinearMovement(0, 0, 0.2, 0.5, 1200);    // Left edge.

gcode += slicer.codeAutohome();

console.log(gcode);
```

### Three.js Integration

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

// Basic slicing (simplified).
const layerHeight = 0.2;
const numLayers = Math.ceil(5 / layerHeight);
let gcode = slicer.slice();

// Add layer-by-layer printing logic here ...
```

### Browser Integration

```html
<!DOCTYPE html>
<html>
    <head>
        <title>Polyslice Browser Example</title>
        <script src="https://unpkg.com/three@0.180.0/build/three.min.js"></script>
        <script src="https://unpkg.com/polyslice/dist/index.browser.min.js"></script>
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

## Development

```bash
# Install Dependencies
npm install

# Run Tests
npm test

# Build for Production
npm run build

# Run Examples
node examples/basic.js
node examples/threejs-integration.js
```

## Testing

The project includes comprehensive tests using Jest:

```bash
npm test              # Run all tests.
npm run test:watch    # Run tests in watch mode.
npm run test:coverage # Run tests with coverage.
```

## Building

Multiple build targets are supported:

```bash
npm run build:node     # Node.js builds (CommonJS + ESM).
npm run build:browser  # Browser build (IIFE).
npm run build:cjs      # CommonJS build only.
npm run build:esm      # ES modules build only.
npm run build:minify   # Minified builds.
npm run build          # All builds.
```

## Tools

To assist in designing and testing this slicer I developed a simple mini app called '[Web G-code Sender](https://jgphilpott.github.io/polyslice/serial/browser/sender.html)' for experimenting with G-code and writing/reading printer data via [Web Serial API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API). I recommend taking a look at it if you want to learn G-code or how to remotely control a 3D printer from a web browser.

## Contributing

Contributions are welcome! Please feel free to [Open an Issue](https://github.com/jgphilpott/polyslice/issues) submit a [Pull Request](https://github.com/jgphilpott/polyslice/pulls).

## License

MIT **©** [Jacob Philpott](https://github.com/jgphilpott)
