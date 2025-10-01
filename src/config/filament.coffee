filaments = require('./filaments')

class Filament

    constructor: (material = "GenericPLA") ->

        # Load filament configuration from library.
        if filaments[material]

            config = filaments[material]

        else

            # Default to GenericPLA if material not found.
            console.warn("Filament material '#{material}' not found. Using default 'GenericPLA'.")
            config = filaments["GenericPLA"]

        # Filament type and identification.
        @type = config.type # String ['pla', 'petg', 'abs', 'tpu', 'nylon', etc.].
        @name = config.name # String - full name of the filament.
        @description = config.description # String - description.
        @brand = config.brand # String - manufacturer/brand name.
        @color = config.color # String - hex color code.

        # Physical properties.
        @diameter = config.diameter # Number - filament diameter in mm (1.75 or 2.85).
        @density = config.density # Number - density in g/cm³.
        @weight = config.weight # Number - spool weight in grams.
        @cost = config.cost # Number - cost per spool in currency units.

        # Printing settings.
        @fan = config.fan # Number 0-100 - fan speed percentage.

        # Temperature settings in Celsius.
        @temperature = {
            bed: config.temperature.bed # Number - bed temperature.
            nozzle: config.temperature.nozzle # Number - nozzle temperature.
            standby: config.temperature.standby # Number - standby temperature.
        }

        # Retraction settings.
        @retraction = {
            speed: config.retraction.speed # Number - retraction speed in mm/s.
            distance: config.retraction.distance # Number - retraction distance in mm.
        }

        # Store the material name for reference.
        @material = material

    # Getters

    getMaterial: ->

        return this.material

    getType: ->

        return this.type

    getName: ->

        return this.name

    getDescription: ->

        return this.description

    getBrand: ->

        return this.brand

    getColor: ->

        return this.color

    getDiameter: ->

        return this.diameter

    getDensity: ->

        return this.density

    getWeight: ->

        return this.weight

    getCost: ->

        return this.cost

    getFan: ->

        return this.fan

    getTemperature: ->

        return this.temperature

    getBedTemperature: ->

        return this.temperature.bed

    getNozzleTemperature: ->

        return this.temperature.nozzle

    getStandbyTemperature: ->

        return this.temperature.standby

    getRetraction: ->

        return this.retraction

    getRetractionSpeed: ->

        return this.retraction.speed

    getRetractionDistance: ->

        return this.retraction.distance

    # Setters

    setType: (type) ->

        if typeof type is 'string'
            this.type = type

        return this

    setName: (name) ->

        if typeof name is 'string'
            this.name = name

        return this

    setDescription: (description) ->

        if typeof description is 'string'
            this.description = description

        return this

    setBrand: (brand) ->

        if typeof brand is 'string'
            this.brand = brand

        return this

    setColor: (color) ->

        if typeof color is 'string'
            this.color = color

        return this

    setDiameter: (diameter) ->

        if typeof diameter is 'number' and diameter > 0
            this.diameter = diameter

        return this

    setDensity: (density) ->

        if typeof density is 'number' and density > 0
            this.density = density

        return this

    setWeight: (weight) ->

        if typeof weight is 'number' and weight > 0
            this.weight = weight

        return this

    setCost: (cost) ->

        if typeof cost is 'number' and cost >= 0
            this.cost = cost

        return this

    setFan: (fan) ->

        if typeof fan is 'number' and fan >= 0 and fan <= 100
            this.fan = fan

        return this

    setBedTemperature: (temp) ->

        if typeof temp is 'number' and temp >= 0
            this.temperature.bed = temp

        return this

    setNozzleTemperature: (temp) ->

        if typeof temp is 'number' and temp >= 0
            this.temperature.nozzle = temp

        return this

    setStandbyTemperature: (temp) ->

        if typeof temp is 'number' and temp >= 0
            this.temperature.standby = temp

        return this

    setRetractionSpeed: (speed) ->

        if typeof speed is 'number' and speed >= 0
            this.retraction.speed = speed

        return this

    setRetractionDistance: (distance) ->

        if typeof distance is 'number' and distance >= 0
            this.retraction.distance = distance

        return this

    # Utility Methods

    listAvailableFilaments: ->

        return Object.keys(filaments)

# Export the class for Node.js
if typeof module isnt 'undefined' and module.exports

    module.exports = Filament

# Export for browser environments.
if typeof window isnt 'undefined'

    window.Filament = Filament
