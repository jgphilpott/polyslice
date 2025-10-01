# Tests for the Printer class:

Printer = require('./printer')

describe 'Printer', ->

    printer = null

    beforeEach ->

        printer = new Printer()

    describe 'Constructor and Default Values', ->

        test 'should create a new instance with default printer (Ender3)', ->

            expect(printer).toBeInstanceOf(Printer)
            expect(printer.getModel()).toBe('Ender3')
            expect(printer.getSizeX()).toBe(220)
            expect(printer.getSizeY()).toBe(220)
            expect(printer.getSizeZ()).toBe(250)
            expect(printer.getShape()).toBe('rectangular')
            expect(printer.getCentred()).toBe(false)
            expect(printer.getHeatedBed()).toBe(true)
            expect(printer.getHeatedVolume()).toBe(false)
            expect(printer.getNozzleCount()).toBe(1)

        test 'should create instance with specified printer model', ->

            prusaPrinter = new Printer('PrusaI3MK3S')

            expect(prusaPrinter.getModel()).toBe('PrusaI3MK3S')
            expect(prusaPrinter.getSizeX()).toBe(250)
            expect(prusaPrinter.getSizeY()).toBe(210)
            expect(prusaPrinter.getSizeZ()).toBe(210)

        test 'should default to Ender3 for unknown printer model', ->

            unknownPrinter = new Printer('UnknownModel')

            expect(unknownPrinter.getModel()).toBe('UnknownModel')
            expect(unknownPrinter.getSizeX()).toBe(220) # Ender3 defaults
            expect(unknownPrinter.getSizeY()).toBe(220)
            expect(unknownPrinter.getSizeZ()).toBe(250)

        test 'should support multi-nozzle printers', ->

            dualPrinter = new Printer('FlashForgeCreatorPro')

            expect(dualPrinter.getNozzleCount()).toBe(2)
            expect(dualPrinter.getNozzle(0)).toBeDefined()
            expect(dualPrinter.getNozzle(1)).toBeDefined()

    describe 'Size Getters and Setters', ->

        test 'should get and set build volume size', ->

            size = printer.getSize()

            expect(size.x).toBe(220)
            expect(size.y).toBe(220)
            expect(size.z).toBe(250)

            printer.setSize(300, 300, 400)

            expect(printer.getSizeX()).toBe(300)
            expect(printer.getSizeY()).toBe(300)
            expect(printer.getSizeZ()).toBe(400)

        test 'should set individual size dimensions', ->

            printer.setSizeX(250)
            expect(printer.getSizeX()).toBe(250)

            printer.setSizeY(200)
            expect(printer.getSizeY()).toBe(200)

            printer.setSizeZ(300)
            expect(printer.getSizeZ()).toBe(300)

        test 'should ignore invalid size values', ->

            printer.setSizeX(-10)
            expect(printer.getSizeX()).toBe(220) # unchanged

            printer.setSizeY(0)
            expect(printer.getSizeY()).toBe(220) # unchanged

            printer.setSizeZ('invalid')
            expect(printer.getSizeZ()).toBe(250) # unchanged

    describe 'Shape and Centring', ->

        test 'should get and set build plate shape', ->

            expect(printer.getShape()).toBe('rectangular')

            printer.setShape('circular')
            expect(printer.getShape()).toBe('circular')

        test 'should ignore invalid shape values', ->

            printer.setShape('invalid')
            expect(printer.getShape()).toBe('rectangular') # unchanged

        test 'should get and set centred origin', ->

            expect(printer.getCentred()).toBe(false)

            printer.setCentred(true)
            expect(printer.getCentred()).toBe(true)

        test 'should return chaining for setters', ->

            result = printer.setCentred(true)
            expect(result).toBe(printer)

    describe 'Heating Capabilities', ->

        test 'should get heated bed status', ->

            expect(printer.getHeatedBed()).toBe(true)

        test 'should set heated bed status', ->

            printer.setHeatedBed(false)
            expect(printer.getHeatedBed()).toBe(false)

        test 'should get heated volume status', ->

            expect(printer.getHeatedVolume()).toBe(false)

        test 'should set heated volume status', ->

            printer.setHeatedVolume(true)
            expect(printer.getHeatedVolume()).toBe(true)

        test 'should get all heating capabilities', ->

            heated = printer.getHeated()

            expect(heated.bed).toBe(true)
            expect(heated.volume).toBe(false)

    describe 'Nozzle Configuration', ->

        test 'should get nozzle count', ->

            expect(printer.getNozzleCount()).toBe(1)

        test 'should get all nozzles', ->

            nozzles = printer.getNozzles()

            expect(nozzles.length).toBe(1)
            expect(nozzles[0].filament).toBe(1.75)
            expect(nozzles[0].diameter).toBe(0.4)
            expect(nozzles[0].gantry).toBe(25)

        test 'should get specific nozzle by index', ->

            nozzle = printer.getNozzle(0)

            expect(nozzle).toBeDefined()
            expect(nozzle.filament).toBe(1.75)
            expect(nozzle.diameter).toBe(0.4)

        test 'should return null for invalid nozzle index', ->

            expect(printer.getNozzle(10)).toBeNull()
            expect(printer.getNozzle(-1)).toBeNull()

        test 'should set nozzle properties', ->

            printer.setNozzle(0, 2.85, 0.6, 30)

            nozzle = printer.getNozzle(0)

            expect(nozzle.filament).toBe(2.85)
            expect(nozzle.diameter).toBe(0.6)
            expect(nozzle.gantry).toBe(30)

        test 'should add new nozzle', ->

            printer.addNozzle(1.75, 0.6, 30)

            expect(printer.getNozzleCount()).toBe(2)

            nozzle = printer.getNozzle(1)

            expect(nozzle.filament).toBe(1.75)
            expect(nozzle.diameter).toBe(0.6)

        test 'should remove nozzle', ->

            printer.addNozzle(1.75, 0.6, 30)
            expect(printer.getNozzleCount()).toBe(2)

            printer.removeNozzle(1)
            expect(printer.getNozzleCount()).toBe(1)

    describe 'Utility Methods', ->

        test 'should list available printers', ->

            printers = printer.listAvailablePrinters()

            expect(Array.isArray(printers)).toBe(true)
            expect(printers.length).toBeGreaterThan(0)
            expect(printers).toContain('Ender3')
            expect(printers).toContain('PrusaI3MK3S')

    describe 'Popular Printer Models', ->

        test 'should load Ender3 configuration', ->

            ender3 = new Printer('Ender3')

            expect(ender3.getSizeX()).toBe(220)
            expect(ender3.getSizeY()).toBe(220)
            expect(ender3.getSizeZ()).toBe(250)

        test 'should load Ender5 configuration', ->

            ender5 = new Printer('Ender5')

            expect(ender5.getSizeX()).toBe(220)
            expect(ender5.getSizeY()).toBe(220)
            expect(ender5.getSizeZ()).toBe(300)

        test 'should load PrusaI3MK3S configuration', ->

            prusa = new Printer('PrusaI3MK3S')

            expect(prusa.getSizeX()).toBe(250)
            expect(prusa.getSizeY()).toBe(210)
            expect(prusa.getSizeZ()).toBe(210)

        test 'should load CR10 configuration', ->

            cr10 = new Printer('CR10')

            expect(cr10.getSizeX()).toBe(300)
            expect(cr10.getSizeY()).toBe(300)
            expect(cr10.getSizeZ()).toBe(400)

        test 'should load UltimakerS5 with 2.85mm filament', ->

            ultimaker = new Printer('UltimakerS5')

            nozzle = ultimaker.getNozzle(0)

            expect(nozzle.filament).toBe(2.85)
            expect(ultimaker.getSizeX()).toBe(330)
