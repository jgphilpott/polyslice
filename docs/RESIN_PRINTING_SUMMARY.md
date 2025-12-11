# Resin Printing Support - Executive Summary

## Quick Overview

This document provides a concise summary of recommendations for adding resin printing (SLA/DLP/LCD) support to Polyslice based on analysis of the MinceSlicer repository.

**Full detailed research**: See [RESIN_PRINTING_RESEARCH.md](./RESIN_PRINTING_RESEARCH.md)

---

## What is Resin Printing?

Resin printing uses UV light to cure liquid photopolymer resin layer by layer:

1. Display layer image on LCD/DLP screen
2. UV light cures resin where pixels are white
3. Build plate lifts to unstick from FEP film
4. Lower to next layer and repeat

**Key Difference from FDM**: Outputs raster images (PNG) instead of vector paths (G-code)

---

## Recommended Approach

### ✅ Extend Polyslice (Don't Fork)

Add resin support as a **dual-mode system**:

```javascript
// FDM mode (default, unchanged)
const fdmSlicer = new Polyslice({
  printMode: "fdm",  // or omit for default
  filament: pla
});
const gcode = fdmSlicer.slice(mesh);  // Returns G-code string

// Resin mode (new)
const resinSlicer = new Polyslice({
  printMode: "resin",
  printer: new ResinPrinter("AnyCubicPhotonMono"),
  layerHeight: 0.05,
  normalExposureTime: 8.0
});
const zipData = resinSlicer.slice(mesh);  // Returns ZIP archive
```

**Benefits:**
- ✅ Maintains backward compatibility
- ✅ Shares common infrastructure
- ✅ Unified API for users
- ✅ No breaking changes

---

## How MinceSlicer Works

### Core Algorithm

```javascript
// For each layer at height Z:
for (let y = 0; y < resolutionY; y++) {
  for (let x = 0; x < resolutionX; x++) {
    // Convert pixel to world coordinates
    const worldPos = pixelToWorld(x, y);
    
    // Cast ray through mesh
    const ray = new Ray(worldPos, direction);
    const hits = mesh.raycastAll(ray);
    
    // Odd hits = inside (white), even = outside (black)
    pixels[y * resolutionX + x] = (hits.length % 2) ? 255 : 0;
  }
}
```

### Output Format

ZIP archive containing:
- `run.gcode` - Metadata (exposure times, layer count, etc.)
- `0000.png` - Layer images (grayscale, printer resolution)
- `0001.png`
- `...`

