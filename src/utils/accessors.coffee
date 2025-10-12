# Getter and setter methods for Polyslice.

conversions = require('./conversions')

module.exports =

    # Getters

    getAutohome: (slicer) ->

        return slicer.autohome

    getWorkspacePlane: (slicer) ->

        return slicer.workspacePlane

    getTimeUnit: (slicer) ->

        return slicer.timeUnit

    getLengthUnit: (slicer) ->

        return slicer.lengthUnit

    getTemperatureUnit: (slicer) ->

        return slicer.temperatureUnit

    getSpeedUnit: (slicer) ->

        return slicer.speedUnit

    getAngleUnit: (slicer) ->

        return slicer.angleUnit

    getNozzleTemperature: (slicer) ->

        return conversions.temperatureFromInternal(slicer.nozzleTemperature, slicer.temperatureUnit)

    getBedTemperature: (slicer) ->

        return conversions.temperatureFromInternal(slicer.bedTemperature, slicer.temperatureUnit)

    getFanSpeed: (slicer) ->

        return slicer.fanSpeed

    getLayerHeight: (slicer) ->

        return conversions.lengthFromInternal(slicer.layerHeight, slicer.lengthUnit)

    getExtrusionMultiplier: (slicer) ->

        return slicer.extrusionMultiplier

    getFilamentDiameter: (slicer) ->

        return conversions.lengthFromInternal(slicer.filamentDiameter, slicer.lengthUnit)

    getNozzleDiameter: (slicer) ->

        return conversions.lengthFromInternal(slicer.nozzleDiameter, slicer.lengthUnit)

    getPerimeterSpeed: (slicer) ->

        return conversions.speedFromInternal(slicer.perimeterSpeed, slicer.speedUnit)

    getInfillSpeed: (slicer) ->

        return conversions.speedFromInternal(slicer.infillSpeed, slicer.speedUnit)

    getTravelSpeed: (slicer) ->

        return conversions.speedFromInternal(slicer.travelSpeed, slicer.speedUnit)

    getRetractionDistance: (slicer) ->

        return conversions.lengthFromInternal(slicer.retractionDistance, slicer.lengthUnit)

    getRetractionSpeed: (slicer) ->

        return conversions.speedFromInternal(slicer.retractionSpeed, slicer.speedUnit)

    getBuildPlateWidth: (slicer) ->

        return conversions.lengthFromInternal(slicer.buildPlateWidth, slicer.lengthUnit)

    getBuildPlateLength: (slicer) ->

        return conversions.lengthFromInternal(slicer.buildPlateLength, slicer.lengthUnit)

    getInfillDensity: (slicer) ->

        return slicer.infillDensity

    getInfillPattern: (slicer) ->

        return slicer.infillPattern

    getShellSkinThickness: (slicer) ->

        return conversions.lengthFromInternal(slicer.shellSkinThickness, slicer.lengthUnit)

    getShellWallThickness: (slicer) ->

        return conversions.lengthFromInternal(slicer.shellWallThickness, slicer.lengthUnit)

    getSupportEnabled: (slicer) ->

        return slicer.supportEnabled

    getSupportType: (slicer) ->

        return slicer.supportType

    getSupportPlacement: (slicer) ->

        return slicer.supportPlacement

    getSupportThreshold: (slicer) ->

        return conversions.angleFromInternal(slicer.supportThreshold, slicer.angleUnit)

    getAdhesionEnabled: (slicer) ->

        return slicer.adhesionEnabled

    getAdhesionType: (slicer) ->

        return slicer.adhesionType

    getTestStrip: (slicer) ->

        return slicer.testStrip

    getOutline: (slicer) ->

        return slicer.outline

    getMetadata: (slicer) ->

        return slicer.metadata

    getVerbose: (slicer) ->

        return slicer.verbose

    getBuzzer: (slicer) ->

        return slicer.buzzer

    getWipeNozzle: (slicer) ->

        return slicer.wipeNozzle

    getPositioningMode: (slicer) ->

        return slicer.positioningMode

    getExtruderMode: (slicer) ->

        return slicer.extruderMode

    getPrinter: (slicer) ->

        return slicer.printer

    getFilament: (slicer) ->

        return slicer.filament

    # Setters

    setAutohome: (slicer, autohome = true) ->

        slicer.autohome = Boolean autohome

        return slicer

    setWorkspacePlane: (slicer, plane = "XY") ->

        plane = plane.toUpperCase().trim()

        if ["XY", "XZ", "YZ"].includes plane

            slicer.workspacePlane = String plane

        return slicer

    setTimeUnit: (slicer, unit = "milliseconds") ->

        unit = unit.toLowerCase().trim()

        if ["milliseconds", "seconds"].includes unit

            slicer.timeUnit = String unit

        return slicer

    setLengthUnit: (slicer, unit = "millimeters") ->

        unit = unit.toLowerCase().trim()

        if ["millimeters", "inches"].includes unit

            slicer.lengthUnit = String unit

        return slicer

    setSpeedUnit: (slicer, unit = "millimeterSecond") ->

        if ["millimeterSecond", "inchSecond", "meterSecond"].includes unit

            slicer.speedUnit = String unit

        return slicer

    setTemperatureUnit: (slicer, unit = "celsius") ->

        unit = unit.toLowerCase().trim()

        if ["celsius", "fahrenheit", "kelvin"].includes unit

            slicer.temperatureUnit = String unit

        return slicer

    setAngleUnit: (slicer, unit = "degree") ->

        unit = unit.toLowerCase().trim()

        if ["degree", "radian", "gradian"].includes unit

            slicer.angleUnit = String unit

        return slicer

    setNozzleTemperature: (slicer, temp = 0) ->

        if typeof temp is "number" and temp >= 0

            slicer.nozzleTemperature = conversions.temperatureToInternal(temp, slicer.temperatureUnit)

        return slicer

    setBedTemperature: (slicer, temp = 0) ->

        if typeof temp is "number" and temp >= 0

            slicer.bedTemperature = conversions.temperatureToInternal(temp, slicer.temperatureUnit)

        return slicer

    setFanSpeed: (slicer, speed = 100) ->

        if typeof speed is "number" and speed >= 0 and speed <= 100

            slicer.fanSpeed = Number speed

        return slicer

    setLayerHeight: (slicer, height = 0.2) ->

        if typeof height is "number" and height > 0

            slicer.layerHeight = conversions.lengthToInternal(height, slicer.lengthUnit)

        return slicer

    setExtrusionMultiplier: (slicer, multiplier = 1.0) ->

        if typeof multiplier is "number" and multiplier > 0

            slicer.extrusionMultiplier = Number multiplier

        return slicer

    setFilamentDiameter: (slicer, diameter = 1.75) ->

        if typeof diameter is "number" and diameter > 0

            slicer.filamentDiameter = conversions.lengthToInternal(diameter, slicer.lengthUnit)

        return slicer

    setNozzleDiameter: (slicer, diameter = 0.4) ->

        if typeof diameter is "number" and diameter > 0

            slicer.nozzleDiameter = conversions.lengthToInternal(diameter, slicer.lengthUnit)

        return slicer

    setPerimeterSpeed: (slicer, speed = 30) ->

        if typeof speed is "number" and speed > 0

            slicer.perimeterSpeed = conversions.speedToInternal(speed, slicer.speedUnit)

        return slicer

    setInfillSpeed: (slicer, speed = 60) ->

        if typeof speed is "number" and speed > 0

            slicer.infillSpeed = conversions.speedToInternal(speed, slicer.speedUnit)

        return slicer

    setTravelSpeed: (slicer, speed = 120) ->

        if typeof speed is "number" and speed > 0

            slicer.travelSpeed = conversions.speedToInternal(speed, slicer.speedUnit)

        return slicer

    setRetractionDistance: (slicer, distance = 1.0) ->

        if typeof distance is "number" and distance >= 0

            slicer.retractionDistance = conversions.lengthToInternal(distance, slicer.lengthUnit)

        return slicer

    setRetractionSpeed: (slicer, speed = 40) ->

        if typeof speed is "number" and speed > 0

            slicer.retractionSpeed = conversions.speedToInternal(speed, slicer.speedUnit)

        return slicer

    setBuildPlateWidth: (slicer, width = 220) ->

        if typeof width is "number" and width > 0

            slicer.buildPlateWidth = conversions.lengthToInternal(width, slicer.lengthUnit)

        return slicer

    setBuildPlateLength: (slicer, length = 220) ->

        if typeof length is "number" and length > 0

            slicer.buildPlateLength = conversions.lengthToInternal(length, slicer.lengthUnit)

        return slicer

    setInfillDensity: (slicer, density = 20) ->

        if typeof density is "number" and density >= 0 and density <= 100

            slicer.infillDensity = Number density

        return slicer

    setInfillPattern: (slicer, pattern = "grid") ->

        pattern = pattern.toLowerCase().trim()

        if ["grid", "lines", "triangles", "cubic", "gyroid", "honeycomb"].includes pattern

            slicer.infillPattern = String pattern

        return slicer

    setShellSkinThickness: (slicer, thickness = 0.8) ->

        if typeof thickness is "number" and thickness >= 0

            slicer.shellSkinThickness = conversions.lengthToInternal(thickness, slicer.lengthUnit)

        return slicer

    setShellWallThickness: (slicer, thickness = 0.8) ->

        if typeof thickness is "number" and thickness >= 0

            slicer.shellWallThickness = conversions.lengthToInternal(thickness, slicer.lengthUnit)

        return slicer

    setSupportEnabled: (slicer, enabled = false) ->

        slicer.supportEnabled = Boolean enabled

        return slicer

    setSupportType: (slicer, type = "normal") ->

        type = type.toLowerCase().trim()

        if ["normal", "tree"].includes type

            slicer.supportType = String type

        return slicer

    setSupportPlacement: (slicer, placement = "buildPlate") ->

        placement = placement.toLowerCase().trim()

        if ["everywhere", "buildPlate"].includes placement

            slicer.supportPlacement = String placement

        return slicer

    setSupportThreshold: (slicer, angle = 45) ->

        if typeof angle is "number"

            # Convert to internal units (degrees) first.
            angleInDegrees = conversions.angleToInternal(angle, slicer.angleUnit)

            # Validate that the angle in degrees is within 0-90 range.
            if angleInDegrees >= 0 and angleInDegrees <= 90

                slicer.supportThreshold = angleInDegrees

        return slicer

    setAdhesionEnabled: (slicer, enabled = false) ->

        slicer.adhesionEnabled = Boolean enabled

        return slicer

    setAdhesionType: (slicer, type = "skirt") ->

        type = type.toLowerCase().trim()

        if ["skirt", "brim", "raft"].includes type

            slicer.adhesionType = String type

        return slicer

    setTestStrip: (slicer, testStrip = false) ->

        slicer.testStrip = Boolean testStrip

        return slicer

    setOutline: (slicer, outline = true) ->

        slicer.outline = Boolean outline

        return slicer

    setMetadata: (slicer, metadata = true) ->

        slicer.metadata = Boolean metadata

        return slicer

    setVerbose: (slicer, verbose = true) ->

        slicer.verbose = Boolean verbose

        return slicer

    setBuzzer: (slicer, buzzer = true) ->

        slicer.buzzer = Boolean buzzer

        return slicer

    setWipeNozzle: (slicer, wipeNozzle = false) ->

        slicer.wipeNozzle = Boolean wipeNozzle

        return slicer

    setPositioningMode: (slicer, mode = "absolute") ->

        if ["absolute", "relative"].includes mode

            slicer.positioningMode = String mode

        return slicer

    setExtruderMode: (slicer, mode = "absolute") ->

        if ["absolute", "relative"].includes mode

            slicer.extruderMode = String mode

        return slicer

    setPrinter: (slicer, printer) ->

        if printer # Apply printer settings and override existing configuration.

            slicer.printer = printer

            slicer.buildPlateWidth = conversions.lengthToInternal(printer.getSizeX(), slicer.lengthUnit)
            slicer.buildPlateLength = conversions.lengthToInternal(printer.getSizeY(), slicer.lengthUnit)

            slicer.nozzleDiameter = conversions.lengthToInternal(printer.getNozzle(0).diameter, slicer.lengthUnit)

            if not slicer.filament # Update filament diameter from printer if no filament is set.

                slicer.filamentDiameter = conversions.lengthToInternal(printer.getNozzle(0).filament, slicer.lengthUnit)

        else

            slicer.printer = null

        return slicer

    setFilament: (slicer, filament) ->

        if filament # Apply filament settings and override existing configuration.

            slicer.filament = filament

            slicer.nozzleTemperature = conversions.temperatureToInternal(filament.getNozzleTemperature(), slicer.temperatureUnit)
            slicer.bedTemperature = conversions.temperatureToInternal(filament.getBedTemperature(), slicer.temperatureUnit)

            slicer.retractionDistance = conversions.lengthToInternal(filament.getRetractionDistance(), slicer.lengthUnit)
            slicer.retractionSpeed = conversions.speedToInternal(filament.getRetractionSpeed(), slicer.speedUnit)

            slicer.filamentDiameter = conversions.lengthToInternal(filament.getDiameter(), slicer.lengthUnit)

            slicer.fanSpeed = filament.getFan()

        else

            slicer.filament = null

        return slicer
