# Release v26.1.2: Metadata & Progress Tracking

Prepares v26.1.2 release (third release of January 2026) introducing comprehensive metadata and progress tracking capabilities.

## Changes

### 1. G-code Metadata Extraction (`getGcodeMetadata()`)

Extracts structured metadata from G-code with multi-slicer support:

```javascript
const metadata = slicer.getGcodeMetadata();

// Returns structured data with units
console.log(metadata.printer);              // "Ender3"
console.log(metadata.nozzleTemp);           // { value: 200, unit: "°C" }
console.log(metadata.totalLayers);          // 50
console.log(metadata.filamentLength);       // { value: 1234.5, unit: "mm" }

// Also accepts custom G-code strings
const metadata = slicer.getGcodeMetadata(customGcode);
```

**Capabilities:**
- Automatic slicer detection (Polyslice, Cura, PrusaSlicer)
- Parses common fields across all slicers (printer, layers, filament, print time)
- Extracts Polyslice-specific fields (infill pattern, wall count, material volume/weight, bounding box)
- Returns empty object `{}` when no metadata present
- Works in Node.js and browsers

### 2. Configurable Metadata Fields

Fine-grained control over metadata output with 20+ configurable fields:

```javascript
const slicer = new Polyslice({
  metadataVersion: true,       // Version number
  metadataTimestamp: true,     // ISO 8601 timestamp
  metadataRepository: true,    // Repository URL
  metadataPrinter: true,       // Printer information
  metadataFilament: true,      // Filament information
  metadataNozzleTemp: true,    // Nozzle temperature
  metadataBedTemp: true,       // Bed temperature
  metadataLayerHeight: true,   // Layer height
  metadataTotalLayers: true,   // Total layers count
  metadataFilamentLength: true, // Filament length
  metadataMaterialVolume: true, // Material volume
  metadataMaterialWeight: true, // Material weight
  metadataPrintTime: true,     // Estimated print time
  metadataFlavor: true,        // G-code flavor
  metadataInfillDensity: true, // Infill density
  metadataInfillPattern: true, // Infill pattern
  metadataWallCount: true,     // Wall count
  metadataSupport: true,       // Support enabled
  metadataAdhesion: true,      // Adhesion type
  metadataSpeeds: true,        // Print speeds
  metadataBoundingBox: true    // Bounding box coordinates
});
```

All metadata fields output with proper units (°C for temperature, mm for length, etc.).

### 3. Progress Callback System

Real-time slicing feedback with customizable progress callbacks:

```javascript
const slicer = new Polyslice({
  progressCallback: (progressInfo) => {
    console.log(`Stage: ${progressInfo.stage}`);
    console.log(`Progress: ${progressInfo.percent}%`);
    if (progressInfo.currentLayer) {
      console.log(`Layer: ${progressInfo.currentLayer}/${progressInfo.totalLayers}`);
    }
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

**Default Progress Bar:** If no custom callback provided, includes lightweight progress bar for Node.js and browsers.

### 4. Print Time Calculation

Accurate print time estimation from G-code analysis:

```javascript
const gcode = slicer.slice(mesh);
const metadata = slicer.getGcodeMetadata();
console.log(metadata.estimatedPrintTime); // "2h 34m 15s"
```

- Analyzes all G-code movement commands (G0, G1, G2, G3)
- Accounts for feedrates and positioning modes
- Supports arc movements and relative positioning

### 5. Enhanced Metadata Headers

G-code files now include comprehensive metadata headers with all print parameters.

## Version Management

- `package.json`: 26.1.2
- `CHANGELOG.md`: Release notes with comparison links
- Git tag: `v26.1.2`

## Documentation

- Comprehensive release notes for GitHub release page
- API documentation with usage examples
- Release checklist and summary

## Breaking Changes

None. Fully backward compatible feature addition.

---

> **Custom agent used: release-agent**
> Manage releases for Polyslice, including version bumping, release notes, git tagging, and npm publishing.
