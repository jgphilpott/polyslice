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
| `progressCallback` | function | Default progress bar | Callback for slicing progress updates (default shows progress bar with in-place updates) |
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

// Build Plate Adhesion
slicer.getAdhesionEnabled();
slicer.setAdhesionEnabled(true);
slicer.getAdhesionType();
slicer.setAdhesionType('skirt');

// Skirt Settings
slicer.getSkirtType();
slicer.setSkirtType('circular');
slicer.getSkirtDistance();
slicer.setSkirtDistance(5);
slicer.getSkirtLineCount();
slicer.setSkirtLineCount(3);

// Brim Settings
slicer.getBrimDistance();
slicer.setBrimDistance(0);
slicer.getBrimLineCount();
slicer.setBrimLineCount(8);

// Raft Settings
slicer.getRaftMargin();
slicer.setRaftMargin(5);
slicer.getRaftBaseThickness();
slicer.setRaftBaseThickness(0.3);
slicer.getRaftInterfaceLayers();
slicer.setRaftInterfaceLayers(2);
slicer.getRaftInterfaceThickness();
slicer.setRaftInterfaceThickness(0.2);
slicer.getRaftAirGap();
slicer.setRaftAirGap(0.2);
slicer.getRaftLineSpacing();
slicer.setRaftLineSpacing(2);

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

### `getGcodeMetadata(gcode = null)`

Extract metadata from G-code and return it as a JSON object.

```javascript
// Extract from slicer.gcode
const metadata = slicer.getGcodeMetadata();

// Or extract from custom G-code string
const customGcode = '...';
const metadata = slicer.getGcodeMetadata(customGcode);
```

**Parameters:**
- `gcode` (String, optional): G-code string to extract metadata from. If omitted, uses `slicer.gcode`.

**Returns:** Object - JSON object containing extracted metadata fields

**Metadata Fields:**

**Common Fields (all slicers):**
- `generatedBy` (String): Slicer name (e.g., "Polyslice", "Cura", "PrusaSlicer", or "Unknown")
- `version` (String): Slicer version number
- `printer` (String): Printer model name
- `layerHeight` (Object): `{value: Number, unit: String}` - Layer height
- `totalLayers` (Number): Total layer count
- `filamentLength` (Object): `{value: Number, unit: String}` - Filament used
- `estimatedPrintTime` (String): Human-readable print time estimate

**Polyslice-specific fields:**
- `timestamp` (String): ISO 8601 timestamp
- `repository` (String): Repository URL
- `filament` (String): Filament name and type
- `nozzleTemp` (Object): `{value: Number, unit: String}` - Nozzle temperature
- `bedTemp` (Object): `{value: Number, unit: String}` - Bed temperature
- `materialVolume` (Object): `{value: Number, unit: String}` - Material volume
- `materialWeight` (Object): `{value: Number, unit: String}` - Material weight
- `flavor` (String): G-code flavor/firmware (e.g., "Marlin")
- `infillDensity` (String): Infill density with percentage (e.g., "30%")
- `infillPattern` (String): Infill pattern type (e.g., "triangles", "hexagons")
- `wallCount` (Number): Number of wall/perimeter lines
- `support` (String): Support enabled status ("Yes" or "No")
- `adhesion` (String): Adhesion type (e.g., "brim", "skirt", "raft", "None")
- `perimeterSpeed` (Object): `{value: Number, unit: String}` - Perimeter print speed
- `infillSpeed` (Object): `{value: Number, unit: String}` - Infill print speed
- `travelSpeed` (Object): `{value: Number, unit: String}` - Travel speed
- `boundingBox` (Object): Bounding box coordinates `{minx, maxx, miny, maxy, minz, maxz}`

**Cura-specific fields:**
- `flavor` (String): G-code flavor (e.g., "Marlin")
- `boundingBox` (Object): Bounding box coordinates `{minx, maxx, miny, maxy, minz, maxz}`

**PrusaSlicer-specific fields:**
- `timestamp` (String): ISO 8601 timestamp
- `materialVolume` (Object): `{value: Number, unit: String}` - Material volume
- `materialWeight` (Object): `{value: Number, unit: String}` - Material weight

**Key Conversions:**
- Keys are converted to camelCase (e.g., "Nozzle Temp" → "nozzleTemp")
- Plain integers: `"50"` → `50`
- Plain floats: `"0.2"` → `0.2`
- Values with units: `"200°C"` → `{value: 200, unit: "°C"}`
- Complex strings preserved: version numbers, timestamps, URLs

