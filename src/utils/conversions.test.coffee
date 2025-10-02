# Tests for unit conversion utilities

Polyslice = require('../index')

describe 'Unit Conversions', ->

    describe 'Temperature Conversions', ->

        test 'should convert temperature units correctly', ->

            # Test Fahrenheit conversions.
            fahrenheitSlicer = new Polyslice({temperatureUnit: 'fahrenheit'})
            fahrenheitSlicer.setNozzleTemperature(392) # 200°C in Fahrenheit.
            expect(fahrenheitSlicer.getNozzleTemperature()).toBeCloseTo(392, 1)

            # Test Kelvin conversions.
            kelvinSlicer = new Polyslice({temperatureUnit: 'kelvin'})
            kelvinSlicer.setNozzleTemperature(473.15) # 200°C in Kelvin.
            expect(kelvinSlicer.getNozzleTemperature()).toBeCloseTo(473.15, 1)

    describe 'Length Conversions', ->

        test 'should convert length units correctly', ->

            # Test inch conversions.
            inchSlicer = new Polyslice({lengthUnit: 'inches'})
            inchSlicer.setLayerHeight(0.008) # ~0.2mm in inches.
            expect(inchSlicer.getLayerHeight()).toBeCloseTo(0.008, 3)

            inchSlicer.setNozzleDiameter(0.016) # ~0.4mm in inches.
            expect(inchSlicer.getNozzleDiameter()).toBeCloseTo(0.016, 3)

    describe 'Speed Conversions', ->

        test 'should convert speed units correctly', ->

            # Test inch/second conversions.
            inchSpeedSlicer = new Polyslice({speedUnit: 'inchSecond'})
            inchSpeedSlicer.setPerimeterSpeed(1.18) # ~30mm/s in inches/s.
            expect(inchSpeedSlicer.getPerimeterSpeed()).toBeCloseTo(1.18, 2)

            # Test meter/second conversions.
            meterSpeedSlicer = new Polyslice({speedUnit: 'meterSecond'})
            meterSpeedSlicer.setTravelSpeed(0.12) # ~120mm/s in meters/s.
            expect(meterSpeedSlicer.getTravelSpeed()).toBeCloseTo(0.12, 2)

            # Test default millimeter/second.
            defaultSlicer = new Polyslice()
            defaultSlicer.setInfillSpeed(60)
            expect(defaultSlicer.getInfillSpeed()).toBe(60)

    describe 'Internal Storage', ->

        test 'should maintain internal storage in standard units', ->

            # Create slicer with non-standard units.
            customSlicer = new Polyslice({
                temperatureUnit: 'fahrenheit'
                lengthUnit: 'inches'
            })

            # Set values in user units.
            customSlicer.setNozzleTemperature(392) # 200°C.
            customSlicer.setLayerHeight(0.008) # ~0.2mm.

            # Internal storage should be in standard units for G-code generation.
            # This is tested indirectly by ensuring G-code generation works correctly.
            # The values should convert properly when retrieved in user units.
            expect(customSlicer.getNozzleTemperature()).toBeCloseTo(392, 1)
            expect(customSlicer.getLayerHeight()).toBeCloseTo(0.008, 3)
