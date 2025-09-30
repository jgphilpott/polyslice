coders = require('./utils/coders')
helpers = require('./utils/helpers')
conversions = require('./utils/conversions')

polyconvert = require('@jgphilpott/polyconvert')
polytree = require('@jgphilpott/polytree')

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
        @nozzleTemperature = conversions.temperatureToInternal(options.nozzleTemperature ?= 0, this.temperatureUnit) # Number (°C internal).
        @bedTemperature = conversions.temperatureToInternal(options.bedTemperature ?= 0, this.temperatureUnit) # Number (°C internal).
        @fanSpeed = options.fanSpeed ?= 100 # Number 0-100.

        # Slicing and extrusion settings (stored internally in millimeters).
        @layerHeight = conversions.lengthToInternal(options.layerHeight ?= 0.2, this.lengthUnit) # Number (mm internal).
        @extrusionMultiplier = options.extrusionMultiplier ?= 1.0 # Number (multiplier).
        @filamentDiameter = conversions.lengthToInternal(options.filamentDiameter ?= 1.75, this.lengthUnit) # Number (mm internal).
        @nozzleDiameter = conversions.lengthToInternal(options.nozzleDiameter ?= 0.4, this.lengthUnit) # Number (mm internal).

        # Speed settings for different types of movements (stored internally in mm/s).
        @perimeterSpeed = conversions.speedToInternal(options.perimeterSpeed ?= 30, this.speedUnit) # Number (mm/s internal).
        @infillSpeed = conversions.speedToInternal(options.infillSpeed ?= 60, this.speedUnit) # Number (mm/s internal).
        @travelSpeed = conversions.speedToInternal(options.travelSpeed ?= 120, this.speedUnit) # Number (mm/s internal).

        # Retraction settings to prevent stringing during travel moves (stored internally in mm and mm/s).
        @retractionDistance = conversions.lengthToInternal(options.retractionDistance ?= 1.0, this.lengthUnit) # Number (mm internal).
        @retractionSpeed = conversions.speedToInternal(options.retractionSpeed ?= 40, this.speedUnit) # Number (mm/s internal).

        # Build plate dimensions for bounds checking and validation (stored internally in mm).
        @buildPlateWidth = conversions.lengthToInternal(options.buildPlateWidth ?= 220, this.lengthUnit) # Number (mm internal).
        @buildPlateLength = conversions.lengthToInternal(options.buildPlateLength ?= 220, this.lengthUnit) # Number (mm internal).

    # Getters

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

        return conversions.temperatureFromInternal(this.nozzleTemperature, this.temperatureUnit)

    getBedTemperature: ->

        return conversions.temperatureFromInternal(this.bedTemperature, this.temperatureUnit)

    getFanSpeed: ->

        return this.fanSpeed

    getLayerHeight: ->

        return conversions.lengthFromInternal(this.layerHeight, this.lengthUnit)

    getExtrusionMultiplier: ->

        return this.extrusionMultiplier

    getFilamentDiameter: ->

        return conversions.lengthFromInternal(this.filamentDiameter, this.lengthUnit)

    getNozzleDiameter: ->

        return conversions.lengthFromInternal(this.nozzleDiameter, this.lengthUnit)

    getPerimeterSpeed: ->

        return conversions.speedFromInternal(this.perimeterSpeed, this.speedUnit)

    getInfillSpeed: ->

        return conversions.speedFromInternal(this.infillSpeed, this.speedUnit)

    getTravelSpeed: ->

        return conversions.speedFromInternal(this.travelSpeed, this.speedUnit)

    getRetractionDistance: ->

        return conversions.lengthFromInternal(this.retractionDistance, this.lengthUnit)

    getRetractionSpeed: ->

        return conversions.speedFromInternal(this.retractionSpeed, this.speedUnit)

    getBuildPlateWidth: ->

        return conversions.lengthFromInternal(this.buildPlateWidth, this.lengthUnit)

    getBuildPlateLength: ->

        return conversions.lengthFromInternal(this.buildPlateLength, this.lengthUnit)

    # Setters

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

            this.nozzleTemperature = conversions.temperatureToInternal(temp, this.temperatureUnit)

        return this

    setBedTemperature: (temp = 0) ->

        if typeof temp is "number" and temp >= 0

            this.bedTemperature = conversions.temperatureToInternal(temp, this.temperatureUnit)

        return this

    setFanSpeed: (speed = 100) ->

        if typeof speed is "number" and speed >= 0 and speed <= 100

            this.fanSpeed = Number speed

        return this

    setLayerHeight: (height = 0.2) ->

        if typeof height is "number" and height > 0

            this.layerHeight = conversions.lengthToInternal(height, this.lengthUnit)

        return this

    setExtrusionMultiplier: (multiplier = 1.0) ->

        if typeof multiplier is "number" and multiplier > 0

            this.extrusionMultiplier = Number multiplier

        return this

    setFilamentDiameter: (diameter = 1.75) ->

        if typeof diameter is "number" and diameter > 0

            this.filamentDiameter = conversions.lengthToInternal(diameter, this.lengthUnit)

        return this

    setNozzleDiameter: (diameter = 0.4) ->

        if typeof diameter is "number" and diameter > 0

            this.nozzleDiameter = conversions.lengthToInternal(diameter, this.lengthUnit)

        return this

    setPerimeterSpeed: (speed = 30) ->

        if typeof speed is "number" and speed > 0

            this.perimeterSpeed = conversions.speedToInternal(speed, this.speedUnit)

        return this

    setInfillSpeed: (speed = 60) ->

        if typeof speed is "number" and speed > 0

            this.infillSpeed = conversions.speedToInternal(speed, this.speedUnit)

        return this

    setTravelSpeed: (speed = 120) ->

        if typeof speed is "number" and speed > 0

            this.travelSpeed = conversions.speedToInternal(speed, this.speedUnit)

        return this

    setRetractionDistance: (distance = 1.0) ->

        if typeof distance is "number" and distance >= 0

            this.retractionDistance = conversions.lengthToInternal(distance, this.lengthUnit)

        return this

    setRetractionSpeed: (speed = 40) ->

        if typeof speed is "number" and speed > 0

            this.retractionSpeed = conversions.speedToInternal(speed, this.speedUnit)

        return this

    setBuildPlateWidth: (width = 220) ->

        if typeof width is "number" and width > 0

            this.buildPlateWidth = conversions.lengthToInternal(width, this.lengthUnit)

        return this

    setBuildPlateLength: (length = 220) ->

        if typeof length is "number" and length > 0

            this.buildPlateLength = conversions.lengthToInternal(length, this.lengthUnit)

        return this

    # Coder method delegates

    codeAutohome: (x, y, z, skip, raise, leveling) ->
        coders.codeAutohome(this, x, y, z, skip, raise, leveling)

    codeWorkspacePlane: (plane) ->
        coders.codeWorkspacePlane(this, plane)

    codeLengthUnit: (unit) ->
        coders.codeLengthUnit(this, unit)

    codeTemperatureUnit: (unit) ->
        coders.codeTemperatureUnit(this, unit)

    codeMovement: (x, y, z, extrude, feedrate, power) ->
        coders.codeMovement(this, x, y, z, extrude, feedrate, power)

    codeLinearMovement: (x, y, z, extrude, feedrate, power) ->
        coders.codeLinearMovement(this, x, y, z, extrude, feedrate, power)

    codeArcMovement: (direction, x, y, z, extrude, feedrate, power, xOffset, yOffset, radius, circles) ->
        coders.codeArcMovement(this, direction, x, y, z, extrude, feedrate, power, xOffset, yOffset, radius, circles)

    codeBézierMovement: (controlPoints) ->
        coders.codeBézierMovement(this, controlPoints)

    codePositionReport: (auto, interval, real, detail, extruder) ->
        coders.codePositionReport(this, auto, interval, real, detail, extruder)

    codeNozzleTemperature: (temp, wait, index) ->
        coders.codeNozzleTemperature(this, temp, wait, index)

    codeBedTemperature: (temp, wait, time) ->
        coders.codeBedTemperature(this, temp, wait, time)

    codeTemperatureReport: (auto, interval, index, sensor) ->
        coders.codeTemperatureReport(this, auto, interval, index, sensor)

    codeFanSpeed: (speed, index) ->
        coders.codeFanSpeed(this, speed, index)

    codeFanReport: (auto, interval) ->
        coders.codeFanReport(this, auto, interval)

    codeDwell: (time, interruptible, message) ->
        coders.codeDwell(this, time, interruptible, message)

    codeInterrupt: ->
        coders.codeInterrupt(this)

    codeWait: ->
        coders.codeWait(this)

    codeTone: (duration, frequency) ->
        coders.codeTone(this, duration, frequency)

    codeMessage: (message) ->
        coders.codeMessage(this, message)

    codeShutdown: ->
        coders.codeShutdown(this)

    codeFirmwareReport: ->
        coders.codeFirmwareReport(this)

    codeSDReport: (auto, interval, name) ->
        coders.codeSDReport(this, auto, interval, name)

    codeProgressReport: (percent, time) ->
        coders.codeProgressReport(this, percent, time)

    codeRetract: (distance, speed) ->
        coders.codeRetract(this, distance, speed)

    codeUnretract: (distance, speed) ->
        coders.codeUnretract(this, distance, speed)

    # Helper method delegates

    isWithinBounds: (x, y) ->
        helpers.isWithinBounds(this, x, y)

    calculateExtrusion: (distance, lineWidth) ->
        helpers.calculateExtrusion(this, distance, lineWidth)

    # Main slicing method

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
