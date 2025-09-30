# Import conversion utilities for unit handling.
conversions = require('./utils/conversions')

class Polyslice

    constructor: (options = {}) ->

        @gcode = ""
        @newline = "\n"

        # Basic printer configuration and behavior settings.
        @autohome = options.autohome ?= true # Boolean.
        @workspacePlane = options.workspacePlane ?= "XY" # String ['XY', 'XZ', 'YZ'].

        # Unit settings for time, distance, and temperature measurements.
        @timeUnit = options.timeUnit ?= "milliseconds" # String ['milliseconds', 'seconds'].
        @lengthUnit = options.lengthUnit ?= "millimeters" # String ['millimeters', 'inches'].
        @speedUnit = options.speedUnit ?= "millimeterSecond" # String ['millimeterSecond', 'inchSecond', 'meterSecond'].
        @temperatureUnit = options.temperatureUnit ?= "celsius" # String ['celsius', 'fahrenheit', 'kelvin'].

        # Temperature control settings for hotend and heated bed (stored internally in Celsius).
        @nozzleTemperature = conversions.convertTemperatureToInternal(options.nozzleTemperature ?= 0, this.temperatureUnit) # Number (°C internal).
        @bedTemperature = conversions.convertTemperatureToInternal(options.bedTemperature ?= 0, this.temperatureUnit) # Number (°C internal).
        @fanSpeed = options.fanSpeed ?= 100 # Number 0-100.

        # Slicing and extrusion settings (stored internally in millimeters).
        @layerHeight = conversions.convertLengthToInternal(options.layerHeight ?= 0.2, this.lengthUnit) # Number (mm internal).
        @extrusionMultiplier = options.extrusionMultiplier ?= 1.0 # Number (multiplier).
        @filamentDiameter = conversions.convertLengthToInternal(options.filamentDiameter ?= 1.75, this.lengthUnit) # Number (mm internal).
        @nozzleDiameter = conversions.convertLengthToInternal(options.nozzleDiameter ?= 0.4, this.lengthUnit) # Number (mm internal).

        # Speed settings for different types of movements (stored internally in mm/s).
        @perimeterSpeed = conversions.convertSpeedToInternal(options.perimeterSpeed ?= 30, this.speedUnit) # Number (mm/s internal).
        @infillSpeed = conversions.convertSpeedToInternal(options.infillSpeed ?= 60, this.speedUnit) # Number (mm/s internal).
        @travelSpeed = conversions.convertSpeedToInternal(options.travelSpeed ?= 120, this.speedUnit) # Number (mm/s internal).

        # Retraction settings to prevent stringing during travel moves (stored internally in mm and mm/s).
        @retractionDistance = conversions.convertLengthToInternal(options.retractionDistance ?= 1.0, this.lengthUnit) # Number (mm internal).
        @retractionSpeed = conversions.convertSpeedToInternal(options.retractionSpeed ?= 40, this.speedUnit) # Number (mm/s internal).

        # Build plate dimensions for bounds checking and validation (stored internally in mm).
        @buildPlateWidth = conversions.convertLengthToInternal(options.buildPlateWidth ?= 220, this.lengthUnit) # Number (mm internal).
        @buildPlateLength = conversions.convertLengthToInternal(options.buildPlateLength ?= 220, this.lengthUnit) # Number (mm internal).

    getAutohome: ->

        return this.autohome

    getWorkspacePlane: ->

        return this.workspacePlane

    getTimeUnit: ->

        return this.timeUnit

    getLengthUnit: ->

        return this.lengthUnit

    getTemperatureUnit: ->

        return this.temperatureUnit

    getSpeedUnit: ->

        return this.speedUnit

    getNozzleTemperature: ->

        return conversions.convertTemperatureFromInternal(this.nozzleTemperature, this.temperatureUnit)

    getBedTemperature: ->

        return conversions.convertTemperatureFromInternal(this.bedTemperature, this.temperatureUnit)

    getFanSpeed: ->

        return this.fanSpeed

    getLayerHeight: ->

        return conversions.convertLengthFromInternal(this.layerHeight, this.lengthUnit)

    getExtrusionMultiplier: ->

        return this.extrusionMultiplier

    getFilamentDiameter: ->

        return conversions.convertLengthFromInternal(this.filamentDiameter, this.lengthUnit)

    getNozzleDiameter: ->

        return conversions.convertLengthFromInternal(this.nozzleDiameter, this.lengthUnit)

    getPerimeterSpeed: ->

        return conversions.convertSpeedFromInternal(this.perimeterSpeed, this.speedUnit)

    getInfillSpeed: ->

        return conversions.convertSpeedFromInternal(this.infillSpeed, this.speedUnit)

    getTravelSpeed: ->

        return conversions.convertSpeedFromInternal(this.travelSpeed, this.speedUnit)

    getRetractionDistance: ->

        return conversions.convertLengthFromInternal(this.retractionDistance, this.lengthUnit)

    getRetractionSpeed: ->

        return conversions.convertSpeedFromInternal(this.retractionSpeed, this.speedUnit)

    getBuildPlateWidth: ->

        return conversions.convertLengthFromInternal(this.buildPlateWidth, this.lengthUnit)

    getBuildPlateLength: ->

        return conversions.convertLengthFromInternal(this.buildPlateLength, this.lengthUnit)

    setAutohome: (autohome = true) ->

        this.autohome = Boolean autohome

        return this

    setWorkspacePlane: (plane = "XY") ->

        plane = plane.toUpperCase().trim()

        if ["XY", "XZ", "YZ"].includes plane

            this.workspacePlane = String plane

        return this

    setTimeUnit: (unit = "milliseconds") ->

        unit = unit.toLowerCase().trim()

        if ["milliseconds", "seconds"].includes unit

            this.timeUnit = String unit

        return this

    setLengthUnit: (unit = "millimeters") ->

        unit = unit.toLowerCase().trim()

        if ["millimeters", "inches"].includes unit

            this.lengthUnit = String unit

        return this

    setSpeedUnit: (unit = "millimeterSecond") ->

        # Speed unit should match polyconvert naming (e.g., millimeterSecond, inchSecond)
        if ["millimeterSecond", "inchSecond", "meterSecond"].includes unit

            this.speedUnit = String unit

        return this

    setTemperatureUnit: (unit = "celsius") ->

        unit = unit.toLowerCase().trim()

        if ["celsius", "fahrenheit", "kelvin"].includes unit

            this.temperatureUnit = String unit

        return this

    setNozzleTemperature: (temp = 0) ->

        if typeof temp is "number" and temp >= 0

            this.nozzleTemperature = conversions.convertTemperatureToInternal(temp, this.temperatureUnit)

        return this

    setBedTemperature: (temp = 0) ->

        if typeof temp is "number" and temp >= 0

            this.bedTemperature = conversions.convertTemperatureToInternal(temp, this.temperatureUnit)

        return this

    setFanSpeed: (speed = 100) ->

        if typeof speed is "number" and speed >= 0 and speed <= 100

            this.fanSpeed = Number speed

        return this

    setLayerHeight: (height = 0.2) ->

        if typeof height is "number" and height > 0

            this.layerHeight = conversions.convertLengthToInternal(height, this.lengthUnit)

        return this

    setExtrusionMultiplier: (multiplier = 1.0) ->

        if typeof multiplier is "number" and multiplier > 0

            this.extrusionMultiplier = Number multiplier

        return this

    setFilamentDiameter: (diameter = 1.75) ->

        if typeof diameter is "number" and diameter > 0

            this.filamentDiameter = conversions.convertLengthToInternal(diameter, this.lengthUnit)

        return this

    setNozzleDiameter: (diameter = 0.4) ->

        if typeof diameter is "number" and diameter > 0

            this.nozzleDiameter = conversions.convertLengthToInternal(diameter, this.lengthUnit)

        return this

    setPerimeterSpeed: (speed = 30) ->

        if typeof speed is "number" and speed > 0

            this.perimeterSpeed = conversions.convertSpeedToInternal(speed, this.speedUnit)

        return this

    setInfillSpeed: (speed = 60) ->

        if typeof speed is "number" and speed > 0

            this.infillSpeed = conversions.convertSpeedToInternal(speed, this.speedUnit)

        return this

    setTravelSpeed: (speed = 120) ->

        if typeof speed is "number" and speed > 0

            this.travelSpeed = conversions.convertSpeedToInternal(speed, this.speedUnit)

        return this

    setRetractionDistance: (distance = 1.0) ->

        if typeof distance is "number" and distance >= 0

            this.retractionDistance = conversions.convertLengthToInternal(distance, this.lengthUnit)

        return this

    setRetractionSpeed: (speed = 40) ->

        if typeof speed is "number" and speed > 0

            this.retractionSpeed = conversions.convertSpeedToInternal(speed, this.speedUnit)

        return this

    setBuildPlateWidth: (width = 220) ->

        if typeof width is "number" and width > 0

            this.buildPlateWidth = conversions.convertLengthToInternal(width, this.lengthUnit)

        return this

    setBuildPlateLength: (length = 220) ->

        if typeof length is "number" and length > 0

            this.buildPlateLength = conversions.convertLengthToInternal(length, this.lengthUnit)

        return this

    # https://marlinfw.org/docs/gcode/G028.html
    # Generate autohome G-code command.
    codeAutohome: (x = null, y = null, z = null, skip = null, raise = null, leveling = null) ->

        gcode = "G28"

        if x then gcode += " X"
        if y then gcode += " Y"
        if z then gcode += " Z"

        if skip then gcode += " O"
        if leveling then gcode += " L"

        if typeof raise is "number" then gcode += " R" + raise

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/G017-G019.html
    # Set workspace plane for coordinate system interpretation.
    codeWorkspacePlane: (plane = null) ->

        if plane isnt null

            this.setWorkspacePlane plane

        if this.getWorkspacePlane() is "XY"

            return "G17" + this.newline

        if this.getWorkspacePlane() is "XZ"

            return "G18" + this.newline

        if this.getWorkspacePlane() is "YZ"

            return "G19" + this.newline

    # https://marlinfw.org/docs/gcode/G021.html
    # https://marlinfw.org/docs/gcode/G020.html
    # Set length units for coordinate measurements.
    codeLengthUnit: (unit = null) ->

        if unit isnt null

            this.setLengthUnit unit

        if this.getLengthUnit() is "millimeters"

            return "G21" + this.newline

        if this.getLengthUnit() is "inches"

            return "G20" + this.newline

    # https://marlinfw.org/docs/gcode/M149.html
    # Set temperature units for thermal measurements.
    codeTemperatureUnit: (unit = null) ->

        if unit isnt null

            this.setTemperatureUnit unit

        if this.getTemperatureUnit() is "celsius"

            return "M149 C" + this.newline

        if this.getTemperatureUnit() is "fahrenheit"

            return "M149 F" + this.newline

        if this.getTemperatureUnit() is "kelvin"

            return "M149 K" + this.newline

    # Helper method to build movement parameter strings.
    codeMovement: (x = null, y = null, z = null, extrude = null, feedrate = null, power = null) ->

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

    # https://marlinfw.org/docs/gcode/G000-G001.html
    # Generate linear movement G-code command.
    codeLinearMovement: (x = null, y = null, z = null, extrude = null, feedrate = null, power = null) ->

        if not extrude then gcode = "G0" else gcode = "G1"

        gcode += this.codeMovement x, y, z, extrude, feedrate, power

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/G002-G003.html
    # Generate arc movement G-code command.
    codeArcMovement: (direction = "clockwise", x = null, y = null, z = null, extrude = null, feedrate = null, power = null, xOffset = null, yOffset = null, radius = null, circles = null) ->

        if direction is "clockwise" then gcode = "G2" else gcode = "G3"

        if (xOffset isnt null or yOffset isnt null) and radius is null

            gcode += this.codeMovement x, y, z, extrude, feedrate, power

            if typeof xOffset is "number"

                gcode += " I" + xOffset

            if typeof yOffset is "number"

                gcode += " J" + yOffset

            if typeof circles is "number"

                gcode += " P" + circles

        else if xOffset is null and yOffset is null and radius isnt null and x isnt null and y isnt null

            gcode += this.codeMovement x, y, z, extrude, feedrate, power

            if typeof radius is "number"

                gcode += " R" + radius

            if typeof circles is "number"

                gcode += " P" + circles

        else

            console.error "Invalid Arc Movement Parameters"

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/G005.html
    # Generate Bézier curve movement G-code commands.
    codeBézierMovement: (controlPoints = []) ->

        gcode = ""

        for controlPoint, index in controlPoints

            if typeof controlPoint.xOffsetEnd is "number" and typeof controlPoint.yOffsetEnd is "number"

                if index is 0 and (typeof controlPoint.xOffsetStart isnt "number" or typeof controlPoint.yOffsetStart isnt "number")

                    console.error "Invalid Bézier Movement Parameters"

                else

                    gcode += "G5"

                    x = controlPoint.x
                    y = controlPoint.y
                    extrude = controlPoint.extrude
                    feedrate = controlPoint.feedrate
                    power = controlPoint.power

                    gcode += this.codeMovement x, y, null, extrude, feedrate, power

                    if typeof controlPoint.xOffsetStart is "number" and typeof controlPoint.yOffsetStart is "number"

                        gcode += " I" + controlPoint.xOffsetStart
                        gcode += " J" + controlPoint.yOffsetStart

                    gcode += " P" + controlPoint.xOffsetEnd
                    gcode += " Q" + controlPoint.yOffsetEnd

                    gcode += this.newline

            else

                console.error "Invalid Bézier Movement Parameters"

        return gcode

    # https://marlinfw.org/docs/gcode/M114.html
    # https://marlinfw.org/docs/gcode/M154.html
    # Generate position reporting G-code commands.
    codePositionReport: (auto = true, interval = 1, real = false, detail = false, extruder = false) ->

        if auto

            gcode = "M154"

            if typeof interval is "number" and interval >= 0

                if this.getTimeUnit() is "milliseconds"

                    interval /= 1000

                gcode += " S" + interval

        else

            gcode = "M114"

            if real then gcode += " R"
            if detail then gcode += " D"
            if extruder then gcode += " E"

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/M109.html
    # https://marlinfw.org/docs/gcode/M104.html
    # Generate nozzle temperature control G-code commands.
    codeNozzleTemperature: (temp = null, wait = true, index = null) ->

        if temp isnt null

            this.setNozzleTemperature temp

        else

            temp = this.nozzleTemperature

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

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/M190.html
    # https://marlinfw.org/docs/gcode/M140.html
    # Generate bed temperature control G-code commands.
    codeBedTemperature: (temp = null, wait = true, time = null) ->

        if temp isnt null

            this.setBedTemperature temp

        else

            temp = this.bedTemperature

        if wait

            gcode = "M190"

            if typeof temp is "number" and temp >= 0

                gcode += " R" + temp

            if typeof time is "number" and time > 0

                if this.getTimeUnit() is "milliseconds"

                    time /= 1000

                gcode += " T" + time

        else

            gcode = "M140"

            if typeof temp is "number" and temp >= 0

                gcode += " S" + temp

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/M105.html
    # https://marlinfw.org/docs/gcode/M155.html
    # Generate temperature reporting G-code commands.
    codeTemperatureReport: (auto = true, interval = 1, index = null, sensor = null) ->

        if auto

            gcode = "M155"

            if typeof interval is "number" and interval >= 0

                if this.getTimeUnit() is "milliseconds"

                    interval /= 1000

                gcode += " S" + interval

        else

            gcode = "M105"

            if typeof index is "number"

                gcode += " T" + index

            if sensor then gcode += " R"

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/M106.html
    # https://marlinfw.org/docs/gcode/M107.html
    # Generate fan speed control G-code commands.
    codeFanSpeed: (speed = null, index = null) ->

        if speed isnt null

            this.setFanSpeed speed

        else

            speed = this.getFanSpeed()

        if typeof speed is "number" and speed >= 0 and speed <= 100

            if speed > 0

                gcode = "M106" + " S" + Math.round(speed * 2.55)

            else

                gcode = "M107"

            if typeof index is "number"

                gcode += " P" + index

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/M123.html
    # Generate fan status reporting G-code commands.
    codeFanReport: (auto = true, interval = 1) ->

        gcode = "M123"

        if auto and typeof interval is "number" and interval >= 0

            if this.getTimeUnit() is "milliseconds"

                interval /= 1000

            gcode += " S" + interval

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/G004.html
    # https://marlinfw.org/docs/gcode/M000-M001.html
    # Generate pause/dwell G-code commands.
    codeDwell: (time = null, interruptible = true, message = "") ->

        if interruptible then gcode = "M0" else gcode = "G4"

        if typeof time is "number" and time > 0

            if this.getTimeUnit() is "milliseconds" then gcode += " P" + time
            if this.getTimeUnit() is "seconds" then gcode += " S" + time

        if message and typeof message is "string"

            gcode += " " + message

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/M108.html
    # Generate emergency interrupt G-code command.
    codeInterrupt: ->

        return "M108" + this.newline

    # https://marlinfw.org/docs/gcode/M400.html
    # Generate wait for moves completion G-code command.
    codeWait: ->

        return "M400" + this.newline

    # https://marlinfw.org/docs/gcode/M300.html
    # Generate buzzer/tone G-code command.
    codeTone: (duration = 1, frequency = 500) ->

        gcode = "M300"

        if typeof duration is "number" and duration > 0

            if this.getTimeUnit() is "seconds"

                duration *= 1000

            gcode += " P" + duration

        if typeof frequency is "number" and frequency > 0

            gcode += " S" + frequency

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/M117.html
    # https://marlinfw.org/docs/gcode/M118.html
    # Generate display message G-code command.
    codeMessage: (message = "") ->

        return "M117 " + message + this.newline

    # https://marlinfw.org/docs/gcode/M112.html
    # Generate emergency shutdown G-code command.
    codeShutdown: ->

        return "M112" + this.newline

    # https://marlinfw.org/docs/gcode/M115.html
    # Generate firmware info request G-code command.
    codeFirmwareReport: ->

        return "M115" + this.newline

    # https://marlinfw.org/docs/gcode/M027.html
    # Generate SD card status reporting G-code commands.
    codeSDReport: (auto = true, interval = 1, name = false) ->

        gcode = "M27"

        if name then gcode += " C"

        if auto and typeof interval is "number" and interval >= 0

            if this.getTimeUnit() is "milliseconds"

                interval /= 1000

            gcode += " S" + interval

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/M073.html
    # Generate print progress reporting G-code commands.
    codeProgressReport: (percent = null, time = null) ->

        gcode = "M73"

        if typeof percent is "number" and percent >= 0

            gcode += " P" + percent

        if typeof time is "number" and time >= 0

            if this.getTimeUnit() is "milliseconds"

                time /= 60000

            else if this.getTimeUnit() is "seconds"

                time /= 60

            gcode += " R" + time

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/G010-G011.html
    # Generate retraction G-code using the configured retraction settings.
    codeRetract: (distance = null, speed = null) ->

        retractDistance = if distance isnt null then distance else this.retractionDistance # Use internal storage (mm)
        retractSpeed = if speed isnt null then speed else this.retractionSpeed # Use internal storage (mm/s)

        if retractDistance <= 0

            return "" # No retraction needed

        gcode = "G1"
        gcode += " E-" + retractDistance # E is always in mm for G-code

        if retractSpeed > 0

            # Convert mm/s to mm/min for F parameter using polyconvert
            feedratePerMin = Math.round(require('@jgphilpott/polyconvert').speed.millimeterSecond.millimeterMinute(retractSpeed))
            gcode += " F" + feedratePerMin

        return gcode + this.newline

    # Generate unretract/prime G-code using configured settings.
    codeUnretract: (distance = null, speed = null) ->

        retractDistance = if distance isnt null then distance else this.retractionDistance # Use internal storage (mm)
        retractSpeed = if speed isnt null then speed else this.retractionSpeed # Use internal storage (mm/s)

        if retractDistance <= 0

            return "" # No unretraction needed

        gcode = "G1"
        gcode += " E" + retractDistance # E is always in mm for G-code

        if retractSpeed > 0

            # Convert mm/s to mm/min for F parameter using polyconvert
            feedratePerMin = Math.round(require('@jgphilpott/polyconvert').speed.millimeterSecond.millimeterMinute(retractSpeed))
            gcode += " F" + feedratePerMin

        return gcode + this.newline

    # Utility method to check if coordinates are within build plate bounds.
    isWithinBounds: (x, y) ->

        if typeof x isnt "number" or typeof y isnt "number"

            return false

        halfWidth = this.getBuildPlateWidth() / 2
        halfLength = this.getBuildPlateLength() / 2

        return x >= -halfWidth and x <= halfWidth and y >= -halfLength and y <= halfLength

    # Calculate extrusion amount based on distance, layer height, and settings.
    calculateExtrusion: (distance, lineWidth = null) ->

        if typeof distance isnt "number" or distance <= 0

            return 0

        # Use nozzle diameter as default line width if not specified.
        width = if lineWidth isnt null then lineWidth else this.getNozzleDiameter()

        layerHeight = this.getLayerHeight()
        filamentRadius = this.getFilamentDiameter() / 2
        extrusionMultiplier = this.getExtrusionMultiplier()

        # Calculate cross-sectional area of the extruded line.
        lineArea = width * layerHeight

        # Calculate cross-sectional area of the filament.
        filamentArea = Math.PI * filamentRadius * filamentRadius

        # Calculate extrusion length.
        extrusionLength = (lineArea * distance * extrusionMultiplier) / filamentArea

        return extrusionLength

    slice: (scene = {}) ->

        if this.getAutohome()

            this.gcode += this.codeAutohome()

        return this.gcode

# Export the class for Node.js
if typeof module isnt 'undefined' and module.exports

    module.exports = Polyslice

# Export for browser environments.
if typeof window isnt 'undefined'

    window.Polyslice = Polyslice
