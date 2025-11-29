# G-code generation methods for Polyslice.

polyconvert = require('@jgphilpott/polyconvert')

module.exports =

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

        if typeof x is "number"

            gcode += " X" + x

        if typeof y is "number"

            gcode += " Y" + y

        if typeof z is "number"

            gcode += " Z" + z

        if typeof extrude is "number"

            gcode += " E" + extrude

        if typeof feedrate is "number"

            gcode += " F" + feedrate

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

        if typeof xOffset is "number"

            gcode += " I" + xOffset

        if typeof yOffset is "number"

            gcode += " J" + yOffset

        if typeof radius is "number"

            gcode += " R" + radius

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

            temp = slicer.nozzleTemperature # Use internal storage for G-code generation

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

            temp = slicer.bedTemperature # Use internal storage for G-code generation

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
        gcode += "; Generated by Polyslice" + slicer.newline
        gcode += "; Version: " + version + slicer.newline
        gcode += "; Timestamp: " + timestamp + slicer.newline
        gcode += "; Repository: https://github.com/jgphilpott/polyslice" + slicer.newline

        if slicer.printer # Add printer information if available.

            gcode += "; Printer: " + slicer.printer.model + slicer.newline

        if slicer.filament # Add filament information if available.

            gcode += "; Filament: " + slicer.filament.name + " (" + slicer.filament.type + ")" + slicer.newline

        # Add key print settings.
        gcode += "; Nozzle Temp: " + slicer.nozzleTemperature + "°C" + slicer.newline
        gcode += "; Bed Temp: " + slicer.bedTemperature + "°C" + slicer.newline
        gcode += "; Layer Height: " + slicer.getLayerHeight() + "mm" + slicer.newline

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
        buzzer = slicer.getBuzzer()

        if verbose then gcode += module.exports.codeMessage(slicer, "Starting post-print sequence...")

        # Turn off fan.
        gcode += module.exports.codeFanSpeed(slicer, 0).replace(slicer.newline, (if verbose then "; Turn Fan Off" + slicer.newline else slicer.newline))

        # Switch to relative positioning for safe moves.
        gcode += module.exports.codePositioningMode(slicer, false).replace(slicer.newline, (if verbose then "; Relative Positioning" + slicer.newline else slicer.newline))

        if wipeNozzle # Wipe out (optional based on setting).

            gcode += module.exports.codeLinearMovement(slicer, 5, 5, null, null, 3000).replace(slicer.newline, (if verbose then "; Wipe Nozzle" + slicer.newline else slicer.newline))

        # Retract and raise Z.
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

            gcode += "M300 P1000 S420"

        if verbose then gcode += module.exports.codeMessage(slicer, "Print complete!")

        return gcode
