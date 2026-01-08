# G-code Generation

The G-code coders module provides methods for generating G-code commands for 3D printing. All commands follow the [Marlin G-code](https://marlinfw.org/docs/gcode/) specification.

## Overview

The coders module (`src/slicer/gcode/coders.coffee`) contains all G-code generation methods used by the slicer. These methods generate properly formatted G-code strings that can be sent to Marlin-compatible 3D printers.

## Precision Settings

Polyslice allows you to configure the decimal precision for G-code output. This can significantly reduce file sizes while maintaining practical printing accuracy.

### Configuration

```javascript
const slicer = new Polyslice({
    coordinatePrecision: 3,  // Decimal places for X, Y, Z (default: 3)
    extrusionPrecision: 5,   // Decimal places for E values (default: 5)
    feedratePrecision: 0     // Decimal places for F values (default: 0)
});
```

### Default Values and Rationale

| Parameter | Default | Resolution | Rationale |
|-----------|---------|------------|-----------|
| `coordinatePrecision` | 3 | 0.001mm (1 micron) | Far exceeds typical printer accuracy (~0.01-0.1mm) |
| `extrusionPrecision` | 5 | 0.00001mm | Balances precision with file size |
| `feedratePrecision` | 0 | 1 mm/min | Integer speeds are adequate for motion control |

### Performance Impact

Using default precision settings can reduce G-code file sizes by **20-30%** compared to unlimited precision:

```javascript
// Example: Sphere with 16x16 segments
// High precision (10 decimals):  1,336,825 bytes
// Default precision (3/5/0):       981,842 bytes  (-26.6%)
// Low precision (2/3/0):           851,836 bytes  (-36.3%)
```

### Adjusting Precision

You can adjust precision at any time using setter methods:

```javascript
slicer.setCoordinatePrecision(2);  // Lower precision = smaller files
slicer.setExtrusionPrecision(4);
slicer.setFeedratePrecision(1);

// Valid range: 0-10 decimal places
```

**Note:** Trailing zeros are automatically removed for cleaner output.

## Usage

G-code commands are typically accessed through the Polyslice instance:

```javascript
const Polyslice = require("@jgphilpott/polyslice");

const slicer = new Polyslice({
    nozzleTemperature: 200,
    bedTemperature: 60,
    fanSpeed: 100
});

// Generate G-code commands
let gcode = "";
gcode += slicer.codeAutohome();           // G28 - Home all axes
gcode += slicer.codeNozzleTemperature(200, true);  // M109 R200 - Wait for nozzle temp
gcode += slicer.codeBedTemperature(60, true);      // M190 R60 - Wait for bed temp
gcode += slicer.codeLinearMovement(10, 10, 0.2, 0.5, 1500);  // G1 X10 Y10 Z0.2 E0.5 F1500

console.log(gcode);
```

## Movement Commands

### Linear Movement (G0/G1)

[Marlin Documentation](https://marlinfw.org/docs/gcode/G000-G001.html)

```javascript
// Travel move (G0) - no extrusion
slicer.codeLinearMovement(x, y, z, null, feedrate);

// Print move (G1) - with extrusion
slicer.codeLinearMovement(x, y, z, extrude, feedrate, power);
```

**Parameters:**
- `x`, `y`, `z`: Target coordinates (optional)
- `extrude`: Extrusion amount in mm (optional, null for travel)
- `feedrate`: Feed rate in mm/min (optional)
- `power`: Laser power for CNC (optional)

**Example:**
```javascript
slicer.codeLinearMovement(50, 50, 0.2, 0.5, 1200);
// Output: G1 X50 Y50 Z0.2 E0.5 F1200
```

### Arc Movement (G2/G3)

[Marlin Documentation](https://marlinfw.org/docs/gcode/G002-G003.html)

```javascript
slicer.codeArcMovement(direction, x, y, z, extrude, feedrate, power, xOffset, yOffset, radius, circles);
```

**Parameters:**
- `direction`: "clockwise" (G2) or "counterclockwise" (G3)
- `x`, `y`, `z`: Target coordinates
- `extrude`, `feedrate`, `power`: Movement parameters
- `xOffset`, `yOffset`: Arc center offset (I, J parameters)
- `radius`: Arc radius (R parameter, alternative to I/J)
- `circles`: Number of full circles (P parameter)

### Bézier Movement (G5)

[Marlin Documentation](https://marlinfw.org/docs/gcode/G005.html)

```javascript
slicer.codeBézierMovement(controlPoints);
```

**Parameters:**
- `controlPoints`: Array of control point objects with:
  - `xOffsetStart`, `yOffsetStart`: Start control point offset (I, J)
  - `xOffsetEnd`, `yOffsetEnd`: End control point offset (P, Q)

## Temperature Commands

### Nozzle Temperature (M104/M109)

[Marlin Documentation: M104](https://marlinfw.org/docs/gcode/M104.html), [M109](https://marlinfw.org/docs/gcode/M109.html)

```javascript
// Set temperature without waiting (M104)
slicer.codeNozzleTemperature(200, false);
// Output: M104 S200

// Set temperature and wait (M109)
slicer.codeNozzleTemperature(200, true);
// Output: M109 R200
```

**Parameters:**
- `temp`: Target temperature in Celsius (or null to use slicer setting)
- `wait`: Whether to wait for temperature (true = M109, false = M104)
- `index`: Tool index for multi-extruder (optional)

### Bed Temperature (M140/M190)

[Marlin Documentation: M140](https://marlinfw.org/docs/gcode/M140.html), [M190](https://marlinfw.org/docs/gcode/M190.html)

```javascript
// Set temperature without waiting (M140)
slicer.codeBedTemperature(60, false);
// Output: M140 S60

// Set temperature and wait (M190)
slicer.codeBedTemperature(60, true);
// Output: M190 R60
```

## Fan Control

### Fan Speed (M106/M107)

[Marlin Documentation: M106](https://marlinfw.org/docs/gcode/M106.html), [M107](https://marlinfw.org/docs/gcode/M107.html)

```javascript
// Turn fan on at percentage (M106)
slicer.codeFanSpeed(100);   // M106 S255
slicer.codeFanSpeed(50);    // M106 S128

// Turn fan off (M107)
slicer.codeFanSpeed(0);     // M107
```

**Parameters:**
- `speed`: Fan speed percentage (0-100)
- `index`: Fan index for multi-fan systems (optional)

## Homing and Positioning

### Autohome (G28)

[Marlin Documentation](https://marlinfw.org/docs/gcode/G028.html)

```javascript
// Home all axes
slicer.codeAutohome();              // G28

// Home specific axes
slicer.codeAutohome(true, false, true);  // G28 X Z
```

**Parameters:**
- `x`, `y`, `z`: Home specific axes (optional)
- `skip`: Skip if already homed (O parameter)
- `raise`: Raise Z after homing (R parameter)
- `leveling`: Restore leveling state (L parameter)

### Set Position (G92)

[Marlin Documentation](https://marlinfw.org/docs/gcode/G092.html)

```javascript
// Set current position
slicer.codeSetPosition(0, 0, 0, 0);  // G92 X0 Y0 Z0 E0

// Reset extruder position only
slicer.codeSetPosition(null, null, null, 0);  // G92 E0
```

### Positioning Mode (G90/G91)

[Marlin Documentation](https://marlinfw.org/docs/gcode/G090-G091.html)

```javascript
// Absolute positioning (G90)
slicer.codePositioningMode(true);

// Relative positioning (G91)
slicer.codePositioningMode(false);
```

### Extruder Mode (M82/M83)

[Marlin Documentation](https://marlinfw.org/docs/gcode/M082-M083.html)

```javascript
// Absolute extrusion (M82)
slicer.codeExtruderMode(true);

// Relative extrusion (M83)
slicer.codeExtruderMode(false);
```

## Workspace Configuration

### Workspace Plane (G17/G18/G19)

[Marlin Documentation](https://marlinfw.org/docs/gcode/G017-G019.html)

```javascript
slicer.codeWorkspacePlane("XY");  // G17
slicer.codeWorkspacePlane("XZ");  // G18
slicer.codeWorkspacePlane("YZ");  // G19
```

### Length Unit (G20/G21)

[Marlin Documentation](https://marlinfw.org/docs/gcode/G020-G021.html)

```javascript
slicer.codeLengthUnit("millimeters");  // G21
slicer.codeLengthUnit("inches");       // G20
```

### Temperature Unit (M149)

[Marlin Documentation](https://marlinfw.org/docs/gcode/M149.html)

```javascript
slicer.codeTemperatureUnit("celsius");     // M149 C
slicer.codeTemperatureUnit("fahrenheit");  // M149 F
slicer.codeTemperatureUnit("kelvin");      // M149 K
```

## Retraction

### Retract (G1 E-)

```javascript
// Retract using slicer settings
slicer.codeRetract();

// Retract with custom settings
slicer.codeRetract(5, 45);  // 5mm at 45mm/s
// Output: G1 E-5 F2700
```

### Unretract/Prime (G1 E+)

```javascript
// Unretract using slicer settings
slicer.codeUnretract();

// Unretract with custom settings
slicer.codeUnretract(5, 45);  // 5mm at 45mm/s
// Output: G1 E5 F2700
```

## Utility Commands

### Wait for Moves (M400)

[Marlin Documentation](https://marlinfw.org/docs/gcode/M400.html)

```javascript
slicer.codeWait();  // M400
```

### Dwell/Pause (G4/M0)

[Marlin Documentation: G4](https://marlinfw.org/docs/gcode/G004.html), [M0](https://marlinfw.org/docs/gcode/M000-M001.html)

```javascript
// Non-interruptible dwell (G4)
slicer.codeDwell(1000, false);  // G4 P1000 (1 second)

// Interruptible pause (M0)
slicer.codeDwell(1000, true, "Press button to continue");
```

### Display Message (M117)

[Marlin Documentation](https://marlinfw.org/docs/gcode/M117.html)

```javascript
slicer.codeMessage("Printing layer 1");  // M117 Printing layer 1
```

### Buzzer/Tone (M300)

[Marlin Documentation](https://marlinfw.org/docs/gcode/M300.html)

```javascript
slicer.codeTone(1000, 500);  // M300 P1000 S500 (1 second at 500Hz)
```

### Disable Steppers (M84)

[Marlin Documentation](https://marlinfw.org/docs/gcode/M084.html)

```javascript
// Disable all steppers
slicer.codeDisableSteppers();  // M84

// Disable specific steppers
slicer.codeDisableSteppers(true, true, false, true);  // M84 X Y E
```

### Emergency Shutdown (M112)

[Marlin Documentation](https://marlinfw.org/docs/gcode/M112.html)

```javascript
slicer.codeShutdown();  // M112
```

### Emergency Interrupt (M108)

[Marlin Documentation](https://marlinfw.org/docs/gcode/M108.html)

```javascript
slicer.codeInterrupt();  // M108
```

## Reporting Commands

### Position Report (M114/M154)

[Marlin Documentation: M114](https://marlinfw.org/docs/gcode/M114.html), [M154](https://marlinfw.org/docs/gcode/M154.html)

```javascript
// Single position report (M114)
slicer.codePositionReport(false);

// Auto position reporting (M154)
slicer.codePositionReport(true, 1);  // Report every 1 second
```

### Temperature Report (M105/M155)

[Marlin Documentation: M105](https://marlinfw.org/docs/gcode/M105.html), [M155](https://marlinfw.org/docs/gcode/M155.html)

```javascript
// Single temperature report (M105)
slicer.codeTemperatureReport(false);

// Auto temperature reporting (M155)
slicer.codeTemperatureReport(true, 1);  // Report every 1 second
```

### Fan Report (M123)

[Marlin Documentation](https://marlinfw.org/docs/gcode/M123.html)

```javascript
slicer.codeFanReport(true, 1);  // M123 S1
```

### SD Card Report (M27)

[Marlin Documentation](https://marlinfw.org/docs/gcode/M027.html)

```javascript
slicer.codeSDReport(true, 1);  // M27 S1
```

### Progress Report (M73)

[Marlin Documentation](https://marlinfw.org/docs/gcode/M073.html)

```javascript
slicer.codeProgressReport(50, 120);  // M73 P50 R120 (50%, 120 min remaining)
```

### Firmware Report (M115)

[Marlin Documentation](https://marlinfw.org/docs/gcode/M115.html)

```javascript
slicer.codeFirmwareReport();  // M115
```

## Print Sequence Commands

### Pre-Print Sequence

Generates the initialization sequence before printing:

```javascript
slicer.codePrePrint();
```

Includes:
1. Metadata header comment
2. Start heating nozzle and bed (parallel)
3. Autohome while heating
4. Raise Z to protect bed during heating
5. Wait for temperatures
6. Set extrusion mode
7. Set workspace plane and units
8. Print test strip (if enabled)
9. Reset extruder position
10. Initial retraction

### Post-Print Sequence

Generates the cleanup sequence after printing:

```javascript
slicer.codePostPrint();
```

Includes:
1. Turn off fan
2. Wipe nozzle (if enabled)
3. Retract and raise Z
4. Present print (home X/Y)
5. Turn off heaters
6. Disable steppers (except Z)
7. Play completion tone (if enabled)

### Metadata Header

Generates a comment header with print information:

```javascript
slicer.codeMetadata();
```

Output example:
```gcode
; Generated by Polyslice
; Version: 25.11.1
; Timestamp: 2024-01-15T10:30:00.000Z
; Repository: https://github.com/jgphilpott/polyslice
; Printer: Ender3
; Filament: Prusament PLA (pla)
; Nozzle Temp: 215°C
; Bed Temp: 60°C
; Layer Height: 0.2mm
```

### Test Strip

Generates a test strip to verify extrusion before printing:

```javascript
slicer.codeTestStrip(length, width, height);
```

Prints two parallel lines at the front of the build plate to verify filament flow and bed adhesion.

## G-code Reference

| Command | Description | Parameters |
|---------|-------------|------------|
| G0 | Rapid move | X Y Z F |
| G1 | Linear move | X Y Z E F |
| G2 | Clockwise arc | X Y Z E F I J R P |
| G3 | Counter-clockwise arc | X Y Z E F I J R P |
| G4 | Dwell | P (ms) or S (sec) |
| G5 | Bézier curve | I J P Q X Y |
| G17 | XY plane | - |
| G18 | XZ plane | - |
| G19 | YZ plane | - |
| G20 | Inches | - |
| G21 | Millimeters | - |
| G28 | Home | X Y Z O R L |
| G90 | Absolute positioning | - |
| G91 | Relative positioning | - |
| G92 | Set position | X Y Z E |
| M0 | Unconditional stop | - |
| M27 | SD status | S C |
| M73 | Progress | P R |
| M82 | Absolute extrusion | - |
| M83 | Relative extrusion | - |
| M84 | Disable steppers | X Y Z E |
| M104 | Set nozzle temp | S T |
| M105 | Temperature report | T R |
| M106 | Fan on | S P |
| M107 | Fan off | P |
| M108 | Break/resume | - |
| M109 | Wait nozzle temp | R S T |
| M112 | Emergency stop | - |
| M114 | Position report | R D E |
| M115 | Firmware info | - |
| M117 | LCD message | string |
| M123 | Fan report | S |
| M140 | Set bed temp | S |
| M149 | Temperature units | C F K |
| M154 | Auto position report | S |
| M155 | Auto temp report | S |
| M190 | Wait bed temp | R S T |
| M300 | Tone | P S |
| M400 | Wait for moves | - |
