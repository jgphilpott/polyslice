# Tests for exposure detection of cavities and holes (Issue: dome cavity detection).

Polyslice = require('../index')

THREE = require('three')

{ Polytree } = require('@jgphilpott/polytree')

describe 'Exposure Detection - Cavity and Hole Detection', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Dome Cavity Detection', ->

        test 'should detect adaptive skin above hemispherical cavity', ->

            # Create a dome by subtracting a hemisphere from a box.
            # The cavity creates exposed areas that should be detected.
            width = 25
            depth = 25
            thickness = 12
            radius = 10

            boxGeometry = new THREE.BoxGeometry(width, depth, thickness)
            boxMesh = new THREE.Mesh(boxGeometry, new THREE.MeshBasicMaterial())

            sphereGeometry = new THREE.SphereGeometry(radius, 32, 24)
            sphereMesh = new THREE.Mesh(sphereGeometry, new THREE.MeshBasicMaterial())

            # Place sphere to carve cavity from top.
            sphereMesh.position.set(0, 0, -(thickness / 2))
            sphereMesh.updateMatrixWorld()

            # Perform CSG subtraction.
            resultMesh = await Polytree.subtract(boxMesh, sphereMesh)

            # Position final mesh with build plate at Z=0.
            finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material)
            finalMesh.position.set(0, 0, thickness / 2)
            finalMesh.updateMatrixWorld()

            # Configure slicer with exposure detection enabled.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8)  # 4 skin layers.
            slicer.setShellWallThickness(0.8)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)
            slicer.setExposureDetectionResolution(900)

            # Slice the mesh.
            result = slicer.slice(finalMesh)

            # Extract skin occurrences by layer.
            lines = result.split('\n')
            skinLayersSet = new Set()

            currentLayer = null

            for line in lines

                if line.includes('LAYER:')

                    layerMatch = line.match(/LAYER:\s*(\d+)/)

                    if layerMatch
                        currentLayer = parseInt(layerMatch[1])

                else if currentLayer? and line.includes('TYPE: SKIN')

                    skinLayersSet.add(currentLayer)

            skinLayers = Array.from(skinLayersSet).sort((a, b) -> a - b)

            # Total layers: 60 (12mm / 0.2mm = 60 layers).
            # Expected skin layers:
            # - Bottom 4 layers (0-3): absolute bottom.
            # - Top 4 layers (56-59): absolute top.
            # - Middle layers with cavity (approximately 4-50): adaptive skin above cavity.
            # The cavity extends from Z=0 to Z=10mm (layers 0-49).
            # Layers above the cavity should detect exposure from below.
            expect(skinLayers.length).toBeGreaterThan(20)

            # Verify bottom layers have skin.
            expect(skinLayers).toContain(0)
            expect(skinLayers).toContain(1)
            expect(skinLayers).toContain(2)
            expect(skinLayers).toContain(3)

            # Verify top layers have skin.
            expect(skinLayers).toContain(56)
            expect(skinLayers).toContain(57)
            expect(skinLayers).toContain(58)
            expect(skinLayers).toContain(59)

            # Verify middle layers with cavity have adaptive skin.
            # Layers around the cavity (e.g., 20-50) should have skin.
            middleLayersWithSkin = skinLayers.filter((l) -> l >= 10 and l <= 50)

            expect(middleLayersWithSkin.length).toBeGreaterThan(10)

    describe 'Through-Hole Detection', ->

        test 'should detect adaptive skin on layers with through-holes', ->

            # Create a sheet with a cylindrical hole through it.
            # Middle layers should get adaptive skin due to the hole.
            sheetGeometry = new THREE.BoxGeometry(50, 50, 5)
            sheetMesh = new THREE.Mesh(sheetGeometry, new THREE.MeshBasicMaterial())

            holeRadius = 5
            holeGeometry = new THREE.CylinderGeometry(holeRadius, holeRadius, 10, 32)
            holeMesh = new THREE.Mesh(holeGeometry, new THREE.MeshBasicMaterial())

            # Rotate and position hole to pierce through the sheet.
            holeMesh.rotation.x = Math.PI / 2
            holeMesh.position.set(0, 0, 0)
            holeMesh.updateMatrixWorld()

            # Perform CSG subtraction.
            resultMesh = await Polytree.subtract(sheetMesh, holeMesh)

            # Position final mesh with build plate at Z=0.
            finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material)
            finalMesh.position.set(0, 0, 2.5)
            finalMesh.updateMatrixWorld()

            # Configure slicer with exposure detection enabled.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8)  # 4 skin layers.
            slicer.setShellWallThickness(0.8)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)
            slicer.setExposureDetectionResolution(900)

            # Slice the mesh.
            result = slicer.slice(finalMesh)

            # Extract skin occurrences by layer.
            lines = result.split('\n')
            skinLayersSet = new Set()

            currentLayer = null

            for line in lines

                if line.includes('LAYER:')

                    layerMatch = line.match(/LAYER:\s*(\d+)/)

                    if layerMatch
                        currentLayer = parseInt(layerMatch[1])

                else if currentLayer? and line.includes('TYPE: SKIN')

                    skinLayersSet.add(currentLayer)

            skinLayers = Array.from(skinLayersSet).sort((a, b) -> a - b)

            # Total layers: 25 (5mm / 0.2mm = 25 layers).
            # Expected skin layers:
            # - Bottom 4 layers (0-3): absolute bottom.
            # - Top 4 layers (21-24): absolute top.
            # - Middle layers (4-20): adaptive skin due to hole exposure.
            expect(skinLayers.length).toBeGreaterThan(15)

            # Verify all layers have skin (because hole exposes all layers).
            # Bottom layers.
            expect(skinLayers).toContain(0)
            expect(skinLayers).toContain(1)
            expect(skinLayers).toContain(2)
            expect(skinLayers).toContain(3)

            # Middle layers (should have adaptive skin due to hole).
            middleLayersWithSkin = skinLayers.filter((l) -> l >= 4 and l <= 20)

            expect(middleLayersWithSkin.length).toBeGreaterThan(10)

            # Top layers.
            expect(skinLayers).toContain(21)
            expect(skinLayers).toContain(22)
            expect(skinLayers).toContain(23)
            expect(skinLayers).toContain(24)

    describe 'Cavity vs Solid Comparison', ->

        test 'should generate more skin for geometry with cavity than solid', ->

            # Compare skin generation between solid box and box with cavity.
            width = 25
            depth = 25
            thickness = 12

            # Solid box (no cavity).
            solidGeometry = new THREE.BoxGeometry(width, depth, thickness)
            solidMesh = new THREE.Mesh(solidGeometry, new THREE.MeshBasicMaterial())

            solidMesh.position.set(0, 0, thickness / 2)
            solidMesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8)  # 4 skin layers.
            slicer.setShellWallThickness(0.8)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            # Slice solid box.
            solidResult = slicer.slice(solidMesh)

            solidSkinCount = (solidResult.match(/TYPE: SKIN/g) || []).length

            # Box with cavity.
            radius = 10

            boxGeometry = new THREE.BoxGeometry(width, depth, thickness)
            boxMesh = new THREE.Mesh(boxGeometry, new THREE.MeshBasicMaterial())

            sphereGeometry = new THREE.SphereGeometry(radius, 32, 24)
            sphereMesh = new THREE.Mesh(sphereGeometry, new THREE.MeshBasicMaterial())

            sphereMesh.position.set(0, 0, -(thickness / 2))
            sphereMesh.updateMatrixWorld()

            cavityMesh = await Polytree.subtract(boxMesh, sphereMesh)

            finalCavityMesh = new THREE.Mesh(cavityMesh.geometry, cavityMesh.material)
            finalCavityMesh.position.set(0, 0, thickness / 2)
            finalCavityMesh.updateMatrixWorld()

            # Slice cavity box.
            cavityResult = slicer.slice(finalCavityMesh)

            cavitySkinCount = (cavityResult.match(/TYPE: SKIN/g) || []).length

            # Cavity should generate significantly more skin due to adaptive detection.
            # Solid box: only 8 skin occurrences (4 bottom + 4 top).
            # Cavity box: many more due to exposed areas from cavity.
            expect(solidSkinCount).toBeLessThan(15)

            expect(cavitySkinCount).toBeGreaterThan(50)

            expect(cavitySkinCount).toBeGreaterThan(solidSkinCount * 5)

    describe 'Exposure Detection Disabled', ->

        test 'should not generate middle layer skin when exposure detection disabled', ->

            # Verify that disabling exposure detection prevents adaptive skin on cavity.
            width = 25
            depth = 25
            thickness = 12
            radius = 10

            boxGeometry = new THREE.BoxGeometry(width, depth, thickness)
            boxMesh = new THREE.Mesh(boxGeometry, new THREE.MeshBasicMaterial())

            sphereGeometry = new THREE.SphereGeometry(radius, 32, 24)
            sphereMesh = new THREE.Mesh(sphereGeometry, new THREE.MeshBasicMaterial())

            sphereMesh.position.set(0, 0, -(thickness / 2))
            sphereMesh.updateMatrixWorld()

            resultMesh = await Polytree.subtract(boxMesh, sphereMesh)

            finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material)
            finalMesh.position.set(0, 0, thickness / 2)
            finalMesh.updateMatrixWorld()

            # Configure slicer with exposure detection DISABLED.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8)  # 4 skin layers.
            slicer.setShellWallThickness(0.8)
            slicer.setAutohome(false)
            slicer.setExposureDetection(false)  # Disabled.

            # Slice the mesh.
            result = slicer.slice(finalMesh)

            # Extract skin occurrences by layer.
            lines = result.split('\n')
            skinLayersSet = new Set()

            currentLayer = null

            for line in lines

                if line.includes('LAYER:')

                    layerMatch = line.match(/LAYER:\s*(\d+)/)

                    if layerMatch
                        currentLayer = parseInt(layerMatch[1])

                else if currentLayer? and line.includes('TYPE: SKIN')

                    skinLayersSet.add(currentLayer)

            skinLayers = Array.from(skinLayersSet).sort((a, b) -> a - b)

            # Should only have skin on top and bottom 4 layers (no adaptive skin).
            expect(skinLayers.length).toBeLessThanOrEqual(8)

            # Verify only top and bottom layers have skin.
            for layer in skinLayers

                expect(layer < 4 or layer >= 56).toBe(true)