**Example:**
```javascript
const THREE = require('three');
const { Polyslice, Printer, Filament } = require('@jgphilpott/polyslice');

const printer = new Printer('Ender3');
const filament = new Filament('GenericPLA');

const slicer = new Polyslice({
  printer: printer,
  filament: filament,
  metadata: true
});

const geometry = new THREE.BoxGeometry(10, 10, 10);
const mesh = new THREE.Mesh(geometry);
const gcode = slicer.slice(mesh);

// Extract metadata
const metadata = slicer.getGcodeMetadata();

console.log(metadata.printer);              // "Ender3"
console.log(metadata.nozzleTemp.value);     // 200
console.log(metadata.nozzleTemp.unit);      // "°C"
console.log(metadata.totalLayers);          // 50 (depends on model)
```

**Handling Missing Metadata:**
```javascript
// Returns empty object {} if no metadata present
const gcodeWithoutMetadata = 'G28\nG0 X10 Y10';
const result = slicer.getGcodeMetadata(gcodeWithoutMetadata);
console.log(result); // {}
```

## Progress Feedback

### `progressCallback`

Get real-time feedback during the slicing process with the `progressCallback` option. This is especially useful for long slices that may take several minutes.

**Default Behavior:**

By default, Polyslice provides a lightweight progress bar that shows real-time updates:

```javascript
// Default callback (automatically included)
// In Node.js: Uses process.stdout.write for in-place updates
// In browsers: Uses console.log for each update
//
// Example output:
// INITIALIZING: [░░░░░░░░░░░░░░░░░░░░] 0% - Starting...
// SLICING: [████████░░░░░░░░░░░░] 40% - Layer 20/50
// COMPLETE: [████████████████████] 100% - G-code generation complete
```

**Callback Signature:**

```javascript
function progressCallback(progressInfo) {
  // progressInfo object contains:
  // - stage: string - Current stage ('initializing', 'pre-print', 'adhesion', 'slicing', 'post-print', 'complete')
  // - percent: number - Overall progress percentage (0-100)
  // - currentLayer: number|null - Current layer being processed (1-based)
  // - totalLayers: number|null - Total number of layers
  // - message: string|null - Optional status message
}
```

**Example with Custom Console Output:**

```javascript
const slicer = new Polyslice({
  progressCallback: (info) => {
    console.log(`${info.stage}: ${info.percent}% - ${info.message || ''}`);
    if (info.currentLayer) {
      console.log(`  Layer ${info.currentLayer}/${info.totalLayers}`);
    }
  }
});

const gcode = slicer.slice(mesh);
```

**Example with Progress Bar:**

```javascript
// Simple text-based progress bar
function createProgressBar(current, total, barLength = 40) {
  const percent = Math.floor((current / total) * 100);
  const filled = Math.floor((current / total) * barLength);
  const empty = barLength - filled;
  const bar = '█'.repeat(filled) + '░'.repeat(empty);
  return `[${bar}] ${percent}%`;
}

const slicer = new Polyslice({
  progressCallback: (info) => {
    if (info.stage === 'slicing' && info.currentLayer) {
      const bar = createProgressBar(info.currentLayer, info.totalLayers);
      process.stdout.write(`\r${info.stage.toUpperCase()}: ${bar} - Layer ${info.currentLayer}/${info.totalLayers}`);
    } else {
      const bar = createProgressBar(info.percent, 100);
      process.stdout.write(`\r${info.stage.toUpperCase()}: ${bar} - ${info.message || ''}`);
    }
  }
});
```

**Progress Stages:**

| Stage | Description | Percent Range |
|-------|-------------|---------------|
| `initializing` | Preparing mesh and setup | 0% |
| `pre-print` | Generating pre-print sequence (heating, homing) | 5% |
| `adhesion` | Generating adhesion structures (if enabled) | 10% |
| `slicing` | Processing layers (walls, infill, skin) | 15-85% |
| `post-print` | Generating post-print sequence (cooling, homing) | 90% |
| `complete` | G-code generation complete | 100% |

**Getter and Setter:**

```javascript
// Get current callback
const callback = slicer.getProgressCallback();

// Set or update callback
slicer.setProgressCallback((info) => {
  console.log(`Progress: ${info.percent}%`);
});

// Disable progress reporting (set to null)
slicer.setProgressCallback(null);
```

**Error Handling:**

The slicer automatically catches and logs any errors thrown by the progress callback to prevent disrupting the slicing process. If your callback throws an error, slicing will continue normally.

**Disabling Progress Output:**

To disable all progress output, set the callback to `null`:

```javascript
const slicer = new Polyslice({
  progressCallback: null  // No progress output
});
```

**See Also:**
- [Progress Example Script](../../examples/scripts/progress-example.js) - Complete working example with progress bar

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
