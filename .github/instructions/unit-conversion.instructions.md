---
applyTo: '*.coffee'
---

# Unit Conversion Guidelines for Polyslice

These guidelines ensure consistent unit handling throughout the Polyslice codebase for user input/output and internal storage.

## Internal Storage Units

Polyslice uses standardized units internally for consistency and G-code generation:

- **Time**: milliseconds
- **Distance**: millimeters  
- **Temperature**: celsius

## User Interface Units

Users can configure different unit scales via constructor options or setters:

- **timeUnit**: 'milliseconds' | 'seconds'
- **lengthUnit**: 'millimeters' | 'inches' 
- **temperatureUnit**: 'celsius' | 'fahrenheit' | 'kelvin'

## Conversion Rules

### Setter Methods
- Accept user input in the configured unit scale
- Convert to internal storage units using `@jgphilpott/polyconvert`
- Store internally in standard units (ms, mm, °C)

### Getter Methods  
- Retrieve values from internal storage (always in standard units)
- Convert to user's configured unit scale using `@jgphilpott/polyconvert`
- Return values in the user's expected units

### Coder Methods
- Should NOT perform unit conversions
- Always use internal standard units for G-code generation
- Are intended for internal use by `slice()` method, not direct user calls
- This keeps G-code generation consistent and prevents double conversions

## Conversion Implementation

Use `@jgphilpott/polyconvert` for all conversions:

```coffeescript
# Temperature conversions
convert = require('@jgphilpott/polyconvert')
celsius = convert.temperature.fahrenheit.celsius(fahrenheitValue)
fahrenheit = convert.temperature.celsius.fahrenheit(celsiusValue)

# Length conversions  
millimeters = convert.length.inch.millimeter(inchValue)
inches = convert.length.millimeter.inch(millimeterValue)

# Time conversions
milliseconds = convert.time.second.millisecond(secondValue)  
seconds = convert.time.millisecond.second(millisecondValue)
```

## Supported Units

Based on polyconvert capabilities:

- **Temperature**: celsius, fahrenheit, kelvin
- **Length**: millimeter, inch (extensible to others as needed)
- **Time**: millisecond, second (extensible to others as needed)

## Examples

```coffeescript
# User sets temperature in Fahrenheit (configured unit)
slicer.setTemperatureUnit('fahrenheit')
slicer.setNozzleTemperature(400) # User input: 400°F
# Internally stored as: ~204.4°C

# User gets temperature in Fahrenheit (configured unit) 
temp = slicer.getNozzleTemperature() # Returns: 400°F
# Retrieved from internal: ~204.4°C and converted back

# G-code generation always uses internal units
gcode = slicer.codeNozzleTemperature() # Generates: M109 S204
```