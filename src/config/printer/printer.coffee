printers = require('./printers')

class Printer

    constructor: (model = "Ender3") ->

        # Load printer configuration from library.
        if printers[model]

            config = printers[model]

        else

            # Default to Ender3 if model not found.
            console.warn("Printer model '#{model}' not found. Using default 'Ender3'.")
            config = printers["Ender3"]

        # Build volume size in millimeters.
        @size = {
            x: config.size.x
            y: config.size.y
            z: config.size.z
        }

        # Build plate shape.
        @shape = config.shape # String ['rectangular', 'circular'].

        # Whether origin is at center or corner.
        @centred = config.centred # Boolean.

        # Heating capabilities.
        @heated = {
            volume: config.heated.volume # Boolean - enclosed heated chamber.
            bed: config.heated.bed # Boolean - heated build plate.
        }

        # Nozzle configuration (array to support multi-nozzle printers).
        @nozzles = []

        for nozzle in config.nozzles

            @nozzles.push({
                filament: nozzle.filament # Number - filament diameter in mm.
                diameter: nozzle.diameter # Number - nozzle diameter in mm.
                gantry: nozzle.gantry # Number - gantry/carriage size in mm.
            })

        # Store the model name for reference.
        @model = model

    # Getters

    getModel: ->

        return this.model

    getSize: ->

        return this.size

    getSizeX: ->

        return this.size.x

    getSizeY: ->

        return this.size.y

    getSizeZ: ->

        return this.size.z

    getShape: ->

        return this.shape

    getCentred: ->

        return this.centred

    getHeated: ->

        return this.heated

    getHeatedVolume: ->

        return this.heated.volume

    getHeatedBed: ->

        return this.heated.bed

    getNozzles: ->

        return this.nozzles

    getNozzle: (index = 0) ->

        if index >= 0 and index < this.nozzles.length

            return this.nozzles[index]

        return null

    getNozzleCount: ->

        return this.nozzles.length

    # Setters

    setSize: (x, y, z) ->

        if typeof x is 'number' and x > 0

            this.size.x = x

        if typeof y is 'number' and y > 0

            this.size.y = y

        if typeof z is 'number' and z > 0

            this.size.z = z

        return this

    setSizeX: (x) ->

        if typeof x is 'number' and x > 0

            this.size.x = x

        return this

    setSizeY: (y) ->

        if typeof y is 'number' and y > 0

            this.size.y = y

        return this

    setSizeZ: (z) ->

        if typeof z is 'number' and z > 0

            this.size.z = z

        return this

    setShape: (shape) ->

        if shape in ['rectangular', 'circular']

            this.shape = shape

        return this

    setCentred: (centred) ->

        if typeof centred is 'boolean'

            this.centred = centred

        return this

    setHeatedVolume: (heated) ->

        if typeof heated is 'boolean'

            this.heated.volume = heated

        return this

    setHeatedBed: (heated) ->

        if typeof heated is 'boolean'

            this.heated.bed = heated

        return this

    setNozzle: (index, filament, diameter, gantry) ->

        if index >= 0 and index < this.nozzles.length

            if typeof filament is 'number' and filament > 0

                this.nozzles[index].filament = filament

            if typeof diameter is 'number' and diameter > 0

                this.nozzles[index].diameter = diameter

            if typeof gantry is 'number' and gantry > 0

                this.nozzles[index].gantry = gantry

        return this

    addNozzle: (filament = 1.75, diameter = 0.4, gantry = 25) ->

        this.nozzles.push({
            filament: filament
            diameter: diameter
            gantry: gantry
        })

        return this

    removeNozzle: (index) ->

        if index >= 0 and index < this.nozzles.length

            this.nozzles.splice(index, 1)

        return this

    # Utility Methods

    listAvailablePrinters: ->

        return Object.keys(printers)

# Export the class for Node.js
if typeof module isnt 'undefined' and module.exports

    module.exports = Printer

# Export for browser environments.
if typeof window isnt 'undefined'

    window.Printer = Printer
