# Unit conversion utilities for Polyslice
# All conversions use @jgphilpott/polyconvert library

polyconvert = require('@jgphilpott/polyconvert')

# Export conversion helper functions
module.exports =

    # Convert user input to internal storage units.

    temperatureToInternal: (temp, temperatureUnit) ->

        return 0 if typeof temp isnt "number"

        switch temperatureUnit
            when "fahrenheit" then polyconvert.temperature.fahrenheit.celsius(temp)
            when "kelvin" then polyconvert.temperature.kelvin.celsius(temp)
            else temp # Already celsius or invalid unit

    lengthToInternal: (length, lengthUnit) ->

        return 0 if typeof length isnt "number"

        switch lengthUnit
            when "inches" then polyconvert.length.inch.millimeter(length)
            else length # Already millimeters or invalid unit

    speedToInternal: (speed, speedUnit) ->

        return 0 if typeof speed isnt "number"

        switch speedUnit
            when "inchSecond" then polyconvert.speed.inchSecond.millimeterSecond(speed)
            when "meterSecond" then polyconvert.speed.meterSecond.millimeterSecond(speed)
            else speed # Already millimeterSecond or invalid unit

    timeToInternal: (time, timeUnit) ->

        return 0 if typeof time isnt "number"

        switch timeUnit
            when "seconds" then polyconvert.time.second.millisecond(time)
            else time # Already milliseconds or invalid unit

    volumeToInternal: (volume, volumeUnit) ->

        return 0 if typeof volume isnt "number"

        switch volumeUnit
            when "inchCu" then polyconvert.volume.inchCu.millimeterCu(volume)
            when "centimeterCu" then polyconvert.volume.centimeterCu.millimeterCu(volume)
            else volume # Already millimeterCu or invalid unit

    massToInternal: (mass, massUnit) ->

        return 0 if typeof mass isnt "number"

        switch massUnit
            when "ounce" then polyconvert.mass.ounce.gram(mass)
            when "kilogram" then polyconvert.mass.kilogram.gram(mass)
            when "pound" then polyconvert.mass.pound.gram(mass)
            else mass # Already grams or invalid unit

    densityToInternal: (density, densityUnit) ->

        return 0 if typeof density isnt "number"

        switch densityUnit
            when "ounceInchCu" then polyconvert.density.ounceInchCu.gramCentimeterCu(density)
            when "kilogramMeterCu" then polyconvert.density.kilogramMeterCu.gramCentimeterCu(density)
            when "poundFootCu" then polyconvert.density.poundFootCu.gramCentimeterCu(density)
            else density # Already gramCentimeterCu or invalid unit

    dataToInternal: (data, dataUnit) ->

        return 0 if typeof data isnt "number"

        switch dataUnit
            when "kilobyte" then polyconvert.data.kilobyte.megabyte(data)
            when "gigabyte" then polyconvert.data.gigabyte.megabyte(data)
            when "terabyte" then polyconvert.data.terabyte.megabyte(data)
            else data # Already megabyte or invalid unit

    areaToInternal: (area, areaUnit) ->

        return 0 if typeof area isnt "number"

        switch areaUnit
            when "inchSq" then polyconvert.area.inchSq.millimeterSq(area)
            when "centimeterSq" then polyconvert.area.centimeterSq.millimeterSq(area)
            else area # Already millimeterSq or invalid unit

    angleToInternal: (angle, angleUnit) ->

        return 0 if typeof angle isnt "number"

        switch angleUnit
            when "radian" then polyconvert.angle.radian.degree(angle)
            when "gradian" then polyconvert.angle.gradian.degree(angle)
            else angle # Already degrees or invalid unit

    # Convert internal storage units to user output units.

    temperatureFromInternal: (temp, temperatureUnit) ->

        return 0 if typeof temp isnt "number"

        switch temperatureUnit
            when "fahrenheit" then polyconvert.temperature.celsius.fahrenheit(temp)
            when "kelvin" then polyconvert.temperature.celsius.kelvin(temp)
            else temp # Return celsius

    lengthFromInternal: (length, lengthUnit) ->

        return 0 if typeof length isnt "number"

        switch lengthUnit
            when "inches" then polyconvert.length.millimeter.inch(length)
            else length # Return millimeters

    speedFromInternal: (speed, speedUnit) ->

        return 0 if typeof speed isnt "number"

        switch speedUnit
            when "inchSecond" then polyconvert.speed.millimeterSecond.inchSecond(speed)
            when "meterSecond" then polyconvert.speed.millimeterSecond.meterSecond(speed)
            else speed # Return millimeterSecond

    timeFromInternal: (time, timeUnit) ->

        return 0 if typeof time isnt "number"

        switch timeUnit
            when "seconds" then polyconvert.time.millisecond.second(time)
            else time # Return milliseconds

    volumeFromInternal: (volume, volumeUnit) ->

        return 0 if typeof volume isnt "number"

        switch volumeUnit
            when "inchCu" then polyconvert.volume.millimeterCu.inchCu(volume)
            when "centimeterCu" then polyconvert.volume.millimeterCu.centimeterCu(volume)
            else volume # Return millimeterCu

    massFromInternal: (mass, massUnit) ->

        return 0 if typeof mass isnt "number"

        switch massUnit
            when "ounce" then polyconvert.mass.gram.ounce(mass)
            when "kilogram" then polyconvert.mass.gram.kilogram(mass)
            when "pound" then polyconvert.mass.gram.pound(mass)
            else mass # Return grams

    densityFromInternal: (density, densityUnit) ->

        return 0 if typeof density isnt "number"

        switch densityUnit
            when "ounceInchCu" then polyconvert.density.gramCentimeterCu.ounceInchCu(density)
            when "kilogramMeterCu" then polyconvert.density.gramCentimeterCu.kilogramMeterCu(density)
            when "poundFootCu" then polyconvert.density.gramCentimeterCu.poundFootCu(density)
            else density # Return gramCentimeterCu

    dataFromInternal: (data, dataUnit) ->

        return 0 if typeof data isnt "number"

        switch dataUnit
            when "kilobyte" then polyconvert.data.megabyte.kilobyte(data)
            when "gigabyte" then polyconvert.data.megabyte.gigabyte(data)
            when "terabyte" then polyconvert.data.megabyte.terabyte(data)
            else data # Return megabyte

    areaFromInternal: (area, areaUnit) ->

        return 0 if typeof area isnt "number"

        switch areaUnit
            when "inchSq" then polyconvert.area.millimeterSq.inchSq(area)
            when "centimeterSq" then polyconvert.area.millimeterSq.centimeterSq(area)
            else area # Return millimeterSq

    angleFromInternal: (angle, angleUnit) ->

        return 0 if typeof angle isnt "number"

        switch angleUnit
            when "radian" then polyconvert.angle.degree.radian(angle)
            when "gradian" then polyconvert.angle.degree.gradian(angle)
            else angle # Return degrees
