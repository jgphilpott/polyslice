---
applyTo: 'src/config/**/*.coffee'
---

# Configuration Module Overview

The configuration module provides classes for printer and filament settings. Located in `src/config/`.

## Purpose

- Encapsulate printer hardware specifications
- Store filament material properties
- Provide presets for common printers and filaments
- Allow customization of print settings

## Printer Class

Located in `src/config/printer/printer.coffee`.

### Constructor

```coffeescript
printer = new Printer("Ender3")  # Uses preset configuration
printer = new Printer()          # Defaults to Ender3
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `size` | Object | Build volume dimensions `{ x, y, z }` in mm |
| `shape` | String | Build plate shape: `'rectangular'` or `'circular'` |
| `centred` | Boolean | Whether origin is at center or corner |
| `heated` | Object | Heating capabilities `{ volume, bed }` |
| `nozzles` | Array | Nozzle configurations |
| `model` | String | Printer model name |

### Nozzle Configuration

Each nozzle entry contains:

```coffeescript
nozzle = {
    filament: 1.75    # Filament diameter in mm
    diameter: 0.4     # Nozzle diameter in mm
    gantry: 25        # Gantry/carriage size in mm
}
```

### Getters

```coffeescript
printer.getModel()         # → "Ender3"
printer.getSize()          # → { x: 220, y: 220, z: 250 }
printer.getSizeX()         # → 220
printer.getSizeY()         # → 220
printer.getSizeZ()         # → 250
printer.getShape()         # → "rectangular"
printer.getCentred()       # → false
printer.getHeated()        # → { volume: false, bed: true }
printer.getHeatedVolume()  # → false
printer.getHeatedBed()     # → true
printer.getNozzles()       # → [{ filament: 1.75, diameter: 0.4, gantry: 25 }]
printer.getNozzle(0)       # → { filament: 1.75, diameter: 0.4, gantry: 25 }
printer.getNozzleCount()   # → 1
```

### Setters

All setters support method chaining:

```coffeescript
printer
    .setSize(200, 200, 300)
    .setSizeX(250)
    .setSizeY(250)
    .setSizeZ(400)
    .setShape('circular')
    .setCentred(true)
    .setHeatedVolume(true)
    .setHeatedBed(true)
    .setNozzle(0, 1.75, 0.6, 30)  # index, filament, diameter, gantry
    .addNozzle(1.75, 0.4, 25)
    .removeNozzle(1)
```

### Available Printers

```coffeescript
printer.listAvailablePrinters()  # Returns array of preset names
```

Presets are defined in `src/config/printer/printers.coffee`.

## Filament Class

Located in `src/config/filament/filament.coffee`.

### Constructor

```coffeescript
filament = new Filament("GenericPLA")  # Uses preset configuration
filament = new Filament()              # Defaults to GenericPLA
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `type` | String | Material type: `'pla'`, `'petg'`, `'abs'`, `'tpu'`, `'nylon'` |
| `name` | String | Full filament name |
| `description` | String | Material description |
| `brand` | String | Manufacturer/brand name |
| `color` | String | Hex color code |
| `diameter` | Number | Filament diameter in mm (1.75 or 2.85) |
| `density` | Number | Density in g/cm³ |
| `weight` | Number | Spool weight in grams |
| `cost` | Number | Cost per spool |
| `fan` | Number | Fan speed percentage (0-100) |
| `temperature` | Object | Temperature settings |
| `retraction` | Object | Retraction settings |
| `material` | String | Material preset name |

### Temperature Settings

```coffeescript
temperature = {
    bed: 60       # Bed temperature in °C
    nozzle: 200   # Nozzle temperature in °C
    standby: 150  # Standby temperature in °C
}
```

### Retraction Settings

```coffeescript
retraction = {
    speed: 40      # Retraction speed in mm/s
    distance: 1.0  # Retraction distance in mm
}
```

### Getters

```coffeescript
filament.getMaterial()           # → "GenericPLA"
filament.getType()               # → "pla"
filament.getName()               # → "Generic PLA"
filament.getDescription()        # → "Standard PLA filament..."
filament.getBrand()              # → "Generic"
filament.getColor()              # → "#ffffff"
filament.getDiameter()           # → 1.75
filament.getDensity()            # → 1.24
filament.getWeight()             # → 1000
filament.getCost()               # → 25
filament.getFan()                # → 100
filament.getTemperature()        # → { bed: 60, nozzle: 200, standby: 150 }
filament.getBedTemperature()     # → 60
filament.getNozzleTemperature()  # → 200
filament.getStandbyTemperature() # → 150
filament.getRetraction()         # → { speed: 40, distance: 1.0 }
filament.getRetractionSpeed()    # → 40
filament.getRetractionDistance() # → 1.0
```

### Setters

All setters support method chaining:

```coffeescript
filament
    .setType('petg')
    .setName('Custom PETG')
    .setDescription('High temperature PETG')
    .setBrand('Acme')
    .setColor('#00ff00')
    .setDiameter(1.75)
    .setDensity(1.27)
    .setWeight(750)
    .setCost(30)
    .setFan(50)
    .setBedTemperature(80)
    .setNozzleTemperature(240)
    .setStandbyTemperature(170)
    .setRetractionSpeed(30)
    .setRetractionDistance(1.5)
```

### Available Filaments

```coffeescript
filament.listAvailableFilaments()  # Returns array of preset names
```

Presets are defined in `src/config/filament/filaments.coffee`.

## Integration with Polyslice

### Applying Printer Settings

```coffeescript
slicer.setPrinter(printer)
# Automatically sets:
# - buildPlateWidth from printer.getSizeX()
# - buildPlateLength from printer.getSizeY()
# - nozzleDiameter from printer.getNozzle(0).diameter
# - filamentDiameter from printer.getNozzle(0).filament (if no filament set)
```

### Applying Filament Settings

```coffeescript
slicer.setFilament(filament)
# Automatically sets:
# - nozzleTemperature from filament.getNozzleTemperature()
# - bedTemperature from filament.getBedTemperature()
# - retractionDistance from filament.getRetractionDistance()
# - retractionSpeed from filament.getRetractionSpeed()
# - filamentDiameter from filament.getDiameter()
# - fanSpeed from filament.getFan()
```

## Environment Compatibility

Both classes export for Node.js and browser:

```coffeescript
# Node.js (CommonJS)
if typeof module isnt 'undefined' and module.exports
    module.exports = Printer

# Browser (Global)
if typeof window isnt 'undefined'
    window.Printer = Printer
```

## Important Conventions

1. **Default values**: Always default to safe, common values
2. **Validation**: Setters validate input types and ranges
3. **Method chaining**: All setters return `this` for chaining
4. **Console warnings**: Log warnings for unknown presets, don't throw errors
5. **Unit consistency**: All dimensions in mm, temperatures in °C
