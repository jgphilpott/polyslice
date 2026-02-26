# Tests for spiral infill pattern

Polyslice = require('../../../index')

THREE = require('three')

describe 'Spiral Infill Generation', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice({progressCallback: null})

    describe 'Pattern Generation Tests', ->

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
            slicer.setInfillPattern('spiral')
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

        test 'should respect infillDensity setting', ->

            # Create a 1cm cube.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillPattern('spiral')
            slicer.setVerbose(true)

            # Test with 0% infill.
            slicer.setInfillDensity(0)
            result0 = slicer.slice(mesh)
            expect(result0).not.toContain('; TYPE: FILL')

            # Test with 50% infill.
            slicer.setInfillDensity(50)
            result50 = slicer.slice(mesh)
            expect(result50).toContain('; TYPE: FILL')

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
            slicer.setInfillPattern('spiral')
            slicer.setInfillPatternCentering('object')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain FILL type.
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
            slicer.setInfillPattern('spiral')
            slicer.setInfillPatternCentering('global')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain FILL type.
            expect(result).toContain('; TYPE: FILL')

        test 'should handle circular parts', ->

            # Create a cylinder (circular cross-section).
            geometry = new THREE.CylinderGeometry(5, 5, 10, 32)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.rotation.x = Math.PI / 2
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('spiral')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Should contain FILL type.
            expect(result).toContain('; TYPE: FILL')

            # Should have multiple G1 commands (extrusion).
            lines = result.split('\n')
            g1Count = 0

            for line in lines

                if line.trim().startsWith('G1') and line.includes('E')
                    g1Count++

            expect(g1Count).toBeGreaterThan(10)

    describe 'Global Centering with Offset Boundary', ->

        test 'should generate spiral infill for boundary far from origin with global centering', ->

            # Regression test for: missing spiral infill when infillPatternCentering = 'global'
            # and the infill boundary is positioned far from the origin (0, 0).
            #
            # Root cause: maxRadius was computed as half the boundary's own diagonal.
            # With global centering the pattern center is (0,0), but the boundary might be
            # 15+ mm away. The spiral terminated before it reached the boundary.
            # Fix: compute maxRadius as the max distance from (centerX, centerY) to any
            # bounding box corner, which correctly handles both centering modes.

            # Create a small box offset well away from origin.
            boxSize = 8
            offsetX = 30
            offsetY = 25

            geometry = new THREE.BoxGeometry(boxSize, boxSize, 1)
            mesh = new THREE.Mesh(geometry)
            mesh.position.set(offsetX, offsetY, 0.5)
            mesh.updateMatrixWorld()

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('spiral')
            slicer.setInfillPatternCentering('global')
            slicer.setVerbose(true)

            result = slicer.slice(mesh)

            # Middle layer should have infill.
            layers = result.split('M117 LAYER:')
            skinLayerCount = 2 # shellSkinThickness 0.4 / layerHeight 0.2 = 2.
            middleLayers = layers.slice(skinLayerCount + 1, layers.length - skinLayerCount)

            hasInfillInMiddle = false

            for layer in middleLayers

                if layer.includes('; TYPE: FILL')
                    fillSection = layer.split('; TYPE: FILL')[1]
                    sectionContent = fillSection.split('; TYPE:')[0]
                    extrusions = sectionContent.match(/G1\s+X[\d.]+\s+Y[\d.]+.*?E[\d.]+/g)

                    if extrusions and extrusions.length > 0
                        hasInfillInMiddle = true
                        break

            expect(hasInfillInMiddle).toBe(true)

            return

        test 'should generate consistent spiral infill across all layers with global centering', ->

            # Regression test: ensures infill is not lost in later layers when the boundary
            # is far from the pattern origin and the spiral maxRadius calculation is correct.
            BufferGeometryUtils = null

            try
                mod = require('three/examples/jsm/utils/BufferGeometryUtils.js')
                BufferGeometryUtils = mod
            catch error
                return

            # Two small pillars offset from origin - mirrors the flipped arch scenario.
            pillarSize = 9
            pillarHeight = 0.6
            pillarOffsetX = 15

            geometries = []

            for side in [-1, 1]
                box = new THREE.BoxGeometry(pillarSize, pillarSize, pillarHeight)
                boxMesh = new THREE.Mesh(box)
                boxMesh.position.set(side * pillarOffsetX, 0, pillarHeight / 2)
                boxMesh.updateMatrixWorld()
                geom = boxMesh.geometry.clone()
                geom.applyMatrix4(boxMesh.matrixWorld)
                geometries.push(geom)

            mergedGeometry = BufferGeometryUtils.mergeGeometries(geometries, false)
            mergedMesh = new THREE.Mesh(mergedGeometry)

            slicer.setNozzleDiameter(0.4)
            slicer.setShellWallThickness(0.8)
            slicer.setShellSkinThickness(0.4)
            slicer.setLayerHeight(0.2)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('spiral')
            slicer.setInfillPatternCentering('global')
            slicer.setVerbose(true)

            result = slicer.slice(mergedMesh)

            # Collect infill extrusion counts for all middle layers.
            layers = result.split('M117 LAYER:')
            skinLayerCount = 2

            infillCountsPerLayer = []

            for i in [skinLayerCount + 1...layers.length - skinLayerCount]
                layer = layers[i]
                continue unless layer

                # Each layer should have 2 FILL sections (one per pillar).
                fillSections = layer.split('; TYPE: FILL').slice(1)
                continue if fillSections.length isnt 2

                counts = []

                for section in fillSections
                    sectionContent = section.split('; TYPE:')[0]
                    extrusions = sectionContent.match(/G1\s+X[\d.]+\s+Y[\d.]+.*?E[\d.]+/g)
                    counts.push(if extrusions then extrusions.length else 0)

                infillCountsPerLayer.push(counts)

            expect(infillCountsPerLayer.length).toBeGreaterThan(0)

            firstLayerCounts = infillCountsPerLayer[0]

            # All middle layers must have infill in both pillars.
            for counts in infillCountsPerLayer
                expect(counts[0]).toBeGreaterThan(0)
                expect(counts[1]).toBeGreaterThan(0)

                # Both pillars should be symmetric.
                expect(Math.abs(counts[0] - counts[1])).toBeLessThanOrEqual(2)

                # Infill count must not drop significantly between layers.
                expect(Math.abs(counts[0] - firstLayerCounts[0])).toBeLessThanOrEqual(2)

            return
