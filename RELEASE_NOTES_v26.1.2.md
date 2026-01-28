# Release v26.1.2

## Release Date
January 28, 2026

## Highlights

This release adds **comprehensive metadata and progress tracking** capabilities to Polyslice, including G-code metadata extraction, configurable metadata headers, progress callbacks, and print time calculation.

## New Features

### 1. G-code Metadata Extraction (`getGcodeMetadata()`)

Extract metadata from G-code files with automatic multi-slicer support:

```javascript
// Extract from slicer's internal G-code
const metadata = slicer.getGcodeMetadata();

// Or extract from any G-code string
const customGcode = fs.readFileSync('print.gcode', 'utf8');
const metadata = slicer.getGcodeMetadata(customGcode);

console.log(metadata.printer);              // "Ender3"
console.log(metadata.nozzleTemp.value);     // 200
console.log(metadata.nozzleTemp.unit);      // "°C"
console.log(metadata.totalLayers);          // 50
console.log(metadata.filamentLength.value); // 1234.5
console.log(metadata.filamentLength.unit);  // "mm"
```

**Supported Slicers:**
- ✅ Polyslice (native)
- ✅ Cura / Ultimaker Cura
- ✅ PrusaSlicer
- ✅ Generic G-code (fallback parser)

**Extracted Metadata Fields:**

**Common Fields (all slicers):**
- `generatedBy` - Slicer name
- `version` - Slicer version
- `printer` - Printer model
- `layerHeight` - Layer height with units
- `totalLayers` - Layer count
- `filamentLength` - Filament used with units
- `estimatedPrintTime` - Print time estimate

**Polyslice-specific Fields:**
- `timestamp` - ISO 8601 timestamp
- `repository` - Repository URL
- `filament` - Filament name and type
- `nozzleTemp` - Nozzle temperature with units
- `bedTemp` - Bed temperature with units
- `materialVolume` - Material volume with units
- `materialWeight` - Material weight with units
- `flavor` - G-code flavor (e.g., "Marlin")
- `infillDensity` - Infill percentage
- `infillPattern` - Infill pattern type
- `wallCount` - Number of perimeters
- `boundingBox` - Print bounding box coordinates

### 2. Configurable Metadata Fields

Fine-grained control over metadata output with 20+ configurable fields:

```javascript
const slicer = new Polyslice({
  metadataVersion: true,      // Include version number
  metadataTimestamp: true,    // Include timestamp
  metadataRepository: true,   // Include repository URL
  metadataPrinter: true,      // Include printer info
  metadataFilament: true,     // Include filament info
  metadataNozzleTemp: true,   // Include nozzle temperature
  metadataBedTemp: true,      // Include bed temperature
  metadataLayerHeight: true,  // Include layer height
  metadataTotalLayers: true,  // Include total layers
  metadataFilamentLength: true, // Include filament length
  metadataMaterialVolume: true, // Include material volume
  metadataMaterialWeight: true, // Include material weight
  metadataPrintTime: true,    // Include estimated print time
  metadataFlavor: true,       // Include G-code flavor
  metadataInfillDensity: true, // Include infill density
  metadataInfillPattern: true, // Include infill pattern
  metadataWallCount: true,    // Include wall count
  metadataSupport: true,      // Include support status
  metadataAdhesion: true,     // Include adhesion type
  metadataSpeeds: true,       // Include print speeds
  metadataBoundingBox: true   // Include bounding box
});
```

All metadata fields output with proper units (°C for temperature, mm for length, etc.).

### 3. Progress Callback System

Real-time feedback during slicing with customizable progress callbacks:

```javascript
const slicer = new Polyslice({
  progressCallback: (progressInfo) => {
    console.log(`Stage: ${progressInfo.stage}`);
    console.log(`Progress: ${progressInfo.percent}%`);
    if (progressInfo.currentLayer) {
      console.log(`Layer: ${progressInfo.currentLayer}/${progressInfo.totalLayers}`);
    }
    console.log(`Message: ${progressInfo.message}`);
  }
});

const gcode = slicer.slice(mesh);
```

**Progress Stages:**
- `initializing` - Mesh preparation
- `pre-print` - Pre-print G-code generation
- `adhesion` - Adhesion structure generation
- `slicing` - Layer-by-layer slicing (0-100%)
- `post-print` - Post-print G-code generation
- `complete` - Slicing finished

**Default Progress Bar:**

