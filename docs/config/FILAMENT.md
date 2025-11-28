# Filament Configuration

The `Filament` class provides pre-configured settings for popular 3D printing filaments, including temperature, retraction, and material properties.

## Features

- **Pre-configured Filaments**: 35 popular filament types with optimized settings
- **Material Properties**: Density, diameter, and physical characteristics
- **Temperature Settings**: Nozzle, bed, and standby temperatures
- **Retraction Settings**: Speed and distance for clean prints
- **Customizable**: Modify any setting after creation

## Usage

### Basic Usage

```javascript
const { Filament } = require("@jgphilpott/polyslice");

// Create a filament instance
const filament = new Filament("GenericPLA");

// Access filament properties
console.log(filament.getType());              // "pla"
console.log(filament.getNozzleTemperature()); // 200
console.log(filament.getBedTemperature());    // 60
console.log(filament.getFan());               // 100
console.log(filament.getRetractionDistance());// 5

// List all available filament presets
console.log(filament.listAvailableFilaments());
```

### With Polyslice

```javascript
const { Polyslice, Filament } = require("@jgphilpott/polyslice");

// Create slicer with filament configuration
const slicer = new Polyslice({
    filament: new Filament("GenericPLA")
});

// Filament settings automatically configure temperatures and retraction
console.log(slicer.getNozzleTemperature());  // 200
console.log(slicer.getBedTemperature());     // 60
console.log(slicer.getFanSpeed());           // 100
console.log(slicer.getRetractionDistance()); // 5
```

### Combined with Printer

```javascript
const { Polyslice, Printer, Filament } = require("@jgphilpott/polyslice");

// Automatic configuration from both printer and filament
const slicer = new Polyslice({
    printer: new Printer("Ender3"),
    filament: new Filament("PrusamentPLA")
});

// All settings are automatically configured
console.log(slicer.getBuildPlateWidth());    // 220 (from printer)
console.log(slicer.getNozzleTemperature());  // 215 (from filament)
console.log(slicer.getBedTemperature());     // 60 (from filament)
```

### Customizing Filament Settings

```javascript
const filament = new Filament("GenericPLA");

// Modify temperature settings
filament.setNozzleTemperature(210);
filament.setBedTemperature(65);
filament.setStandbyTemperature(180);

// Modify retraction settings
filament.setRetractionSpeed(50);
filament.setRetractionDistance(6);

// Modify fan speed
filament.setFan(80);

// Modify physical properties
filament.setDiameter(1.75);
filament.setDensity(1.24);
```

## Available Filaments

### Generic Materials

| Material | Nozzle Temp | Bed Temp | Fan | Notes |
|----------|-------------|----------|-----|-------|
| `GenericPLA` | 200°C | 60°C | 100% | Standard PLA for general purpose |
| `GenericPETG` | 240°C | 80°C | 50% | Durable with good layer adhesion |
| `GenericABS` | 240°C | 100°C | 0% | Strong, requires enclosed printer |
| `GenericTPU` | 220°C | 60°C | 50% | Flexible for elastic parts |
| `GenericNylon` | 250°C | 80°C | 20% | Engineering grade, strong and flexible |
| `GenericASA` | 250°C | 100°C | 0% | Weather resistant outdoor alternative to ABS |

### PLA Brands

| Material | Brand | Nozzle Temp | Bed Temp | Notes |
|----------|-------|-------------|----------|-------|
| `HatchboxPLA` | Hatchbox | 205°C | 60°C | High quality PLA |
| `eSunPLAPlus` | eSun | 210°C | 60°C | Enhanced strength |
| `OverturePLA` | Overture | 200°C | 60°C | Reliable, consistent quality |
| `PrusamentPLA` | Prusa | 215°C | 60°C | Premium with tight tolerances |
| `PolymakerPolyLitePLA` | Polymaker | 210°C | 60°C | Easy to print for beginners |
| `PolymakerPolyTerraPLA` | Polymaker | 210°C | 60°C | Eco-friendly matte finish |
| `PolymakerPolyMaxPLA` | Polymaker | 215°C | 60°C | Toughest PLA available |
| `BambuLabPLABasic` | Bambu Lab | 210°C | 60°C | Optimized for Bambu printers |
| `BambuLabPLAMatte` | Bambu Lab | 210°C | 60°C | Matte finish with reduced sheen |
| `SunluPLA` | Sunlu | 205°C | 60°C | Budget-friendly good quality |
| `ColorFabbPLAPHA` | ColorFabb | 210°C | 60°C | Premium blend with enhanced properties |

