class Polyslice

    constructor: (options = {}) ->

        @gcode = ""
        @newline = "\n"

        @autohome = options.autohome ?= true # Boolean
        @workspacePlane = options.workspacePlane ?= "XY" # String ['XY', 'XZ', 'YZ']

        @timeUnit = options.timeUnit ?= "milliseconds" # String ['milliseconds', 'seconds']
        @lengthUnit = options.lengthUnit ?= "millimeters" # String ['millimeters', 'inches']
        @temperatureUnit = options.temperatureUnit ?= "celsius" # String ['celsius', 'fahrenheit', 'kelvin']

        @nozzleTemperature = options.nozzleTemperature ?= 0 # Number
        @bedTemperature = options.bedTemperature ?= 0 # Number
        @fanSpeed = options.fanSpeed ?= 100 # Number 0-100

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

    getNozzleTemperature: ->

        return this.nozzleTemperature

    getBedTemperature: ->

        return this.bedTemperature

    getFanSpeed: ->

        return this.fanSpeed

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

    setTemperatureUnit: (unit = "celsius") ->

        unit = unit.toLowerCase().trim()

        if ["celsius", "fahrenheit", "kelvin"].includes unit

            this.temperatureUnit = String unit

        return this

    setNozzleTemperature: (temp = 0) ->

        if typeof temp is "number" and temp >= 0

            this.nozzleTemperature = Number temp

        return this

    setBedTemperature: (temp = 0) ->

        if typeof temp is "number" and temp >= 0

            this.bedTemperature = Number temp

        return this

    setFanSpeed: (speed = 100) ->

        if typeof speed is "number" and speed >= 0 and speed <= 100

            this.fanSpeed = Number speed

        return this

    # https://marlinfw.org/docs/gcode/G028.html
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
    codeLengthUnit: (unit = null) ->

        if unit isnt null

            this.setLengthUnit unit

        if this.getLengthUnit() is "millimeters"

            return "G21" + this.newline

        if this.getLengthUnit() is "inches"

            return "G20" + this.newline

    # https://marlinfw.org/docs/gcode/M149.html
    codeTemperatureUnit: (unit = null) ->

        if unit isnt null

            this.setTemperatureUnit unit

        if this.getTemperatureUnit() is "celsius"

            return "M149 C" + this.newline

        if this.getTemperatureUnit() is "fahrenheit"

            return "M149 F" + this.newline

        if this.getTemperatureUnit() is "kelvin"

            return "M149 K" + this.newline

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
    codeLinearMovement: (x = null, y = null, z = null, extrude = null, feedrate = null, power = null) ->

        if not extrude then gcode = "G0" else gcode = "G1"

        gcode += this.codeMovement x, y, z, extrude, feedrate, power

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/G002-G003.html
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
    codeNozzleTemperature: (temp = null, wait = true, index = null) ->

        if temp isnt null

            this.setNozzleTemperature temp

        else

            temp = this.getNozzleTemperature()

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
    codeBedTemperature: (temp = null, wait = true, time = null) ->

        if temp isnt null

            this.setBedTemperature temp

        else

            temp = this.getBedTemperature()

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
    codeFanSpeed: (speed = null, index = null) ->

        if speed isnt null

            this.setFanSpeed speed

        else

            speed = this.getFanSpeed()

        if typeof speed is "number" and speed >= 0 and speed <= 100

            if speed > 0

                gcode = "M106" + " S" + speed * 2.55

            else

                gcode = "M107"

            if typeof index is "number"

                gcode += " P" + index

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/G004.html
    # https://marlinfw.org/docs/gcode/M000-M001.html
    codeDwell: (time = null, interruptible = true, message = "") ->

        if interruptible then gcode = "M0" else gcode = "G4"

        if typeof time is "number" and time > 0

            if this.getTimeUnit() is "milliseconds" then gcode += " P" + time
            if this.getTimeUnit() is "seconds" then gcode += " S" + time

        if message and typeof message is "string"

            gcode += " " + message

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/M108.html
    codeInterrupt: ->

        return "M108" + this.newline

    # https://marlinfw.org/docs/gcode/M400.html
    codeWait: ->

        return "M400" + this.newline

    # https://marlinfw.org/docs/gcode/M300.html
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
    codeMessage: (message = "") ->

        return "M117 " + message + this.newline

    # https://marlinfw.org/docs/gcode/M112.html
    codeShutdown: ->

        return "M112" + this.newline

    # https://marlinfw.org/docs/gcode/M115.html
    codeFirmwareReport: ->

        return "M115" + this.newline

    slice: (scene = {}) ->

        if this.getAutohome()

            this.gcode += this.codeAutohome()

        return this.gcode
