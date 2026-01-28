# G-code generation methods for Polyslice.

polyconvert = require('@jgphilpott/polyconvert')

module.exports =

    # Helper method to format a numeric value to specified decimal precision.
    # Removes trailing zeros and unnecessary decimal points.
    formatPrecision: (value, decimals) ->

        if typeof value isnt "number" or isNaN(value)

            return value

        # Round to specified decimal places.
        factor = Math.pow(10, decimals)
        rounded = Math.round(value * factor) / factor

        # Convert to string with fixed decimals, then remove trailing zeros.
        formatted = rounded.toFixed(decimals)

        # Remove trailing zeros after decimal point, but keep at least "0" for zero values.
        if formatted.includes('.')
            formatted = formatted.replace(/\.?0+$/, '')

        # Handle edge case where formatted becomes empty string (e.g., 0.0 with 0 decimals).
        if formatted is '' or formatted is '-'
            formatted = '0'

        return formatted

    # Calculate estimated print time from G-code.
    # Parses G-code commands to estimate total print time based on movement distances and feedrates.
    calculatePrintTime: (slicer) ->

        totalTime = 0 # Total time in seconds.
        lines = slicer.gcode.split(slicer.newline)

        currentX = 0
        currentY = 0
        currentZ = 0

        currentFeedrate = null # Feedrate in mm/min.

        # Track positioning mode (true = absolute G90, false = relative G91)
        isAbsolutePositioning = true

        for line in lines

            # Skip empty lines and comments.
            line = line.trim()
            continue if line is '' or line.startsWith(';')

            # Extract command and parameters.
            parts = line.split(/\s+/)
            command = parts[0]

            # Track positioning mode changes
            if command is 'G90'
                isAbsolutePositioning = true
                continue
            else if command is 'G91'
                isAbsolutePositioning = false
                continue

            # Process movement commands (G0, G1, G2, G3).
            if command in ['G0', 'G1', 'G2', 'G3']

                # Extract coordinates and feedrate from the command.
                newX = currentX
                newY = currentY
                newZ = currentZ

                newFeedrate = currentFeedrate

                # Arc parameters (for G2/G3)
                arcI = null
                arcJ = null
                arcR = null

                # Track if coordinates were specified
                hasX = false
                hasY = false
                hasZ = false
                xValue = 0
                yValue = 0
                zValue = 0

                for part in parts[1..]

                    if part.startsWith('X')
                        hasX = true
                        xValue = parseFloat(part.substring(1))
                    else if part.startsWith('Y')
                        hasY = true
                        yValue = parseFloat(part.substring(1))
                    else if part.startsWith('Z')
                        hasZ = true
                        zValue = parseFloat(part.substring(1))
                    else if part.startsWith('F')
                        newFeedrate = parseFloat(part.substring(1))
                    else if part.startsWith('I')
                        arcI = parseFloat(part.substring(1))
                    else if part.startsWith('J')
                        arcJ = parseFloat(part.substring(1))
                    else if part.startsWith('R')
                        arcR = parseFloat(part.substring(1))

                # Apply positioning mode to coordinates
                if isAbsolutePositioning
                    # Absolute mode: coordinates are absolute positions
                    newX = xValue if hasX
                    newY = yValue if hasY
                    newZ = zValue if hasZ
                else
                    # Relative mode: coordinates are offsets from current position
                    newX = currentX + xValue if hasX
                    newY = currentY + yValue if hasY
                    newZ = currentZ + zValue if hasZ

                # Calculate distance moved.
                distance = 0

                # For arc movements (G2/G3), calculate arc length
                if (command is 'G2' or command is 'G3') and (arcI? or arcJ? or arcR?)

                    # Calculate arc length using the arc parameters
                    if arcR?
                        # R format: radius is given directly
                        radius = Math.abs(arcR)
                    else if arcI? or arcJ?
                        # I/J format: center offset from start point
                        i = arcI ? 0
                        j = arcJ ? 0
                        radius = Math.sqrt(i * i + j * j)

                    if radius > 0
                        # Calculate the chord length (straight line distance)
                        dx = newX - currentX
                        dy = newY - currentY
                        dz = newZ - currentZ
                        chordLength = Math.sqrt(dx * dx + dy * dy)

                        # Calculate the angle subtended by the arc
                        # Using the formula: angle = 2 * arcsin(chord / (2 * radius))
                        if chordLength < 2 * radius
                            angle = 2 * Math.asin(chordLength / (2 * radius))

                            # Arc length = radius * angle
                            arcLength = radius * angle

                            # Include Z component if present (helical arc)
                            if dz isnt 0
                                distance = Math.sqrt(arcLength * arcLength + dz * dz)
                            else
                                distance = arcLength
                        else
                            # Chord is too long for the radius (degenerate case), use straight line
                            distance = Math.sqrt(dx * dx + dy * dy + dz * dz)
                    else
                        # Invalid radius, fall back to straight line
                        dx = newX - currentX
                        dy = newY - currentY
                        dz = newZ - currentZ
                        distance = Math.sqrt(dx * dx + dy * dy + dz * dz)
                else
                    # Linear movement (G0/G1) or arc without parameters
                    dx = newX - currentX
                    dy = newY - currentY
                    dz = newZ - currentZ
                    distance = Math.sqrt(dx * dx + dy * dy + dz * dz)

                # Calculate time for this move if we have a feedrate.
                if distance > 0 and newFeedrate isnt null and newFeedrate > 0

                    # Feedrate is in mm/min, convert to mm/s then calculate time.
                    speedMmPerSec = newFeedrate / 60
                    moveTime = distance / speedMmPerSec
                    totalTime += moveTime

                # Update current position and feedrate.
                currentX = newX
                currentY = newY
                currentZ = newZ

                currentFeedrate = newFeedrate

            # Process dwell commands (G4).
            else if command is 'G4'

                for part in parts[1..]

                    if part.startsWith('P')
                        # P parameter is in milliseconds.
                        dwellTime = parseFloat(part.substring(1)) / 1000
                        totalTime += dwellTime
                    else if part.startsWith('S')
                        # S parameter is in seconds.
                        dwellTime = parseFloat(part.substring(1))
                        totalTime += dwellTime

            # Process heating commands (M109, M190) - add estimated heating time.
            else if command in ['M109', 'M190']

                # Estimate heating time: ~30 seconds for nozzle, ~60 seconds for bed.
                if command is 'M109'
                    totalTime += 30
                else if command is 'M190'
                    totalTime += 60

        return totalTime

    # Format time in seconds to HH:MM:SS format.
    formatTime: (timeInSeconds) ->

        # Handle negative or invalid time values.
        if typeof timeInSeconds isnt 'number' or isNaN(timeInSeconds) or timeInSeconds < 0
            return "00:00:00"

        hours = Math.floor(timeInSeconds / 3600)
        minutes = Math.floor((timeInSeconds % 3600) / 60)
        seconds = Math.floor(timeInSeconds % 60)

        # Pad with zeros for consistent formatting.
        hoursStr = String(hours).padStart(2, '0')
        minutesStr = String(minutes).padStart(2, '0')
        secondsStr = String(seconds).padStart(2, '0')

        return "#{hoursStr}:#{minutesStr}:#{secondsStr}"

    # https://marlinfw.org/docs/gcode/G028.html
    # Generate autohome G-code command.
    codeAutohome: (slicer, x = null, y = null, z = null, skip = null, raise = null, leveling = null) ->

        gcode = "G28"

        if x then gcode += " X"
        if y then gcode += " Y"
        if z then gcode += " Z"

        if skip then gcode += " O"
        if leveling then gcode += " L"

        if typeof raise is "number" then gcode += " R" + raise

        return gcode + slicer.newline

    # https://marlinfw.org/docs/gcode/G017-G019.html
    # Set workspace plane for coordinate system interpretation.
    codeWorkspacePlane: (slicer, plane = null) ->

        if plane is null

            plane = slicer.getWorkspacePlane()

        if plane is "XY"

            return "G17" + slicer.newline

        if plane is "XZ"

            return "G18" + slicer.newline

        if plane is "YZ"

            return "G19" + slicer.newline

    # https://marlinfw.org/docs/gcode/G020-G021.html
    # Set length units for coordinate measurements.
    codeLengthUnit: (slicer, unit = null) ->

        if unit is null

            unit = slicer.getLengthUnit()

        if unit is "millimeters"

            return "G21" + slicer.newline

        if unit is "inches"

            return "G20" + slicer.newline

    # https://marlinfw.org/docs/gcode/M149.html
    # Set temperature units for thermal measurements.
    codeTemperatureUnit: (slicer, unit = null) ->

        if unit is null

            unit = slicer.getTemperatureUnit()

        if unit is "celsius"

            return "M149 C" + slicer.newline

        if unit is "fahrenheit"

            return "M149 F" + slicer.newline

        if unit is "kelvin"

            return "M149 K" + slicer.newline

    # Helper method to build movement parameter strings.
    codeMovement: (slicer, x = null, y = null, z = null, extrude = null, feedrate = null, power = null) ->

        gcode = ""

        # Get precision settings from slicer.
        coordPrecision = slicer.getCoordinatePrecision()
        extrusionPrecision = slicer.getExtrusionPrecision()
        feedratePrecision = slicer.getFeedratePrecision()

        if typeof x is "number"

            gcode += " X" + module.exports.formatPrecision(x, coordPrecision)

        if typeof y is "number"

            gcode += " Y" + module.exports.formatPrecision(y, coordPrecision)

        if typeof z is "number"

            gcode += " Z" + module.exports.formatPrecision(z, coordPrecision)

        if typeof extrude is "number"

            gcode += " E" + module.exports.formatPrecision(extrude, extrusionPrecision)

        if typeof feedrate is "number"

            gcode += " F" + module.exports.formatPrecision(feedrate, feedratePrecision)

        if typeof power is "number"

            gcode += " S" + power

        return gcode

    # https://marlinfw.org/docs/gcode/G090-G091.html
    # Set positioning mode (absolute or relative).
    codePositioningMode: (slicer, absolute = true) ->

        if absolute

            return "G90" + slicer.newline

        else

            return "G91" + slicer.newline

    # https://marlinfw.org/docs/gcode/M082-M083.html
    # Set extruder mode (absolute or relative).
    codeExtruderMode: (slicer, absolute = true) ->

        if absolute

            return "M82" + slicer.newline

        else

            return "M83" + slicer.newline

    # https://marlinfw.org/docs/gcode/G092.html
    # Set position of axes or extruder.
    codeSetPosition: (slicer, x = null, y = null, z = null, extrude = null) ->

        gcode = "G92"

        if typeof x is "number"

            gcode += " X" + x

        if typeof y is "number"

            gcode += " Y" + y

        if typeof z is "number"

            gcode += " Z" + z

        if typeof extrude is "number"

            gcode += " E" + extrude

        return gcode + slicer.newline

    # https://marlinfw.org/docs/gcode/M084.html
    # Disable steppers.
    codeDisableSteppers: (slicer, x = false, y = false, z = false, e = false) ->

        gcode = "M84"

        if x then gcode += " X"
        if y then gcode += " Y"
        if z then gcode += " Z"
        if e then gcode += " E"

        return gcode + slicer.newline

    # https://marlinfw.org/docs/gcode/G000-G001.html
    # Generate linear movement G-code command.
    # NOTE: feedrate parameter should be in mm/min (G-code format), not mm/s.
    codeLinearMovement: (slicer, x = null, y = null, z = null, extrude = null, feedrate = null, power = null) ->

        if not extrude then gcode = "G0" else gcode = "G1"

        gcode += module.exports.codeMovement slicer, x, y, z, extrude, feedrate, power

        return gcode + slicer.newline

    # https://marlinfw.org/docs/gcode/G002-G003.html
    # Generate arc movement G-code command.
    codeArcMovement: (slicer, direction = "clockwise", x = null, y = null, z = null, extrude = null, feedrate = null, power = null, xOffset = null, yOffset = null, radius = null, circles = null) ->

        if direction is "clockwise"

            gcode = "G2"

        else if direction is "counterclockwise"

            gcode = "G3"

        else

            console.error "Invalid direction: #{direction}"
            return ""

        gcode += module.exports.codeMovement slicer, x, y, z, extrude, feedrate, power

        # Get coordinate precision for arc offsets.
        coordPrecision = slicer.getCoordinatePrecision()

        if typeof xOffset is "number"

            gcode += " I" + module.exports.formatPrecision(xOffset, coordPrecision)

        if typeof yOffset is "number"

            gcode += " J" + module.exports.formatPrecision(yOffset, coordPrecision)

        if typeof radius is "number"

            gcode += " R" + module.exports.formatPrecision(radius, coordPrecision)

        if typeof circles is "number"

            gcode += " P" + circles

        return gcode + slicer.newline

    # https://marlinfw.org/docs/gcode/G005.html
    # Generate Bézier curve movement G-code commands.
    codeBézierMovement: (slicer, controlPoints = []) ->

        gcode = ""

        for controlPoint, index in controlPoints

            if typeof controlPoint.xOffsetEnd is "number" and typeof controlPoint.yOffsetEnd is "number"

                if index is 0 and (typeof controlPoint.xOffsetStart isnt "number" or typeof controlPoint.yOffsetStart isnt "number")

                    console.error "First Bézier control point must have start offsets"

                else

                    gcode += "G5"

                    if index is 0

                        gcode += " I" + controlPoint.xOffsetStart
                        gcode += " J" + controlPoint.yOffsetStart

                    if typeof controlPoint.xOffsetStart is "number" and typeof controlPoint.yOffsetStart is "number"

                        gcode += " I" + controlPoint.xOffsetStart
                        gcode += " J" + controlPoint.yOffsetStart

                    gcode += " P" + controlPoint.xOffsetEnd
                    gcode += " Q" + controlPoint.yOffsetEnd

                    gcode += slicer.newline

            else

                console.error "Invalid Bézier Movement Parameters"

        return gcode

    # https://marlinfw.org/docs/gcode/M114.html
    # https://marlinfw.org/docs/gcode/M154.html
    # Generate position reporting G-code commands.
    codePositionReport: (slicer, auto = true, interval = 1, real = false, detail = false, extruder = false) ->

        if auto

            gcode = "M154"

            if typeof interval is "number" and interval >= 0

                if slicer.getTimeUnit() is "milliseconds"

                    interval /= 1000

                gcode += " S" + interval

        else

            gcode = "M114"

            if real then gcode += " R"
            if detail then gcode += " D"
            if extruder then gcode += " E"

        return gcode + slicer.newline

    # https://marlinfw.org/docs/gcode/M104.html
    # https://marlinfw.org/docs/gcode/M109.html
    # Generate nozzle temperature control G-code commands.
    codeNozzleTemperature: (slicer, temp = null, wait = true, index = null) ->

        if temp is null

            temp = slicer.getNozzleTemperature()

        if wait

            gcode = "M109"

            if typeof temp is "number" and temp >= 0

                gcode += " R" + temp

            if typeof index is "number"

                gcode += " T" + index

        else

            gcode = "M104"

            if typeof temp is "number" and temp >= 0

                gcode += " S" + temp

            if typeof index is "number"

                gcode += " T" + index

        return gcode + slicer.newline

    # https://marlinfw.org/docs/gcode/M140.html
    # https://marlinfw.org/docs/gcode/M190.html
    # Generate bed temperature control G-code commands.
    codeBedTemperature: (slicer, temp = null, wait = true, time = null) ->

        if temp is null

            temp = slicer.getBedTemperature()

        if wait

            gcode = "M190"

            if typeof temp is "number" and temp >= 0

                gcode += " R" + temp

            if typeof time is "number" and time > 0

                gcode += " T" + time

        else

            gcode = "M140"

            if typeof temp is "number" and temp >= 0

                gcode += " S" + temp

        return gcode + slicer.newline

    # https://marlinfw.org/docs/gcode/M105.html
    # https://marlinfw.org/docs/gcode/M155.html
    # Generate temperature reporting G-code commands.
    codeTemperatureReport: (slicer, auto = true, interval = 1, index = null, sensor = null) ->

        if auto

            gcode = "M155"

            if typeof interval is "number" and interval >= 0

                if slicer.getTimeUnit() is "milliseconds"

                    interval /= 1000

                gcode += " S" + interval

        else

            gcode = "M105"

            if typeof index is "number"

                gcode += " T" + index

            if typeof sensor is "number"

                gcode += " R" + sensor

        return gcode + slicer.newline

    # https://marlinfw.org/docs/gcode/M106.html
    # https://marlinfw.org/docs/gcode/M107.html
    # Generate fan speed control G-code commands.
    codeFanSpeed: (slicer, speed = null, index = null) ->

        if speed is null

            speed = slicer.getFanSpeed()

        if speed > 0

            gcode = "M106" + " S" + Math.round(speed * 2.55)

        else

            gcode = "M107"

        if typeof index is "number"

            gcode += " P" + index

        return gcode + slicer.newline

    # https://marlinfw.org/docs/gcode/M123.html
    # Generate fan status reporting G-code commands.
    codeFanReport: (slicer, auto = true, interval = 1) ->

        gcode = "M123"

        if auto and typeof interval is "number" and interval >= 0

            if slicer.getTimeUnit() is "milliseconds"

                interval /= 1000

            gcode += " S" + interval

        return gcode + slicer.newline

    # https://marlinfw.org/docs/gcode/G004.html
    # https://marlinfw.org/docs/gcode/M000-M001.html
    # Generate pause/dwell G-code commands.
    codeDwell: (slicer, time = null, interruptible = true, message = "") ->

        if interruptible then gcode = "M0" else gcode = "G4"

        if typeof time is "number" and time > 0

            if slicer.getTimeUnit() is "milliseconds" then gcode += " P" + time
            if slicer.getTimeUnit() is "seconds" then gcode += " S" + time

        if message and typeof message is "string"

            gcode += " " + message

        return gcode + slicer.newline

    # https://marlinfw.org/docs/gcode/M108.html
    # Generate emergency interrupt G-code command.
    codeInterrupt: (slicer) ->

        return "M108" + slicer.newline

    # https://marlinfw.org/docs/gcode/M400.html
    # Generate wait for moves completion G-code command.
    codeWait: (slicer) ->

        return "M400" + slicer.newline

    # https://marlinfw.org/docs/gcode/M300.html
    # Generate buzzer/tone G-code command.
    codeTone: (slicer, duration = 1, frequency = 500) ->

        gcode = "M300"

        if typeof duration is "number" and duration > 0

            if slicer.getTimeUnit() is "milliseconds"

                gcode += " P" + duration

            if slicer.getTimeUnit() is "seconds"

                gcode += " P" + (duration * 1000)

        if typeof frequency is "number" and frequency > 0

            gcode += " S" + frequency

        return gcode + slicer.newline

    # https://marlinfw.org/docs/gcode/M117.html
    # https://marlinfw.org/docs/gcode/M118.html
    # Generate display message G-code command.
    codeMessage: (slicer, message = "") ->

        return "M117 " + message + slicer.newline

    # https://marlinfw.org/docs/gcode/M112.html
    # Generate emergency shutdown G-code command.
    codeShutdown: (slicer) ->

        return "M112" + slicer.newline

    # https://marlinfw.org/docs/gcode/M115.html
    # Generate firmware info request G-code command.
    codeFirmwareReport: (slicer) ->

        return "M115" + slicer.newline

    # https://marlinfw.org/docs/gcode/M027.html
    # Generate SD card status reporting G-code commands.
    codeSDReport: (slicer, auto = true, interval = 1, name = false) ->

        gcode = "M27"

        if name then gcode += " C"

        if auto and typeof interval is "number" and interval >= 0

            if slicer.getTimeUnit() is "milliseconds"

                interval /= 1000

            gcode += " S" + interval

        return gcode + slicer.newline

    # https://marlinfw.org/docs/gcode/M073.html
    # Generate print progress reporting G-code commands.
    codeProgressReport: (slicer, percent = null, time = null) ->

        gcode = "M73"

        if typeof percent is "number" and percent >= 0

            gcode += " P" + percent

        if typeof time is "number" and time >= 0

            if slicer.getTimeUnit() is "milliseconds"

                time /= 60000

            else if slicer.getTimeUnit() is "seconds"

                time /= 60

            gcode += " R" + time

        return gcode + slicer.newline

    # https://marlinfw.org/docs/gcode/G010-G011.html
    # Generate retraction G-code using the configured retraction settings.
    codeRetract: (slicer, distance = null, speed = null) ->

        retractDistance = if distance isnt null then distance else slicer.retractionDistance # Use internal storage (mm)
        retractSpeed = if speed isnt null then speed else slicer.retractionSpeed # Use internal storage (mm/s)

        if retractDistance <= 0

            return "" # No retraction needed

        gcode = "G1"
        gcode += " E-" + retractDistance # E is always in mm for G-code

        if retractSpeed > 0

            # Convert mm/s to mm/min for F parameter using polyconvert
            feedratePerMin = Math.round(polyconvert.speed.millimeterSecond.millimeterMinute(retractSpeed))
            gcode += " F" + feedratePerMin

        return gcode + slicer.newline

    # Generate unretract/prime G-code using configured settings.
    codeUnretract: (slicer, distance = null, speed = null) ->

        retractDistance = if distance isnt null then distance else slicer.retractionDistance # Use internal storage (mm)
        retractSpeed = if speed isnt null then speed else slicer.retractionSpeed # Use internal storage (mm/s)

        if retractDistance <= 0

            return "" # No unretraction needed

        gcode = "G1"
        gcode += " E" + retractDistance # E is always in mm for G-code

        if retractSpeed > 0

            # Convert mm/s to mm/min for F parameter using polyconvert
            feedratePerMin = Math.round(polyconvert.speed.millimeterSecond.millimeterMinute(retractSpeed))
            gcode += " F" + feedratePerMin

        return gcode + slicer.newline

    # Update metadata in G-code with print statistics.
    # This should be called after slicing is complete to add statistics to the metadata header.
    updateMetadataWithStats: (slicer) ->

        # Only update if metadata is enabled.
        return unless slicer.getMetadata()

        # Find the end of the metadata block (marked by blank line after metadata).
        lines = slicer.gcode.split(slicer.newline)
        metadataEndIndex = -1

        inMetadata = false

        for line, index in lines

            # Metadata starts with "; Generated by Polyslice"
            if line.startsWith('; Generated by Polyslice')
                inMetadata = true

            # Metadata ends with a blank line
            else if inMetadata and line.trim() is ''
                metadataEndIndex = index
                break

        # If we found the metadata block, insert statistics before the blank line.
        if metadataEndIndex > 0

            statsLines = []

            # Add print statistics.
            if slicer.getMetadataTotalLayers() and slicer.totalLayers?

                statsLines.push("; Total Layers: " + slicer.totalLayers)

            if slicer.totalFilamentLength?

                # Filament length in mm.
                filamentLengthMm = slicer.totalFilamentLength

                if slicer.getMetadataFilamentLength()

                    statsLines.push("; Filament Length: " + module.exports.formatPrecision(filamentLengthMm, 2) + "mm")

                # Calculate material volume in mm³.
                # Use internal units (filamentDiameter is already in mm).
                filamentRadius = slicer.filamentDiameter / 2
                volumeMm3 = Math.PI * filamentRadius * filamentRadius * filamentLengthMm

                if slicer.getMetadataMaterialVolume()

                    statsLines.push("; Material Volume: " + module.exports.formatPrecision(volumeMm3, 2) + "mm³")

                # Calculate material weight in grams if filament density is available.
                if slicer.getMetadataMaterialWeight() and slicer.filament and slicer.filament.getDensity()

                    densityGPerCm3 = slicer.filament.getDensity()
                    volumeCm3 = volumeMm3 / 1000 # Convert mm³ to cm³.
                    weightGrams = volumeCm3 * densityGPerCm3
                    statsLines.push("; Material Weight: " + module.exports.formatPrecision(weightGrams, 2) + "g")

            # Calculate estimated print time.
            if slicer.getMetadataPrintTime()

                printTimeSeconds = module.exports.calculatePrintTime(slicer)
                formattedTime = module.exports.formatTime(printTimeSeconds)
                statsLines.push("; Estimated Print Time: " + formattedTime)

            # Insert statistics before the blank line that ends the metadata block.
            lines.splice(metadataEndIndex, 0, statsLines...)

            # Reconstruct the G-code.
            slicer.gcode = lines.join(slicer.newline)

        return

    # Generate metadata header comment for G-code.
    codeMetadata: (slicer) ->

        gcode = ""

        now = new Date() # Get current timestamp.
        timestamp = now.toISOString()

        try # Get package version (this will be available in the compiled context).

            pkg = require('../../package.json')
            version = pkg.version

        catch

            version = "Unknown"

        # Generate metadata header.
        # Always include the title as a marker for the metadata block.
        gcode += "; Generated by Polyslice" + slicer.newline

        if slicer.getMetadataVersion()

            gcode += "; Version: " + version + slicer.newline

        if slicer.getMetadataTimestamp()

            gcode += "; Timestamp: " + timestamp + slicer.newline

        if slicer.getMetadataRepository()

            gcode += "; Repository: https://github.com/jgphilpott/polyslice" + slicer.newline

        # G-code flavor/firmware compatibility
        gcode += "; Flavor: Marlin" + slicer.newline

        if slicer.getMetadataPrinter() and slicer.printer # Add printer information if available.

            gcode += "; Printer: " + slicer.printer.model + slicer.newline

        if slicer.getMetadataFilament() and slicer.filament # Add filament information if available.

            gcode += "; Filament: " + slicer.filament.name + " (" + slicer.filament.type + ")" + slicer.newline

        # Add key print settings.
        if slicer.getMetadataNozzleTemp()

            gcode += "; Nozzle Temp: " + slicer.nozzleTemperature + "°C" + slicer.newline

        if slicer.getMetadataBedTemp()

            gcode += "; Bed Temp: " + slicer.bedTemperature + "°C" + slicer.newline

        if slicer.getMetadataLayerHeight()

            gcode += "; Layer Height: " + slicer.getLayerHeight() + "mm" + slicer.newline

        # Add additional critical print parameters
        gcode += "; Infill Density: " + slicer.infillDensity + "%" + slicer.newline
        gcode += "; Infill Pattern: " + slicer.infillPattern + slicer.newline

        # Calculate wall count
        wallCount = Math.max(1, Math.floor((slicer.shellWallThickness / slicer.nozzleDiameter) + 0.0001))
        gcode += "; Wall Count: " + wallCount + slicer.newline

        # Support and adhesion information
        gcode += "; Support: " + (if slicer.supportEnabled then "Yes" else "No") + slicer.newline

        if slicer.adhesionEnabled
            gcode += "; Adhesion: " + slicer.adhesionType + slicer.newline
        else
            gcode += "; Adhesion: None" + slicer.newline

        # Print speed settings
        gcode += "; Perimeter Speed: " + slicer.getPerimeterSpeed() + "mm/s" + slicer.newline
        gcode += "; Infill Speed: " + slicer.getInfillSpeed() + "mm/s" + slicer.newline
        gcode += "; Travel Speed: " + slicer.getTravelSpeed() + "mm/s" + slicer.newline

        # Bounding box (will be filled in after slicing if available)
        if slicer.meshBounds?
            minX = module.exports.formatPrecision(slicer.meshBounds.minX, 2)
            minY = module.exports.formatPrecision(slicer.meshBounds.minY, 2)
            minZ = module.exports.formatPrecision(slicer.meshBounds.minZ, 2)
            maxX = module.exports.formatPrecision(slicer.meshBounds.maxX, 2)
            maxY = module.exports.formatPrecision(slicer.meshBounds.maxY, 2)
            maxZ = module.exports.formatPrecision(slicer.meshBounds.maxZ, 2)
            # Emit Cura-style per-axis bounding box metadata for consistent parsing.
            gcode += "; MINX: " + minX + slicer.newline
            gcode += "; MAXX: " + maxX + slicer.newline
            gcode += "; MINY: " + minY + slicer.newline
            gcode += "; MAXY: " + maxY + slicer.newline
            gcode += "; MINZ: " + minZ + slicer.newline
            gcode += "; MAXZ: " + maxZ + slicer.newline

        gcode += slicer.newline

        return gcode

    # Generate test strip G-code to verify extrusion before print.
    codeTestStrip: (slicer, length = null, width = 0.4, height = 0.25) ->

        gcode = ""

        margin = 10

        verbose = slicer.getVerbose()

        # Calculate test strip length: use full bed width minus margins.
        if length is null

            length = slicer.getBuildPlateWidth() - (margin * 2) # margin on each end.

        if verbose then gcode += module.exports.codeMessage(slicer, "Printing test strip...")

        # Reset extruder position before test strip.
        gcode += module.exports.codeSetPosition(slicer, null, null, null, 0).replace(slicer.newline, (if verbose then "; Reset Extruder" + slicer.newline else slicer.newline))

        # Move Z axis up first.
        gcode += module.exports.codeLinearMovement(slicer, null, null, 2.0, null, 3000).replace(slicer.newline, (if verbose then "; Move Z Up" + slicer.newline else slicer.newline))

        # Move to starting position at front left of bed (along X-axis).
        startX = margin
        startY = margin

        gcode += module.exports.codeLinearMovement(slicer, startX, startY, height, null, 5000).replace(slicer.newline, (if verbose then "; Move to Start Position" + slicer.newline else slicer.newline))

        # Draw the first line along X-axis.
        gcode += module.exports.codeLinearMovement(slicer, startX + length, startY, height, 15, 1500).replace(slicer.newline, (if verbose then "; Draw First Line" + slicer.newline else slicer.newline))

        # Move to side a little (travel move).
        gcode += module.exports.codeLinearMovement(slicer, startX + length, startY + width, height, null, 5000).replace(slicer.newline, (if verbose then "; Move to Side" + slicer.newline else slicer.newline))

        # Draw the second line (cumulative extrusion to E30).
        gcode += module.exports.codeLinearMovement(slicer, startX, startY + width, height, 30, 1500).replace(slicer.newline, (if verbose then "; Draw Second Line" + slicer.newline else slicer.newline))

        # Reset extruder after test strip.
        gcode += module.exports.codeSetPosition(slicer, null, null, null, 0).replace(slicer.newline, (if verbose then "; Reset Extruder" + slicer.newline else slicer.newline))

        # Lift nozzle.
        gcode += module.exports.codeLinearMovement(slicer, null, null, 2.0, null, 3000).replace(slicer.newline, (if verbose then "; Lift Nozzle" + slicer.newline else slicer.newline))

        return gcode

    # Generate pre-print sequence G-code.
    codePrePrint: (slicer) ->

        gcode = ""

        verbose = slicer.getVerbose()

        # Add metadata header if enabled.
        if slicer.getMetadata()

            gcode += module.exports.codeMetadata(slicer)

        if verbose then gcode += module.exports.codeMessage(slicer, "Starting pre-print sequence...")

        # Optimized heating: Start heating nozzle and bed simultaneously (without wait).
        if slicer.nozzleTemperature > 0

            gcode += module.exports.codeNozzleTemperature(slicer, null, false).replace(slicer.newline, (if verbose then "; Start Heating Nozzle" + slicer.newline else slicer.newline))

        if slicer.bedTemperature > 0

            gcode += module.exports.codeBedTemperature(slicer, null, false).replace(slicer.newline, (if verbose then "; Start Heating Bed" + slicer.newline else slicer.newline))

        # Perform autohome while heating (parallel operation for speed optimization).
        if slicer.getAutohome()

            gcode += module.exports.codeAutohome(slicer).replace(slicer.newline, (if verbose then "; Home All Axes" + slicer.newline else slicer.newline))

        # Back off bed 1cm after autohome (so hot nozzle isn't resting on bed while waiting for temp).
        gcode += module.exports.codeLinearMovement(slicer, null, null, 10, null, 3000).replace(slicer.newline, (if verbose then "; Raise Z to 10mm (protect bed while heating)" + slicer.newline else slicer.newline))

        # Now wait for both nozzle and bed to reach temperature.
        if slicer.nozzleTemperature > 0

            gcode += module.exports.codeNozzleTemperature(slicer, null, true).replace(slicer.newline, (if verbose then "; Wait for Nozzle Temperature" + slicer.newline else slicer.newline))

        if slicer.bedTemperature > 0

            gcode += module.exports.codeBedTemperature(slicer, null, true).replace(slicer.newline, (if verbose then "; Wait for Bed Temperature" + slicer.newline else slicer.newline))

        # Set extrusion mode based on slicer settings.
        isAbsoluteExtrusion = slicer.getExtruderMode() is "absolute"
        gcode += module.exports.codeExtruderMode(slicer, isAbsoluteExtrusion).replace(slicer.newline, (if verbose then "; Set '" + slicer.getExtruderMode() + "' Extrusion Mode" + slicer.newline else slicer.newline))

        # Set workspace plane and units.
        gcode += module.exports.codeWorkspacePlane(slicer).replace(slicer.newline, (if verbose then "; Set Workspace Plane" + slicer.newline else slicer.newline))

        gcode += module.exports.codeLengthUnit(slicer).replace(slicer.newline, (if verbose then "; Set Units" + slicer.newline else slicer.newline))

        # Lay test strip if enabled.
        if slicer.getTestStrip()

            gcode += module.exports.codeTestStrip(slicer)

        # Reset extruder position before print starts.
        gcode += module.exports.codeSetPosition(slicer, null, null, null, 0).replace(slicer.newline, (if verbose then "; Reset Extruder Position" + slicer.newline else slicer.newline))

        # Retract slightly before print.
        gcode += module.exports.codeLinearMovement(slicer, null, null, null, -5, 2700).replace(slicer.newline, (if verbose then "; Retract Filament" + slicer.newline else slicer.newline))

        if verbose then gcode += module.exports.codeMessage(slicer, "Pre-print sequence complete.")

        return gcode

    # Generate post-print sequence G-code.
    codePostPrint: (slicer) ->

        gcode = ""

        verbose = slicer.getVerbose()
        wipeNozzle = slicer.getWipeNozzle()
        smartWipeNozzle = slicer.getSmartWipeNozzle()
        buzzer = slicer.getBuzzer()

        if verbose then gcode += module.exports.codeMessage(slicer, "Starting post-print sequence...")

        # Turn off fan.
        gcode += module.exports.codeFanSpeed(slicer, 0).replace(slicer.newline, (if verbose then "; Turn Fan Off" + slicer.newline else slicer.newline))

        # Switch to relative positioning for safe moves.
        gcode += module.exports.codePositioningMode(slicer, false).replace(slicer.newline, (if verbose then "; Relative Positioning" + slicer.newline else slicer.newline))

        if wipeNozzle # Wipe out (optional based on setting).

            if smartWipeNozzle and slicer.lastLayerEndPoint and slicer._meshBounds and slicer.centerOffsetX? and slicer.centerOffsetY?

                # Use smart wipe logic to avoid wiping onto the mesh.
                wipeUtils = require('../utils/wipe')
                wipeDirection = wipeUtils.calculateSmartWipeDirection(
                    slicer.lastLayerEndPoint,
                    slicer._meshBounds,
                    slicer.centerOffsetX,
                    slicer.centerOffsetY,
                    10 # Maximum wipe distance in mm.
                )

                # Calculate retraction amount during wipe.
                retractionDistance = slicer.getRetractionDistance()

                # Generate wipe move with retraction.
                gcode += module.exports.codeLinearMovement(
                    slicer,
                    wipeDirection.x,
                    wipeDirection.y,
                    null,
                    -retractionDistance, # Retract during wipe.
                    3000
                ).replace(slicer.newline, (if verbose then "; Smart Wipe Nozzle (with retraction)" + slicer.newline else slicer.newline))

            else

                # Fall back to simple wipe (X+5, Y+5) if smart wipe data not available.
                gcode += module.exports.codeLinearMovement(slicer, 5, 5, null, null, 3000).replace(slicer.newline, (if verbose then "; Wipe Nozzle" + slicer.newline else slicer.newline))

        # Retract and raise Z.
        # Note: Retraction amount is reduced if smart wipe already retracted.
        if wipeNozzle and smartWipeNozzle and slicer.lastLayerEndPoint and slicer._meshBounds

            # Already retracted during smart wipe, so only raise Z.
            gcode += module.exports.codeLinearMovement(slicer, null, null, 10, null, 2400).replace(slicer.newline, (if verbose then "; Raise Z" + slicer.newline else slicer.newline))

        else

            # Normal retract and raise Z.
            gcode += module.exports.codeLinearMovement(slicer, null, null, 10, -2, 2400).replace(slicer.newline, (if verbose then "; Retract and Raise Z" + slicer.newline else slicer.newline))

        # Switch back to absolute positioning.
        gcode += module.exports.codePositioningMode(slicer, true).replace(slicer.newline, (if verbose then "; Absolute Positioning" + slicer.newline else slicer.newline))

        # Present print (home X and Y only, not Z).
        gcode += module.exports.codeAutohome(slicer, true, true, false).replace(slicer.newline, (if verbose then "; Present Print (Home X/Y)" + slicer.newline else slicer.newline))

        # Turn off fan (redundant but ensures it's off).
        gcode += module.exports.codeFanSpeed(slicer, 0).replace(slicer.newline, (if verbose then "; Turn Fan Off" + slicer.newline else slicer.newline))

        # Turn off nozzle temperature.
        gcode += module.exports.codeNozzleTemperature(slicer, 0, false).replace(slicer.newline, (if verbose then "; Turn Nozzle Off" + slicer.newline else slicer.newline))

        # Turn off bed temperature.
        gcode += module.exports.codeBedTemperature(slicer, 0, false).replace(slicer.newline, (if verbose then "; Turn Bed Off" + slicer.newline else slicer.newline))

        # Disable steppers (X, Y, E but not Z).
        gcode += module.exports.codeDisableSteppers(slicer, true, true, false, true).replace(slicer.newline, (if verbose then "; Disable X/Y/E Steppers" + slicer.newline else slicer.newline))

        # Set extrusion mode based on slicer settings.
        isAbsoluteExtrusion = slicer.getExtruderMode() is "absolute"
        gcode += module.exports.codeExtruderMode(slicer, isAbsoluteExtrusion).replace(slicer.newline, (if verbose then "; Set '" + slicer.getExtruderMode() + "' Extrusion Mode" + slicer.newline else slicer.newline))

        # Turn off nozzle again (ensure it's off).
        gcode += module.exports.codeNozzleTemperature(slicer, 0, false).replace(slicer.newline, (if verbose then "; Turn Nozzle Off (ensure)" + slicer.newline else slicer.newline))

        if verbose then gcode += module.exports.codeMessage(slicer, "Post-print sequence complete.")

        if buzzer # Sound buzzer if enabled.

            gcode += "M300 P1000 S420" + slicer.newline

        if verbose then gcode += module.exports.codeMessage(slicer, "Print complete!")

        return gcode
