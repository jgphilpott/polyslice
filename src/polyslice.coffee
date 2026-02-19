bounds = require('./slicer/utils/bounds')
extrusion = require('./slicer/utils/extrusion')
accessors = require('./utils/accessors')
conversions = require('./utils/conversions')

coders = require('./slicer/gcode/coders')
slicer = require('./slicer/slice')

class Polyslice

    constructor: (options = {}) ->

        @gcode = ""
        @newline = "\n"

        # Printer and filament configuration objects.
        @printer = options.printer ?= null # Printer instance or null.
        @filament = options.filament ?= null # Filament instance or null.

        printerSettings = {} # Apply printer settings if provided (before applying other options).

        if @printer

            printerSettings.buildPlateWidth = @printer.getSizeX()
            printerSettings.buildPlateLength = @printer.getSizeY()
            printerSettings.nozzleDiameter = @printer.getNozzle(0).diameter
            printerSettings.filamentDiameter = @printer.getNozzle(0).filament

        filamentSettings = {} # Apply filament settings if provided (before applying other options).

        if @filament

            filamentSettings.nozzleTemperature = @filament.getNozzleTemperature()
            filamentSettings.bedTemperature = @filament.getBedTemperature()

            filamentSettings.retractionDistance = @filament.getRetractionDistance()
            filamentSettings.retractionSpeed = @filament.getRetractionSpeed()
            filamentSettings.filamentDiameter = @filament.getDiameter()

            filamentSettings.fanSpeed = @filament.getFan()

        # Basic printer configuration and behavior settings.
        @autohome = options.autohome ?= true # Boolean.
        @workspacePlane = options.workspacePlane ?= "XY" # String ['XY', 'XZ', 'YZ'].

        # Unit settings for time, distance, and temperature measurements.
        @timeUnit = options.timeUnit ?= "milliseconds" # String ['milliseconds', 'seconds'].
        @lengthUnit = options.lengthUnit ?= "millimeters" # String ['millimeters', 'inches'].
        @speedUnit = options.speedUnit ?= "millimeterSecond" # String ['millimeterSecond', 'inchSecond', 'meterSecond'].
        @temperatureUnit = options.temperatureUnit ?= "celsius" # String ['celsius', 'fahrenheit', 'kelvin'].
        @angleUnit = options.angleUnit ?= "degree" # String ['degree', 'radian', 'gradian'].

        # Temperature control settings for hotend and heated bed (stored internally in Celsius).
        @nozzleTemperature = conversions.temperatureToInternal(options.nozzleTemperature ? filamentSettings.nozzleTemperature ? 0, this.temperatureUnit) # Number (°C internal).
        @bedTemperature = conversions.temperatureToInternal(options.bedTemperature ? filamentSettings.bedTemperature ? 0, this.temperatureUnit) # Number (°C internal).
        @fanSpeed = options.fanSpeed ? filamentSettings.fanSpeed ? 100 # Number 0-100.

        # Slicing and extrusion settings (stored internally in millimeters).
        @layerHeight = conversions.lengthToInternal(options.layerHeight ?= 0.2, this.lengthUnit) # Number (mm internal).
        @extrusionMultiplier = options.extrusionMultiplier ?= 1.0 # Number (multiplier).
        @filamentDiameter = conversions.lengthToInternal(options.filamentDiameter ? filamentSettings.filamentDiameter ? printerSettings.filamentDiameter ? 1.75, this.lengthUnit) # Number (mm internal).
        @nozzleDiameter = conversions.lengthToInternal(options.nozzleDiameter ? printerSettings.nozzleDiameter ? 0.4, this.lengthUnit) # Number (mm internal).

        # Speed settings for different types of movements (stored internally in mm/s).
        @perimeterSpeed = conversions.speedToInternal(options.perimeterSpeed ?= 30, this.speedUnit) # Number (mm/s internal).
        @infillSpeed = conversions.speedToInternal(options.infillSpeed ?= 60, this.speedUnit) # Number (mm/s internal).
        @travelSpeed = conversions.speedToInternal(options.travelSpeed ?= 120, this.speedUnit) # Number (mm/s internal).

        # Retraction settings to prevent stringing during travel moves (stored internally in mm and mm/s).
        @retractionDistance = conversions.lengthToInternal(options.retractionDistance ? filamentSettings.retractionDistance ? 1.0, this.lengthUnit) # Number (mm internal).
        @retractionSpeed = conversions.speedToInternal(options.retractionSpeed ? filamentSettings.retractionSpeed ? 40, this.speedUnit) # Number (mm/s internal).

        # Build plate dimensions for bounds checking and validation (stored internally in mm).
        @buildPlateWidth = conversions.lengthToInternal(options.buildPlateWidth ? printerSettings.buildPlateWidth ? 220, this.lengthUnit) # Number (mm internal).
        @buildPlateLength = conversions.lengthToInternal(options.buildPlateLength ? printerSettings.buildPlateLength ? 220, this.lengthUnit) # Number (mm internal).

        # Infill settings for interior structure and strength.
        @infillDensity = options.infillDensity ?= 20 # Number 0-100 (percentage).
        @infillPattern = options.infillPattern ?= "hexagons" # String ['grid', 'triangles', 'hexagons', 'concentric', 'gyroid', 'spiral', 'lightning'].
        @infillPatternCentering = options.infillPatternCentering ?= "object" # String ['object', 'global'] - center patterns on object boundaries or build plate center.
        @shellSkinThickness = conversions.lengthToInternal(options.shellSkinThickness ?= 0.8, this.lengthUnit) # Number (mm internal).
        @shellWallThickness = conversions.lengthToInternal(options.shellWallThickness ?= 0.8, this.lengthUnit) # Number (mm internal).
        @exposureDetection = options.exposureDetection ?= true # Boolean - enable adaptive skin layer generation for exposed surfaces.
        @exposureDetectionResolution = options.exposureDetectionResolution ?= 961 # Number - sample count for exposure detection (961 = 31x31 grid).

        # Support structure settings for overhangs and bridges.
        @supportEnabled = options.supportEnabled ?= false # Boolean.
        @supportType = options.supportType ?= "normal" # String ['normal', 'tree'].
        @supportPlacement = options.supportPlacement ?= "buildPlate" # String ['buildPlate', 'everywhere'].
        @supportThreshold = conversions.angleToInternal(options.supportThreshold ?= 55, this.angleUnit) # Number (degrees internal).

        # Build plate adhesion settings for first layer stability.
        @adhesionEnabled = options.adhesionEnabled ?= false # Boolean.
        @adhesionType = options.adhesionType ?= "skirt" # String ['skirt', 'brim', 'raft'].

        # Skirt adhesion settings.
        @skirtType = options.skirtType ?= "circular" # String ['circular', 'shape'].
        @skirtDistance = conversions.lengthToInternal(options.skirtDistance ?= 5, this.lengthUnit) # Number (mm internal).
        @skirtLineCount = options.skirtLineCount ?= 3 # Number.

        # Brim adhesion settings.
        @brimDistance = conversions.lengthToInternal(options.brimDistance ?= 0, this.lengthUnit) # Number (mm internal).
        @brimLineCount = options.brimLineCount ?= 8 # Number.

        # Raft adhesion settings.
        @raftMargin = conversions.lengthToInternal(options.raftMargin ?= 5, this.lengthUnit) # Number (mm internal).
        @raftBaseThickness = conversions.lengthToInternal(options.raftBaseThickness ?= 0.3, this.lengthUnit) # Number (mm internal).
        @raftInterfaceLayers = options.raftInterfaceLayers ?= 2 # Number.
        @raftInterfaceThickness = conversions.lengthToInternal(options.raftInterfaceThickness ?= 0.2, this.lengthUnit) # Number (mm internal).
        @raftAirGap = conversions.lengthToInternal(options.raftAirGap ?= 0.2, this.lengthUnit) # Number (mm internal).
        @raftLineSpacing = conversions.lengthToInternal(options.raftLineSpacing ?= 2, this.lengthUnit) # Number (mm internal).

        # Test strip settings for print preparation.
        @testStrip = options.testStrip ?= false # Boolean - lay down test strip before main print.

        # G-code generation settings.
        @metadata = options.metadata ?= true # Boolean - include metadata header in G-code.
        @verbose = options.verbose ?= true # Boolean - include comments/annotations in G-code.

        # Metadata field settings (individual control over each metadata field).
        # Note: The title "Generated by Polyslice" is always included when metadata is enabled.
        @metadataVersion = options.metadataVersion ?= true # Boolean - include version number.
        @metadataTimestamp = options.metadataTimestamp ?= true # Boolean - include timestamp.
        @metadataRepository = options.metadataRepository ?= true # Boolean - include repository URL.
        @metadataPrinter = options.metadataPrinter ?= true # Boolean - include printer information.
        @metadataFilament = options.metadataFilament ?= true # Boolean - include filament information.
        @metadataNozzleTemp = options.metadataNozzleTemp ?= true # Boolean - include nozzle temperature.
        @metadataBedTemp = options.metadataBedTemp ?= true # Boolean - include bed temperature.
        @metadataLayerHeight = options.metadataLayerHeight ?= true # Boolean - include layer height.
        @metadataTotalLayers = options.metadataTotalLayers ?= true # Boolean - include total layers count.
        @metadataFilamentLength = options.metadataFilamentLength ?= true # Boolean - include filament length.
        @metadataMaterialVolume = options.metadataMaterialVolume ?= true # Boolean - include material volume.
        @metadataMaterialWeight = options.metadataMaterialWeight ?= true # Boolean - include material weight.
        @metadataPrintTime = options.metadataPrintTime ?= true # Boolean - include estimated print time.
        @metadataFlavor = options.metadataFlavor ?= true # Boolean - include G-code flavor/firmware.
        @metadataInfillDensity = options.metadataInfillDensity ?= true # Boolean - include infill density.
        @metadataInfillPattern = options.metadataInfillPattern ?= true # Boolean - include infill pattern.
        @metadataWallCount = options.metadataWallCount ?= true # Boolean - include wall count.
        @metadataSupport = options.metadataSupport ?= true # Boolean - include support enabled status.
        @metadataAdhesion = options.metadataAdhesion ?= true # Boolean - include adhesion type.
        @metadataSpeeds = options.metadataSpeeds ?= true # Boolean - include print speeds (perimeter/infill/travel).
        @metadataBoundingBox = options.metadataBoundingBox ?= true # Boolean - include bounding box coordinates.

        # G-code precision settings for output formatting (number of decimal places).
        @coordinatePrecision = options.coordinatePrecision ?= 3 # Number - decimal places for X, Y, Z coordinates (0.001mm resolution).
        @extrusionPrecision = options.extrusionPrecision ?= 5 # Number - decimal places for E (extrusion) values.
        @feedratePrecision = options.feedratePrecision ?= 0 # Number - decimal places for F (feedrate) values (integer mm/min).

        # Mesh preprocessing settings to improve slicing quality.
        @meshPreprocessing = options.meshPreprocessing ?= false # Boolean - enable mesh subdivision for sparse geometries.

        # Post-print settings.
        @buzzer = options.buzzer ?= true # Boolean - sound buzzer at end of post-print.
        @wipeNozzle = options.wipeNozzle ?= true # Boolean - perform wipe move during post-print.
        @smartWipeNozzle = options.smartWipeNozzle ?= true # Boolean - use smart wipe (avoids mesh boundaries) instead of simple X+5, Y+5.

        # Positioning and extrusion mode settings.
        @positioningMode = options.positioningMode ?= "absolute" # String ['absolute', 'relative'].
        @extruderMode = options.extruderMode ?= "absolute" # String ['absolute', 'relative'].

        # Progress callback for slicing feedback.
        # Default lightweight progress bar function (works in Node.js and browsers).
        # Each instance gets its own lastStage tracker to avoid shared state issues.
        defaultProgressCallback = (info) ->

            isNode = typeof process isnt 'undefined' and process?.stdout?.write

            # Use instance-specific lastStage tracking (stored on the slicer instance)
            if not @_lastProgressStage?
                @_lastProgressStage = null

            @_lastProgressStage = info.stage

            # Create simple progress bar
            if info.currentLayer and info.totalLayers
                percent = Math.floor((info.currentLayer / info.totalLayers) * 100)
                filled = Math.floor((info.currentLayer / info.totalLayers) * 20)
            else
                percent = info.percent
                filled = Math.floor((info.percent / 100) * 20)

            empty = 20 - filled
            bar = '█'.repeat(filled) + '░'.repeat(empty)

            # Format message
            if info.currentLayer and info.totalLayers
                message = "#{info.stage.toUpperCase()}: [#{bar}] #{percent}% - Layer #{info.currentLayer}/#{info.totalLayers}"
            else
                message = "#{info.stage.toUpperCase()}: [#{bar}] #{percent}% - #{info.message or ''}"

            # Use process.stdout.write for in-place updates in Node.js, console.log for browsers
            if isNode
                process.stdout.write("\r#{message}")
                if info.percent is 100
                    console.log() # Add newline at completion
            else
                # In browser, just log (can't do in-place updates reliably)
                console.log(message)

        # Bind the default callback to this instance so it can track state per-instance
        # Check if progressCallback was explicitly provided (even if null)
        @progressCallback = if options.hasOwnProperty('progressCallback')
            options.progressCallback
        else
            defaultProgressCallback.bind(this) # Bind to slicer instance

    # Getter method delegates:

    getAutohome: ->
        accessors.getAutohome(this)

    getWorkspacePlane: ->
        accessors.getWorkspacePlane(this)

    getTimeUnit: ->
        accessors.getTimeUnit(this)

    getLengthUnit: ->
        accessors.getLengthUnit(this)

    getTemperatureUnit: ->
        accessors.getTemperatureUnit(this)

    getSpeedUnit: ->
        accessors.getSpeedUnit(this)

    getAngleUnit: ->
        accessors.getAngleUnit(this)

    getNozzleTemperature: ->
        accessors.getNozzleTemperature(this)

    getBedTemperature: ->
        accessors.getBedTemperature(this)

    getFanSpeed: ->
        accessors.getFanSpeed(this)

    getLayerHeight: ->
        accessors.getLayerHeight(this)

    getExtrusionMultiplier: ->
        accessors.getExtrusionMultiplier(this)

    getFilamentDiameter: ->
        accessors.getFilamentDiameter(this)

    getNozzleDiameter: ->
        accessors.getNozzleDiameter(this)

    getPerimeterSpeed: ->
        accessors.getPerimeterSpeed(this)

    getInfillSpeed: ->
        accessors.getInfillSpeed(this)

    getTravelSpeed: ->
        accessors.getTravelSpeed(this)

    getRetractionDistance: ->
        accessors.getRetractionDistance(this)

    getRetractionSpeed: ->
        accessors.getRetractionSpeed(this)

    getBuildPlateWidth: ->
        accessors.getBuildPlateWidth(this)

    getBuildPlateLength: ->
        accessors.getBuildPlateLength(this)

    getInfillDensity: ->
        accessors.getInfillDensity(this)

    getInfillPattern: ->
        accessors.getInfillPattern(this)

    getInfillPatternCentering: ->
        accessors.getInfillPatternCentering(this)

    getShellSkinThickness: ->
        accessors.getShellSkinThickness(this)

    getShellWallThickness: ->
        accessors.getShellWallThickness(this)

    getExposureDetection: ->
        accessors.getExposureDetection(this)

    getExposureDetectionResolution: ->
        accessors.getExposureDetectionResolution(this)

    getSupportEnabled: ->
        accessors.getSupportEnabled(this)

    getSupportType: ->
        accessors.getSupportType(this)

    getSupportPlacement: ->
        accessors.getSupportPlacement(this)

    getSupportThreshold: ->
        accessors.getSupportThreshold(this)

    getAdhesionEnabled: ->
        accessors.getAdhesionEnabled(this)

    getAdhesionType: ->
        accessors.getAdhesionType(this)

    getSkirtType: ->
        accessors.getSkirtType(this)

    getSkirtDistance: ->
        accessors.getSkirtDistance(this)

    getSkirtLineCount: ->
        accessors.getSkirtLineCount(this)

    getBrimDistance: ->
        accessors.getBrimDistance(this)

    getBrimLineCount: ->
        accessors.getBrimLineCount(this)

    getRaftMargin: ->
        accessors.getRaftMargin(this)

    getRaftBaseThickness: ->
        accessors.getRaftBaseThickness(this)

    getRaftInterfaceLayers: ->
        accessors.getRaftInterfaceLayers(this)

    getRaftInterfaceThickness: ->
        accessors.getRaftInterfaceThickness(this)

    getRaftAirGap: ->
        accessors.getRaftAirGap(this)

    getRaftLineSpacing: ->
        accessors.getRaftLineSpacing(this)

    getTestStrip: ->
        accessors.getTestStrip(this)

    getMetadata: ->
        accessors.getMetadata(this)

    getVerbose: ->
        accessors.getVerbose(this)

    getMetadataVersion: ->
        accessors.getMetadataVersion(this)

    getMetadataTimestamp: ->
        accessors.getMetadataTimestamp(this)

    getMetadataRepository: ->
        accessors.getMetadataRepository(this)

    getMetadataPrinter: ->
        accessors.getMetadataPrinter(this)

    getMetadataFilament: ->
        accessors.getMetadataFilament(this)

    getMetadataNozzleTemp: ->
        accessors.getMetadataNozzleTemp(this)

    getMetadataBedTemp: ->
        accessors.getMetadataBedTemp(this)

    getMetadataLayerHeight: ->
        accessors.getMetadataLayerHeight(this)

    getMetadataTotalLayers: ->
        accessors.getMetadataTotalLayers(this)

    getMetadataFilamentLength: ->
        accessors.getMetadataFilamentLength(this)

    getMetadataMaterialVolume: ->
        accessors.getMetadataMaterialVolume(this)

    getMetadataMaterialWeight: ->
        accessors.getMetadataMaterialWeight(this)

    getMetadataPrintTime: ->
        accessors.getMetadataPrintTime(this)

    getMetadataFlavor: ->
        accessors.getMetadataFlavor(this)

    getMetadataInfillDensity: ->
        accessors.getMetadataInfillDensity(this)

    getMetadataInfillPattern: ->
        accessors.getMetadataInfillPattern(this)

    getMetadataWallCount: ->
        accessors.getMetadataWallCount(this)

    getMetadataSupport: ->
        accessors.getMetadataSupport(this)

    getMetadataAdhesion: ->
        accessors.getMetadataAdhesion(this)

    getMetadataSpeeds: ->
        accessors.getMetadataSpeeds(this)

    getMetadataBoundingBox: ->
        accessors.getMetadataBoundingBox(this)

    getCoordinatePrecision: ->
        accessors.getCoordinatePrecision(this)

    getExtrusionPrecision: ->
        accessors.getExtrusionPrecision(this)

    getFeedratePrecision: ->
        accessors.getFeedratePrecision(this)

    getMeshPreprocessing: ->
        accessors.getMeshPreprocessing(this)

    getBuzzer: ->
        accessors.getBuzzer(this)

    getWipeNozzle: ->
        accessors.getWipeNozzle(this)

    getSmartWipeNozzle: ->
        accessors.getSmartWipeNozzle(this)

    getPositioningMode: ->
        accessors.getPositioningMode(this)

    getExtruderMode: ->
        accessors.getExtruderMode(this)

    getProgressCallback: ->
        accessors.getProgressCallback(this)

    getPrinter: ->
        accessors.getPrinter(this)

    getFilament: ->
        accessors.getFilament(this)

    getGcodeMetadata: (gcode = null) ->
        accessors.getGcodeMetadata(this, gcode)

    # Setter method delegates:

    setAutohome: (autohome = true) ->
        accessors.setAutohome(this, autohome)

    setWorkspacePlane: (plane = "XY") ->
        accessors.setWorkspacePlane(this, plane)

    setTimeUnit: (unit = "milliseconds") ->
        accessors.setTimeUnit(this, unit)

    setLengthUnit: (unit = "millimeters") ->
        accessors.setLengthUnit(this, unit)

    setSpeedUnit: (unit = "millimeterSecond") ->
        accessors.setSpeedUnit(this, unit)

    setTemperatureUnit: (unit = "celsius") ->
        accessors.setTemperatureUnit(this, unit)

    setAngleUnit: (unit = "degree") ->
        accessors.setAngleUnit(this, unit)

    setNozzleTemperature: (temp = 0) ->
        accessors.setNozzleTemperature(this, temp)

    setBedTemperature: (temp = 0) ->
        accessors.setBedTemperature(this, temp)

    setFanSpeed: (speed = 100) ->
        accessors.setFanSpeed(this, speed)

    setLayerHeight: (height = 0.2) ->
        accessors.setLayerHeight(this, height)

    setExtrusionMultiplier: (multiplier = 1.0) ->
        accessors.setExtrusionMultiplier(this, multiplier)

    setFilamentDiameter: (diameter = 1.75) ->
        accessors.setFilamentDiameter(this, diameter)

    setNozzleDiameter: (diameter = 0.4) ->
        accessors.setNozzleDiameter(this, diameter)

    setPerimeterSpeed: (speed = 30) ->
        accessors.setPerimeterSpeed(this, speed)

    setInfillSpeed: (speed = 60) ->
        accessors.setInfillSpeed(this, speed)

    setTravelSpeed: (speed = 120) ->
        accessors.setTravelSpeed(this, speed)

    setRetractionDistance: (distance = 1.0) ->
        accessors.setRetractionDistance(this, distance)

    setRetractionSpeed: (speed = 40) ->
        accessors.setRetractionSpeed(this, speed)

    setBuildPlateWidth: (width = 220) ->
        accessors.setBuildPlateWidth(this, width)

    setBuildPlateLength: (length = 220) ->
        accessors.setBuildPlateLength(this, length)

    setInfillDensity: (density = 20) ->
        accessors.setInfillDensity(this, density)

    setInfillPattern: (pattern = "hexagons") ->
        accessors.setInfillPattern(this, pattern)

    setInfillPatternCentering: (centering = "object") ->
        accessors.setInfillPatternCentering(this, centering)

    setShellSkinThickness: (thickness = 0.8) ->
        accessors.setShellSkinThickness(this, thickness)

    setShellWallThickness: (thickness = 0.8) ->
        accessors.setShellWallThickness(this, thickness)

    setExposureDetection: (enabled = false) ->
        accessors.setExposureDetection(this, enabled)

    setExposureDetectionResolution: (resolution = 961) ->
        accessors.setExposureDetectionResolution(this, resolution)

    setSupportEnabled: (enabled = false) ->
        accessors.setSupportEnabled(this, enabled)

    setSupportType: (type = "normal") ->
        accessors.setSupportType(this, type)

    setSupportPlacement: (placement = "buildPlate") ->
        accessors.setSupportPlacement(this, placement)

    setSupportThreshold: (angle = 55) ->
        accessors.setSupportThreshold(this, angle)

    setAdhesionEnabled: (enabled = false) ->
        accessors.setAdhesionEnabled(this, enabled)

    setAdhesionType: (type = "skirt") ->
        accessors.setAdhesionType(this, type)

    setSkirtType: (type = "circular") ->
        accessors.setSkirtType(this, type)

    setSkirtDistance: (distance = 5) ->
        accessors.setSkirtDistance(this, distance)

    setSkirtLineCount: (count = 3) ->
        accessors.setSkirtLineCount(this, count)

    setBrimDistance: (distance = 0) ->
        accessors.setBrimDistance(this, distance)

    setBrimLineCount: (count = 8) ->
        accessors.setBrimLineCount(this, count)

    setRaftMargin: (margin = 5) ->
        accessors.setRaftMargin(this, margin)

    setRaftBaseThickness: (thickness = 0.3) ->
        accessors.setRaftBaseThickness(this, thickness)

    setRaftInterfaceLayers: (layers = 2) ->
        accessors.setRaftInterfaceLayers(this, layers)

    setRaftInterfaceThickness: (thickness = 0.2) ->
        accessors.setRaftInterfaceThickness(this, thickness)

    setRaftAirGap: (gap = 0.2) ->
        accessors.setRaftAirGap(this, gap)

    setRaftLineSpacing: (spacing = 2) ->
        accessors.setRaftLineSpacing(this, spacing)

    setTestStrip: (testStrip = false) ->
        accessors.setTestStrip(this, testStrip)

    setMetadata: (metadata = true) ->
        accessors.setMetadata(this, metadata)

    setVerbose: (verbose = true) ->
        accessors.setVerbose(this, verbose)

    setMetadataVersion: (enabled = true) ->
        accessors.setMetadataVersion(this, enabled)

    setMetadataTimestamp: (enabled = true) ->
        accessors.setMetadataTimestamp(this, enabled)

    setMetadataRepository: (enabled = true) ->
        accessors.setMetadataRepository(this, enabled)

    setMetadataPrinter: (enabled = true) ->
        accessors.setMetadataPrinter(this, enabled)

    setMetadataFilament: (enabled = true) ->
        accessors.setMetadataFilament(this, enabled)

    setMetadataNozzleTemp: (enabled = true) ->
        accessors.setMetadataNozzleTemp(this, enabled)

    setMetadataBedTemp: (enabled = true) ->
        accessors.setMetadataBedTemp(this, enabled)

    setMetadataLayerHeight: (enabled = true) ->
        accessors.setMetadataLayerHeight(this, enabled)

    setMetadataTotalLayers: (enabled = true) ->
        accessors.setMetadataTotalLayers(this, enabled)

    setMetadataFilamentLength: (enabled = true) ->
        accessors.setMetadataFilamentLength(this, enabled)

    setMetadataMaterialVolume: (enabled = true) ->
        accessors.setMetadataMaterialVolume(this, enabled)

    setMetadataMaterialWeight: (enabled = true) ->
        accessors.setMetadataMaterialWeight(this, enabled)

    setMetadataPrintTime: (enabled = true) ->
        accessors.setMetadataPrintTime(this, enabled)

    setMetadataFlavor: (enabled = true) ->
        accessors.setMetadataFlavor(this, enabled)

    setMetadataInfillDensity: (enabled = true) ->
        accessors.setMetadataInfillDensity(this, enabled)

    setMetadataInfillPattern: (enabled = true) ->
        accessors.setMetadataInfillPattern(this, enabled)

    setMetadataWallCount: (enabled = true) ->
        accessors.setMetadataWallCount(this, enabled)

    setMetadataSupport: (enabled = true) ->
        accessors.setMetadataSupport(this, enabled)

    setMetadataAdhesion: (enabled = true) ->
        accessors.setMetadataAdhesion(this, enabled)

    setMetadataSpeeds: (enabled = true) ->
        accessors.setMetadataSpeeds(this, enabled)

    setMetadataBoundingBox: (enabled = true) ->
        accessors.setMetadataBoundingBox(this, enabled)

    setCoordinatePrecision: (precision = 3) ->
        accessors.setCoordinatePrecision(this, precision)

    setExtrusionPrecision: (precision = 5) ->
        accessors.setExtrusionPrecision(this, precision)

    setFeedratePrecision: (precision = 0) ->
        accessors.setFeedratePrecision(this, precision)

    setMeshPreprocessing: (enabled = false) ->
        accessors.setMeshPreprocessing(this, enabled)

    setBuzzer: (buzzer = true) ->
        accessors.setBuzzer(this, buzzer)

    setWipeNozzle: (wipeNozzle = true) ->
        accessors.setWipeNozzle(this, wipeNozzle)

    setSmartWipeNozzle: (smartWipeNozzle = true) ->
        accessors.setSmartWipeNozzle(this, smartWipeNozzle)

    setPositioningMode: (mode = "absolute") ->
        accessors.setPositioningMode(this, mode)

    setExtruderMode: (mode = "absolute") ->
        accessors.setExtruderMode(this, mode)

    setProgressCallback: (callback = null) ->
        accessors.setProgressCallback(this, callback)

    setPrinter: (printer) ->
        accessors.setPrinter(this, printer)

    setFilament: (filament) ->
        accessors.setFilament(this, filament)

    # Coder method delegates:

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

    codePositioningMode: (absolute) ->
        coders.codePositioningMode(this, absolute)

    codeExtruderMode: (absolute) ->
        coders.codeExtruderMode(this, absolute)

    codeSetPosition: (x, y, z, extrude) ->
        coders.codeSetPosition(this, x, y, z, extrude)

    codeDisableSteppers: (x, y, z, e) ->
        coders.codeDisableSteppers(this, x, y, z, e)

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

    codeMetadata: ->
        coders.codeMetadata(this)

    codeTestStrip: (length, width, height) ->
        coders.codeTestStrip(this, length, width, height)

    codePrePrint: ->
        coders.codePrePrint(this)

    codePostPrint: ->
        coders.codePostPrint(this)

    # Helper method delegates:

    isWithinBounds: (x, y) ->
        bounds.isWithinBounds(this, x, y)

    calculateExtrusion: (distance, lineWidth) ->
        extrusion.calculateExtrusion(this, distance, lineWidth)

    # Main slicing method delegate:

    slice: (scene = {}) ->
        slicer.slice(this, scene)

# Export the class for Node.js
if typeof module isnt 'undefined' and module.exports

    module.exports = Polyslice

# Export for browser environments.
if typeof window isnt 'undefined'

    window.Polyslice = Polyslice
