# Resin Printing Example Code Structure

This document shows example code snippets demonstrating the proposed resin printing implementation.

## Example 1: Basic Resin Printing

```javascript
// Import Polyslice with resin support
const THREE = require("three");
const { Polyslice, ResinPrinter, ResinMaterial, ResinExporter } = require("@jgphilpott/polyslice");

// Create a resin printer profile
const printer = new ResinPrinter("AnyCubicPhotonMono");

// Create a resin material profile  
const resin = new ResinMaterial("StandardResin");

// Create slicer in resin mode
const slicer = new Polyslice({
  printMode: "resin",           // Switch to resin mode
  printer: printer,
  resin: resin,
  
  // Resin-specific settings
  layerHeight: 0.05,            // 50 microns
  normalExposureTime: 8.0,      // 8 seconds per layer
  bottomLayerCount: 5,
  bottomExposureTime: 45.0,     // 45 seconds for bottom layers
  antialiasingLevel: 2          // 2x anti-aliasing for quality
});

// Create a simple model
const geometry = new THREE.BoxGeometry(20, 20, 20);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const cube = new THREE.Mesh(geometry, material);

// Slice the model - returns ZIP data instead of G-code
const zipData = slicer.slice(cube);

// Save the ZIP file
ResinExporter.save(zipData, "output.zip");

console.log("Resin print file saved as output.zip");
console.log("Convert with: uv3dp output.zip output.ctb");
```

## Example 2: Custom Printer Configuration

```javascript
const { Polyslice, ResinPrinter } = require("@jgphilpott/polyslice");

// Create custom printer profile
const customPrinter = new ResinPrinter()
  .setModel("MyCustomPrinter")
  .setResolution(3840, 2400)    // 4K resolution
  .setBuildVolume(134.4, 84.0, 200)  // X, Y, Z in mm
  .setPixelSize(0.035, 0.035);  // Pixel size in mm

// Use custom printer
const slicer = new Polyslice({
  printMode: "resin",
  printer: customPrinter,
  layerHeight: 0.025            // High resolution - 25 microns
});
```

## Example 3: Material-Specific Settings

```javascript
const { Polyslice, ResinMaterial } = require("@jgphilpott/polyslice");

// Create custom resin material
const customResin = new ResinMaterial()
  .setName("FastResin")
  .setDensity(1.10)                    // g/cm³
  .setNormalExposure(6.0)              // Fast curing
  .setBottomExposure(35.0)
  .setLiftSettings(5.0, 80)            // height (mm), speed (mm/min)
  .setDropSpeed(150)
  .setPrice(25);                       // $ per kg

const slicer = new Polyslice({
  printMode: "resin",
  resin: customResin
});
```

## Example 4: Print Information & Estimates

```javascript
const { Polyslice } = require("@jgphilpott/polyslice");

const slicer = new Polyslice({
  printMode: "resin",
  layerHeight: 0.05
});

const mesh = loadModel("miniature.stl");

// Check if model fits on build plate
if (!slicer.checkBuildVolume(mesh)) {
  console.error("Model too large for build volume!");
  process.exit(1);
}

// Get print estimates before slicing
const estimate = slicer.estimatePrint(mesh);

console.log("Print Estimate:");
console.log(`  Layer count: ${estimate.layerCount}`);
console.log(`  Print time: ${estimate.printTime} minutes`);
console.log(`  Resin volume: ${estimate.volume.toFixed(2)} ml`);
console.log(`  Resin weight: ${estimate.weight.toFixed(2)} g`);
console.log(`  Estimated cost: $${estimate.cost.toFixed(2)}`);
console.log(`  Bounding box: ${estimate.boundingBox.x} x ${estimate.boundingBox.y} x ${estimate.boundingBox.z} mm`);

// Proceed with slicing
const zipData = slicer.slice(mesh);
```

## Example 5: Advanced Quality Settings

```javascript
const { Polyslice } = require("@jgphilpott/polyslice");

// High-quality resin slicing
const slicer = new Polyslice({
  printMode: "resin",
  
  // Ultra-high resolution
  layerHeight: 0.025,           // 25 microns
  
  // Maximum anti-aliasing
  antialiasingLevel: 4,         // 4x supersampling
  
  // Fine-tuned exposure
  normalExposureTime: 7.5,
  bottomExposureTime: 40.0,
  
  // Gentle movement
  liftHeight: 6.0,
  liftSpeed: 50,                // Slower for delicate parts
  dropSpeed: 120
});

// This will be slower but produce highest quality
const zipData = slicer.slice(detailedModel);
```

