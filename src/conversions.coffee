# Unit conversion utilities for Polyslice
# All conversions use @jgphilpott/polyconvert library

convert = require('@jgphilpott/polyconvert')

# Export conversion helper functions
module.exports =

    # Convert user input to internal storage units
    convertTemperatureToInternal: (temp, temperatureUnit) ->

        return 0 if typeof temp isnt "number"

        switch temperatureUnit
            when "fahrenheit" then convert.temperature.fahrenheit.celsius(temp)
            when "kelvin" then convert.temperature.kelvin.celsius(temp)
            else temp # Already celsius or invalid unit

    convertLengthToInternal: (length, lengthUnit) ->

        return 0 if typeof length isnt "number"

        switch lengthUnit
            when "inches" then convert.length.inch.millimeter(length)
            else length # Already millimeters or invalid unit

    convertSpeedToInternal: (speed, speedUnit) ->

        return 0 if typeof speed isnt "number"

        switch speedUnit
            when "inchSecond" then convert.speed.inchSecond.millimeterSecond(speed)
            when "meterSecond" then convert.speed.meterSecond.millimeterSecond(speed)
            else speed # Already millimeterSecond or invalid unit

    convertTimeToInternal: (time, timeUnit) ->

        return 0 if typeof time isnt "number"

        switch timeUnit
            when "seconds" then convert.time.second.millisecond(time)
            else time # Already milliseconds or invalid unit

    convertVolumeToInternal: (volume, volumeUnit) ->

        return 0 if typeof volume isnt "number"

        switch volumeUnit
            when "inchCu" then convert.volume.inchCu.millimeterCu(volume)
            when "centimeterCu" then convert.volume.centimeterCu.millimeterCu(volume)
            else volume # Already millimeterCu or invalid unit

    convertMassToInternal: (mass, massUnit) ->

        return 0 if typeof mass isnt "number"

        switch massUnit
            when "ounce" then convert.mass.ounce.gram(mass)
            when "kilogram" then convert.mass.kilogram.gram(mass)
            when "pound" then convert.mass.pound.gram(mass)
            else mass # Already grams or invalid unit

    convertDensityToInternal: (density, densityUnit) ->

        return 0 if typeof density isnt "number"

        switch densityUnit
            when "ounceInchCu" then convert.density.ounceInchCu.gramCentimeterCu(density)
            when "kilogramMeterCu" then convert.density.kilogramMeterCu.gramCentimeterCu(density)
            when "poundFootCu" then convert.density.poundFootCu.gramCentimeterCu(density)
            else density # Already gramCentimeterCu or invalid unit

    convertDataToInternal: (data, dataUnit) ->

        return 0 if typeof data isnt "number"

        switch dataUnit
            when "kilobyte" then convert.data.kilobyte.megabyte(data)
            when "gigabyte" then convert.data.gigabyte.megabyte(data)
            when "terabyte" then convert.data.terabyte.megabyte(data)
            else data # Already megabyte or invalid unit

    convertAreaToInternal: (area, areaUnit) ->

        return 0 if typeof area isnt "number"

        switch areaUnit
            when "inchSq" then convert.area.inchSq.millimeterSq(area)
            when "centimeterSq" then convert.area.centimeterSq.millimeterSq(area)
            else area # Already millimeterSq or invalid unit

    convertAngleToInternal: (angle, angleUnit) ->

        return 0 if typeof angle isnt "number"

        switch angleUnit
            when "radian" then convert.angle.radian.degree(angle)
            when "gradian" then convert.angle.gradian.degree(angle)
            else angle # Already degrees or invalid unit

    # Convert internal storage units to user output units
    convertTemperatureFromInternal: (temp, temperatureUnit) ->

        return 0 if typeof temp isnt "number"

        switch temperatureUnit
            when "fahrenheit" then convert.temperature.celsius.fahrenheit(temp)
            when "kelvin" then convert.temperature.celsius.kelvin(temp)
            else temp # Return celsius

    convertLengthFromInternal: (length, lengthUnit) ->

        return 0 if typeof length isnt "number"

        switch lengthUnit
            when "inches" then convert.length.millimeter.inch(length)
            else length # Return millimeters

    convertSpeedFromInternal: (speed, speedUnit) ->

        return 0 if typeof speed isnt "number"

        switch speedUnit
            when "inchSecond" then convert.speed.millimeterSecond.inchSecond(speed)
            when "meterSecond" then convert.speed.millimeterSecond.meterSecond(speed)
            else speed # Return millimeterSecond

    convertTimeFromInternal: (time, timeUnit) ->

        return 0 if typeof time isnt "number"

        switch timeUnit
            when "seconds" then convert.time.millisecond.second(time)
            else time # Return milliseconds

    convertVolumeFromInternal: (volume, volumeUnit) ->

        return 0 if typeof volume isnt "number"

        switch volumeUnit
            when "inchCu" then convert.volume.millimeterCu.inchCu(volume)
            when "centimeterCu" then convert.volume.millimeterCu.centimeterCu(volume)
            else volume # Return millimeterCu

    convertMassFromInternal: (mass, massUnit) ->

        return 0 if typeof mass isnt "number"

        switch massUnit
            when "ounce" then convert.mass.gram.ounce(mass)
            when "kilogram" then convert.mass.gram.kilogram(mass)
            when "pound" then convert.mass.gram.pound(mass)
            else mass # Return grams

    convertDensityFromInternal: (density, densityUnit) ->

        return 0 if typeof density isnt "number"

        switch densityUnit
            when "ounceInchCu" then convert.density.gramCentimeterCu.ounceInchCu(density)
            when "kilogramMeterCu" then convert.density.gramCentimeterCu.kilogramMeterCu(density)
            when "poundFootCu" then convert.density.gramCentimeterCu.poundFootCu(density)
            else density # Return gramCentimeterCu

    convertDataFromInternal: (data, dataUnit) ->

        return 0 if typeof data isnt "number"

        switch dataUnit
            when "kilobyte" then convert.data.megabyte.kilobyte(data)
            when "gigabyte" then convert.data.megabyte.gigabyte(data)
            when "terabyte" then convert.data.megabyte.terabyte(data)
            else data # Return megabyte

    convertAreaFromInternal: (area, areaUnit) ->

        return 0 if typeof area isnt "number"

        switch areaUnit
            when "inchSq" then convert.area.millimeterSq.inchSq(area)
            when "centimeterSq" then convert.area.millimeterSq.centimeterSq(area)
            else area # Return millimeterSq

    convertAngleFromInternal: (angle, angleUnit) ->

        return 0 if typeof angle isnt "number"

        switch angleUnit
            when "radian" then convert.angle.degree.radian(angle)
            when "gradian" then convert.angle.degree.gradian(angle)
            else angle # Return degrees
