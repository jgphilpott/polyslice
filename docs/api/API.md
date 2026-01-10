# API Reference

This document provides a complete API reference for Polyslice.

## Constructor

```javascript
const slicer = new Polyslice(options);
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `autohome` | boolean | `true` | Auto-home before slicing |
| `workspacePlane` | string | `'XY'` | Workspace plane: 'XY', 'XZ', or 'YZ' |
| `timeUnit` | string | `'milliseconds'` | Time unit: 'milliseconds' or 'seconds' |
| `lengthUnit` | string | `'millimeters'` | Length unit: 'millimeters' or 'inches' |
| `temperatureUnit` | string | `'celsius'` | Temperature unit: 'celsius', 'fahrenheit', or 'kelvin' |
| `nozzleTemperature` | number | `0` | Nozzle temperature |
| `bedTemperature` | number | `0` | Bed temperature |
| `fanSpeed` | number | `100` | Fan speed percentage 0-100 |
| `exposureDetection` | boolean | `true` | Enable adaptive skin layer generation |
| `exposureDetectionResolution` | number | `961` | Sample count for exposure detection (31×31 grid) |
| `wipeNozzle` | boolean | `true` | Perform wipe move during post-print |
| `smartWipeNozzle` | boolean | `true` | Use smart wipe (avoids mesh) vs simple X+5, Y+5 |
| `buzzer` | boolean | `true` | Sound buzzer at end of print |
| `printer` | Printer | `null` | Printer instance for automatic configuration |
| `filament` | Filament | `null` | Filament instance for automatic configuration |

## Automatic Configuration

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

### Configuration Priority

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

## Getters and Setters

All configuration options have corresponding getter and setter methods:

```javascript
// Temperature
slicer.getNozzleTemperature();
slicer.setNozzleTemperature(210);
slicer.getBedTemperature();
slicer.setBedTemperature(60);

// Fan
slicer.getFanSpeed();
slicer.setFanSpeed(100);

// Build plate
slicer.getBuildPlateWidth();
slicer.setBuildPlateWidth(220);
slicer.getBuildPlateLength();
slicer.setBuildPlateLength(220);

// Nozzle
slicer.getNozzleDiameter();
slicer.setNozzleDiameter(0.4);
slicer.getFilamentDiameter();
slicer.setFilamentDiameter(1.75);

// Retraction
slicer.getRetractionDistance();
slicer.setRetractionDistance(5);
slicer.getRetractionSpeed();
slicer.setRetractionSpeed(45);

// Speed
slicer.getTravelSpeed();
slicer.setTravelSpeed(150);
slicer.getPerimeterSpeed();
slicer.setPerimeterSpeed(45);
slicer.getInfillSpeed();
slicer.setInfillSpeed(60);

// Layer
slicer.getLayerHeight();
slicer.setLayerHeight(0.2);

// Shell
slicer.getShellWallThickness();
slicer.setShellWallThickness(0.8);
slicer.getShellSkinThickness();
slicer.setShellSkinThickness(0.8);

// Infill
slicer.getInfillDensity();
slicer.setInfillDensity(20);
slicer.getInfillPattern();
slicer.setInfillPattern('grid');

// Exposure detection
slicer.getExposureDetection();
slicer.setExposureDetection(true);
slicer.getExposureDetectionResolution();
slicer.setExposureDetectionResolution(961);

// Post-print settings
slicer.getWipeNozzle();
slicer.setWipeNozzle(true);
slicer.getSmartWipeNozzle();
slicer.setSmartWipeNozzle(true);
slicer.getBuzzer();
slicer.setBuzzer(true);

// Printer and Filament
slicer.getPrinter();
slicer.setPrinter(new Printer('Ender3'));
slicer.getFilament();
slicer.setFilament(new Filament('GenericPLA'));
```

## Slicing

### `slice(mesh)`

Generate G-code from a three.js mesh.

```javascript
const gcode = slicer.slice(mesh);
```

**Parameters:**
- `mesh` (THREE.Mesh): The mesh to slice

**Returns:** String - The generated G-code

**Important Behaviors:**
- **Non-destructive**: The original mesh is not modified. Position, rotation, scale, and geometry remain unchanged.
- **Automatic centering**: The mesh is automatically centered on the build plate based on its bounding box, regardless of its world position.
- **Cloning**: Internally creates a clone of the mesh (including geometry) for all transformations.

**Example:**
```javascript
const mesh = new THREE.Mesh(geometry, material);
mesh.position.set(100, 200, 50); // Any world position

const gcode = slicer.slice(mesh);

// Original mesh unchanged:
console.log(mesh.position.z); // Still 50
console.log(mesh.geometry.boundingBox); // Still null if not computed before

// Print will be centered on build plate in G-code
```

## G-code Generation Methods

See [GCODE.md](../slicer/gcode/GCODE.md) for the complete G-code generation reference.

### Quick Reference

```javascript
// Basic Setup
slicer.codeAutohome()                    // G28 - Auto-home all axes
slicer.codeWorkspacePlane('XY')          // G17/G18/G19 - Set workspace plane
slicer.codeLengthUnit('millimeters')     // G20/G21 - Set units

// Temperature Control
slicer.codeNozzleTemperature(200, true)  // M109/M104 - Set nozzle temp
slicer.codeBedTemperature(60, true)      // M190/M140 - Set bed temp
slicer.codeFanSpeed(100)                 // M106/M107 - Control fan

// Movement
slicer.codeLinearMovement(x, y, z, e, f) // G0/G1 - Linear movement
slicer.codeArcMovement(...)              // G2/G3 - Arc movement
slicer.codeBézierMovement([...])         // G5 - Bézier curves

// Utilities
slicer.codeMessage('Hello World!')       // M117 - Display message
slicer.codeDwell(1000)                   // G4/M0 - Pause/dwell
slicer.codeWait()                        // M400 - Wait for moves to finish
```

## Related Documentation

- [Printer Configuration](../config/PRINTER.md) - Pre-configured printer profiles
- [Filament Configuration](../config/FILAMENT.md) - Pre-configured filament profiles
- [G-code Generation](../slicer/gcode/GCODE.md) - Complete G-code reference
- [File Loading](../loaders/LOADERS.md) - Loading 3D models
- [G-code Export](../exporters/EXPORTERS.md) - Saving and streaming G-code
