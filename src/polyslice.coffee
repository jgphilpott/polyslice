class Polyslice

    constructor: (options = {}) ->

        @newline = "\n"

        @autohome = options.autohome ?= true # Boolean

    getAutohome: ->

        return this.autohome

    setAutohome: (autohome = true) ->

        this.autohome = Boolean autohome

        return this

    slice: (target = {}) ->

        gcode = ""

        if this.autohome

            gcode += "G28" + this.newline

        return gcode
