# Tests for lightning infill pattern

Polyslice = require('../../../index')

THREE = require('three')

# Helper: create a minimal mock slicer for direct lightning module testing.
createMockSlicer = ->
    getVerbose: -> false
    getNozzleDiameter: -> 0.4
    getTravelSpeed: -> 50
    getInfillSpeed: -> 40
    getCoordinatePrecision: -> 3
    getExtrusionPrecision: -> 5
    getFeedratePrecision: -> 0
    gcode: ''
    cumulativeE: 0
    newline: '\n'
    calculateExtrusion: (d, n) -> d * 0.03

describe 'Lightning Infill Generation', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice({progressCallback: null})

    describe 'Lightning Infill Generation', ->

        test 'should generate infill for middle layers', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8) # 2 walls.
            slicer.setShellSkinThickness(0.4) # 2 bottom + 2 top layers.
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('lightning')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain FILL type for middle layers.
            expect(result).toContain('; TYPE: FILL')

            # Count infill occurrences (should be in middle layers only).
            lines = result.split('\n')
            infillCount = 0

            for line in lines

                if line.includes('; TYPE: FILL')
                    infillCount++

            # 1cm cube with 0.2mm layer height = 50 total layers.
            # 2 bottom + 2 top skin layers = 4 skin layers.
            # Remaining 46 layers should have infill.
            expect(infillCount).toBeGreaterThan(40)

        test 'should not generate infill when density is 0', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(0) # No infill.
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should not contain FILL type when density is 0.
            expect(result).not.toContain('; TYPE: FILL')

        test 'should generate tree-like branching structure', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('lightning')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should generate G-code with extrusion moves.
            expect(result).toContain('G1')

            # Count extrusion lines in infill sections.
            lines = result.split('\n')
            inFillSection = false
            extrusionCount = 0

            for line in lines

                if line.includes('; TYPE: FILL')
                    inFillSection = true
                else if line.includes('; TYPE:') and not line.includes('; TYPE: FILL')
                    inFillSection = false

                if inFillSection and line.includes('G1') and line.includes('E')
                    extrusionCount++

            # Lightning pattern should generate some extrusion moves.
            expect(extrusionCount).toBeGreaterThan(0)

        test 'should handle circular shapes', ->

            # Create a cylinder.
            geometry = new THREE.CylinderGeometry(5, 5, 10, 32)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.rotation.x = Math.PI / 2
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(15)
            slicer.setInfillPattern('lightning')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should successfully slice circular shapes.
            expect(result).toContain('; TYPE: FILL')

        test 'should support object centering mode', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('lightning')
            slicer.setInfillPatternCentering('object')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should generate infill with object centering.
            expect(result).toContain('; TYPE: FILL')

        test 'should support global centering mode', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('lightning')
            slicer.setInfillPatternCentering('global')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should generate infill with global centering.
            expect(result).toContain('; TYPE: FILL')

        test 'should work with different densities', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setVerbose(true)

            # Test with low density.
            slicer.setInfillDensity(10)
            slicer.setInfillPattern('lightning')
            result10 = slicer.slice(mesh)
            expect(result10).toContain('; TYPE: FILL')

            # Test with high density.
            slicer.setInfillDensity(50)
            slicer.setInfillPattern('lightning')
            result50 = slicer.slice(mesh)
            expect(result50).toContain('; TYPE: FILL')

            # Higher density should have more branches (more G-code).
            expect(result50.length).toBeGreaterThan(result10.length)

        test 'should produce G1 extrusion moves with multiple segments per branch', ->

            # Directly invoke the lightning module with a minimal mock slicer.
            lightningModule = require('./lightning')

            # Simple 10mm square boundary.
            boundary = [{x: 0, y: 0}, {x: 10, y: 0}, {x: 10, y: 10}, {x: 0, y: 10}]

            mockSlicer = createMockSlicer()

            lightningModule.generateLightningInfill(mockSlicer, boundary, 0.2, 0, 0, 4.0, 'object')

            # Zig-zag segments produce extrusion G1 moves — verify they are present.
            expect(mockSlicer.gcode).toContain('G1')

            # Zig-zag kinking means multiple G1 segments per branch, so total count > 5.
            expect(mockSlicer.gcode.split('G1').length - 1).toBeGreaterThan(5)

        test 'should generate zig-zag kinks in branch lines', ->

            # Directly invoke the lightning module with a minimal mock slicer.
            lightningModule = require('./lightning')

            # Simple 10mm square boundary.
            boundary = [{x: 0, y: 0}, {x: 10, y: 0}, {x: 10, y: 10}, {x: 0, y: 10}]

            mockSlicer = createMockSlicer()

            lightningModule.generateLightningInfill(mockSlicer, boundary, 0.2, 0, 0, 4.0, 'object')

            # Count extrusion G1 lines (lines containing both 'G1' and 'E').
            extrusionLineCount = mockSlicer.gcode.split('\n').filter((line) -> line.includes('G1') and line.includes('E')).length

            # For a 10mm square (perimeter=40mm) with lineSpacing=4.0 (branchSpacing=10mm),
            # at least 3 branches are generated. Each branch with zig-zag produces ≥2 segments.
            branchEstimate = 3
            expect(extrusionLineCount).toBeGreaterThan(branchEstimate * 2)
