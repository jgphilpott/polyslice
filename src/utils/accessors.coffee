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

    getInfillPatternCentering: (slicer) ->

        return slicer.infillPatternCentering

    getShellSkinThickness: (slicer) ->

        return conversions.lengthFromInternal(slicer.shellSkinThickness, slicer.lengthUnit)

    getShellWallThickness: (slicer) ->

        return conversions.lengthFromInternal(slicer.shellWallThickness, slicer.lengthUnit)

    getExposureDetection: (slicer) ->

        return slicer.exposureDetection

    getExposureDetectionResolution: (slicer) ->

        return slicer.exposureDetectionResolution

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

    getSkirtType: (slicer) ->

        return slicer.skirtType

    getSkirtDistance: (slicer) ->

        return conversions.lengthFromInternal(slicer.skirtDistance, slicer.lengthUnit)

    getSkirtLineCount: (slicer) ->

        return slicer.skirtLineCount

    getBrimDistance: (slicer) ->

        return conversions.lengthFromInternal(slicer.brimDistance, slicer.lengthUnit)

    getBrimLineCount: (slicer) ->

        return slicer.brimLineCount

    getRaftMargin: (slicer) ->

        return conversions.lengthFromInternal(slicer.raftMargin, slicer.lengthUnit)

    getRaftBaseThickness: (slicer) ->

        return conversions.lengthFromInternal(slicer.raftBaseThickness, slicer.lengthUnit)

    getRaftInterfaceLayers: (slicer) ->

        return slicer.raftInterfaceLayers

    getRaftInterfaceThickness: (slicer) ->

        return conversions.lengthFromInternal(slicer.raftInterfaceThickness, slicer.lengthUnit)

    getRaftAirGap: (slicer) ->

        return conversions.lengthFromInternal(slicer.raftAirGap, slicer.lengthUnit)

    getRaftLineSpacing: (slicer) ->

        return conversions.lengthFromInternal(slicer.raftLineSpacing, slicer.lengthUnit)

    getTestStrip: (slicer) ->

        return slicer.testStrip

    getMetadata: (slicer) ->

        return slicer.metadata

    getVerbose: (slicer) ->

        return slicer.verbose

    getMetadataVersion: (slicer) ->

        return slicer.metadataVersion

    getMetadataTimestamp: (slicer) ->

        return slicer.metadataTimestamp

    getMetadataRepository: (slicer) ->

        return slicer.metadataRepository

    getMetadataPrinter: (slicer) ->

        return slicer.metadataPrinter

    getMetadataFilament: (slicer) ->

        return slicer.metadataFilament

    getMetadataNozzleTemp: (slicer) ->

        return slicer.metadataNozzleTemp

    getMetadataBedTemp: (slicer) ->

        return slicer.metadataBedTemp

    getMetadataLayerHeight: (slicer) ->

        return slicer.metadataLayerHeight

    getMetadataTotalLayers: (slicer) ->

        return slicer.metadataTotalLayers

    getMetadataFilamentLength: (slicer) ->

        return slicer.metadataFilamentLength

    getMetadataMaterialVolume: (slicer) ->

        return slicer.metadataMaterialVolume

    getMetadataMaterialWeight: (slicer) ->

        return slicer.metadataMaterialWeight

    getMetadataPrintTime: (slicer) ->

        return slicer.metadataPrintTime

    getMetadataFlavor: (slicer) ->

        return slicer.metadataFlavor

    getMetadataInfillDensity: (slicer) ->

        return slicer.metadataInfillDensity

    getMetadataInfillPattern: (slicer) ->

        return slicer.metadataInfillPattern

    getMetadataWallCount: (slicer) ->

        return slicer.metadataWallCount

    getMetadataSupport: (slicer) ->

        return slicer.metadataSupport

    getMetadataAdhesion: (slicer) ->

        return slicer.metadataAdhesion

    getMetadataSpeeds: (slicer) ->

        return slicer.metadataSpeeds

    getMetadataBoundingBox: (slicer) ->

        return slicer.metadataBoundingBox

    getCoordinatePrecision: (slicer) ->

        return slicer.coordinatePrecision

    getExtrusionPrecision: (slicer) ->

        return slicer.extrusionPrecision

    getFeedratePrecision: (slicer) ->

        return slicer.feedratePrecision

    getMeshPreprocessing: (slicer) ->

        return slicer.meshPreprocessing

    getBuzzer: (slicer) ->

        return slicer.buzzer

    getWipeNozzle: (slicer) ->

        return slicer.wipeNozzle

    getSmartWipeNozzle: (slicer) ->

        return slicer.smartWipeNozzle

    getPositioningMode: (slicer) ->

        return slicer.positioningMode

    getExtruderMode: (slicer) ->

        return slicer.extruderMode

    getProgressCallback: (slicer) ->

        return slicer.progressCallback

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

        if ["grid", "lines", "triangles", "cubic", "gyroid", "hexagons", "honeycomb", "concentric"].includes pattern

            slicer.infillPattern = String pattern

        return slicer

    setInfillPatternCentering: (slicer, centering = "object") ->

        centering = centering.toLowerCase().trim()

        if ["object", "global"].includes centering

            slicer.infillPatternCentering = String centering

        return slicer

    setShellSkinThickness: (slicer, thickness = 0.8) ->

        if typeof thickness is "number" and thickness >= 0

            slicer.shellSkinThickness = conversions.lengthToInternal(thickness, slicer.lengthUnit)

        return slicer

    setShellWallThickness: (slicer, thickness = 0.8) ->

        if typeof thickness is "number" and thickness >= 0

            slicer.shellWallThickness = conversions.lengthToInternal(thickness, slicer.lengthUnit)

        return slicer

    setExposureDetection: (slicer, enabled = false) ->

        slicer.exposureDetection = Boolean enabled

        return slicer

    setExposureDetectionResolution: (slicer, resolution = 961) ->

        slicer.exposureDetectionResolution = Math.max(1, Math.floor(resolution))

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

    setSkirtType: (slicer, type = "circular") ->

        type = type.toLowerCase().trim()

        if ["circular", "shape"].includes type

            slicer.skirtType = String type

        return slicer

    setSkirtDistance: (slicer, distance = 5) ->

        if typeof distance is "number" and distance >= 0

            slicer.skirtDistance = conversions.lengthToInternal(distance, slicer.lengthUnit)

        return slicer

    setSkirtLineCount: (slicer, count = 3) ->

        if typeof count is "number" and count >= 0

            slicer.skirtLineCount = Number count

        return slicer

    setBrimDistance: (slicer, distance = 0) ->

        if typeof distance is "number" and distance >= 0

            slicer.brimDistance = conversions.lengthToInternal(distance, slicer.lengthUnit)

        return slicer

    setBrimLineCount: (slicer, count = 8) ->

        if typeof count is "number" and count >= 0

            slicer.brimLineCount = Number count

        return slicer

    setRaftMargin: (slicer, margin = 5) ->

        if typeof margin is "number" and margin >= 0

            slicer.raftMargin = conversions.lengthToInternal(margin, slicer.lengthUnit)

        return slicer

    setRaftBaseThickness: (slicer, thickness = 0.3) ->

        if typeof thickness is "number" and thickness > 0

            slicer.raftBaseThickness = conversions.lengthToInternal(thickness, slicer.lengthUnit)

        return slicer

    setRaftInterfaceLayers: (slicer, layers = 2) ->

        if typeof layers is "number" and layers >= 0

            slicer.raftInterfaceLayers = Number layers

        return slicer

    setRaftInterfaceThickness: (slicer, thickness = 0.2) ->

        if typeof thickness is "number" and thickness > 0

            slicer.raftInterfaceThickness = conversions.lengthToInternal(thickness, slicer.lengthUnit)

        return slicer

    setRaftAirGap: (slicer, gap = 0.2) ->

        if typeof gap is "number" and gap >= 0

            slicer.raftAirGap = conversions.lengthToInternal(gap, slicer.lengthUnit)

        return slicer

    setRaftLineSpacing: (slicer, spacing = 2) ->

        if typeof spacing is "number" and spacing > 0

            slicer.raftLineSpacing = conversions.lengthToInternal(spacing, slicer.lengthUnit)

        return slicer

    setTestStrip: (slicer, testStrip = false) ->

        slicer.testStrip = Boolean testStrip

        return slicer

    setMetadata: (slicer, metadata = true) ->

        slicer.metadata = Boolean metadata

        return slicer

    setVerbose: (slicer, verbose = true) ->

        slicer.verbose = Boolean verbose

        return slicer

    setMetadataVersion: (slicer, enabled = true) ->

        slicer.metadataVersion = Boolean enabled

        return slicer

    setMetadataTimestamp: (slicer, enabled = true) ->

        slicer.metadataTimestamp = Boolean enabled

        return slicer

    setMetadataRepository: (slicer, enabled = true) ->

        slicer.metadataRepository = Boolean enabled

        return slicer

    setMetadataPrinter: (slicer, enabled = true) ->

        slicer.metadataPrinter = Boolean enabled

        return slicer

    setMetadataFilament: (slicer, enabled = true) ->

        slicer.metadataFilament = Boolean enabled

        return slicer

    setMetadataNozzleTemp: (slicer, enabled = true) ->

        slicer.metadataNozzleTemp = Boolean enabled

        return slicer

    setMetadataBedTemp: (slicer, enabled = true) ->

        slicer.metadataBedTemp = Boolean enabled

        return slicer

    setMetadataLayerHeight: (slicer, enabled = true) ->

        slicer.metadataLayerHeight = Boolean enabled

        return slicer

    setMetadataTotalLayers: (slicer, enabled = true) ->

        slicer.metadataTotalLayers = Boolean enabled

        return slicer

    setMetadataFilamentLength: (slicer, enabled = true) ->

        slicer.metadataFilamentLength = Boolean enabled

        return slicer

    setMetadataMaterialVolume: (slicer, enabled = true) ->

        slicer.metadataMaterialVolume = Boolean enabled

        return slicer

    setMetadataMaterialWeight: (slicer, enabled = true) ->

        slicer.metadataMaterialWeight = Boolean enabled

        return slicer

    setMetadataPrintTime: (slicer, enabled = true) ->

        slicer.metadataPrintTime = Boolean enabled

        return slicer

    setMetadataFlavor: (slicer, enabled = true) ->

        slicer.metadataFlavor = Boolean enabled

        return slicer

    setMetadataInfillDensity: (slicer, enabled = true) ->

        slicer.metadataInfillDensity = Boolean enabled

        return slicer

    setMetadataInfillPattern: (slicer, enabled = true) ->

        slicer.metadataInfillPattern = Boolean enabled

        return slicer

    setMetadataWallCount: (slicer, enabled = true) ->

        slicer.metadataWallCount = Boolean enabled

        return slicer

    setMetadataSupport: (slicer, enabled = true) ->

        slicer.metadataSupport = Boolean enabled

        return slicer

    setMetadataAdhesion: (slicer, enabled = true) ->

        slicer.metadataAdhesion = Boolean enabled

        return slicer

    setMetadataSpeeds: (slicer, enabled = true) ->

        slicer.metadataSpeeds = Boolean enabled

        return slicer

    setMetadataBoundingBox: (slicer, enabled = true) ->

        slicer.metadataBoundingBox = Boolean enabled

        return slicer

    setCoordinatePrecision: (slicer, precision = 3) ->

        if typeof precision is "number" and precision >= 0 and precision <= 10

            slicer.coordinatePrecision = Math.floor(Number precision)

        return slicer

    setExtrusionPrecision: (slicer, precision = 5) ->

        if typeof precision is "number" and precision >= 0 and precision <= 10

            slicer.extrusionPrecision = Math.floor(Number precision)

        return slicer

    setFeedratePrecision: (slicer, precision = 0) ->

        if typeof precision is "number" and precision >= 0 and precision <= 10

            slicer.feedratePrecision = Math.floor(Number precision)

        return slicer

    setMeshPreprocessing: (slicer, enabled = false) ->

        slicer.meshPreprocessing = Boolean enabled

        return slicer

    setBuzzer: (slicer, buzzer = true) ->

        slicer.buzzer = Boolean buzzer

        return slicer

    setWipeNozzle: (slicer, wipeNozzle = true) ->

        slicer.wipeNozzle = Boolean wipeNozzle

        return slicer

    setSmartWipeNozzle: (slicer, smartWipeNozzle = true) ->

        slicer.smartWipeNozzle = Boolean smartWipeNozzle

        return slicer

    setPositioningMode: (slicer, mode = "absolute") ->

        if ["absolute", "relative"].includes mode

            slicer.positioningMode = String mode

        return slicer

    setExtruderMode: (slicer, mode = "absolute") ->

        if ["absolute", "relative"].includes mode

            slicer.extruderMode = String mode

        return slicer

    setProgressCallback: (slicer, callback = null) ->

        if typeof callback is "function" or callback is null

            slicer.progressCallback = callback

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

    # Extract metadata from G-code and return as JSON object.
    # Supports Polyslice, Cura, and PrusaSlicer formats.
    # If no gcode argument provided, extracts from slicer.gcode.
    getGcodeMetadata: (slicer, gcode = null) ->

        # Use provided gcode or default to slicer.gcode
        gcodeToAnalyze = gcode ? slicer.gcode

        # Return empty object if no gcode available
        return {} if not gcodeToAnalyze or gcodeToAnalyze.trim() is ""

        lines = gcodeToAnalyze.split(/\r?\n/)

        # Detect slicer type
        slicerType = null
        for line in lines.slice(0, 20)  # Check first 20 lines
            trimmed = line.trim()
            if trimmed is "; Generated by Polyslice"
                slicerType = "Polyslice"
                break
            else if /^;Generated with Cura/i.test(trimmed)
                slicerType = "Cura"
                break
            else if /^; generated by PrusaSlicer/i.test(trimmed)
                slicerType = "PrusaSlicer"
                break

        # Parse based on detected slicer type
        if slicerType is "Polyslice"
            return @parsePolysliceMetadata(lines)
        else if slicerType is "Cura"
            return @parseCuraMetadata(lines)
        else if slicerType is "PrusaSlicer"
            return @parsePrusaSlicerMetadata(lines)
        else
            # Try generic parsing
            return @parseGenericMetadata(lines)

    # Parse Polyslice format: "; Key: Value"
    parsePolysliceMetadata: (lines) ->

        metadata = { generatedBy: "Polyslice" }
        metadataStarted = false

        for line in lines

            line = line.trim()

            if line is "; Generated by Polyslice"
                metadataStarted = true
                continue

            continue if not metadataStarted

            # Stop at non-comment or empty comment line
            break if not line.startsWith(";") or line is ";"

            # Remove leading "; "
            content = line.substring(1).trim()

            # Split on first ": "
            colonIndex = content.indexOf(": ")
            continue if colonIndex <= 0

            key = content.substring(0, colonIndex).trim()
            value = content.substring(colonIndex + 2).trim()

            # Convert to camelCase and parse value
            camelKey = @toCamelCase(key)
            metadata[camelKey] = @parseValue(value)

        return metadata

    # Parse Cura format: ";KEY:VALUE" or ";Key name: value"
    parseCuraMetadata: (lines) ->

        metadata = { generatedBy: "Cura" }

        for line in lines

            trimmed = line.trim()
            continue if not trimmed.startsWith(";")

            # Extract version from ";Generated with Cura_SteamEngine X.X.X"
            if versionMatch = trimmed.match(/^;Generated with Cura_SteamEngine\s+([\d.]+)/)
                metadata.version = versionMatch[1]

            # Parse ";KEY:VALUE" or ";Key name: value" format
            if match = trimmed.match(/^;([^:]+):\s*(.+)$/)
                key = match[1].trim()
                value = match[2].trim()

                # Map Cura keys to standard fields
                switch key
                    when "TIME"
                        # Convert seconds to time string
                        seconds = parseInt(value, 10)
                        metadata.estimatedPrintTime = @formatSeconds(seconds)
                    when "Filament used"
                        # Parse "0.24553m" format
                        if fMatch = value.match(/^([\d.]+)m$/)
                            metadata.filamentLength = { value: parseFloat(fMatch[1]) * 1000, unit: "mm" }
                    when "Layer height"
                        metadata.layerHeight = { value: parseFloat(value), unit: "mm" }
                    when "LAYER_COUNT"
                        metadata.totalLayers = parseInt(value, 10)
                    when "TARGET_MACHINE.NAME"
                        metadata.printer = value
                    when "FLAVOR"
                        metadata.flavor = value
                    when "MINX", "MINY", "MINZ", "MAXX", "MAXY", "MAXZ"
                        metadata.boundingBox ?= {}
                        metadata.boundingBox[@toCamelCase(key)] = parseFloat(value)

        return metadata

    # Parse PrusaSlicer format: "; key = value"
    parsePrusaSlicerMetadata: (lines) ->

        metadata = { generatedBy: "PrusaSlicer" }

        # Extract version and timestamp from header
        if headerMatch = lines[0]?.match(/^; generated by PrusaSlicer\s+([\d.]+[^\s]*)\s+on\s+([\d-]+)\s+at\s+([\d:]+)\s+UTC/)
            metadata.version = headerMatch[1]
            metadata.timestamp = "#{headerMatch[2]}T#{headerMatch[3]}.000Z"

        for line in lines

            trimmed = line.trim()
            continue if not trimmed.startsWith(";")

            # Parse "; key = value" format
            if match = trimmed.match(/^;\s*([^=]+?)\s*=\s*(.+)$/)
                key = match[1].trim()
                value = match[2].trim()

                # Map PrusaSlicer keys to standard fields
                switch key
                    when "layer_height"
                        metadata.layerHeight = { value: parseFloat(value), unit: "mm" }
                    when "filament used [mm]"
                        metadata.filamentLength = { value: parseFloat(value), unit: "mm" }
                    when "filament used [cm3]"
                        metadata.materialVolume = { value: parseFloat(value), unit: "cm³" }
                    when "total filament used [g]"
                        metadata.materialWeight = { value: parseFloat(value), unit: "g" }
                    when "estimated printing time (normal mode)"
                        metadata.estimatedPrintTime = value

        return metadata

    # Generic fallback parser
    parseGenericMetadata: (lines) ->

        metadata = { generatedBy: "Unknown" }

        for line in lines.slice(0, 50)  # Check first 50 lines
            trimmed = line.trim()
            continue if not trimmed.startsWith(";")

            content = trimmed.substring(1).trim()

            # Try ": " separator
            if colonIndex = content.indexOf(": ")
                if colonIndex > 0
                    key = content.substring(0, colonIndex).trim()
                    value = content.substring(colonIndex + 2).trim()
                    camelKey = @toCamelCase(key)
                    metadata[camelKey] = @parseValue(value)

        return metadata

    # Helper: Convert string to camelCase
    toCamelCase: (str) ->
        str.split(/[\s_]+/).map((word, index) ->
            if index is 0
                word.toLowerCase()
            else
                word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
        ).join('')

    # Helper: Parse value with intelligent type detection
    parseValue: (value) ->

        # Version numbers, timestamps, complex time formats
        isVersionNumber = /^\d+\.\d+\.\d+/.test(value)
        isTimestamp = /^\d{4}-\d{2}-\d{2}/.test(value)
        isComplexTime = /\d+[hms]\s+\d+[hms]/.test(value)

        return value if isVersionNumber or isTimestamp or isComplexTime

        # Plain integer
        return parseInt(value, 10) if /^(\d+)$/.test(value)

        # Plain float
        return parseFloat(value) if /^(\d+\.\d+)$/.test(value)

        # Number with unit
        if match = value.match(/^(\d+\.\d+|\d+)\s*([a-zA-Z°³].*)$/)
            return {
                value: parseFloat(match[1])
                unit: match[2]
            }

        # Everything else as string
        return value

    # Helper: Format seconds to readable time string
    formatSeconds: (seconds) ->
        hours = Math.floor(seconds / 3600)
        minutes = Math.floor((seconds % 3600) / 60)
        secs = seconds % 60

        if hours > 0
            return "#{hours}h #{minutes}m #{secs}s"
        else if minutes > 0
            return "#{minutes}m #{secs}s"
        else
            return "#{secs}s"
