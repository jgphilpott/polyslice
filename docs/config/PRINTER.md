# Printer Configuration

The `Printer` class provides pre-configured settings for popular 3D printers, simplifying the setup process for Polyslice.

## Features

- **Pre-configured Printers**: 44 popular 3D printer models with correct specifications
- **Customizable Settings**: Modify any printer property after creation
- **Multi-nozzle Support**: Support for printers with multiple extruders
- **Build Plate Shapes**: Rectangular and circular build plate support

## Usage

### Basic Usage

```javascript
const { Printer } = require("@jgphilpott/polyslice");

// Create a printer instance with a preset
const printer = new Printer("Ender3");

// Access printer specifications
console.log(printer.getSize());        // { x: 220, y: 220, z: 250 }
console.log(printer.getNozzle(0));     // { filament: 1.75, diameter: 0.4, gantry: 25 }
console.log(printer.getHeatedBed());   // true

// List all available printer presets
console.log(printer.listAvailablePrinters());
```

### With Polyslice

```javascript
const { Polyslice, Printer } = require("@jgphilpott/polyslice");

// Create slicer with printer configuration
const slicer = new Polyslice({
    printer: new Printer("Ender3"),
    nozzleTemperature: 200,
    bedTemperature: 60
});

// Printer settings automatically configure build plate dimensions
console.log(slicer.getBuildPlateWidth());   // 220
console.log(slicer.getBuildPlateLength());  // 220
console.log(slicer.getNozzleDiameter());    // 0.4
```

### Customizing Printer Settings

```javascript
const printer = new Printer("Ender3");

// Modify build volume
printer.setSize(250, 250, 300);
printer.setSizeZ(400);

// Modify nozzle settings
printer.setNozzle(0, 1.75, 0.6, 30);  // index, filament, diameter, gantry

// Add a second nozzle for dual extrusion
printer.addNozzle(1.75, 0.4, 25);

// Modify heating capabilities
printer.setHeatedBed(true);
printer.setHeatedVolume(true);  // For enclosed printers

// Modify build plate shape
printer.setShape("circular");
printer.setCentred(true);
```

## Available Printers

### Creality

| Model | Build Volume | Heated Bed | Notes |
|-------|-------------|------------|-------|
| `Ender3` | 220×220×250 | ✓ | Most popular budget FDM printer |
| `Ender3V2` | 220×220×250 | ✓ | Updated version with improvements |
| `Ender3Pro` | 220×220×250 | ✓ | Enhanced with better components |
| `Ender3S1` | 220×220×270 | ✓ | Direct drive extruder and auto-leveling |
| `Ender5` | 220×220×300 | ✓ | Cube frame design |
| `Ender6` | 250×250×400 | ✓ | CoreXY design with enclosed frame |
| `CR10` | 300×300×400 | ✓ | Large format printer |
| `CR10S5` | 500×500×500 | ✓ | Extra large build volume |
| `CR6SE` | 235×235×250 | ✓ | Auto-leveling with silicone nozzle |
| `CrealityK1` | 220×220×250 | ✓ | High-speed Core XY printer (enclosed) |
| `CrealityK1Max` | 300×300×300 | ✓ | Larger high-speed printer (enclosed) |

### Prusa Research

| Model | Build Volume | Heated Bed | Notes |
|-------|-------------|------------|-------|
| `PrusaI3MK3S` | 250×210×210 | ✓ | Popular open-source printer |
| `PrusaMini` | 180×180×180 | ✓ | Compact version |
| `PrusaMK4` | 250×210×220 | ✓ | Latest variant with input shaping |
| `PrusaXL` | 360×360×360 | ✓ | Multi-tool head system |

### Bambu Lab

| Model | Build Volume | Heated Bed | Enclosed | Notes |
|-------|-------------|------------|----------|-------|
| `BambuLabX1Carbon` | 256×256×256 | ✓ | ✓ | High-speed enclosed printer |
| `BambuLabP1P` | 256×256×256 | ✓ | ✗ | High-speed open-frame printer |
| `BambuLabA1` | 256×256×256 | ✓ | ✗ | Mid-size option |
| `BambuLabA1Mini` | 180×180×180 | ✓ | ✗ | Compact affordable option |

### Anycubic

| Model | Build Volume | Heated Bed | Notes |
|-------|-------------|------------|-------|
| `AnycubicI3Mega` | 210×210×205 | ✓ | Popular budget option |
| `AnycubicKobra` | 220×220×250 | ✓ | Auto-leveling budget printer |
| `AnycubicVyper` | 245×245×260 | ✓ | Auto-leveling with direct drive |
| `AnycubicPhotonMonoX` | 192×120×245 | ✗ | Resin printer (for reference) |

### Elegoo

| Model | Build Volume | Heated Bed | Notes |
|-------|-------------|------------|-------|
| `ElegooNeptune3` | 220×220×280 | ✓ | Budget-friendly with Klipper firmware |
| `ElegooNeptune3Pro` | 225×225×280 | ✓ | Upgraded Neptune with better features |
| `ElegooNeptune4` | 225×225×265 | ✓ | Updated Neptune with Klipper |
| `ElegooNeptune4Pro` | 225×225×265 | ✓ | Pro version with improvements |