### PETG Brands

| Material | Brand | Nozzle Temp | Bed Temp | Notes |
|----------|-------|-------------|----------|-------|
| `PrusamentPETG` | Prusa | 245°C | 85°C | Excellent layer adhesion |
| `PrusaPETG` | Prusa | 245°C | 85°C | Prusa's own formulation |
| `BambuLabPETGHF` | Bambu Lab | 250°C | 80°C | High flow for fast printing |
| `PolymakerPolyLitePETG` | Polymaker | 240°C | 80°C | Easy to print for beginners |
| `eSunPETG` | eSun | 235°C | 80°C | Reliable and affordable |
| `OverturePETG` | Overture | 240°C | 80°C | Affordable with good quality |
| `HatchboxPETG` | Hatchbox | 245°C | 85°C | Consistent quality |
| `SunluPETG` | Sunlu | 235°C | 80°C | Budget-friendly |
| `ColorFabbNGen` | ColorFabb | 240°C | 85°C | Advanced copolyester |

### ABS Brands

| Material | Brand | Nozzle Temp | Bed Temp | Fan | Notes |
|----------|-------|-------------|----------|-----|-------|
| `BambuLabABS` | Bambu Lab | 245°C | 100°C | 0% | For enclosed printers |
| `eSunABSPlus` | eSun | 240°C | 100°C | 0% | Enhanced properties |
| `HatchboxABS` | Hatchbox | 240°C | 100°C | 0% | Reliable for strong parts |

### Flexible (TPU)

| Material | Brand | Nozzle Temp | Bed Temp | Notes |
|----------|-------|-------------|----------|-------|
| `NinjaFlexTPU` | NinjaFlex | 225°C | 40°C | Premium flexible filament |
| `SainSmartTPU` | SainSmart | 220°C | 60°C | Affordable flexible |
| `PolymakerPolyFlexTPU95` | Polymaker | 225°C | 50°C | Shore 95A flexible |

### Engineering

| Material | Brand | Nozzle Temp | Bed Temp | Notes |
|----------|-------|-------------|----------|-------|
| `3DXTechCarbonX` | 3DXTech | 260°C | 90°C | Carbon fiber reinforced nylon |

### 2.85mm Diameter

| Material | Brand | Nozzle Temp | Bed Temp | Notes |
|----------|-------|-------------|----------|-------|
| `UltimakerPLA` | Ultimaker | 210°C | 60°C | For Ultimaker printers |
| `UltimakerToughPLA` | Ultimaker | 215°C | 60°C | Impact resistant technical PLA |

## API Reference

### Constructor

```javascript
new Filament(material)
```

**Parameters:**
- `material` (string): Filament material name (default: "GenericPLA")

If the material is not found, defaults to "GenericPLA" with a warning.

### Getters

| Method | Returns | Description |
|--------|---------|-------------|
| `getMaterial()` | string | Material preset name |
| `getType()` | string | Material type (pla, petg, abs, tpu, nylon, asa) |
| `getName()` | string | Full product name |
| `getDescription()` | string | Material description |
| `getBrand()` | string | Manufacturer/brand name |
| `getColor()` | string | Hex color code |
| `getDiameter()` | number | Filament diameter in mm |
| `getDensity()` | number | Density in g/cm³ |
| `getWeight()` | number | Spool weight in grams |
| `getCost()` | number | Cost per spool |
| `getFan()` | number | Recommended fan speed (0-100) |
| `getTemperature()` | object | `{ bed, nozzle, standby }` in Celsius |
| `getBedTemperature()` | number | Bed temperature in °C |
| `getNozzleTemperature()` | number | Nozzle temperature in °C |
| `getStandbyTemperature()` | number | Standby temperature in °C |
| `getRetraction()` | object | `{ speed, distance }` |
| `getRetractionSpeed()` | number | Retraction speed in mm/s |
| `getRetractionDistance()` | number | Retraction distance in mm |

