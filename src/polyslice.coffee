class Polyslice

    constructor: (options = {}) ->

        @gcode = ""
        @newline = "\n"

        @autohome = options.autohome ?= true # Boolean
        @workspacePlane = options.workspacePlane ?= "XY" # String ['XY', 'XZ', 'YZ']

        @timeUnit = options.timeUnit ?= "milliseconds" # String ['milliseconds', 'seconds']
        @lengthUnit = options.lengthUnit ?= "millimeters" # String ['millimeters', 'inches']
        @temperatureUnit = options.temperatureUnit ?= "celsius" # String ['celsius', 'fahrenheit', 'kelvin']

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

    # https://marlinfw.org/docs/gcode/G028.html
    codeAutohome: (x = null, y = null, z = null, o = null, r = null, l = null) ->

        gcode = "G28"

        if x then gcode += " X"
        if y then gcode += " Y"
        if z then gcode += " Z"

        if o then gcode += " O"
        if l then gcode += " L"

        if typeof r is "number" then gcode += " R" + r

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/G017-G019.html
    codeWorkspacePlane: ->

        if this.getWorkspacePlane() is "XY"

            return "G17" + this.newline

        if this.getWorkspacePlane() is "XZ"

            return "G18" + this.newline

        if this.getWorkspacePlane() is "YZ"

            return "G19" + this.newline

    # https://marlinfw.org/docs/gcode/G021.html
    # https://marlinfw.org/docs/gcode/G020.html
    codeLengthUnit: ->

        if this.getLengthUnit() is "millimeters"

            return "G21" + this.newline

        if this.getLengthUnit() is "inches"

            return "G20" + this.newline

    # https://marlinfw.org/docs/gcode/M149.html
    codeTemperatureUnit: ->

        if this.getTemperatureUnit() is "celsius"

            return "M149 C" + this.newline

        if this.getTemperatureUnit() is "fahrenheit"

            return "M149 F" + this.newline

        if this.getTemperatureUnit() is "kelvin"

            return "M149 K" + this.newline

    codeMovement: (x = null, y = null, z = null, e = null, f = null, s = null) ->

        gcode = ""

        if typeof x is "number"

            gcode += " X" + x

        if typeof y is "number"

            gcode += " Y" + y

        if typeof z is "number"

            gcode += " Z" + z

        if typeof e is "number"

            gcode += " E" + e

        if typeof f is "number"

            gcode += " F" + f

        if typeof s is "number"

            gcode += " S" + s

        return gcode

    # https://marlinfw.org/docs/gcode/G000-G001.html
    codeLinearMovement: (x = null, y = null, z = null, e = null, f = null, s = null) ->

        if e is null then gcode = "G0" else gcode = "G1"

        gcode += this.codeMovement x, y, z, e, f, s

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/G002-G003.html
    codeArcMovement: (direction = "clockwise", x = null, y = null, z = null, e = null, f = null, s = null, i = null, j = null, r = null, p = null) ->

        if direction is "clockwise" then gcode = "G2" else gcode = "G3"

        if (i isnt null or j isnt null) and r is null

            gcode += this.codeMovement x, y, z, e, f, s

            if typeof i is "number"

                gcode += " I" + i

            if typeof j is "number"

                gcode += " J" + j

            if typeof p is "number"

                gcode += " P" + p

        else if i is null and j is null and r isnt null and x isnt null and y isnt null

            gcode += this.codeMovement x, y, z, e, f, s

            if typeof r is "number"

                gcode += " R" + r

            if typeof p is "number"

                gcode += " P" + p

        else

            console.error "Invalid Arc Movement Parameters"

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/G005.html
    codeBézierMovement: (controlPoints = []) ->

        gcode = ""

        for controlPoint, index in controlPoints

            if typeof controlPoint.p is "number" and typeof controlPoint.q is "number"

                if index is 0 and (typeof controlPoint.i isnt "number" or typeof controlPoint.j isnt "number")

                    console.error "Invalid Bézier Movement Parameters"

                else

                    gcode += "G5"

                    x = controlPoint.x
                    y = controlPoint.y
                    e = controlPoint.e
                    f = controlPoint.f
                    s = controlPoint.s

                    gcode += this.codeMovement x, y, null, e, f, s

                    if typeof controlPoint.i is "number" and typeof controlPoint.j is "number"

                        gcode += " I" + controlPoint.i
                        gcode += " J" + controlPoint.j

                    gcode += " P" + controlPoint.p
                    gcode += " Q" + controlPoint.q

                    gcode += this.newline

            else

                console.error "Invalid Bézier Movement Parameters"

        return gcode

    # https://marlinfw.org/docs/gcode/M109.html
    # https://marlinfw.org/docs/gcode/M104.html
    codeNozzleTemperature: (temp = 0, wait = true, index = null) ->

        if wait

            gcode = "M109"

            if typeof temp is "number" and temp > 0

                gcode += " R" + temp

            if typeof index is "number"

                gcode += " T" + index

        else

            gcode = "M104"

            if typeof temp is "number" and temp > 0

                gcode += " S" + temp

            if typeof index is "number"

                gcode += " T" + index

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/M190.html
    # https://marlinfw.org/docs/gcode/M140.html
    codeBedTemperature: (temp = 0, wait = true, time = null) ->

        if wait

            gcode = "M190"

            if typeof temp is "number" and temp > 0

                gcode += " R" + temp

            if typeof time is "number" and time > 0

                if this.getTimeUnit() is "milliseconds"

                    time /= 1000

                gcode += " T" + time

        else

            gcode = "M140"

            if typeof temp is "number" and temp > 0

                gcode += " S" + temp

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

    # https://marlinfw.org/docs/gcode/M117.html
    # https://marlinfw.org/docs/gcode/M118.html
    codeMessage: (message = "") ->

        return "M117 " + message + this.newline

    # https://marlinfw.org/docs/gcode/M112.html
    codeShutdown: ->

        return "M112" + this.newline

    slice: (scene = {}) ->

        if this.getAutohome()

            this.gcode += this.codeAutohome()

        return this.gcode
