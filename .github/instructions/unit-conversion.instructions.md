---
applyTo: '*.coffee'
---

# Unit Conversion Guidelines for Polyslice

These guidelines ensure consistent unit handling throughout the Polyslice codebase for user input/output and internal storage.

## Internal Storage Units

Polyslice uses standardized units internally for consistency and G-code generation:

- **Time**: milliseconds
- **Distance/Length**: millimeters  
- **Speed**: millimeters per second
- **Temperature**: celsius
- **Volume**: millimeters cubed
- **Mass**: grams
- **Density**: grams per centimeter cubed
- **Data**: megabytes
- **Area**: millimeters squared
- **Angle**: degrees

## User Interface Units

Users can configure different unit scales via constructor options or setters:

- **timeUnit**: 'milliseconds' | 'seconds'
- **lengthUnit**: 'millimeters' | 'inches' 
- **speedUnit**: 'millimeterSecond' | 'inchSecond' | 'meterSecond' | etc.
- **temperatureUnit**: 'celsius' | 'fahrenheit' | 'kelvin'
- **volumeUnit**: 'millimeterCu' | 'inchCu' | 'centimeterCu' | etc.
- **massUnit**: 'gram' | 'ounce' | 'kilogram' | 'pound'
- **densityUnit**: 'gramCentimeterCu' | 'ounceInchCu' | etc.
- **dataUnit**: 'megabyte' | 'kilobyte' | 'gigabyte' | 'terabyte'
- **areaUnit**: 'millimeterSq' | 'inchSq' | 'centimeterSq' | etc.
- **angleUnit**: 'degree' | 'radian'

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

Use `@jgphilpott/polyconvert` for **all** conversions. Never use custom conversion equations:

```coffeescript
# Import the conversion library
convert = require('@jgphilpott/polyconvert')

# Temperature conversions
celsius = convert.temperature.fahrenheit.celsius(fahrenheitValue)
fahrenheit = convert.temperature.celsius.fahrenheit(celsiusValue)

# Length conversions  
millimeters = convert.length.inch.millimeter(inchValue)
inches = convert.length.millimeter.inch(millimeterValue)

# Speed conversions (use speed converter, NOT length converter)
mmPerSecond = convert.speed.inchSecond.millimeterSecond(inchPerSecondValue)
inchPerSecond = convert.speed.millimeterSecond.inchSecond(mmPerSecondValue)

# Time conversions
milliseconds = convert.time.second.millisecond(secondValue)  
seconds = convert.time.millisecond.second(millisecondValue)

# Volume conversions
millimetersCubed = convert.volume.inchCu.millimeterCu(inchesCubedValue)
inchesCubed = convert.volume.millimeterCu.inchCu(millimetersCubedValue)

# Mass conversions
grams = convert.mass.ounce.gram(ounceValue)
ounces = convert.mass.gram.ounce(gramValue)

# Density conversions
gramPerCmCubed = convert.density.ounceInchCu.gramCentimeterCu(ouncePerInchCubedValue)
ouncePerInchCubed = convert.density.gramCentimeterCu.ounceInchCu(gramPerCmCubedValue)

# Data conversions
megabytes = convert.data.kilobyte.megabyte(kilobyteValue)
kilobytes = convert.data.megabyte.kilobyte(megabyteValue)

# Area conversions
millimetersSq = convert.area.inchSq.millimeterSq(inchesSqValue)
inchesSq = convert.area.millimeterSq.inchSq(millimetersSqValue)

# Angle conversions
degrees = convert.angle.radian.degree(radianValue)
radians = convert.angle.degree.radian(degreeValue)
```

## Supported Units

Based on polyconvert capabilities:

- **Temperature**: celsius, fahrenheit, kelvin
- **Length**: millimeter, inch, centimeter, meter, etc.
- **Speed**: millimeterSecond, inchSecond, meterSecond, etc.
- **Time**: millisecond, second, minute, hour, etc.
- **Volume**: millimeterCu, inchCu, centimeterCu, meterCu, etc.
- **Mass**: gram, ounce, kilogram, pound, milligram, etc.
- **Density**: gramCentimeterCu, ounceInchCu, kilogramMeterCu, poundFootCu, etc.
- **Data**: kilobyte, megabyte, gigabyte, terabyte, etc.
- **Area**: millimeterSq, inchSq, centimeterSq, meterSq, etc.
- **Angle**: degree, radian, gradian, milliradian, etc.

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