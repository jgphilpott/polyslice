<p align="center">
    <img width="321" height="321" src="./imgs/logo-lowpoly.png">
</p>

<p align="center">
  <a href="https://github.com/jgphilpott/polyslice/actions"><img src="https://github.com/jgphilpott/polyslice/actions/workflows/tests.yml/badge.svg" alt="Polyslice Tests"></a>
  <a href="https://badge.fury.io/js/@jgphilpott%2Fpolyslice"><img src="https://badge.fury.io/js/@jgphilpott%2Fpolyslice.svg" alt="npm version"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT"></a>
</p>

# Polyslice

An AI powered [slicer](https://en.wikipedia.org/wiki/Slicer_(3D_printing)) designed specifically for [three.js](https://github.com/mrdoob/three.js) and inspired by the discussion on [this three.js issue](https://github.com/mrdoob/three.js/issues/17981). The idea is to be able to go straight from a mesh in a three.js scene to a machine usable [G-code](https://en.wikipedia.org/wiki/G-code), thus eliminating the need for intermediary file formats and 3rd party slicing software.

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

Polyslice provides a comprehensive set of features for 3D printing:

| Feature | Description | Documentation |
|---------|-------------|---------------|
| 🚀 **Direct three.js integration** | Work directly with three.js meshes and scenes | [Examples](docs/examples/EXAMPLES.md) |
| 📁 **File format support** | STL, OBJ, 3MF, AMF, PLY, GLTF/GLB, Collada | [Loaders](docs/loaders/LOADERS.md) |
| 📝 **G-code generation** | Full set of G-code commands for FDM printing | [G-code](docs/slicer/gcode/GCODE.md) |
| ⚙️ **Printer profiles** | 44 pre-configured printer profiles | [Printer Config](docs/config/PRINTER.md) |
| 🧵 **Filament profiles** | 35 pre-configured filament profiles | [Filament Config](docs/config/FILAMENT.md) |
| 🔲 **Infill patterns** | Grid, triangles, hexagons patterns | [Infill](docs/slicer/infill/INFILL.md) |
| 🧱 **Wall generation** | Configurable wall thickness | [Walls](docs/slicer/walls/WALLS.md) |
| 🎨 **Skin layers** | Top/bottom solid layers with exposure detection | [Skin](docs/slicer/skin/SKIN.md) |
| 🏗️ **Support structures** | Automatic support generation | [Support](docs/slicer/support/SUPPORT.md) |
| 🔌 **Serial streaming** | Send G-code directly to printers | [Exporters](docs/exporters/EXPORTERS.md) |
| 🌐 **Universal** | Works in Node.js and browsers | [API](docs/api/API.md) |

## About

Polyslice is designed to streamline the 3D printing workflow by integrating directly with three.js. Whether you're designing models in three.js or loading existing STL, OBJ, or other 3D files, Polyslice can process them and generate G-code without the need for separate slicing software like [Cura](https://github.com/Ultimaker/Cura).

With built-in support for popular 3D file formats and the ability to send G-code directly to your 3D printer via [Web Serial API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API), the entire design-to-print workflow can happen seamlessly in a web browser or Node.js environment. This makes 3D printing more accessible and eliminates the friction of using multiple tools.

## Documentation

For detailed documentation, see the [docs folder](docs/README.md):

- [API Reference](docs/api/API.md) - Complete API documentation
- [Examples](docs/examples/EXAMPLES.md) - Practical usage examples
- [Development Guide](docs/development/DEVELOPMENT.md) - Contributing and development
- [Tools](docs/tools/TOOLS.md) - G-code visualizer and sender

## Contributing

Contributions are welcome! Please feel free to [Open an Issue](https://github.com/jgphilpott/polyslice/issues) or submit a [Pull Request](https://github.com/jgphilpott/polyslice/pulls).

## License

MIT **©** [Jacob Philpott](https://github.com/jgphilpott)
