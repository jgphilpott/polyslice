---
applyTo: 'src/utils/**/*.coffee'
---

# Top-Level Utilities Overview

The top-level utilities provide accessor methods and unit conversion functions for the Polyslice class. Located in `src/utils/`.

## Module Structure

| File | Purpose |
|------|---------|
| `accessors.coffee` | Getter and setter methods for Polyslice properties |
| `conversions.coffee` | Unit conversion utilities using polyconvert |

## Accessors Module

Located in `src/utils/accessors.coffee`.

### Purpose

Provides all getter and setter methods for Polyslice properties. These methods:
- Handle unit conversions for user input/output
- Validate input values
- Support method chaining for setters

### Getter Methods

Getters convert from internal units to user's configured units:

```coffeescript
# Temperature (stored in °C)
getNozzleTemperature: (slicer) ->
    return conversions.temperatureFromInternal(slicer.nozzleTemperature, slicer.temperatureUnit)

# Length (stored in mm)
getLayerHeight: (slicer) ->
    return conversions.lengthFromInternal(slicer.layerHeight, slicer.lengthUnit)

# Speed (stored in mm/s)
getPerimeterSpeed: (slicer) ->
    return conversions.speedFromInternal(slicer.perimeterSpeed, slicer.speedUnit)
```

### Setter Methods

Setters convert from user's units to internal storage units:

```coffeescript
# Temperature
setNozzleTemperature: (slicer, temp = 0) ->
    if typeof temp is "number" and temp >= 0
        slicer.nozzleTemperature = conversions.temperatureToInternal(temp, slicer.temperatureUnit)
    return slicer

# Length
setLayerHeight: (slicer, height = 0.2) ->
    if typeof height is "number" and height > 0
        slicer.layerHeight = conversions.lengthToInternal(height, slicer.lengthUnit)
    return slicer
```

### Unit Setters

```coffeescript
setTimeUnit: (slicer, unit = "milliseconds")      # 'milliseconds' | 'seconds'
setLengthUnit: (slicer, unit = "millimeters")     # 'millimeters' | 'inches'
setSpeedUnit: (slicer, unit = "millimeterSecond") # 'millimeterSecond' | 'inchSecond' | 'meterSecond'
setTemperatureUnit: (slicer, unit = "celsius")    # 'celsius' | 'fahrenheit' | 'kelvin'
setAngleUnit: (slicer, unit = "degree")           # 'degree' | 'radian' | 'gradian'
```

### Boolean Properties

```coffeescript
# No conversion needed
getAutohome: (slicer) -> return slicer.autohome
getVerbose: (slicer) -> return slicer.verbose
getTestStrip: (slicer) -> return slicer.testStrip
getExposureDetection: (slicer) -> return slicer.exposureDetection
getSupportEnabled: (slicer) -> return slicer.supportEnabled

setAutohome: (slicer, autohome = true) ->
    slicer.autohome = Boolean autohome
    return slicer
```

### Percentage Properties

```coffeescript
# No unit conversion, but range validation
setFanSpeed: (slicer, speed = 100) ->
    if typeof speed is "number" and speed >= 0 and speed <= 100
        slicer.fanSpeed = Number speed
    return slicer

setInfillDensity: (slicer, density = 20) ->
    if typeof density is "number" and density >= 0 and density <= 100
        slicer.infillDensity = Number density
    return slicer
```

### String Properties

```coffeescript
setWorkspacePlane: (slicer, plane = "XY") ->
    plane = plane.toUpperCase().trim()
    if ["XY", "XZ", "YZ"].includes plane
        slicer.workspacePlane = String plane
    return slicer

setInfillPattern: (slicer, pattern = "grid") ->
    pattern = pattern.toLowerCase().trim()
    if ["grid", "lines", "triangles", "cubic", "gyroid", "hexagons", "honeycomb"].includes pattern
        slicer.infillPattern = String pattern
    return slicer
```

### Configuration Object Setters

Apply printer or filament presets:

