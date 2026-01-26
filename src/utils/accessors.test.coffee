# Tests for getter and setter methods

Polyslice = require('../index')

describe 'Accessors (Getters and Setters)', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Basic Settings Accessors', ->

        test 'should set and get workspace plane', ->

            slicer.setWorkspacePlane('XZ')
            expect(slicer.getWorkspacePlane()).toBe('XZ')

            slicer.setWorkspacePlane('YZ')
            expect(slicer.getWorkspacePlane()).toBe('YZ')

            # Should ignore invalid values.
            slicer.setWorkspacePlane('invalid')
            expect(slicer.getWorkspacePlane()).toBe('YZ') # unchanged.

        test 'should set and get time unit', ->

            slicer.setTimeUnit('seconds')
            expect(slicer.getTimeUnit()).toBe('seconds')

            slicer.setTimeUnit('milliseconds')
            expect(slicer.getTimeUnit()).toBe('milliseconds')

            # Should ignore invalid values.
            slicer.setTimeUnit('invalid')
            expect(slicer.getTimeUnit()).toBe('milliseconds') # unchanged.

        test 'should set and get angle unit', ->

            expect(slicer.getAngleUnit()).toBe('degree')

            slicer.setAngleUnit('radian')
            expect(slicer.getAngleUnit()).toBe('radian')

            slicer.setAngleUnit('gradian')
            expect(slicer.getAngleUnit()).toBe('gradian')

            slicer.setAngleUnit('degree')
            expect(slicer.getAngleUnit()).toBe('degree')

            # Should ignore invalid values.
            slicer.setAngleUnit('invalid')
            expect(slicer.getAngleUnit()).toBe('degree') # unchanged.

    describe 'Temperature Accessors', ->

        test 'should set and get temperatures', ->

            slicer.setNozzleTemperature(210)
            expect(slicer.getNozzleTemperature()).toBe(210)

            slicer.setBedTemperature(65)
            expect(slicer.getBedTemperature()).toBe(65)

            # Should ignore negative values.
            slicer.setNozzleTemperature(-10)
            expect(slicer.getNozzleTemperature()).toBe(210) # unchanged.

        test 'should set and get fan speed', ->

            slicer.setFanSpeed(50)
            expect(slicer.getFanSpeed()).toBe(50)

            # Should ignore values outside range.
            slicer.setFanSpeed(-10)
            expect(slicer.getFanSpeed()).toBe(50) # unchanged.

            slicer.setFanSpeed(150)
            expect(slicer.getFanSpeed()).toBe(50) # unchanged.

    describe 'Extrusion Accessors', ->

        test 'should set and get layer height', ->

            slicer.setLayerHeight(0.15)
            expect(slicer.getLayerHeight()).toBe(0.15)

            slicer.setLayerHeight(0.3)
            expect(slicer.getLayerHeight()).toBe(0.3)

            # Should ignore zero and negative values.
            slicer.setLayerHeight(0)
            expect(slicer.getLayerHeight()).toBe(0.3) # unchanged.

            slicer.setLayerHeight(-0.1)
            expect(slicer.getLayerHeight()).toBe(0.3) # unchanged.

        test 'should set and get extrusion multiplier', ->

            slicer.setExtrusionMultiplier(0.9)
            expect(slicer.getExtrusionMultiplier()).toBe(0.9)

            slicer.setExtrusionMultiplier(1.2)
            expect(slicer.getExtrusionMultiplier()).toBe(1.2)

            # Should ignore zero and negative values.
            slicer.setExtrusionMultiplier(0)
            expect(slicer.getExtrusionMultiplier()).toBe(1.2) # unchanged.

            slicer.setExtrusionMultiplier(-0.5)
            expect(slicer.getExtrusionMultiplier()).toBe(1.2) # unchanged.

        test 'should set and get filament diameter', ->

            slicer.setFilamentDiameter(3.0)
            expect(slicer.getFilamentDiameter()).toBe(3.0)

            slicer.setFilamentDiameter(2.85)
            expect(slicer.getFilamentDiameter()).toBe(2.85)

            # Should ignore zero and negative values.
            slicer.setFilamentDiameter(0)
            expect(slicer.getFilamentDiameter()).toBe(2.85) # unchanged.

        test 'should set and get nozzle diameter', ->

            slicer.setNozzleDiameter(0.6)
            expect(slicer.getNozzleDiameter()).toBe(0.6)

            slicer.setNozzleDiameter(0.8)
            expect(slicer.getNozzleDiameter()).toBe(0.8)

            # Should ignore zero and negative values.
            slicer.setNozzleDiameter(0)
            expect(slicer.getNozzleDiameter()).toBe(0.8) # unchanged.

    describe 'Speed Accessors', ->

        test 'should set and get speed settings', ->

            # Test perimeter speed.
            slicer.setPerimeterSpeed(25)
            expect(slicer.getPerimeterSpeed()).toBe(25)

            # Test infill speed.
            slicer.setInfillSpeed(80)
            expect(slicer.getInfillSpeed()).toBe(80)

            # Test travel speed.
            slicer.setTravelSpeed(200)
            expect(slicer.getTravelSpeed()).toBe(200)

            # Should ignore zero and negative values.
            slicer.setPerimeterSpeed(0)
            expect(slicer.getPerimeterSpeed()).toBe(25) # unchanged.

    describe 'Retraction Accessors', ->

        test 'should set and get retraction settings', ->

            slicer.setRetractionDistance(1.5)
            expect(slicer.getRetractionDistance()).toBe(1.5)

            slicer.setRetractionSpeed(60)
            expect(slicer.getRetractionSpeed()).toBe(60)

            # Should allow zero retraction distance.
            slicer.setRetractionDistance(0)
            expect(slicer.getRetractionDistance()).toBe(0)

            # Should ignore negative values.
            slicer.setRetractionDistance(-1)
            expect(slicer.getRetractionDistance()).toBe(0) # unchanged.

    describe 'Build Plate Accessors', ->

        test 'should set and get build plate dimensions', ->

            slicer.setBuildPlateWidth(300)
            expect(slicer.getBuildPlateWidth()).toBe(300)

            slicer.setBuildPlateLength(250)
            expect(slicer.getBuildPlateLength()).toBe(250)

            # Should ignore zero and negative values.
            slicer.setBuildPlateWidth(0)
            expect(slicer.getBuildPlateWidth()).toBe(300) # unchanged.

    describe 'Advanced Slicing Settings Accessors', ->

        test 'should set and get infill settings', ->

            slicer.setInfillDensity(25)
            expect(slicer.getInfillDensity()).toBe(25)

            slicer.setInfillPattern('gyroid')
            expect(slicer.getInfillPattern()).toBe('gyroid')

            slicer.setInfillPattern('honeycomb')
            expect(slicer.getInfillPattern()).toBe('honeycomb')

            # Test invalid pattern (should not change).
            slicer.setInfillPattern('invalid')
            expect(slicer.getInfillPattern()).toBe('honeycomb')

            # Test density boundaries.
            slicer.setInfillDensity(0)
            expect(slicer.getInfillDensity()).toBe(0)

            slicer.setInfillDensity(100)
            expect(slicer.getInfillDensity()).toBe(100)

        test 'should set and get shell thickness settings', ->

            slicer.setShellSkinThickness(1.2)
            expect(slicer.getShellSkinThickness()).toBe(1.2)

            slicer.setShellWallThickness(1.0)
            expect(slicer.getShellWallThickness()).toBe(1.0)

            # Test with inches.
            inchSlicer = new Polyslice({lengthUnit: 'inches'})
            inchSlicer.setShellSkinThickness(0.047) # ~1.2mm.
            expect(inchSlicer.getShellSkinThickness()).toBeCloseTo(0.047, 3)

        test 'should set and get exposure detection setting', ->

            # Default should be true.
            expect(slicer.getExposureDetection()).toBe(true)

            # Disable exposure detection.
            slicer.setExposureDetection(false)
            expect(slicer.getExposureDetection()).toBe(false)

            # Enable exposure detection.
            slicer.setExposureDetection(true)
            expect(slicer.getExposureDetection()).toBe(true)

        test 'should set and get exposure detection resolution', ->

            # Default should be 961 (31x31 grid).
            expect(slicer.getExposureDetectionResolution()).toBe(961)

            # Set to 400 (20x20 grid).
            slicer.setExposureDetectionResolution(400)
            expect(slicer.getExposureDetectionResolution()).toBe(400)

            # Set to 1600 (40x40 grid).
            slicer.setExposureDetectionResolution(1600)
            expect(slicer.getExposureDetectionResolution()).toBe(1600)

        test 'should set and get support settings', ->

            expect(slicer.getSupportEnabled()).toBe(false)

            slicer.setSupportEnabled(true)
            expect(slicer.getSupportEnabled()).toBe(true)

            slicer.setSupportType('tree')
            expect(slicer.getSupportType()).toBe('tree')

            slicer.setSupportPlacement('everywhere')
            expect(slicer.getSupportPlacement()).toBe('everywhere')

            # Test invalid type (should not change).
            slicer.setSupportType('invalid')
            expect(slicer.getSupportType()).toBe('tree')

            # Test support threshold (default 55 degrees).
            expect(slicer.getSupportThreshold()).toBe(55)

            slicer.setSupportThreshold(60)
            expect(slicer.getSupportThreshold()).toBe(60)

            slicer.setSupportThreshold(30)
            expect(slicer.getSupportThreshold()).toBe(30)

            # Should ignore values outside valid range (0-90).
            slicer.setSupportThreshold(-10)
            expect(slicer.getSupportThreshold()).toBe(30) # unchanged.

            slicer.setSupportThreshold(100)
            expect(slicer.getSupportThreshold()).toBe(30) # unchanged.

            # Test with radians.
            radianSlicer = new Polyslice({angleUnit: 'radian'})
            radianSlicer.setSupportThreshold(Math.PI / 4) # 45 degrees.
            expect(radianSlicer.getSupportThreshold()).toBeCloseTo(Math.PI / 4, 3)

        test 'should set and get adhesion settings', ->

            expect(slicer.getAdhesionEnabled()).toBe(false)

            slicer.setAdhesionEnabled(true)
            expect(slicer.getAdhesionEnabled()).toBe(true)

            slicer.setAdhesionType('brim')
            expect(slicer.getAdhesionType()).toBe('brim')

            slicer.setAdhesionType('raft')
            expect(slicer.getAdhesionType()).toBe('raft')

            # Test invalid type (should not change).
            slicer.setAdhesionType('invalid')
            expect(slicer.getAdhesionType()).toBe('raft')

            # Test skirt distance (default 5mm).
            expect(slicer.getSkirtDistance()).toBe(5)

            slicer.setSkirtDistance(10)
            expect(slicer.getSkirtDistance()).toBe(10)

            slicer.setSkirtDistance(8)
            expect(slicer.getSkirtDistance()).toBe(8)

            # Should ignore negative values.
            slicer.setSkirtDistance(-5)
            expect(slicer.getSkirtDistance()).toBe(8) # unchanged.

            # Test skirt line count (default 3).
            expect(slicer.getSkirtLineCount()).toBe(3)

            slicer.setSkirtLineCount(5)
            expect(slicer.getSkirtLineCount()).toBe(5)

            slicer.setSkirtLineCount(2)
            expect(slicer.getSkirtLineCount()).toBe(2)

            # Should ignore negative values.
            slicer.setSkirtLineCount(-1)
            expect(slicer.getSkirtLineCount()).toBe(2) # unchanged.

            # Test brim distance (default 0mm).
            expect(slicer.getBrimDistance()).toBe(0)

            slicer.setBrimDistance(2)
            expect(slicer.getBrimDistance()).toBe(2)

            slicer.setBrimDistance(1)
            expect(slicer.getBrimDistance()).toBe(1)

            # Should ignore negative values.
            slicer.setBrimDistance(-1)
            expect(slicer.getBrimDistance()).toBe(1) # unchanged.

            # Test brim line count (default 8).
            expect(slicer.getBrimLineCount()).toBe(8)

            slicer.setBrimLineCount(10)
            expect(slicer.getBrimLineCount()).toBe(10)

            slicer.setBrimLineCount(5)
            expect(slicer.getBrimLineCount()).toBe(5)

            # Should ignore negative values.
            slicer.setBrimLineCount(-1)
            expect(slicer.getBrimLineCount()).toBe(5) # unchanged.

        test 'should set and get raft settings', ->

            # Test raft margin (default 5mm).
            expect(slicer.getRaftMargin()).toBe(5)

            slicer.setRaftMargin(8)
            expect(slicer.getRaftMargin()).toBe(8)

            slicer.setRaftMargin(3)
            expect(slicer.getRaftMargin()).toBe(3)

            # Should ignore negative values.
            slicer.setRaftMargin(-2)
            expect(slicer.getRaftMargin()).toBe(3) # unchanged.

            # Test raft base thickness (default 0.3mm).
            expect(slicer.getRaftBaseThickness()).toBe(0.3)

            slicer.setRaftBaseThickness(0.4)
            expect(slicer.getRaftBaseThickness()).toBe(0.4)

            slicer.setRaftBaseThickness(0.25)
            expect(slicer.getRaftBaseThickness()).toBe(0.25)

            # Should ignore zero and negative values.
            slicer.setRaftBaseThickness(0)
            expect(slicer.getRaftBaseThickness()).toBe(0.25) # unchanged.

            slicer.setRaftBaseThickness(-0.1)
            expect(slicer.getRaftBaseThickness()).toBe(0.25) # unchanged.

            # Test raft interface layers (default 2).
            expect(slicer.getRaftInterfaceLayers()).toBe(2)

            slicer.setRaftInterfaceLayers(3)
            expect(slicer.getRaftInterfaceLayers()).toBe(3)

            slicer.setRaftInterfaceLayers(1)
            expect(slicer.getRaftInterfaceLayers()).toBe(1)

            # Should ignore negative values.
            slicer.setRaftInterfaceLayers(-1)
            expect(slicer.getRaftInterfaceLayers()).toBe(1) # unchanged.

            # Test raft interface thickness (default 0.2mm).
            expect(slicer.getRaftInterfaceThickness()).toBe(0.2)

            slicer.setRaftInterfaceThickness(0.25)
            expect(slicer.getRaftInterfaceThickness()).toBe(0.25)

            slicer.setRaftInterfaceThickness(0.15)
            expect(slicer.getRaftInterfaceThickness()).toBe(0.15)

            # Should ignore zero and negative values.
            slicer.setRaftInterfaceThickness(0)
            expect(slicer.getRaftInterfaceThickness()).toBe(0.15) # unchanged.

            # Test raft air gap (default 0.2mm).
            expect(slicer.getRaftAirGap()).toBe(0.2)

            slicer.setRaftAirGap(0.3)
            expect(slicer.getRaftAirGap()).toBe(0.3)

            slicer.setRaftAirGap(0.1)
            expect(slicer.getRaftAirGap()).toBe(0.1)

            # Should ignore negative values (but allow 0 for no gap).
            slicer.setRaftAirGap(-0.1)
            expect(slicer.getRaftAirGap()).toBe(0.1) # unchanged.

            # Test raft line spacing (default 2mm).
            expect(slicer.getRaftLineSpacing()).toBe(2)

            slicer.setRaftLineSpacing(3)
            expect(slicer.getRaftLineSpacing()).toBe(3)

            slicer.setRaftLineSpacing(1.5)
            expect(slicer.getRaftLineSpacing()).toBe(1.5)

            # Should ignore zero and negative values.
            slicer.setRaftLineSpacing(0)
            expect(slicer.getRaftLineSpacing()).toBe(1.5) # unchanged.

            slicer.setRaftLineSpacing(-1)
            expect(slicer.getRaftLineSpacing()).toBe(1.5) # unchanged.

        test 'should support all infill patterns', ->

            patterns = ['grid', 'lines', 'triangles', 'cubic', 'gyroid', 'honeycomb']

            for pattern in patterns
                slicer.setInfillPattern(pattern)
                expect(slicer.getInfillPattern()).toBe(pattern)

            return # Explicitly return undefined for Jest.

        test 'should set and get test strip setting', ->

            # Test default.
            expect(slicer.getTestStrip()).toBe(false)

            # Test setting test strip.
            slicer.setTestStrip(true)
            expect(slicer.getTestStrip()).toBe(true)

            slicer.setTestStrip(false)
            expect(slicer.getTestStrip()).toBe(false)

            # Test chaining.
            result = slicer.setTestStrip(true)
            expect(result).toBe(slicer)
            expect(slicer.getTestStrip()).toBe(true)

    describe 'G-code Generation Settings', ->

        test 'should set and get metadata setting', ->

            expect(slicer.getMetadata()).toBe(true) # default.
            slicer.setMetadata(false)
            expect(slicer.getMetadata()).toBe(false)

            slicer.setMetadata(true)
            expect(slicer.getMetadata()).toBe(true)

        test 'should set and get verbose setting', ->

            expect(slicer.getVerbose()).toBe(true) # default.
            slicer.setVerbose(false)
            expect(slicer.getVerbose()).toBe(false)

            slicer.setVerbose(true)
            expect(slicer.getVerbose()).toBe(true)

        test 'should set and get metadata field settings', ->

            # Test all metadata field settings with defaults.
            expect(slicer.getMetadataVersion()).toBe(true)
            expect(slicer.getMetadataTimestamp()).toBe(true)
            expect(slicer.getMetadataRepository()).toBe(true)
            expect(slicer.getMetadataPrinter()).toBe(true)
            expect(slicer.getMetadataFilament()).toBe(true)
            expect(slicer.getMetadataNozzleTemp()).toBe(true)
            expect(slicer.getMetadataBedTemp()).toBe(true)
            expect(slicer.getMetadataLayerHeight()).toBe(true)
            expect(slicer.getMetadataTotalLayers()).toBe(true)
            expect(slicer.getMetadataFilamentLength()).toBe(true)
            expect(slicer.getMetadataMaterialVolume()).toBe(true)
            expect(slicer.getMetadataMaterialWeight()).toBe(true)
            expect(slicer.getMetadataPrintTime()).toBe(true)

            # Test setting to false.
            slicer.setMetadataVersion(false)
            slicer.setMetadataTimestamp(false)
            slicer.setMetadataRepository(false)
            slicer.setMetadataPrinter(false)
            slicer.setMetadataFilament(false)
            slicer.setMetadataNozzleTemp(false)
            slicer.setMetadataBedTemp(false)
            slicer.setMetadataLayerHeight(false)
            slicer.setMetadataTotalLayers(false)
            slicer.setMetadataFilamentLength(false)
            slicer.setMetadataMaterialVolume(false)
            slicer.setMetadataMaterialWeight(false)
            slicer.setMetadataPrintTime(false)

            expect(slicer.getMetadataVersion()).toBe(false)
            expect(slicer.getMetadataTimestamp()).toBe(false)
            expect(slicer.getMetadataRepository()).toBe(false)
            expect(slicer.getMetadataPrinter()).toBe(false)
            expect(slicer.getMetadataFilament()).toBe(false)
            expect(slicer.getMetadataNozzleTemp()).toBe(false)
            expect(slicer.getMetadataBedTemp()).toBe(false)
            expect(slicer.getMetadataLayerHeight()).toBe(false)
            expect(slicer.getMetadataTotalLayers()).toBe(false)
            expect(slicer.getMetadataFilamentLength()).toBe(false)
            expect(slicer.getMetadataMaterialVolume()).toBe(false)
            expect(slicer.getMetadataMaterialWeight()).toBe(false)
            expect(slicer.getMetadataPrintTime()).toBe(false)

            # Test setting back to true.
            slicer.setMetadataVersion(true)
            slicer.setMetadataTimestamp(true)
            slicer.setMetadataRepository(true)
            slicer.setMetadataPrinter(true)
            slicer.setMetadataFilament(true)
            slicer.setMetadataNozzleTemp(true)
            slicer.setMetadataBedTemp(true)
            slicer.setMetadataLayerHeight(true)
            slicer.setMetadataTotalLayers(true)
            slicer.setMetadataFilamentLength(true)
            slicer.setMetadataMaterialVolume(true)
            slicer.setMetadataMaterialWeight(true)
            slicer.setMetadataPrintTime(true)

            expect(slicer.getMetadataVersion()).toBe(true)
            expect(slicer.getMetadataTimestamp()).toBe(true)
            expect(slicer.getMetadataRepository()).toBe(true)
            expect(slicer.getMetadataPrinter()).toBe(true)
            expect(slicer.getMetadataFilament()).toBe(true)
            expect(slicer.getMetadataNozzleTemp()).toBe(true)
            expect(slicer.getMetadataBedTemp()).toBe(true)
            expect(slicer.getMetadataLayerHeight()).toBe(true)
            expect(slicer.getMetadataTotalLayers()).toBe(true)
            expect(slicer.getMetadataFilamentLength()).toBe(true)
            expect(slicer.getMetadataMaterialVolume()).toBe(true)
            expect(slicer.getMetadataMaterialWeight()).toBe(true)
            expect(slicer.getMetadataPrintTime()).toBe(true)

        test 'should support method chaining for metadata field setters', ->

            result = slicer
                .setMetadataVersion(false)
                .setMetadataTimestamp(false)
                .setMetadataRepository(false)
                .setMetadataPrinter(false)
                .setMetadataFilament(false)
                .setMetadataNozzleTemp(false)
                .setMetadataBedTemp(false)
                .setMetadataLayerHeight(false)
                .setMetadataTotalLayers(false)
                .setMetadataFilamentLength(false)
                .setMetadataMaterialVolume(false)
                .setMetadataMaterialWeight(false)
                .setMetadataPrintTime(false)

            expect(result).toBe(slicer)
            expect(slicer.getMetadataVersion()).toBe(false)
            expect(slicer.getMetadataTimestamp()).toBe(false)
            expect(slicer.getMetadataRepository()).toBe(false)
            expect(slicer.getMetadataPrinter()).toBe(false)
            expect(slicer.getMetadataFilament()).toBe(false)
            expect(slicer.getMetadataNozzleTemp()).toBe(false)
            expect(slicer.getMetadataBedTemp()).toBe(false)
            expect(slicer.getMetadataLayerHeight()).toBe(false)
            expect(slicer.getMetadataTotalLayers()).toBe(false)
            expect(slicer.getMetadataFilamentLength()).toBe(false)
            expect(slicer.getMetadataMaterialVolume()).toBe(false)
            expect(slicer.getMetadataMaterialWeight()).toBe(false)
            expect(slicer.getMetadataPrintTime()).toBe(false)
            expect(slicer.getVerbose()).toBe(true)

        test 'should set and get coordinate precision', ->

            expect(slicer.getCoordinatePrecision()).toBe(3) # default.
            slicer.setCoordinatePrecision(2)
            expect(slicer.getCoordinatePrecision()).toBe(2)

            slicer.setCoordinatePrecision(5)
            expect(slicer.getCoordinatePrecision()).toBe(5)

            # Should validate range 0-10.
            slicer.setCoordinatePrecision(15)
            expect(slicer.getCoordinatePrecision()).toBe(5) # unchanged.

            slicer.setCoordinatePrecision(-1)
            expect(slicer.getCoordinatePrecision()).toBe(5) # unchanged.

        test 'should set and get extrusion precision', ->

            expect(slicer.getExtrusionPrecision()).toBe(5) # default.
            slicer.setExtrusionPrecision(3)
            expect(slicer.getExtrusionPrecision()).toBe(3)

            slicer.setExtrusionPrecision(7)
            expect(slicer.getExtrusionPrecision()).toBe(7)

            # Should validate range 0-10.
            slicer.setExtrusionPrecision(15)
            expect(slicer.getExtrusionPrecision()).toBe(7) # unchanged.

        test 'should set and get feedrate precision', ->

            expect(slicer.getFeedratePrecision()).toBe(0) # default.
            slicer.setFeedratePrecision(2)
            expect(slicer.getFeedratePrecision()).toBe(2)

            slicer.setFeedratePrecision(1)
            expect(slicer.getFeedratePrecision()).toBe(1)

            # Should validate range 0-10.
            slicer.setFeedratePrecision(15)
            expect(slicer.getFeedratePrecision()).toBe(1) # unchanged.

    describe 'Mesh Preprocessing Settings', ->

        test 'should set and get mesh preprocessing setting', ->

            expect(slicer.getMeshPreprocessing()).toBe(false) # default.
            slicer.setMeshPreprocessing(true)
            expect(slicer.getMeshPreprocessing()).toBe(true)

            slicer.setMeshPreprocessing(false)
            expect(slicer.getMeshPreprocessing()).toBe(false)

    describe 'Post-Print Settings', ->

        test 'should set and get buzzer setting', ->

            expect(slicer.getBuzzer()).toBe(true) # default.
            slicer.setBuzzer(false)
            expect(slicer.getBuzzer()).toBe(false)

            slicer.setBuzzer(true)
            expect(slicer.getBuzzer()).toBe(true)

        test 'should set and get wipe nozzle setting', ->

            expect(slicer.getWipeNozzle()).toBe(true) # default.
            slicer.setWipeNozzle(false)
            expect(slicer.getWipeNozzle()).toBe(false)

            slicer.setWipeNozzle(true)
            expect(slicer.getWipeNozzle()).toBe(true)

        test 'should set and get smart wipe nozzle setting', ->

            expect(slicer.getSmartWipeNozzle()).toBe(true) # default.
            slicer.setSmartWipeNozzle(false)
            expect(slicer.getSmartWipeNozzle()).toBe(false)

            slicer.setSmartWipeNozzle(true)
            expect(slicer.getSmartWipeNozzle()).toBe(true)

    describe 'Positioning Mode Settings', ->

        test 'should set and get positioning mode', ->

            expect(slicer.getPositioningMode()).toBe('absolute') # default.
            slicer.setPositioningMode('relative')
            expect(slicer.getPositioningMode()).toBe('relative')

            slicer.setPositioningMode('absolute')
            expect(slicer.getPositioningMode()).toBe('absolute')

            # Should ignore invalid values.
            slicer.setPositioningMode('invalid')
            expect(slicer.getPositioningMode()).toBe('absolute') # unchanged.

        test 'should set and get extruder mode', ->

            expect(slicer.getExtruderMode()).toBe('absolute') # default.
            slicer.setExtruderMode('relative')
            expect(slicer.getExtruderMode()).toBe('relative')

            slicer.setExtruderMode('absolute')
            expect(slicer.getExtruderMode()).toBe('absolute')

            # Should ignore invalid values.
            slicer.setExtruderMode('invalid')
            expect(slicer.getExtruderMode()).toBe('absolute') # unchanged.

    describe 'Configuration Object Accessors', ->

        Printer = require('../config/printer/printer')
        Filament = require('../config/filament/filament')

        test 'should set and get printer', ->

            printer = new Printer('Ender3')
            slicer.setPrinter(printer)

            expect(slicer.getPrinter()).toBe(printer)
            expect(slicer.getBuildPlateWidth()).toBe(220)
            expect(slicer.getBuildPlateLength()).toBe(220)
            expect(slicer.getNozzleDiameter()).toBe(0.4)

        test 'should set and get filament', ->

            filament = new Filament('GenericPLA')
            slicer.setFilament(filament)

            expect(slicer.getFilament()).toBe(filament)
            expect(slicer.getNozzleTemperature()).toBe(200)
            expect(slicer.getBedTemperature()).toBe(60)