## Example 6: Preview Layer Before Slicing

```javascript
const { Polyslice } = require("@jgphilpott/polyslice");
const fs = require("fs");

const slicer = new Polyslice({ printMode: "resin" });
const mesh = loadModel("model.stl");

// Preview a specific layer (e.g., layer 50)
const layerPreview = slicer.previewLayer(mesh, 50);

// Save preview as PNG
fs.writeFileSync("layer_050_preview.png", layerPreview);

// Preview multiple layers to check quality
for (let i = 0; i < 10; i++) {
  const layerNum = i * 20;  // Every 20th layer
  const preview = slicer.previewLayer(mesh, layerNum);
  fs.writeFileSync(`preview_layer_${String(layerNum).padStart(3, '0')}.png`, preview);
}

console.log("Layer previews saved. Check quality before full slice.");
```

## Example 7: Batch Processing Multiple Models

```javascript
const { Polyslice, ResinExporter } = require("@jgphilpott/polyslice");
const glob = require("glob");

// Setup slicer once
const slicer = new Polyslice({
  printMode: "resin",
  layerHeight: 0.05
});

// Find all STL files
const models = glob.sync("models/*.stl");

// Process each model
for (const modelPath of models) {
  console.log(`Processing ${modelPath}...`);
  
  const mesh = loadModel(modelPath);
  const zipData = slicer.slice(mesh);
  
  const outputPath = modelPath.replace(".stl", ".zip");
  ResinExporter.save(zipData, outputPath);
  
  console.log(`  Saved to ${outputPath}`);
}

console.log(`Processed ${models.length} models`);
```

## Example 8: Browser Usage

```html
<!DOCTYPE html>
<html>
<head>
  <title>Polyslice Resin Slicer</title>
  <script src="https://unpkg.com/three@0.180.0/build/three.min.js"></script>
  <script src="https://unpkg.com/@jgphilpott/polyslice/dist/index.browser.min.js"></script>
</head>
<body>
  <input type="file" id="fileInput" accept=".stl,.obj">
  <button id="sliceButton">Slice for Resin</button>
  <div id="info"></div>

  <script>
    const slicer = new Polyslice({
      printMode: "resin",
      printer: new PolysliceResinPrinter("AnyCubicPhotonMono"),
      layerHeight: 0.05,
      normalExposureTime: 8.0
    });

    document.getElementById('sliceButton').addEventListener('click', async () => {
      const file = document.getElementById('fileInput').files[0];
      if (!file) {
        alert("Please select a file first");
        return;
      }

      // Load STL
      const loader = new PolysliceLoader();
      const mesh = await loader.loadSTL(URL.createObjectURL(file));

      // Show estimate
      const estimate = slicer.estimatePrint(mesh);
      document.getElementById('info').innerHTML = `
        Layers: ${estimate.layerCount}<br>
        Volume: ${estimate.volume.toFixed(2)} ml<br>
        Time: ${estimate.printTime} min
      `;

      // Slice
      const zipData = await slicer.slice(mesh);

      // Download ZIP
      const blob = new Blob([zipData], { type: 'application/zip' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'output.zip';
      a.click();
      URL.revokeObjectURL(url);
    });
  </script>
</body>
</html>
```

## Example 9: Mode Switching (FDM vs Resin)

```javascript
const { Polyslice } = require("@jgphilpott/polyslice");

function sliceModel(mesh, mode = "fdm") {
  if (mode === "fdm") {
    // FDM slicing
    const slicer = new Polyslice({
      printMode: "fdm",
      infillDensity: 20,
      layerHeight: 0.2
    });
    const gcode = slicer.slice(mesh);
    return { type: "gcode", data: gcode };
    
  } else if (mode === "resin") {
    // Resin slicing
    const slicer = new Polyslice({
      printMode: "resin",
      layerHeight: 0.05
    });
    const zipData = slicer.slice(mesh);
    return { type: "zip", data: zipData };
  }
}

// Use for either mode
const mesh = loadModel("model.stl");

const fdmResult = sliceModel(mesh, "fdm");
fs.writeFileSync("output.gcode", fdmResult.data);

const resinResult = sliceModel(mesh, "resin");
fs.writeFileSync("output.zip", resinResult.data);
```

## Example 10: Using Resin Printer Presets

