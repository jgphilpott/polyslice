# Resin Printing Support Research & Recommendations

## Executive Summary

This document provides a comprehensive analysis of the MinceSlicer repository and recommendations for integrating resin printing (SLA/DLP/LCD) support into Polyslice. After studying the MinceSlicer architecture and comparing it with Polyslice's current FDM implementation, this document outlines a clear integration strategy that maintains backward compatibility while adding powerful new capabilities.

## Table of Contents

1. [Key Differences: FDM vs Resin Printing](#key-differences-fdm-vs-resin-printing)
2. [MinceSlicer Architecture Analysis](#minceslicer-architecture-analysis)
3. [Integration Strategy](#integration-strategy)
4. [Recommended Implementation Plan](#recommended-implementation-plan)
5. [Technical Specifications](#technical-specifications)
6. [API Design Proposals](#api-design-proposals)
7. [References](#references)

---

## Key Differences: FDM vs Resin Printing

### Output Format

| Aspect | FDM (Current Polyslice) | Resin (MinceSlicer) |
|--------|------------------------|---------------------|
| **Output** | G-code text commands | PNG image layers |
| **Path Type** | Tool path lines (walls, infill) | Rasterized 2D cross-sections |
| **File Format** | `.gcode` | `.zip` containing PNG layers + metadata |
| **Layer Definition** | Movement coordinates (X, Y, Z, E) | Bitmap pixels (black/white or grayscale) |
| **Resolution** | Continuous (nozzle path) | Discrete (printer pixel resolution) |

### Slicing Process

**FDM (Polyslice Current):**
1. Extract layer boundaries using Polytree
2. Generate walls (perimeters) from boundaries
3. Generate infill patterns for interior
4. Generate skin for top/bottom
5. Output G-code movement commands

**Resin (MinceSlicer Approach):**
1. Raycast through mesh at each layer height
2. For each pixel in printer resolution:
   - Cast ray to determine if pixel is inside/outside model
   - Apply anti-aliasing (optional, 1-4x)
   - Apply relief/emboss textures (optional)
3. Generate binary or grayscale image
4. Output PNG layer image
5. Collect all layers in ZIP with G-code metadata

### Hardware & Process Parameters

**FDM Parameters:**
- Nozzle temperature
- Bed temperature
- Print speeds (perimeter, infill, travel)
- Retraction settings
- Layer height
- Extrusion width

**Resin Parameters:**
- Layer height
- Exposure time (normal layers vs bottom layers)
- Lift height and speed
- Drop speed (lowering build plate)
- UV intensity (not always controllable)
- Anti-aliasing level
- Bottom layer count

### Print Workflow

**FDM:**
1. Heat nozzle and bed
2. Home axes
3. Extrude material along toolpath
4. Move to next layer (Z-hop)
5. Repeat

**Resin:**
1. Display layer image on LCD/DLP screen
2. Expose for specified time
3. Lift build plate to unstick from FEP
4. Lower to next layer height
5. Repeat

---

## MinceSlicer Architecture Analysis

### Core Components

MinceSlicer is built with a modular architecture optimized for web-based resin slicing:

```
MinceSlicer/
├── src/
│   ├── slicing/
│   │   ├── Slicer.js          # Core slicing algorithm
│   │   ├── ResinPrint.js      # Print data management
│   │   └── ResinGCode.js      # G-code generation for resin
│   ├── nodes/                 # Relief/emboss node system
│   ├── ui/                    # Web UI components
│   ├── tools/                 # 3D manipulation tools
│   └── utils/                 # Utilities
```

### Key Technologies

1. **three-mesh-bvh**: Fast BVH (Bounding Volume Hierarchy) for raycasting
2. **Three.js Raycaster**: Efficient ray-mesh intersection
3. **fast-png**: High-performance PNG encoding
4. **@zip.js/zip.js**: ZIP archive creation
5. **Web Workers**: Parallel layer processing

### Slicing Algorithm

MinceSlicer uses two slicing approaches:

#### 1. Simple Raycasting (Fast, No Anti-aliasing)

```javascript
// For each pixel at (x, y):
raycaster.set(origin, direction);
const hits = bvh.raycastFirst(raycaster.ray);
// If odd number of intersections → inside model (white)
// If even number of intersections → outside model (black)
```

#### 2. Distance Field with Relief (Slower, High Quality)

```javascript
// For each pixel:
1. Find closest point on mesh surface
2. Determine if inside/outside using ray casting
3. Calculate signed distance to surface
4. Apply relief/emboss texture (optional)
5. Generate grayscale value based on distance + relief
6. Apply anti-aliasing by supersampling
```

### Relief/Emboss System

One of MinceSlicer's unique features is procedural relief texturing:

- **Node-based system**: Similar to shader nodes in Blender
- **UV-mapped**: Uses model UV coordinates for texture placement
- **Procedural generation**: Noise, patterns, images, math operations
- **Height field**: Values from -1 (emboss) to +1 (relief)
- **Real-time preview**: Shows texture in UV space

**Example Relief Nodes:**
- Constant, Add, Multiply, Sin, Cos (math)
- SimplexNoise, PerlinNoise, Voronoi (procedural)
- ImageUV, ImageTiledUV (texture mapping)
- Checkered, Tiles, Circles, Spots (geometric patterns)

This allows creating intricate surface details without modifying the mesh geometry.

### Output Format

MinceSlicer outputs a ZIP archive containing:

```
output.zip
├── run.gcode              # Metadata and machine instructions
├── 0000.png               # Layer 0 (bottom)
├── 0001.png               # Layer 1
├── ...
└── NNNN.png               # Layer N (top)
```

The `run.gcode` file contains metadata like:

```gcode
;(****Build and Slicing Parameters****)
;(Pix per mm X = 20.11)
;(Pix per mm Y = 20.11)
;(X Resolution = 2560)
;(Y Resolution = 1620)
;(Layer Thickness = 0.05)
;(Layer Count = 250)
;(Normal Exposure Time = 8.0)
;(Bottom Layer Count = 5)
;(Bottom Exposure Time = 45.0)
```

This ZIP file must be converted to printer-specific formats (`.ctb`, `.photon`, `.pwmx`, etc.) using tools like [uv3dp](https://github.com/ezrec/uv3dp).

### Performance Optimizations

1. **Web Workers**: Parallel processing of multiple layers
2. **BVH acceleration**: Fast ray-mesh intersection
3. **Cached random generation**: Pre-computed random values for noise
4. **Incremental rendering**: Layer preview while slicing
5. **Optional anti-aliasing**: Trade quality for speed

---

## Integration Strategy

### Recommended Approach: Dual-Mode Slicer

Rather than forking or replacing existing FDM functionality, I recommend **extending Polyslice to support both FDM and resin printing modes**. This approach:

✅ Maintains backward compatibility  
✅ Shares common infrastructure (loaders, preprocessing, configuration)  
✅ Allows users to switch between modes  
✅ Follows single responsibility principle with separate slicing engines  

### Architecture Overview

```
Polyslice (Enhanced)
├── src/
│   ├── polyslice.coffee           # Main class with mode selection
│   ├── slicer/
│   │   ├── slice.coffee           # FDM slicing (existing)
│   │   └── resin-slice.coffee     # NEW: Resin slicing
│   ├── slicer/gcode/
│   │   ├── coders.coffee          # FDM G-code (existing)
│   │   └── resin-coders.coffee    # NEW: Resin G-code metadata
│   ├── slicer/resin/              # NEW: Resin-specific modules
│   │   ├── raycaster.coffee       # Ray-based layer generation
│   │   ├── image-generator.coffee # PNG layer generation
│   │   ├── relief.coffee          # Relief/emboss system
│   │   └── archiver.coffee        # ZIP packaging
│   ├── config/
│   │   ├── printer/
│   │   │   └── resin-printers.coffee  # NEW: Resin printer profiles
│   │   └── resin/
│   │       └── resin-config.coffee    # NEW: Resin material profiles
│   └── exporters/
│       └── resin-exporter.coffee  # NEW: Resin output handling
```

---

## Recommended Implementation Plan

### Phase 1: Foundation (Core Infrastructure)

**Goal**: Set up basic resin printing infrastructure without breaking existing FDM functionality.

**Tasks:**

1. **Add printing mode selection to Polyslice constructor**
   ```coffeescript
   class Polyslice
       constructor: (options = {}) ->
           @printMode = options.printMode ?= "fdm"  # 'fdm' or 'resin'
   ```

2. **Create resin configuration structure**
   ```coffeescript
   # src/config/resin/resin-config.coffee
   class ResinConfig
       constructor: (options = {}) ->
           @layerHeight = options.layerHeight ?= 0.05  # mm
           @resolutionX = options.resolutionX ?= 2560  # pixels
           @resolutionY = options.resolutionY ?= 1620  # pixels
           @machineX = options.machineX ?= 127.4       # mm
           @machineY = options.machineY ?= 80.6        # mm
           @normalExposureTime = options.normalExposureTime ?= 8.0  # seconds
           @bottomLayerCount = options.bottomLayerCount ?= 5
           @bottomExposureTime = options.bottomExposureTime ?= 45.0
           @liftHeight = options.liftHeight ?= 5.0     # mm
           @liftSpeed = options.liftSpeed ?= 60        # mm/min
           @dropSpeed = options.dropSpeed ?= 150       # mm/min
           @antialiasingLevel = options.antialiasingLevel ?= 1  # 1-4
   ```

3. **Add resin printer profiles**
   ```coffeescript
   # src/config/printer/resin-printers.coffee
   resinPrinters =
       "AnyCubicPhotonMono":
           resolutionX: 2560
           resolutionY: 1620
           machineX: 127.4
           machineY: 80.6
           machineZ: 165
       
       "ElegooMars3":
           resolutionX: 4098
           resolutionY: 2560
           machineX: 143.4
           machineY: 89.6
           machineZ: 175
       
       "PhrozenSonic4K":
           resolutionX: 3840
           resolutionY: 2400
           machineX: 134.4
           machineY: 84.0
           machineZ: 200
   ```

4. **Install required dependencies**
   ```bash
   npm install three-mesh-bvh fast-png jszip
   ```

**Estimated Effort**: 1-2 weeks

### Phase 2: Basic Raycasting Slicer

**Goal**: Implement simple raycasting-based slicing that outputs PNG layers.

**Tasks:**

1. **Create raycasting module**
   ```coffeescript
   # src/slicer/resin/raycaster.coffee
   class ResinRaycaster
       sliceLayer: (mesh, layerZ, resolutionX, resolutionY, machineX, machineY) ->
           # Returns pixel array for one layer
           pixels = new Uint8ClampedArray(resolutionX * resolutionY)
           
           # Cast ray for each pixel
           for y in [0...resolutionY]
               for x in [0...resolutionX]
                   # Convert pixel to world coordinates
                   # Cast ray and determine inside/outside
                   # Set pixel white (255) if inside, black (0) if outside
           
           return pixels
   ```

2. **Create image generator**
   ```coffeescript
   # src/slicer/resin/image-generator.coffee
   FastPNG = require('fast-png')
   
   class ImageGenerator
       generatePNG: (pixels, width, height) ->
           # Convert pixel array to PNG using fast-png
           return FastPNG.encode({
               width: width
               height: height
               data: pixels
               depth: 8
               channels: 1  # Grayscale
           })
   ```

3. **Create resin slicer main function**
   ```coffeescript
   # src/slicer/resin-slice.coffee
   module.exports = (slicer, scene) ->
       # Extract mesh
       # Calculate layer count
       # For each layer:
       #   - Raycast to generate pixels
       #   - Convert to PNG
       #   - Store layer data
       # Package into output format
       return layerImages
   ```

4. **Integrate with main Polyslice class**
   ```coffeescript
   # In polyslice.coffee
   slice: (scene) ->
       if @printMode is "fdm"
           return slicer.slice(this, scene)
       else if @printMode is "resin"
           return resinSlice(this, scene)
   ```

**Estimated Effort**: 2-3 weeks

### Phase 3: Output Packaging

**Goal**: Package layer images into proper output format with metadata.

**Tasks:**

1. **Create G-code metadata generator**
   ```coffeescript
   # src/slicer/gcode/resin-coders.coffee
   module.exports.generateResinMetadata = (slicer, layerCount, volume, boundingBox) ->
       gcode = ""
       gcode += ";(****Build and Slicing Parameters****)#{slicer.newline}"
       gcode += ";(Layer Thickness = #{slicer.layerHeight})#{slicer.newline}"
       gcode += ";(Layer Count = #{layerCount})#{slicer.newline}"
       gcode += ";(Normal Exposure Time = #{slicer.normalExposureTime})#{slicer.newline}"
       # ... more metadata
       return gcode
   ```

2. **Create ZIP archiver**
   ```coffeescript
   # src/slicer/resin/archiver.coffee
   JSZip = require('jszip')
   
   class ResinArchiver
       createArchive: (layers, metadata) ->
           zip = new JSZip()
           
           # Add metadata G-code
           zip.file("run.gcode", metadata)
           
           # Add layer images
           for layer, index in layers
               filename = String(index).padStart(4, '0') + '.png'
               zip.file(filename, layer)
           
           # Generate ZIP blob
           return zip.generateAsync({type: 'uint8array'})
   ```

3. **Create resin exporter**
   ```coffeescript
   # src/exporters/resin-exporter.coffee
   module.exports.saveResinPrint = (zipData, filename) ->
       # Save ZIP file (browser or Node.js)
   ```

**Estimated Effort**: 1-2 weeks

### Phase 4: Advanced Features (Optional)

**Goal**: Add advanced resin printing features like anti-aliasing and relief.

**Tasks:**

1. **Implement anti-aliasing**
   - Supersample pixels (2x, 3x, 4x)
   - Average sample results for smooth edges

2. **Add basic relief/emboss support**
   - Simple height field modification
   - Image-based relief textures
   - Skip complex node system initially

3. **Add hollow/drain holes**
   - Detect interior volumes
   - Add drain hole placement

4. **Printer-specific format conversion**
   - Integration with uv3dp or similar
   - Direct `.ctb`, `.photon` output

**Estimated Effort**: 4-6 weeks

---

## Technical Specifications

### Dependencies to Add

```json
{
  "dependencies": {
    "three-mesh-bvh": "^0.9.0",    // Fast raycasting
    "fast-png": "^6.2.0",           // PNG encoding
    "jszip": "^3.10.1"              // ZIP packaging
  }
}
```

### Configuration Schema

```javascript
// Resin printing configuration
{
  printMode: "resin",               // "fdm" or "resin"
  
  // Machine settings
  resolutionX: 2560,                // Printer X resolution (pixels)
  resolutionY: 1620,                // Printer Y resolution (pixels)
  machineX: 127.4,                  // Build volume X (mm)
  machineY: 80.6,                   // Build volume Y (mm)
  machineZ: 165,                    // Build volume Z (mm)
  
  // Layer settings
  layerHeight: 0.05,                // Layer thickness (mm)
  
  // Exposure settings
  normalExposureTime: 8.0,          // Normal layer exposure (seconds)
  bottomLayerCount: 5,              // Number of bottom layers
  bottomExposureTime: 45.0,         // Bottom layer exposure (seconds)
  
  // Movement settings
  liftHeight: 5.0,                  // Lift height (mm)
  liftSpeed: 60,                    // Lift speed (mm/min)
  dropSpeed: 150,                   // Drop speed (mm/min)
  zSlowUpDistance: 0,               // Slow lift distance (mm)
  
  // Light off times
  bottomLightOffTime: 0,            // Bottom layer light off (seconds)
  lightOffTime: 0,                  // Normal layer light off (seconds)
  
  // Quality settings
  antialiasingLevel: 1,             // 1, 2, 3, or 4 (1 = off)
  
  // Material settings
  resinDensity: 1.05,               // Resin density (g/cm³)
  resinPrice: 30,                   // Price per kg
  
  // Advanced features (optional)
  reliefEnabled: false,             // Enable relief/emboss
  reliefMaxHeight: 0.5,             // Max relief height (mm)
  
  // Output settings
  outputFormat: "zip",              // "zip", "ctb", "photon", etc.
  mirror: false                     // Mirror image horizontally
}
```

### File Format Specification

#### ZIP Archive Structure

```
output.zip
├── run.gcode              # Metadata and settings
├── 0000.png               # Layer images (grayscale)
├── 0001.png
├── 0002.png
└── ...
```

#### G-code Metadata Format

```gcode
;(****Build and Slicing Parameters****)
;(Pix per mm X = 20.11)
;(Pix per mm Y = 20.11)
;(X Resolution = 2560)
;(Y Resolution = 1620)
;(Layer Thickness = 0.05)
;(Layer Count = 250)
;(Layer Height = 0.05)
;(Volume = 12.34)
;(Resin = 15.67)
;(Weight = 16.45)
;(Price = 0.49)
;(Bottom Layer Count = 5)
;(Normal Exposure Time = 8.0)
;(Bottom Exposure Time = 45.0)
;(Normal Layer Lift Height = 5.0)
;(Bottom Layer Lift Height = 5.0)
;(Normal Layer Lift Speed = 60.0)
;(Bottom Layer Lift Speed = 60.0)
;(Normal Drop Speed = 150.0)
;(Z Slow Up Distance = 0.0)
;(Bottom Light Off Time = 0.0)
;(Light Off Time = 0.0)
```

### Performance Considerations

**Expected slicing times** (approximate, based on MinceSlicer benchmarks):

| Model Size | Layers | Anti-aliasing | Time |
|-----------|--------|---------------|------|
| Small (50mm) | 200 | 1x (off) | 5-10 seconds |
| Medium (100mm) | 400 | 1x (off) | 15-30 seconds |
| Large (150mm) | 600 | 1x (off) | 30-60 seconds |
| Small (50mm) | 200 | 4x (max) | 60-120 seconds |
| Medium (100mm) | 400 | 4x (max) | 5-10 minutes |

**Optimization strategies:**
1. Use Web Workers for parallel layer processing (browser)
2. Use Worker Threads for parallel processing (Node.js)
3. Implement BVH acceleration for raycasting
4. Cache mesh BVH structure
5. Use fast-png for efficient PNG encoding
6. Optional: GPU-based raycasting using WebGL

---

## API Design Proposals

### Basic Usage

```javascript
const THREE = require("three");
const { Polyslice, ResinPrinter, ResinMaterial } = require("@jgphilpott/polyslice");

// Create resin printer and material profiles
const printer = new ResinPrinter("AnyCubicPhotonMono");
const resin = new ResinMaterial("StandardResin");

// Create slicer in resin mode
const slicer = new Polyslice({
  printMode: "resin",
  printer: printer,
  resin: resin,
  layerHeight: 0.05,
  normalExposureTime: 8.0,
  bottomLayerCount: 5,
  bottomExposureTime: 45.0,
  antialiasingLevel: 2  // Better quality
});

// Load and slice a model
const geometry = new THREE.BoxGeometry(20, 20, 20);
const mesh = new THREE.Mesh(geometry);

// Slice returns ZIP data (Uint8Array) instead of G-code string
const zipData = slicer.slice(mesh);

// Save to file
const { ResinExporter } = require("@jgphilpott/polyslice");
ResinExporter.save(zipData, "output.zip");
```

### Advanced Usage with Relief

```javascript
const slicer = new Polyslice({
  printMode: "resin",
  printer: printer,
  resin: resin,
  
  // Enable relief texturing
  reliefEnabled: true,
  reliefMaxHeight: 0.3,  // 0.3mm relief
  
  // Use image as relief texture
  reliefTexture: loadedImage,
  reliefScale: 1.0,
  
  // Or use procedural relief
  reliefType: "perlin",
  reliefFrequency: 5.0
});
```

### Utility Methods

```javascript
// Check if model fits on build plate
if (!slicer.checkBuildVolume(mesh)) {
  console.warn("Model exceeds build volume!");
}

// Get estimated print information
const info = slicer.estimatePrint(mesh);
console.log(`Layers: ${info.layerCount}`);
console.log(`Volume: ${info.volume} ml`);
console.log(`Resin weight: ${info.weight} g`);
console.log(`Estimated time: ${info.printTime} minutes`);
console.log(`Estimated cost: $${info.cost}`);

// Preview layer
const layerImage = slicer.previewLayer(mesh, 50);  // Layer 50
// Returns PNG data for display
```

### Configuration Classes

```javascript
// Resin Printer Profile
class ResinPrinter {
  constructor(model = "Generic") {
    this.model = model;
    this.resolutionX = 2560;
    this.resolutionY = 1620;
    this.machineX = 127.4;
    this.machineY = 80.6;
    this.machineZ = 165;
  }
  
  // Getters and setters...
}

// Resin Material Profile
class ResinMaterial {
  constructor(type = "Standard") {
    this.type = type;
    this.density = 1.05;          // g/cm³
    this.normalExposure = 8.0;    // seconds
    this.bottomExposure = 45.0;   // seconds
    this.liftHeight = 5.0;        // mm
    this.liftSpeed = 60;          // mm/min
    // ...
  }
}
```

---

## Comparison: Implementation Complexity

### Minimal Implementation (Phase 1-3)

**What you get:**
- Basic resin slicing with raycasting
- PNG layer generation
- ZIP output with metadata
- Configuration for common resin printers
- Resin material profiles

**Estimated total effort:** 4-7 weeks for a working prototype

**Lines of code:** ~2,000-3,000 LOC (including tests and config)

### Full Implementation (All Phases)

**Additional features:**
- Anti-aliasing (2x, 3x, 4x)
- Relief/emboss texturing
- Advanced UI integration
- Printer-specific format export
- Hollow detection and drain holes
- Performance optimizations (workers, BVH)

**Estimated total effort:** 10-14 weeks for production-ready system

**Lines of code:** ~5,000-8,000 LOC (including tests and config)

---

## Migration Path for Existing Users

### Backward Compatibility

All existing FDM functionality remains unchanged:

```javascript
// Existing FDM code continues to work
const slicer = new Polyslice({
  // No printMode specified → defaults to "fdm"
  printer: fdmPrinter,
  filament: pla
});

const gcode = slicer.slice(mesh);  // Returns G-code string as before
```

### Detecting Print Mode

```javascript
// Library can auto-detect based on configuration
const slicer = new Polyslice({
  printer: new ResinPrinter("PhotonMono")  // Auto-sets printMode to "resin"
});

// Or explicit mode selection
const slicer = new Polyslice({
  printMode: "resin",
  resolutionX: 2560,
  resolutionY: 1620
  // ...
});

// Check current mode
console.log(slicer.getPrintMode());  // "fdm" or "resin"
```

---

## Testing Strategy

### Unit Tests

```javascript
describe("Resin Slicing", () => {
  it("should generate correct number of layers", () => {
    const slicer = new Polyslice({ printMode: "resin", layerHeight: 0.05 });
    const mesh = createCubeMesh(10, 10, 5);  // 5mm tall
    const result = slicer.slice(mesh);
    expect(result.layerCount).toBe(100);  // 5mm / 0.05mm = 100 layers
  });
  
  it("should raycast correctly", () => {
    const raycaster = new ResinRaycaster();
    const mesh = createSphereMesh(10);
    const pixels = raycaster.sliceLayer(mesh, 0, 100, 100, 50, 50);
    // Verify center pixel is white (inside sphere)
    expect(pixels[50 * 100 + 50]).toBe(255);
  });
  
  it("should generate valid PNG data", () => {
    const generator = new ImageGenerator();
    const pixels = new Uint8ClampedArray(100 * 100).fill(255);
    const png = generator.generatePNG(pixels, 100, 100);
    expect(png).toBeInstanceOf(Uint8Array);
    expect(png.length).toBeGreaterThan(0);
  });
});
```

### Integration Tests

```javascript
describe("Resin Slicer Integration", () => {
  it("should produce valid ZIP archive", async () => {
    const slicer = new Polyslice({ printMode: "resin" });
    const mesh = createCubeMesh(20, 20, 10);
    const zipData = await slicer.slice(mesh);
    
    const zip = await JSZip.loadAsync(zipData);
    expect(zip.file("run.gcode")).toBeDefined();
    expect(zip.file("0000.png")).toBeDefined();
  });
});
```

---

## Frequently Asked Questions

### Q: Should resin support be in Polyslice or a separate package?

**Recommendation: Keep in Polyslice**

**Reasons:**
1. Shared infrastructure (loaders, preprocessing, configuration)
2. Unified API for users
3. Code reuse for common tasks
4. Easier maintenance with single repository
5. Users can easily switch between FDM and resin

The print mode can be selected via configuration, maintaining clean separation of concerns.

### Q: How do we handle the different output formats?

The `slice()` method return type should depend on print mode:

```typescript
slice(mesh: Mesh): string | Uint8Array {
  if (this.printMode === "fdm") {
    return gcode;  // string
  } else {
    return zipData;  // Uint8Array
  }
}
```

Or use separate methods:

```typescript
sliceFDM(mesh): string { ... }
sliceResin(mesh): Uint8Array { ... }
```

### Q: Should we implement the relief/emboss system?

**Phase 1-3: No** - Focus on basic functionality first  
**Phase 4: Optional** - Add as advanced feature if there's demand

The relief system is complex and specific to artistic/decorative printing. Most users won't need it initially.

### Q: How do we handle printer-specific format conversion?

**Option 1:** Output only ZIP format, users convert with external tools (uv3dp)  
**Option 2:** Integrate format conversion libraries  
**Option 3:** Partner with/use existing converter projects

**Recommendation:** Start with Option 1 (ZIP only), add Option 2 later if needed.

### Q: What about browser vs Node.js?

Both environments should be supported, like current FDM:

**Browser considerations:**
- Use Web Workers for parallel processing
- Return ZIP as Blob for download
- May have memory limitations for large models

**Node.js considerations:**
- Use Worker Threads for parallel processing
- Can save directly to filesystem
- Better for large/complex models

---

## References

### MinceSlicer Resources

- **Repository**: https://github.com/yomboprime/MinceSlicer
- **Live Demo**: https://yomboprime.github.io/MinceSlicer/dist/MinceSlicer.html
- **Three.js Forum Discussion**: https://discourse.threejs.org/t/mince-slicer-resin-3d-printer-slicer-with-three-js-and-three-mesh-bvh/30405

### Resin Printing Resources

- **ChiTuBox**: https://www.chitubox.com/ (Popular desktop slicer)
- **Lychee Slicer**: https://mango3d.io/lychee-slicer/ (Another popular option)
- **uv3dp**: https://github.com/ezrec/uv3dp (Format converter)
- **File Format Specs**: Various printer manufacturer documentation

### Technical Libraries

- **three-mesh-bvh**: https://github.com/gkjohnson/three-mesh-bvh
- **fast-png**: https://github.com/image-js/fast-png
- **jszip**: https://stuk.github.io/jszip/

### Related Projects

- **Polyslice (current)**: https://github.com/jgphilpott/polyslice
- **Polytree**: https://github.com/jgphilpott/polytree (Used for FDM slicing)

---

## Conclusion

Integrating resin printing support into Polyslice is both **feasible and valuable**. The MinceSlicer project provides an excellent reference implementation, demonstrating that Three.js-based resin slicing is production-ready.

### Key Recommendations:

1. ✅ **Implement as dual-mode system** - Keep FDM and add resin in same package
2. ✅ **Start with basic raycasting** - Phases 1-3 provide complete functionality
3. ✅ **Use proven libraries** - three-mesh-bvh, fast-png, jszip
4. ✅ **Output ZIP format initially** - Add printer-specific formats later
5. ✅ **Maintain backward compatibility** - All existing FDM code unchanged
6. ⚠️ **Skip relief/emboss initially** - Add in Phase 4 if demanded
7. ⚠️ **Focus on web and Node.js support** - Like current FDM implementation

### Success Criteria:

- Users can slice models for resin printers with simple API
- Output files work with format converters (uv3dp)
- Performance comparable to MinceSlicer
- No breaking changes to existing FDM functionality
- Comprehensive tests and documentation

### Timeline:

- **Prototype (Phases 1-2)**: 3-5 weeks
- **Working implementation (Phase 3)**: 6-8 weeks total
- **Production-ready with tests**: 10-12 weeks total
- **Advanced features (Phase 4)**: 14-18 weeks total

This represents a significant but manageable enhancement to Polyslice that would make it the **first three.js library to support both FDM and resin 3D printing** comprehensively.

---

**Document Version**: 1.0  
**Date**: December 2024  
**Author**: AI Research Assistant for Polyslice  
**Status**: Recommendations for Review
