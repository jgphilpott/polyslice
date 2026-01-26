<p align="center">
    <img width="300" height="300" src="./imgs/logo-lowpoly.png">
</p>

<p align="center">
  <a href="https://github.com/jgphilpott/polyslice/actions"><img src="https://github.com/jgphilpott/polyslice/actions/workflows/tests.yml/badge.svg" alt="Polyslice Tests"></a>
  <a href="https://badge.fury.io/js/@jgphilpott%2Fpolyslice"><img src="https://badge.fury.io/js/@jgphilpott%2Fpolyslice.svg" alt="npm version"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT"></a>
</p>

# Polyslice

An AI powered [slicer](https://en.wikipedia.org/wiki/Slicer_(3D_printing)) designed specifically for the [three.js](https://github.com/mrdoob/three.js) ecosystem and inspired by the discussion on [this issue](https://github.com/mrdoob/three.js/issues/17981). The idea is to be able to go straight from a three.js mesh to a machine usable [G-code](https://en.wikipedia.org/wiki/G-code), thus eliminating the need for intermediary file formats and 3rd party slicing software.

[Polyslice](https://jgphilpott.github.io/polyslice) is designed to streamline and automate the 3D printing workflow. Whether you're designing models in three.js or loading existing STL, OBJ, or other 3D files, Polyslice can process them and generate machine ready G-code. With built-in support for popular printers/filaments and the ability to send G-code directly to your 3D printer via [Web Serial API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API) or [serialport](https://www.npmjs.com/package/serialport), the entire design-to-print workflow becomes seamless and programmable. It can work in both a web browser or Node.js environment, this makes 3D printing more accessible and eliminates the friction of using multiple tools.

<p align="center">
  <br><em>Click the image below to watch the demo video on YouTube:</em><br>
  <a href="https://www.youtube.com/watch?v=V2h3SiafXRc">
    <img src="https://raw.githubusercontent.com/jgphilpott/jgphilpott/main/imgs/social/light/youtube.png" alt="Polyslice Demo Video" width="72">
  </a>
</p>

## Installation

### Node

```bash
npm install @jgphilpott/polyslice
```

### Browser

```html
<!-- Include three.js first -->
<script src="https://unpkg.com/three@0.180.0/build/three.min.js"></script>

<!-- Include Polyslice next -->
<script src="https://unpkg.com/@jgphilpott/polyslice/dist/index.browser.min.js"></script>
```

## Quick Start

Here is a simple example to get you started:

```javascript
// Require THREE, Polyslice, Printer and Filament (omit for browser)
const THREE = require("three");
const { Polyslice, Printer, Filament } = require("@jgphilpott/polyslice");

// Create the printer and filament objects
const printer = new Printer("Ender3");
const filament = new Filament("GenericPLA");

// Create the slicer instance with the printer, filament and other configs
const slicer = new Polyslice({
  printer: printer,
  filament: filament,
  infillPattern: "triangles",
  infillDensity: 30,
  testStrip: true,
  verbose: true
});

// Create a 1cm cube (10mm x 10mm x 10mm)
const geometry = new THREE.BoxGeometry(10, 10, 10);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const cube = new THREE.Mesh(geometry, material);

// Slice the cube and generate the G-code
const gcode = slicer.slice(cube);
```

**To run this example locally follow these steps:**

1) Clone the Polyslice repo: `git clone git@github.com:jgphilpott/polyslice.git`
2) Navigate into the repo directory: `cd polyslice`
3) Install the node modules: `npm install`
4) Compile the code: `npm run compile`
5) Run the example script: `node examples/scripts/quick-start.js`

## Features

Polyslice provides a comprehensive set of features for the 3D printing workflow:

| Feature | Description | Documentation |
|---------|-------------|---------------|
| 🚀 **Direct three.js integration** | Work directly with three.js meshes and scenes | [Examples](docs/examples/EXAMPLES.md) |
| 📁 **File format support** | STL, OBJ, 3MF, AMF, PLY, GLTF/GLB, Collada | [Loaders](docs/loaders/LOADERS.md) |
| 📝 **G-code generation** | Full set of G-code commands with configurable precision | [G-code](docs/slicer/gcode/GCODE.md) |
| 📊 **Print statistics** | Automatic calculation of filament usage, material weight, and print time | [G-code](docs/slicer/gcode/GCODE.md) |
| ⚙️ **Printer profiles** | 44 pre-configured printer profiles | [Printer Config](docs/config/PRINTER.md) |
| 🧵 **Filament profiles** | 35 pre-configured filament profiles | [Filament Config](docs/config/FILAMENT.md) |
| 🔲 **Infill patterns** | Grid, triangles and hexagons patterns (more coming) | [Infill](docs/slicer/infill/INFILL.md) |
| 🧱 **Wall generation** | Configurable wall thickness | [Walls](docs/slicer/walls/WALLS.md) |
| 🎨 **Skin layers** | Top/bottom solid layers with exposure detection | [Skin](docs/slicer/skin/SKIN.md) |
| 🏗️ **Support structures** | Automatic support generation | [Support](docs/slicer/support/SUPPORT.md) |
| 🔗 **Build plate adhesion** | Skirt, brim, and raft support for first-layer stability | [Adhesion](docs/slicer/adhesion/ADHESION.md) |
| 🔌 **Serial streaming** | Send G-code directly to printers | [Exporters](docs/exporters/EXPORTERS.md) |
| 📏 **Precision control** | Optimize file size with configurable precision (20-30% reduction) | [G-code](docs/slicer/gcode/GCODE.md) |
| 🌐 **Universal** | Works in Node.js and browsers | [API](docs/api/API.md) |

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
