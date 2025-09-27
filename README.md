<p align="center">
    <img width="333" height="333" src="https://raw.githubusercontent.com/jgphilpott/polyslice/refs/heads/main/imgs/favicon/black.png">
</p>

# Polyslice

An [FDM](https://en.wikipedia.org/wiki/Fused_filament_fabrication) [slicer](https://en.wikipedia.org/wiki/Slicer_(3D_printing)) designed specifically for [three.js](https://github.com/mrdoob/three.js) and inspired by the discussion on [this three.js issue](https://github.com/mrdoob/three.js/issues/17981). The idea is to be able to go straight from a mesh in a three.js scene to a machine usable [G-code](https://en.wikipedia.org/wiki/G-code), thus eliminating the need for intermediary file formats and 3rd party slicing software.

[![npm version](https://badge.fury.io/js/polyslice.svg)](https://badge.fury.io/js/polyslice)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js CI](https://github.com/jgphilpott/polyslice/workflows/Node.js%20CI/badge.svg)](https://github.com/jgphilpott/polyslice/actions)

## Installation

```bash
npm install polyslice three
```

## Quick Start

```javascript
const Polyslice = require('polyslice');

// Create a slicer instance
const slicer = new Polyslice({
  nozzleTemperature: 200,
  bedTemperature: 60,
  fanSpeed: 100
});

// Generate some G-code
const gcode = slicer.codeAutohome() + 
             slicer.codeNozzleTemperature(200, false) +
             slicer.codeLinearMovement(10, 10, 0.2, 0.1, 1500);

console.log(gcode);
```

## Features

- 🚀 **Direct three.js integration** - Work directly with three.js meshes and scenes
- 📝 **Comprehensive G-code generation** - Full set of G-code commands for FDM printing
- ⚙️ **Configurable parameters** - Temperatures, speeds, units, and more
- 🔧 **TypeScript support** - Full TypeScript definitions included
- 🧪 **Well tested** - Comprehensive test suite with Jest
- 📦 **Multiple formats** - CommonJS, ESM, and minified builds
- 🌐 **Node.js ready** - Designed specifically for Node.js environments

## About

Currently, if you want to print something you have designed in three.js you need to first export it to an [STL](https://en.wikipedia.org/wiki/STL_(file_format)) or [OBJ](https://en.wikipedia.org/wiki/Wavefront_.obj_file) file, slice that file with another software like [Cura](https://github.com/Ultimaker/Cura) and then transfer the resulting [G-code](https://en.wikipedia.org/wiki/G-code) to your 3D printer. Ideally, you should be able to use a three.js plugin to slice the meshes in your scene and send the G-code directly to your 3D printer via [Web Serial API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API).

With this approach the design, slicing and printing process becomes much more seamless! No download or installation is required, the entire process can happen without leaving a web browser. Intermediary file formats become obsolete and G-codes become invisible for the average user.

## API Documentation

### Constructor

```javascript
const slicer = new Polyslice(options);
```

**Options:**
- `autohome` (boolean): Auto-home before slicing (default: true)
- `workspacePlane` (string): XY, XZ, or YZ (default: 'XY')  
- `timeUnit` (string): 'milliseconds' or 'seconds' (default: 'milliseconds')
- `lengthUnit` (string): 'millimeters' or 'inches' (default: 'millimeters')
- `temperatureUnit` (string): 'celsius', 'fahrenheit', or 'kelvin' (default: 'celsius')
- `nozzleTemperature` (number): Nozzle temperature (default: 0)
- `bedTemperature` (number): Bed temperature (default: 0)
- `fanSpeed` (number): Fan speed percentage 0-100 (default: 100)

### G-code Generation Methods

```javascript
// Basic setup
slicer.codeAutohome()                    // G28 - Auto-home all axes
slicer.codeWorkspacePlane('XY')          // G17/G18/G19 - Set workspace plane
slicer.codeLengthUnit('millimeters')     // G20/G21 - Set units

// Temperature control  
slicer.codeNozzleTemperature(200, true)  // M109/M104 - Set nozzle temp
slicer.codeBedTemperature(60, true)      // M190/M140 - Set bed temp
slicer.codeFanSpeed(100)                 // M106/M107 - Control fan

// Movement
slicer.codeLinearMovement(x, y, z, e, f) // G0/G1 - Linear movement
slicer.codeArcMovement(...)              // G2/G3 - Arc movement
slicer.codeBézierMovement([...])         // G5 - Bézier curves

// Utilities
slicer.codeMessage('Hello World!')      // M117 - Display message
slicer.codeDwell(1000)                  // G4/M0 - Pause/dwell
slicer.codeWait()                       // M400 - Wait for moves to finish
```

## Examples

### Basic Usage

```javascript
const Polyslice = require('polyslice');

const slicer = new Polyslice({
  nozzleTemperature: 210,
  bedTemperature: 60,
  fanSpeed: 80
});

// Print a simple square
let gcode = '';
gcode += slicer.codeAutohome();
gcode += slicer.codeNozzleTemperature(210, true);
gcode += slicer.codeBedTemperature(60, true);

// Draw square perimeter  
gcode += slicer.codeLinearMovement(0, 0, 0.2, null, 3000);    // Move to start
gcode += slicer.codeLinearMovement(10, 0, 0.2, 0.5, 1200);   // Bottom edge
gcode += slicer.codeLinearMovement(10, 10, 0.2, 0.5, 1200);  // Right edge  
gcode += slicer.codeLinearMovement(0, 10, 0.2, 0.5, 1200);   // Top edge
gcode += slicer.codeLinearMovement(0, 0, 0.2, 0.5, 1200);    // Left edge

gcode += slicer.codeAutohome();
console.log(gcode);
```

### Three.js Integration

```javascript
const Polyslice = require('polyslice');
const THREE = require('three');

// Create three.js scene
const scene = new THREE.Scene();
const geometry = new THREE.BoxGeometry(20, 20, 5);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const cube = new THREE.Mesh(geometry, material);
scene.add(cube);

// Create slicer and generate G-code
const slicer = new Polyslice({
  nozzleTemperature: 210,
  bedTemperature: 60
});

// Basic slicing (simplified)
const layerHeight = 0.2;
const numLayers = Math.ceil(5 / layerHeight);
let gcode = slicer.slice(); // Basic initialization

// Add layer-by-layer printing logic here...
```

## Development

```bash
# Install dependencies
npm install

# Run tests
npm test

# Build for production
npm run build

# Run examples
node examples/basic.js
node examples/threejs-integration.js
```

## Testing

The project includes comprehensive tests using Jest:

```bash
npm test              # Run all tests
npm run test:watch    # Run tests in watch mode  
npm run test:coverage # Run tests with coverage
```

## Building

Multiple build targets are supported:

```bash
npm run build:cjs     # CommonJS build
npm run build:esm     # ES modules build  
npm run build:minify  # Minified build
npm run build         # All builds
```

## Tools

To assist in designing and testing this slicer I developed a simple mini app called '[Web G-code Sender](https://jgphilpott.github.io/polyslice/serial/browser/sender.html)' for experimenting with G-code and writing/reading printer data via [Web Serial API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API). I recommend taking a look at it if you want to learn G-code or how to remotely control a 3D printer from a web browser.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT © [Jacob Philpott](https://github.com/jgphilpott)
