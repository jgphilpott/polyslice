class Polyslice

    constructor: (options = {}) ->

        @gcode = ""
        @newline = "\n"

        @autohome = options.autohome ?= true # Boolean

    getAutohome: ->

        return this.autohome

    setAutohome: (autohome = true) ->

        this.autohome = Boolean autohome

        return this

    codeAutohome: ->

        return "G28" + this.newline

    # https://marlinfw.org/docs/gcode/G000-G001.html
    codeLinearMove: (x = null, y = null, z = null, e = null, f = null, s = null) ->

        if e is null

            gcode = "G0"

        else

            gcode = "G1"

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

        return gcode + this.newline

    slice: (target = {}) ->

        if this.getAutohome()

            this.gcode += this.codeAutohome()

        return this.gcode
