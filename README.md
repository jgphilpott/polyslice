<p align="center">
    <img width="321" height="321" src="./imgs/logo-lowpoly.png">
</p>

<p align="center">
  <a href="https://github.com/jgphilpott/polyslice/actions"><img src="https://github.com/jgphilpott/polyslice/actions/workflows/tests.yml/badge.svg" alt="Polyslice Tests"></a>
  <a href="https://badge.fury.io/js/@jgphilpott%2Fpolyslice"><img src="https://badge.fury.io/js/@jgphilpott%2Fpolyslice.svg" alt="npm version"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT"></a>
</p>

# Polyslice

An [FDM](https://en.wikipedia.org/wiki/Fused_filament_fabrication) [slicer](https://en.wikipedia.org/wiki/Slicer_(3D_printing)) designed specifically for [three.js](https://github.com/mrdoob/three.js) and inspired by the discussion on [this three.js issue](https://github.com/mrdoob/three.js/issues/17981). The idea is to be able to go straight from a mesh in a three.js scene to a machine usable [G-code](https://en.wikipedia.org/wiki/G-code), thus eliminating the need for intermediary file formats and 3rd party slicing software.

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
- `printer` (Printer): Printer instance for automatic configuration (default: null).
- `filament` (Filament): Filament instance for automatic configuration (default: null).

**Using Printer and Filament for Automatic Configuration:**

When you provide `printer` and/or `filament` instances, the slicer automatically configures itself with optimal settings:

```javascript
const { Polyslice, Printer, Filament } = require('@jgphilpott/polyslice');

// Automatic configuration from printer and filament
const slicer = new Polyslice({
  printer: new Printer('Ender3'),
  filament: new Filament('GenericPLA')
});
// Automatically sets: build plate size, nozzle diameter, temperatures, retraction, etc.
```

**Configuration Priority:**

Settings are applied in this order (highest priority first):
1. Custom options you provide
2. Filament settings
3. Printer settings
4. Default values

```javascript
// Custom bedTemperature overrides filament setting
const slicer = new Polyslice({
  printer: new Printer('Ender3'),
  filament: new Filament('GenericPLA'),
  bedTemperature: 0  // Overrides filament's 60°C bed temperature
});
```

### Printer Configuration

The `Printer` class provides pre-configured settings for popular 3D printers, simplifying the setup process.

```javascript
const { Printer } = require('@jgphilpott/polyslice');

// Create a printer instance.
const printer = new Printer('Ender3');

// Get printer specifications.
console.log(printer.getSize());        // { x: 220, y: 220, z: 250 }
console.log(printer.getNozzle(0));     // { filament: 1.75, diameter: 0.4, gantry: 25 }
console.log(printer.getHeatedBed());   // true

// Modify printer settings.
printer.setSizeX(250);
printer.setNozzle(0, 1.75, 0.6, 30);

// List all available printers.
console.log(printer.listAvailablePrinters());
```

**Available Printers (44 total):**

- **Creality Ender series**: `Ender3`, `Ender3V2`, `Ender3Pro`, `Ender3S1`, `Ender5`, `Ender6`
- **Creality large format**: `CR10`, `CR10S5`, `CR6SE`
- **Creality high-speed**: `CrealityK1`, `CrealityK1Max` (enclosed)
- **Prusa Research**: `PrusaI3MK3S`, `PrusaMini`, `PrusaXL`, `PrusaMK4`
- **Bambu Lab**: `BambuLabX1Carbon`, `BambuLabP1P`, `BambuLabA1`, `BambuLabA1Mini`
- **Anycubic**: `AnycubicI3Mega`, `AnycubicKobra`, `AnycubicVyper`, `AnycubicPhotonMonoX`
- **Elegoo Neptune**: `ElegooNeptune3`, `ElegooNeptune3Pro`, `ElegooNeptune4`, `ElegooNeptune4Pro`
- **Artillery**: `ArtillerySidewinderX1`, `ArtillerySidewinderX2`, `ArtilleryGenius`
- **Sovol**: `SovolSV06`, `SovolSV06Plus`
- **Others**: `Voron24`, `UltimakerS5`, `FlashForgeCreatorPro`, `FlashforgeAdventurer3`, `Raise3DPro2`, `MakerbotReplicatorPlus`, `QidiXPlus`, `MonopriceSelectMiniV2`, `LulzBotMini2`, `LulzBotTAZ6`, `KingroonKP3S`, `AnkerMakeM5`

**Printer Properties:**

- `size` (object): Build volume dimensions `{ x, y, z }` in millimeters
- `shape` (string): Build plate shape - 'rectangular' or 'circular'
- `centred` (boolean): Whether origin is at center or corner
- `heated` (object): Heating capabilities `{ volume, bed }`
- `nozzles` (array): Array of nozzle configurations with `filament`, `diameter`, and `gantry` properties

### Filament Configuration

The `Filament` class provides pre-configured settings for popular 3D printing filaments, including temperature, retraction, and material properties.

```javascript
const { Filament } = require('@jgphilpott/polyslice');

// Create a filament instance.
const filament = new Filament('GenericPLA');

// Get filament properties.
console.log(filament.getType());              // 'pla'
console.log(filament.getNozzleTemperature()); // 200
console.log(filament.getBedTemperature());    // 60
console.log(filament.getFan());               // 100
console.log(filament.getRetractionDistance());// 5

// Modify filament settings.
filament.setNozzleTemperature(210);
filament.setFan(80);

// List all available filaments.
console.log(filament.listAvailableFilaments());
```

**Available Filaments (35 total):**

- **Generic Materials**: `GenericPLA`, `GenericPETG`, `GenericABS`, `GenericTPU`, `GenericNylon`, `GenericASA`
- **PLA Brands**: `HatchboxPLA`, `eSunPLAPlus`, `OverturePLA`, `PrusamentPLA`, `PolymakerPolyLitePLA`, `PolymakerPolyTerraPLA`, `PolymakerPolyMaxPLA`, `BambuLabPLABasic`, `BambuLabPLAMatte`, `SunluPLA`, `ColorFabbPLAPHA`
- **PETG Brands**: `PrusamentPETG`, `PrusaPETG`, `BambuLabPETGHF`, `PolymakerPolyLitePETG`, `eSunPETG`, `OverturePETG`, `HatchboxPETG`, `SunluPETG`, `ColorFabbNGen`
- **ABS Brands**: `BambuLabABS`, `eSunABSPlus`, `HatchboxABS`
- **Flexible (TPU)**: `NinjaFlexTPU`, `SainSmartTPU`, `PolymakerPolyFlexTPU95`
- **Engineering**: `3DXTechCarbonX` (carbon fiber nylon)
- **2.85mm Diameter**: `UltimakerPLA`, `UltimakerToughPLA`

**Filament Properties:**

- `type` (string): Material type - 'pla', 'petg', 'abs', 'tpu', 'nylon', etc.
- `name` (string): Full product name
- `brand` (string): Manufacturer/brand name
- `diameter` (number): Filament diameter in mm (1.75 or 2.85)
- `density` (number): Material density in g/cm³
- `temperature` (object): Temperatures `{ bed, nozzle, standby }` in Celsius
- `retraction` (object): Retraction settings `{ speed, distance }`
- `fan` (number): Recommended fan speed percentage (0-100)
- `color` (string): Hex color code
- `weight` (number): Spool weight in grams
- `cost` (number): Cost per spool

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
slicer.codeMessage('Hello World!')       // M117 - Display message.
slicer.codeDwell(1000)                   // G4/M0 - Pause/dwell.
slicer.codeWait()                        // M400 - Wait for moves to finish.
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
gcode += slicer.codeLinearMovement(0, 0, 0.2, null, 3000);  // Move to start.
gcode += slicer.codeLinearMovement(10, 0, 0.2, 0.5, 1200);  // Bottom edge.
gcode += slicer.codeLinearMovement(10, 10, 0.2, 0.5, 1200); // Right edge.
gcode += slicer.codeLinearMovement(0, 10, 0.2, 0.5, 1200);  // Top edge.
gcode += slicer.codeLinearMovement(0, 0, 0.2, 0.5, 1200);   // Left edge.

gcode += slicer.codeAutohome();

console.log(gcode);
```

### Using Printer Configurations

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

### Using Printer and Filament Configurations

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
npm run build:node    # Node.js builds (CommonJS + ESM).
npm run build:browser # Browser build (IIFE).
npm run build:cjs     # CommonJS build only.
npm run build:esm     # ES modules build only.
npm run build:minify  # Minified builds.
npm run build         # All builds.
```

## Tools

### G-code Visualizer

A browser-based tool to visualize G-code files in 3D using Three.js. This tool helps with debugging and testing G-code generated by Polyslice (or any other slicer).

**[Open G-code Visualizer](https://jgphilpott.github.io/polyslice/examples/visualizer/visualizer.html)**

Features:
- 📊 **3D Visualization** - View G-code tool paths in interactive 3D
- 🎨 **Color-coded movements** - Different colors for travel (G0), extrusion (G1), and arc (G2/G3) moves
- 🎮 **Orbit controls** - Rotate, zoom, and pan to inspect from any angle
- 📈 **Statistics** - View line counts and movement type breakdowns
- 📁 **File upload** - Drag and drop any G-code file to visualize

See the [visualizer documentation](examples/visualizer/README.md) for more details.

### Web G-code Sender

A simple mini app for experimenting with G-code and writing/reading printer data via [Web Serial API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API).

**[Open Web G-code Sender](https://jgphilpott.github.io/polyslice/serial/browser/sender.html)**

This tool allows you to send G-code directly to your 3D printer via USB or Bluetooth serial connection, making it perfect for testing and learning G-code commands.

## Contributing

Contributions are welcome! Please feel free to [Open an Issue](https://github.com/jgphilpott/polyslice/issues) submit a [Pull Request](https://github.com/jgphilpott/polyslice/pulls).

## License

MIT **©** [Jacob Philpott](https://github.com/jgphilpott)