### Setters

All setters return `this` for chaining.

| Method | Parameters | Description |
|--------|------------|-------------|
| `setType(type)` | string | Set material type |
| `setName(name)` | string | Set product name |
| `setDescription(desc)` | string | Set description |
| `setBrand(brand)` | string | Set brand name |
| `setColor(color)` | string | Set hex color code |
| `setDiameter(diameter)` | number | Set filament diameter |
| `setDensity(density)` | number | Set material density |
| `setWeight(weight)` | number | Set spool weight |
| `setCost(cost)` | number | Set cost per spool |
| `setFan(fan)` | number | Set fan speed (0-100) |
| `setBedTemperature(temp)` | number | Set bed temperature |
| `setNozzleTemperature(temp)` | number | Set nozzle temperature |
| `setStandbyTemperature(temp)` | number | Set standby temperature |
| `setRetractionSpeed(speed)` | number | Set retraction speed |
| `setRetractionDistance(distance)` | number | Set retraction distance |

### Utility Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `listAvailableFilaments()` | array | List of all filament material names |

## Material Properties

Each filament configuration includes:

- **type**: Material category (pla, petg, abs, tpu, nylon, asa)
- **name**: Full product name
- **description**: Brief material description
- **brand**: Manufacturer/brand name
- **color**: Default hex color code
- **diameter**: Filament diameter in mm (1.75 or 2.85)
- **density**: Material density in g/cm³
- **weight**: Spool weight in grams
- **cost**: Cost per spool in currency units
- **fan**: Recommended fan speed percentage (0-100)
- **temperature**: Temperature settings in Celsius
  - `bed`: Heated bed temperature
  - `nozzle`: Printing nozzle temperature
  - `standby`: Standby temperature for multi-material
- **retraction**: Retraction settings
  - `speed`: Retraction speed in mm/s
  - `distance`: Retraction distance in mm

## Material Guide

### PLA (Polylactic Acid)
- **Best for**: General purpose, prototypes, decorative items
- **Temp range**: 190-220°C nozzle, 50-70°C bed
- **Fan**: 100% (cooling helps with overhangs)
- **Retraction**: 5mm at 45mm/s
- **Notes**: Easy to print, biodegradable, no heated bed required

### PETG (Polyethylene Terephthalate Glycol)
- **Best for**: Functional parts, water containers, mechanical parts
- **Temp range**: 230-250°C nozzle, 70-90°C bed
- **Fan**: 50% (some cooling, but not too much)
- **Retraction**: 6mm at 40mm/s
- **Notes**: Durable, food-safe, good layer adhesion

### ABS (Acrylonitrile Butadiene Styrene)
- **Best for**: Functional parts, heat-resistant items, automotive parts
- **Temp range**: 230-250°C nozzle, 95-110°C bed
- **Fan**: 0% (no cooling, causes warping)
- **Retraction**: 5mm at 40mm/s
- **Notes**: Requires enclosed printer, prone to warping

### TPU (Thermoplastic Polyurethane)
- **Best for**: Flexible parts, phone cases, gaskets
- **Temp range**: 210-230°C nozzle, 40-60°C bed
- **Fan**: 50%
- **Retraction**: 1-2mm at 20-25mm/s (minimal)
- **Notes**: Requires direct drive extruder for best results

### Nylon
- **Best for**: Engineering parts, gears, functional prototypes
- **Temp range**: 240-260°C nozzle, 70-90°C bed
- **Fan**: 20% (minimal cooling)
- **Retraction**: 6mm at 40mm/s
- **Notes**: Hygroscopic (absorbs moisture), dry before printing

### ASA (Acrylonitrile Styrene Acrylate)
- **Best for**: Outdoor parts, automotive parts, UV-resistant items
- **Temp range**: 240-260°C nozzle, 95-110°C bed
- **Fan**: 0%
- **Retraction**: 5mm at 40mm/s
- **Notes**: Weather resistant alternative to ABS