This ZIP is converted to printer formats (`.ctb`, `.photon`) using [uv3dp](https://github.com/ezrec/uv3dp).

---

## Implementation Plan

### Phase 1: Foundation (1-2 weeks)

- Add `printMode` option to Polyslice
- Create `ResinConfig` class
- Add resin printer profiles
- Install dependencies: `three-mesh-bvh`, `fast-png`, `jszip`

### Phase 2: Basic Slicer (2-3 weeks)

- Implement raycasting layer generator
- Create PNG image generator
- Build resin slicing pipeline
- Integrate with main `slice()` method

### Phase 3: Output Packaging (1-2 weeks)

- Generate G-code metadata
- Create ZIP archiver
- Add resin exporter

**Total for working prototype: 4-7 weeks**

### Phase 4: Advanced Features (4-6 weeks, optional)

- Anti-aliasing (2x, 3x, 4x quality)
- Relief/emboss texturing
- Hollow detection
- Printer-specific format export

**Total for production system: 10-14 weeks**

---

## Key Dependencies

```json
{
  "dependencies": {
    "three-mesh-bvh": "^0.9.0",   // Fast raycasting
    "fast-png": "^6.2.0",          // PNG encoding
    "jszip": "^3.10.1"             // ZIP packaging
  }
}
```

---

## Configuration Example

```javascript
{
  printMode: "resin",
  
  // Machine settings
  resolutionX: 2560,           // Printer resolution (pixels)
  resolutionY: 1620,
  machineX: 127.4,             // Build volume (mm)
  machineY: 80.6,
  machineZ: 165,
  
  // Layer settings
  layerHeight: 0.05,           // Layer thickness (mm)
  
  // Exposure settings
  normalExposureTime: 8.0,     // Normal layers (seconds)
  bottomLayerCount: 5,         // Bottom layer count
  bottomExposureTime: 45.0,    // Bottom layers (seconds)
  
  // Movement settings
  liftHeight: 5.0,             // Lift distance (mm)
  liftSpeed: 60,               // Lift speed (mm/min)
  dropSpeed: 150,              // Drop speed (mm/min)
  
  // Quality settings
  antialiasingLevel: 1,        // 1 (off), 2, 3, or 4
  
  // Material
  resinDensity: 1.05,          // g/cm³
  resinPrice: 30               // $ per kg
}
```

---

## Resin Printer Profiles

Add profiles for popular resin printers:

```javascript
const resinPrinters = {
  "AnyCubicPhotonMono": {
    resolutionX: 2560,
    resolutionY: 1620,
    machineX: 127.4,
    machineY: 80.6,
    machineZ: 165
  },
  "ElegooMars3": {
    resolutionX: 4098,
    resolutionY: 2560,
    machineX: 143.4,
    machineY: 89.6,
    machineZ: 175
  },
  "PhrozenSonic4K": {
    resolutionX: 3840,
    resolutionY: 2400,
    machineX: 134.4,
    machineY: 84.0,
    machineZ: 200
  }
  // ... more printers
};
```

---

## File Structure

```
src/
├── polyslice.coffee              # Add printMode selection
├── slicer/
│   ├── slice.coffee              # FDM (existing)
│   └── resin-slice.coffee        # NEW: Resin slicing
├── slicer/resin/                 # NEW: Resin modules
│   ├── raycaster.coffee          # Layer generation
│   ├── image-generator.coffee    # PNG creation
│   └── archiver.coffee           # ZIP packaging
├── slicer/gcode/
│   ├── coders.coffee             # FDM (existing)
│   └── resin-coders.coffee       # NEW: Resin metadata
├── config/
│   ├── printer/
│   │   └── resin-printers.coffee # NEW: Resin profiles
│   └── resin/
│       └── resin-config.coffee   # NEW: Resin config class
└── exporters/
    └── resin-exporter.coffee     # NEW: Resin output
```

---

## Performance Expectations

Based on MinceSlicer benchmarks:

| Model Size | Layers | Anti-aliasing | Time |
|-----------|--------|---------------|------|
| Small (50mm) | 200 | Off | 5-10 sec |
| Medium (100mm) | 400 | Off | 15-30 sec |
| Large (150mm) | 600 | Off | 30-60 sec |
| Small (50mm) | 200 | 4x | 1-2 min |
| Medium (100mm) | 400 | 4x | 5-10 min |

Optimizations:
- Use BVH for fast raycasting
- Parallel processing with Web Workers
- Efficient PNG encoding with fast-png

---

## Testing Strategy

```javascript
// Unit tests
describe("Resin Raycaster", () => {
  it("should detect inside/outside correctly", () => {
    const mesh = createSphereMesh(10);
    const raycaster = new ResinRaycaster();
    const pixels = raycaster.sliceLayer(mesh, 0, 100, 100, 50, 50);
    expect(pixels[50 * 100 + 50]).toBe(255);  // Center = white
  });
});

// Integration tests
describe("Resin Slicer", () => {
  it("should produce valid ZIP with metadata", async () => {
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

## Migration Guide

### For Existing FDM Users

Nothing changes! All existing code continues to work:

```javascript
// This still works exactly as before
const slicer = new Polyslice({
  filament: pla,
  infillDensity: 20
});
const gcode = slicer.slice(mesh);
```

### For New Resin Users

```javascript
// Import new classes
const { Polyslice, ResinPrinter, ResinMaterial } = require("@jgphilpott/polyslice");

// Create resin slicer
const slicer = new Polyslice({
  printMode: "resin",
  printer: new ResinPrinter("AnyCubicPhotonMono"),
  resin: new ResinMaterial("StandardResin"),
  layerHeight: 0.05
});

// Slice returns ZIP data
const zipData = slicer.slice(mesh);

// Save to file
const { ResinExporter } = require("@jgphilpott/polyslice");
await ResinExporter.save(zipData, "output.zip");
```

---

## Unique Value Proposition

Adding resin support would make Polyslice:

🎯 **The ONLY three.js library supporting both FDM and resin printing**

This positions Polyslice as:
- Complete 3D printing solution for JavaScript
- Unified API for all printing technologies
- Web-native slicing for both print types
- Perfect for educational, artistic, and production use

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking changes | Use dual-mode system, default to FDM |
| Performance issues | Implement BVH, parallel processing |
| Complex relief system | Skip initially, add in Phase 4 |
| Format compatibility | Start with ZIP, add converters later |
| Browser memory limits | Add size warnings, optimize for Node.js |

---

## Decision Points

### Should we do this?

✅ **YES** - High value, proven feasible, manageable scope

### When?

- **Option A**: After current FDM stabilization (recommended)
- **Option B**: Parallel development with dedicated contributor
- **Option C**: Community contribution with guidance

### How much effort?

- **Minimum viable**: 4-7 weeks (Phases 1-3)
- **Production ready**: 10-14 weeks (All phases)
- **Maintenance**: Ongoing, shared with FDM

---

## Next Steps

1. **Approval**: Review this proposal and decide to proceed
2. **Planning**: Create detailed issues/tasks for each phase
3. **Setup**: Install dependencies, create branch
4. **Phase 1**: Implement foundation (1-2 weeks)
5. **Phase 2**: Basic slicer (2-3 weeks)
6. **Phase 3**: Output packaging (1-2 weeks)
7. **Testing**: Comprehensive tests throughout
8. **Documentation**: API docs, examples, tutorials
9. **Release**: Beta release for community feedback
10. **Phase 4**: Advanced features (optional)

---

## Resources

- **Full Research Document**: [RESIN_PRINTING_RESEARCH.md](./RESIN_PRINTING_RESEARCH.md)
- **MinceSlicer Repo**: https://github.com/yomboprime/MinceSlicer
- **MinceSlicer Demo**: https://yomboprime.github.io/MinceSlicer/dist/MinceSlicer.html
- **uv3dp Converter**: https://github.com/ezrec/uv3dp
- **three-mesh-bvh**: https://github.com/gkjohnson/three-mesh-bvh

---

## Conclusion

Resin printing support is a **high-value, feasible addition** to Polyslice that would:

- ✅ Differentiate from all other three.js slicers
- ✅ Complete the 3D printing ecosystem
- ✅ Open new use cases (jewelry, miniatures, dental, etc.)
- ✅ Maintain all existing FDM functionality
- ✅ Build on proven technology (MinceSlicer)

**Recommendation: Proceed with Phases 1-3** for a working prototype, evaluate Phase 4 based on user feedback.

---

**Document Version**: 1.0  
**Last Updated**: December 2024  
**Status**: Ready for Review