If no custom callback is provided, Polyslice includes a default lightweight progress bar:
- Node.js: In-place updating progress bar using `process.stdout.write`
- Browser: Console.log updates for each stage

### 4. Print Time Calculation

Accurate print time estimation from G-code analysis:

```javascript
// Automatically calculated during slicing
const gcode = slicer.slice(mesh);
const metadata = slicer.getGcodeMetadata();
console.log(metadata.estimatedPrintTime); // "2h 34m 15s"
```

**Features:**
- Analyzes all G-code movement commands (G0, G1, G2, G3)
- Accounts for feedrates and positioning modes (absolute/relative)
- Supports arc movements and Bézier curves
- Parses actual G-code for accurate estimates

### 5. Enhanced Metadata Headers

G-code files now include comprehensive metadata headers:

```gcode
; Generated by Polyslice
; Version: 26.1.2
; Timestamp: 2026-01-28T12:00:00.000Z
; Repository: https://github.com/jgphilpott/polyslice
; Printer: Ender3
; Filament: Generic PLA (pla)
; Nozzle Temp: 200°C
; Bed Temp: 60°C
; Layer Height: 0.2mm
; Total Layers: 50
; Filament Length: 1234.5mm
; Material Volume: 3.2cm³
; Material Weight: 4.0g
; Estimated Print Time: 2h 34m 15s
; Flavor: Marlin
; Infill Density: 20%
; Infill Pattern: grid
; Wall Count: 2
; Support: false
; Adhesion: skirt
; Perimeter Speed: 50mm/s
; Infill Speed: 60mm/s
; Travel Speed: 120mm/s
; Bounding Box: X[0.0,100.0] Y[0.0,100.0] Z[0.0,10.0]
```

## Improvements

- **Improved Metadata Parsing** - Better handling of multiple G-code flavors
- **Enhanced G-code Headers** - Comprehensive metadata in G-code comments
- **Better Metadata Organization** - Structured data with proper units
- **Improved Code Documentation** - Better inline documentation for metadata features

## Use Cases

1. **G-code Analysis Tools** - Build tools to analyze and compare print settings
2. **Print Management** - Track and categorize prints by settings
3. **Quality Control** - Verify print parameters before sending to printer
4. **Cross-Slicer Compatibility** - Read metadata from any slicer
5. **Print Statistics** - Collect statistics on material usage and print times
6. **Progress Monitoring** - Track slicing progress in real-time
7. **Custom Metadata Headers** - Generate G-code with specific metadata fields

## API Changes

### New Configuration Options

```javascript
// Metadata field options (all default to true)
metadataVersion
metadataTimestamp
metadataRepository
metadataPrinter
metadataFilament
metadataNozzleTemp
metadataBedTemp
metadataLayerHeight
metadataTotalLayers
metadataFilamentLength
metadataMaterialVolume
metadataMaterialWeight
metadataPrintTime
metadataFlavor
metadataInfillDensity
metadataInfillPattern
metadataWallCount
metadataSupport
metadataAdhesion
metadataSpeeds
metadataBoundingBox

// Progress callback option
progressCallback: Function
```

### New Methods

```javascript
// Extract metadata from G-code
slicer.getGcodeMetadata(gcode?: string): Object
```

## Installation

```bash
npm install @jgphilpott/polyslice@26.1.2
```

Or update your existing installation:

```bash
npm update @jgphilpott/polyslice
```

## CDN (Browser)

```html
<script type="module">
  import Polyslice from 'https://unpkg.com/@jgphilpott/polyslice@26.1.2/dist/index.browser.esm.js';
</script>
```

## Documentation

Full API documentation: https://github.com/jgphilpott/polyslice/blob/main/docs/api/API.md#getgcodemetadatagcode--null

## Breaking Changes

None - This is a backward-compatible feature addition.

## Dependencies

No dependency changes in this release.

## Testing

- All 695 tests passed ✅
- Linting passed with no issues ✅
- All distributions built successfully ✅

## Thanks

This feature was developed to improve G-code interoperability and enable better tooling around 3D printing workflows.

## Full Changelog

See [CHANGELOG.md](https://github.com/jgphilpott/polyslice/blob/main/CHANGELOG.md) for complete version history.

---

**Previous Release:** [v26.1.1](https://github.com/jgphilpott/polyslice/releases/tag/v26.1.1)
**Next Release:** TBD
