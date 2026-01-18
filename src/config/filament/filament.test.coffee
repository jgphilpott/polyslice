# Tests for the Filament class:

Filament = require('./filament')

describe 'Filament', ->

    filament = null

    beforeEach ->

        filament = new Filament()

    describe 'Constructor and Default Values', ->

        test 'should create a new instance with default filament (GenericPLA)', ->

            expect(filament).toBeInstanceOf(Filament)
            expect(filament.getMaterial()).toBe('GenericPLA')
            expect(filament.getType()).toBe('pla')
            expect(filament.getName()).toBe('Generic PLA')
            expect(filament.getBrand()).toBe('Generic')
            expect(filament.getDiameter()).toBe(1.75)
            expect(filament.getDensity()).toBe(1.24)
            expect(filament.getNozzleTemperature()).toBe(200)
            expect(filament.getBedTemperature()).toBe(60)
            expect(filament.getFan()).toBe(100)

        test 'should create instance with specified filament material', ->

            petg = new Filament('GenericPETG')

            expect(petg.getMaterial()).toBe('GenericPETG')
            expect(petg.getType()).toBe('petg')
            expect(petg.getNozzleTemperature()).toBe(240)
            expect(petg.getBedTemperature()).toBe(80)
            expect(petg.getFan()).toBe(50)

        test 'should default to GenericPLA for unknown material', ->

            # Suppress expected warning.
            originalWarn = console.warn
            console.warn = jest.fn()

            unknown = new Filament('UnknownMaterial')

            # Restore console.warn.
            console.warn = originalWarn

            expect(unknown.getMaterial()).toBe('UnknownMaterial')
            expect(unknown.getType()).toBe('pla') # GenericPLA defaults
            expect(unknown.getNozzleTemperature()).toBe(200)
            expect(unknown.getBedTemperature()).toBe(60)

    describe 'Basic Property Getters', ->

        test 'should get filament type', ->

            expect(filament.getType()).toBe('pla')

        test 'should get filament name', ->

            expect(filament.getName()).toBe('Generic PLA')

        test 'should get filament description', ->

            expect(filament.getDescription()).toBe('Standard PLA filament for general purpose printing')

        test 'should get filament brand', ->

            expect(filament.getBrand()).toBe('Generic')

        test 'should get filament color', ->

            expect(filament.getColor()).toBe('#FFFFFF')

    describe 'Physical Property Getters', ->

        test 'should get filament diameter', ->

            expect(filament.getDiameter()).toBe(1.75)

        test 'should get filament density', ->

            expect(filament.getDensity()).toBe(1.24)

        test 'should get spool weight', ->

            expect(filament.getWeight()).toBe(1000)

        test 'should get filament cost', ->

            expect(filament.getCost()).toBe(20)

    describe 'Printing Settings Getters', ->

        test 'should get fan speed', ->

            expect(filament.getFan()).toBe(100)

        test 'should get all temperatures', ->

            temps = filament.getTemperature()

            expect(temps.bed).toBe(60)
            expect(temps.nozzle).toBe(200)
            expect(temps.standby).toBe(180)

        test 'should get individual temperatures', ->

            expect(filament.getBedTemperature()).toBe(60)
            expect(filament.getNozzleTemperature()).toBe(200)
            expect(filament.getStandbyTemperature()).toBe(180)

        test 'should get retraction settings', ->

            retraction = filament.getRetraction()

            expect(retraction.speed).toBe(45)
            expect(retraction.distance).toBe(5)

        test 'should get individual retraction values', ->

            expect(filament.getRetractionSpeed()).toBe(45)
            expect(filament.getRetractionDistance()).toBe(5)

    describe 'Setters', ->

        test 'should set and get type', ->

            filament.setType('petg')
            expect(filament.getType()).toBe('petg')

        test 'should set and get name', ->

            filament.setName('Custom PLA')
            expect(filament.getName()).toBe('Custom PLA')

        test 'should set and get description', ->

            filament.setDescription('Custom description')
            expect(filament.getDescription()).toBe('Custom description')

        test 'should set and get brand', ->

            filament.setBrand('CustomBrand')
            expect(filament.getBrand()).toBe('CustomBrand')

        test 'should set and get color', ->

            filament.setColor('#FF0000')
            expect(filament.getColor()).toBe('#FF0000')

        test 'should set and get diameter', ->

            filament.setDiameter(2.85)
            expect(filament.getDiameter()).toBe(2.85)

        test 'should ignore invalid diameter values', ->

            filament.setDiameter(-1)
            expect(filament.getDiameter()).toBe(1.75) # unchanged

            filament.setDiameter(0)
            expect(filament.getDiameter()).toBe(1.75) # unchanged

        test 'should set and get density', ->

            filament.setDensity(1.30)
            expect(filament.getDensity()).toBe(1.30)

        test 'should set and get weight', ->

            filament.setWeight(750)
            expect(filament.getWeight()).toBe(750)

        test 'should set and get cost', ->

            filament.setCost(25)
            expect(filament.getCost()).toBe(25)

        test 'should set and get fan speed', ->

            filament.setFan(75)
            expect(filament.getFan()).toBe(75)

        test 'should ignore invalid fan speed values', ->

            filament.setFan(-10)
            expect(filament.getFan()).toBe(100) # unchanged

            filament.setFan(150)
            expect(filament.getFan()).toBe(100) # unchanged

        test 'should set and get temperatures', ->

            filament.setBedTemperature(70)
            expect(filament.getBedTemperature()).toBe(70)

            filament.setNozzleTemperature(220)
            expect(filament.getNozzleTemperature()).toBe(220)

            filament.setStandbyTemperature(200)
            expect(filament.getStandbyTemperature()).toBe(200)

        test 'should set and get retraction settings', ->

            filament.setRetractionSpeed(50)
            expect(filament.getRetractionSpeed()).toBe(50)

            filament.setRetractionDistance(6)
            expect(filament.getRetractionDistance()).toBe(6)

        test 'should return chaining for setters', ->

            result = filament.setFan(75)
            expect(result).toBe(filament)

    describe 'Utility Methods', ->

        test 'should list available filaments', ->

            materials = filament.listAvailableFilaments()

            expect(Array.isArray(materials)).toBe(true)
            expect(materials.length).toBeGreaterThan(0)
            expect(materials).toContain('GenericPLA')
            expect(materials).toContain('GenericPETG')
            expect(materials).toContain('GenericABS')

    describe 'Popular Filament Materials', ->

        test 'should load GenericPLA configuration', ->

            pla = new Filament('GenericPLA')

            expect(pla.getType()).toBe('pla')
            expect(pla.getNozzleTemperature()).toBe(200)
            expect(pla.getBedTemperature()).toBe(60)

        test 'should load GenericPETG configuration', ->

            petg = new Filament('GenericPETG')

            expect(petg.getType()).toBe('petg')
            expect(petg.getNozzleTemperature()).toBe(240)
            expect(petg.getBedTemperature()).toBe(80)

        test 'should load GenericABS configuration', ->

            abs = new Filament('GenericABS')

            expect(abs.getType()).toBe('abs')
            expect(abs.getNozzleTemperature()).toBe(240)
            expect(abs.getBedTemperature()).toBe(100)
            expect(abs.getFan()).toBe(0) # ABS typically uses no fan

        test 'should load GenericTPU flexible filament', ->

            tpu = new Filament('GenericTPU')

            expect(tpu.getType()).toBe('tpu')
            expect(tpu.getNozzleTemperature()).toBe(220)
            expect(tpu.getRetractionDistance()).toBe(2) # TPU uses minimal retraction

        test 'should load HatchboxPLA brand filament', ->

            hatchbox = new Filament('HatchboxPLA')

            expect(hatchbox.getBrand()).toBe('Hatchbox')
            expect(hatchbox.getNozzleTemperature()).toBe(205)

        test 'should load PrusamentPLA brand filament', ->

            prusa = new Filament('PrusamentPLA')

            expect(prusa.getBrand()).toBe('Prusa')
            expect(prusa.getNozzleTemperature()).toBe(215)

        test 'should load UltimakerPLA with 2.85mm diameter', ->

            ultimaker = new Filament('UltimakerPLA')

            expect(ultimaker.getDiameter()).toBe(2.85)
            expect(ultimaker.getBrand()).toBe('Ultimaker')