### Artillery

| Model | Build Volume | Heated Bed | Notes |
|-------|-------------|------------|-------|
| `ArtillerySidewinderX1` | 300×300×400 | ✓ | Direct drive extruder |
| `ArtillerySidewinderX2` | 300×300×400 | ✓ | Updated model |
| `ArtilleryGenius` | 220×220×250 | ✓ | Titan direct drive extruder |

### Sovol

| Model | Build Volume | Heated Bed | Notes |
|-------|-------------|------------|-------|
| `SovolSV06` | 220×220×250 | ✓ | Direct drive with auto-leveling |
| `SovolSV06Plus` | 300×300×340 | ✓ | Larger SV06 |

### Other Manufacturers

| Model | Build Volume | Heated Bed | Notes |
|-------|-------------|------------|-------|
| `Voron24` | 350×350×350 | ✓ | DIY CoreXY printer (enclosed) |
| `UltimakerS5` | 330×240×300 | ✓ | Professional grade (2.85mm filament) |
| `FlashForgeCreatorPro` | 225×145×150 | ✓ | Dual extruder |
| `FlashforgeAdventurer3` | 150×150×150 | ✓ | Compact enclosed printer |
| `Raise3DPro2` | 305×305×300 | ✓ | Professional large volume |
| `MakerbotReplicatorPlus` | 295×195×165 | ✓ | Professional desktop printer |
| `QidiXPlus` | 270×200×200 | ✓ | Enclosed industrial printer |
| `MonopriceSelectMiniV2` | 120×120×120 | ✓ | Ultra-compact budget printer |
| `LulzBotMini2` | 160×160×180 | ✓ | Open-source auto-leveling (2.85mm) |
| `LulzBotTAZ6` | 280×280×250 | ✓ | Large format open-source (2.85mm) |
| `KingroonKP3S` | 180×180×180 | ✓ | Compact budget printer |
| `AnkerMakeM5` | 235×235×250 | ✓ | Fast consumer printer |

## API Reference

### Constructor

```javascript
new Printer(model)
```

**Parameters:**
- `model` (string): Printer model name (default: "Ender3")

If the model is not found, defaults to "Ender3" with a warning.

### Getters

| Method | Returns | Description |
|--------|---------|-------------|
| `getModel()` | string | Model name |
| `getSize()` | object | Build volume `{ x, y, z }` in mm |
| `getSizeX()` | number | Build width in mm |
| `getSizeY()` | number | Build length in mm |
| `getSizeZ()` | number | Build height in mm |
| `getShape()` | string | "rectangular" or "circular" |
| `getCentred()` | boolean | Whether origin is at center |
| `getHeated()` | object | `{ volume, bed }` heating capabilities |
| `getHeatedVolume()` | boolean | Has heated chamber |
| `getHeatedBed()` | boolean | Has heated bed |
| `getNozzles()` | array | All nozzle configurations |
| `getNozzle(index)` | object | Single nozzle `{ filament, diameter, gantry }` |
| `getNozzleCount()` | number | Number of nozzles |

### Setters

All setters return `this` for chaining.

| Method | Parameters | Description |
|--------|------------|-------------|
| `setSize(x, y, z)` | numbers | Set build volume |
| `setSizeX(x)` | number | Set build width |
| `setSizeY(y)` | number | Set build length |
| `setSizeZ(z)` | number | Set build height |
| `setShape(shape)` | string | "rectangular" or "circular" |
| `setCentred(centred)` | boolean | Set origin at center |
| `setHeatedVolume(heated)` | boolean | Set heated chamber |
| `setHeatedBed(heated)` | boolean | Set heated bed |
| `setNozzle(index, filament, diameter, gantry)` | numbers | Modify nozzle config |
| `addNozzle(filament, diameter, gantry)` | numbers | Add new nozzle |
| `removeNozzle(index)` | number | Remove nozzle at index |

### Utility Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `listAvailablePrinters()` | array | List of all printer model names |

## Printer Properties

Each printer configuration includes:

- **size**: Build volume dimensions `{ x, y, z }` in millimeters
- **shape**: Build plate shape ("rectangular" or "circular")
- **centred**: Whether the origin is at the center (true) or corner (false)
- **heated**: Heating capabilities `{ volume, bed }`
  - `volume`: Enclosed heated chamber (for ABS, etc.)
  - `bed`: Heated build plate
- **nozzles**: Array of nozzle configurations
  - `filament`: Filament diameter in mm (1.75 or 2.85)
  - `diameter`: Nozzle diameter in mm (0.4, 0.6, etc.)
  - `gantry`: Gantry/carriage size in mm (for collision avoidance)

## Notes

- Most FDM printers use 1.75mm filament; some older models (Ultimaker, LulzBot) use 2.85mm
- The `gantry` value is used for calculating safe travel paths to avoid collisions
- Enclosed printers (`heatedVolume: true`) are better suited for ABS and other temperature-sensitive materials
- Build plate origin is typically at the front-left corner; some printers center it
