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

            # Default should be 2500 (50x50 grid).
            expect(slicer.getExposureDetectionResolution()).toBe(2500)

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

            # Test support threshold (default 45 degrees).
            expect(slicer.getSupportThreshold()).toBe(45)

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

        test 'should support all infill patterns', ->

            patterns = ['grid', 'lines', 'triangles', 'cubic', 'gyroid', 'honeycomb']

            for pattern in patterns
                slicer.setInfillPattern(pattern)
                expect(slicer.getInfillPattern()).toBe(pattern)

            return # Explicitly return undefined for Jest.

        test 'should set and get test strip and outline settings', ->

            # Test defaults.
            expect(slicer.getTestStrip()).toBe(false)
            expect(slicer.getOutline()).toBe(true)

            # Test setting test strip.
            slicer.setTestStrip(true)
            expect(slicer.getTestStrip()).toBe(true)

            slicer.setTestStrip(false)
            expect(slicer.getTestStrip()).toBe(false)

            # Test setting outline.
            slicer.setOutline(false)
            expect(slicer.getOutline()).toBe(false)

            slicer.setOutline(true)
            expect(slicer.getOutline()).toBe(true)

            # Test chaining.
            result = slicer.setTestStrip(true).setOutline(false)
            expect(result).toBe(slicer)
            expect(slicer.getTestStrip()).toBe(true)
            expect(slicer.getOutline()).toBe(false)
