class Polyslice

    constructor: (options = {}) ->

        @gcode = ""
        @newline = "\n"

        @autohome = options.autohome ?= true # Boolean
        @workspacePlane = options.workspacePlane ?= "XY" # String ['XY', 'XZ', 'YZ']

    getAutohome: ->

        return this.autohome

    getWorkspacePlane: ->

        return this.workspacePlane

    setAutohome: (autohome = true) ->

        this.autohome = Boolean autohome

        return this

    setWorkspacePlane: (plane = "XY") ->

        plane = plane.toUpperCase().trim()

        if ["XY", "XZ", "YZ"].includes plane

            this.workspacePlane = String plane

        return this

    codeAutohome: ->

        return "G28" + this.newline

    codeWorkspacePlane: ->

        if this.getWorkspacePlane() is "XY"

            return "G17" + this.newline

        if this.getWorkspacePlane() is "XZ"

            return "G18" + this.newline

        if this.getWorkspacePlane() is "YZ"

            return "G19" + this.newline

    codeMovement: (x = null, y = null, z = null, e = null, f = null, s = null) ->

        gcode = ""

        if x isnt null and typeof x is "number"

            gcode += " X" + x

        if y isnt null and typeof y is "number"

            gcode += " Y" + y

        if z isnt null and typeof z is "number"

            gcode += " Z" + z

        if e isnt null and typeof e is "number"

            gcode += " E" + e

        if f isnt null and typeof f is "number"

            gcode += " F" + f

        if s isnt null and typeof s is "number"

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

            if i isnt null and typeof i is "number"

                gcode += " I" + i

            if j isnt null and typeof j is "number"

                gcode += " J" + j

            if p isnt null and typeof p is "number"

                gcode += " P" + p

        else if i is null and j is null and r isnt null and x isnt null and y isnt null

            gcode += this.codeMovement x, y, z, e, f, s

            if r isnt null and typeof r is "number"

                gcode += " R" + r

            if p isnt null and typeof p is "number"

                gcode += " P" + p

        else

            console.error "Invalid Arc Movement Parameters"

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/G004.html
    # https://marlinfw.org/docs/gcode/M000-M001.html
    codeDwell: (time = null, interruptible = true, message = "") ->

        if interruptible then gcode = "M0" else gcode = "G4"

        if time isnt null and typeof time is "number" and time > 0

            gcode += " P" + time

        if message and typeof message is "string"

            gcode += " " + message

        return gcode + this.newline

    # https://marlinfw.org/docs/gcode/M108.html
    codeInterrupt: ->

        return "M108" + this.newline

    # https://marlinfw.org/docs/gcode/M400.html
    codeWait: ->

        return "M400" + this.newline

    # https://marlinfw.org/docs/gcode/M112.html
    codeShutdown: ->

        return "M112" + this.newline

    slice: (scene = {}) ->

        if this.getAutohome()

            this.gcode += this.codeAutohome()

        return this.gcode