```javascript
const { Polyslice, ResinPrinter } = require("@jgphilpott/polyslice");

// List available resin printers
console.log("Available resin printers:");
console.log(ResinPrinter.listAvailablePrinters());
// Output:
// [
//   "AnyCubicPhotonMono",
//   "ElegooMars3",
//   "PhrozenSonic4K",
//   "EpaxX1",
//   ...
// ]

// Use a preset
const printer = new ResinPrinter("ElegooMars3");

console.log(`Printer: ${printer.getModel()}`);
console.log(`Resolution: ${printer.getResolutionX()} x ${printer.getResolutionY()}`);
console.log(`Build volume: ${printer.getMachineX()} x ${printer.getMachineY()} x ${printer.getMachineZ()} mm`);

// Or customize a preset
const customizedPrinter = new ResinPrinter("ElegooMars3")
  .setResolution(3840, 2400)   // Upgrade to 4K screen
  .setMachineZ(200);            // Taller build volume

const slicer = new Polyslice({
  printMode: "resin",
  printer: customizedPrinter
});
```

---

## Implementation File Structure (Example)

### Main Polyslice Class Enhancement

```coffeescript
# src/polyslice.coffee

class Polyslice

    constructor: (options = {}) ->
        
        # ... existing FDM options ...
        
        # NEW: Print mode selection
        @printMode = options.printMode ?= "fdm"  # "fdm" or "resin"
        
        if @printMode is "resin"
            # Resin-specific initialization
            @resinConfig = new ResinConfig(options)
            @resin = options.resin ?= null
        
    slice: (scene) ->
        
        if @printMode is "fdm"
            # Existing FDM slicing
            return slicer.slice(this, scene)
            
        else if @printMode is "resin"
            # NEW: Resin slicing
            return resinSlicer.slice(this, scene)
        
        else
            throw new Error("Unknown print mode: #{@printMode}")
```

### Resin Slicer Module

```coffeescript
# src/slicer/resin-slice.coffee

ResinRaycaster = require('./resin/raycaster')
ImageGenerator = require('./resin/image-generator')
ResinArchiver = require('./resin/archiver')
resinCoders = require('./gcode/resin-coders')

module.exports = (slicer, scene) ->
    
    # Extract mesh from scene
    mesh = preprocessing.extractMesh(scene)
    
    # Calculate layers
    bounds = mesh.geometry.boundingBox
    layerCount = Math.ceil(bounds.max.z / slicer.layerHeight)
    
    # Initialize raycaster
    raycaster = new ResinRaycaster(mesh, slicer)
    
    # Slice each layer
    layers = []
    for layerIndex in [0...layerCount]
        z = layerIndex * slicer.layerHeight
        
        # Generate pixel data for this layer
        pixels = raycaster.sliceLayer(z)
        
        # Convert to PNG
        png = ImageGenerator.generatePNG(pixels, slicer.resolutionX, slicer.resolutionY)
        
        layers.push(png)
    
    # Generate metadata
    metadata = resinCoders.generateMetadata(slicer, layerCount, bounds)
    
    # Package into ZIP
    zipData = ResinArchiver.createArchive(layers, metadata)
    
    return zipData
```

### Resin Configuration Class

```coffeescript
# src/config/resin/resin-config.coffee

class ResinConfig

    constructor: (options = {}) ->
        
        # Machine settings (pixels)
        @resolutionX = options.resolutionX ?= 2560
        @resolutionY = options.resolutionY ?= 1620
        
        # Build volume (mm)
        @machineX = options.machineX ?= 127.4
        @machineY = options.machineY ?= 80.6
        @machineZ = options.machineZ ?= 165
        
        # Layer settings
        @layerHeight = options.layerHeight ?= 0.05
        
        # Exposure settings (seconds)
        @normalExposureTime = options.normalExposureTime ?= 8.0
        @bottomLayerCount = options.bottomLayerCount ?= 5
        @bottomExposureTime = options.bottomExposureTime ?= 45.0
        
        # Movement settings (mm and mm/min)
        @liftHeight = options.liftHeight ?= 5.0
        @normalLiftSpeed = options.normalLiftSpeed ?= 60
        @bottomLiftSpeed = options.bottomLiftSpeed ?= 60
        @dropSpeed = options.dropSpeed ?= 150
        
        # Quality settings
        @antialiasingLevel = options.antialiasingLevel ?= 1
        
        # Material settings
        @resinDensity = options.resinDensity ?= 1.05
        @resinPrice = options.resinPrice ?= 30

module.exports = ResinConfig
```

---

These examples demonstrate the proposed API design and usage patterns for resin printing support in Polyslice. The implementation maintains consistency with existing FDM patterns while introducing resin-specific functionality.