```coffeescript
setPrinter: (slicer, printer) ->
    if printer
        slicer.printer = printer
        slicer.buildPlateWidth = conversions.lengthToInternal(printer.getSizeX(), slicer.lengthUnit)
        slicer.buildPlateLength = conversions.lengthToInternal(printer.getSizeY(), slicer.lengthUnit)
        slicer.nozzleDiameter = conversions.lengthToInternal(printer.getNozzle(0).diameter, slicer.lengthUnit)
        if not slicer.filament
            slicer.filamentDiameter = conversions.lengthToInternal(printer.getNozzle(0).filament, slicer.lengthUnit)
    return slicer

setFilament: (slicer, filament) ->
    if filament
        slicer.filament = filament
        slicer.nozzleTemperature = conversions.temperatureToInternal(filament.getNozzleTemperature(), slicer.temperatureUnit)
        slicer.bedTemperature = conversions.temperatureToInternal(filament.getBedTemperature(), slicer.temperatureUnit)
        # ... more property assignments
    return slicer
```

## Conversions Module

Located in `src/utils/conversions.coffee`.

### Purpose

Provides bidirectional unit conversion using the `@jgphilpott/polyconvert` library.

### To Internal (User → Storage)

```coffeescript
# Temperature: user unit → Celsius
temperatureToInternal: (temp, temperatureUnit) ->
    switch temperatureUnit
        when "fahrenheit" then polyconvert.temperature.fahrenheit.celsius(temp)
        when "kelvin" then polyconvert.temperature.kelvin.celsius(temp)
        else temp  # Already celsius

# Length: user unit → Millimeters
lengthToInternal: (length, lengthUnit) ->
    switch lengthUnit
        when "inches" then polyconvert.length.inch.millimeter(length)
        else length  # Already millimeters

# Speed: user unit → mm/s
speedToInternal: (speed, speedUnit) ->
    switch speedUnit
        when "inchSecond" then polyconvert.speed.inchSecond.millimeterSecond(speed)
        when "meterSecond" then polyconvert.speed.meterSecond.millimeterSecond(speed)
        else speed  # Already mm/s
```

### From Internal (Storage → User)

```coffeescript
# Temperature: Celsius → user unit
temperatureFromInternal: (temp, temperatureUnit) ->
    switch temperatureUnit
        when "fahrenheit" then polyconvert.temperature.celsius.fahrenheit(temp)
        when "kelvin" then polyconvert.temperature.celsius.kelvin(temp)
        else temp  # Return celsius

# Length: Millimeters → user unit
lengthFromInternal: (length, lengthUnit) ->
    switch lengthUnit
        when "inches" then polyconvert.length.millimeter.inch(length)
        else length  # Return millimeters
```

### All Conversion Functions

| Function | Input | Output |
|----------|-------|--------|
| `temperatureToInternal` | User temp unit | Celsius |
| `temperatureFromInternal` | Celsius | User temp unit |
| `lengthToInternal` | User length unit | Millimeters |
| `lengthFromInternal` | Millimeters | User length unit |
| `speedToInternal` | User speed unit | mm/s |
| `speedFromInternal` | mm/s | User speed unit |
| `timeToInternal` | User time unit | Milliseconds |
| `timeFromInternal` | Milliseconds | User time unit |
| `volumeToInternal` | User volume unit | mm³ |
| `volumeFromInternal` | mm³ | User volume unit |
| `massToInternal` | User mass unit | Grams |
| `massFromInternal` | Grams | User mass unit |
| `densityToInternal` | User density unit | g/cm³ |
| `densityFromInternal` | g/cm³ | User density unit |
| `dataToInternal` | User data unit | Megabytes |
| `dataFromInternal` | Megabytes | User data unit |
| `areaToInternal` | User area unit | mm² |
| `areaFromInternal` | mm² | User area unit |
| `angleToInternal` | User angle unit | Degrees |
| `angleFromInternal` | Degrees | User angle unit |

### Type Safety

All conversion functions handle invalid input:

```coffeescript
temperatureToInternal: (temp, temperatureUnit) ->
    return 0 if typeof temp isnt "number"
    # ... conversion logic
```

## Important Conventions

1. **Internal units**: Always use standard units internally (mm, °C, mm/s, ms)
2. **Validation**: Setters validate type and range before assignment
3. **Method chaining**: All setters return `slicer` for chaining
4. **Type coercion**: Use `Boolean()`, `Number()`, `String()` for explicit conversion
5. **Default values**: Provide sensible defaults for all setter parameters
6. **Case handling**: Normalize string inputs with `.toLowerCase().trim()` or `.toUpperCase().trim()`
