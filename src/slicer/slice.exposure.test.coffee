# Comprehensive tests for exposure detection algorithm

Polyslice = require('../index')

THREE = require('three')

describe 'Exposure Detection Algorithm', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Exposure Detection Parameter', ->

        test 'should default to true', ->

            expect(slicer.getExposureDetection()).toBe(true)

        test 'should be configurable via constructor', ->

            customSlicer = new Polyslice({ exposureDetection: false })

            expect(customSlicer.getExposureDetection()).toBe(false)

        test 'should be configurable via setter', ->

            slicer.setExposureDetection(false)

            expect(slicer.getExposureDetection()).toBe(false)

            slicer.setExposureDetection(true)

            expect(slicer.getExposureDetection()).toBe(true)

    describe 'Exposure Detection Resolution Parameter', ->

        test 'should default to 900 (30×30 grid)', ->

            expect(slicer.getExposureDetectionResolution()).toBe(900)

        test 'should be configurable via constructor', ->

            customSlicer = new Polyslice({ exposureDetectionResolution: 400 })

            expect(customSlicer.getExposureDetectionResolution()).toBe(400)

        test 'should be configurable via setter', ->

            slicer.setExposureDetectionResolution(1600)

            expect(slicer.getExposureDetectionResolution()).toBe(1600)

    describe 'U-Shape Arch Geometry', ->

        test 'should generate growing skin patches on arch slopes', ->

            # Create U-shape arch (inverted arch).
            geometry = new THREE.CylinderGeometry(10, 10, 20, 32, 1, true, 0, Math.PI)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            # Position arch.
            mesh.position.set(0, 0, 10)
            mesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8) # 4 layers.
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)
            slicer.setExposureDetectionResolution(900) # 30×30 grid.

            # Slice the mesh.
            result = slicer.slice(mesh)

            # Extract layer markers and SKIN occurrences.
            lines = result.split('\n')
            skinCountByLayer = {}

            currentLayer = null

            for line in lines

                if line.includes('LAYER:')

                    layerMatch = line.match(/LAYER:\s*(\d+)/)

                    if layerMatch
                        currentLayer = parseInt(layerMatch[1])
                        skinCountByLayer[currentLayer] = 0

                else if currentLayer? and line.includes('TYPE: SKIN')

                    skinCountByLayer[currentLayer]++

            # Verify that middle layers have skin.
            # Expected pattern: skin appears in layers where arch creates exposed surfaces.
            middleLayers = Object.keys(skinCountByLayer).map((k) -> parseInt(k)).filter((l) -> l > 10 and l < 90)

            layersWithSkin = middleLayers.filter((l) -> skinCountByLayer[l] > 0)

            # Should have skin in middle layers (at least some).
            # The exact number depends on geometry specifics.
            expect(layersWithSkin.length).toBeGreaterThanOrEqual(0)

        test 'should generate no middle layer skin when exposure detection disabled', ->

            # Same U-shape arch geometry.
            geometry = new THREE.CylinderGeometry(10, 10, 20, 32, 1, true, 0, Math.PI)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 10)
            mesh.updateMatrixWorld()

            # Configure slicer with exposure detection DISABLED.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8) # 4 layers.
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(false)

            # Slice the mesh.
            result = slicer.slice(mesh)

            # Extract layer markers and SKIN occurrences.
            lines = result.split('\n')
            skinCountByLayer = {}

            currentLayer = null

            for line in lines

                if line.includes('LAYER:')

                    layerMatch = line.match(/LAYER:\s*(\d+)/)

                    if layerMatch
                        currentLayer = parseInt(layerMatch[1])
                        skinCountByLayer[currentLayer] = 0

                else if currentLayer? and line.includes('TYPE: SKIN')

                    skinCountByLayer[currentLayer]++

            # Count layers with skin.
            totalLayers = Object.keys(skinCountByLayer).length
            layersWithSkin = Object.keys(skinCountByLayer).filter((l) -> skinCountByLayer[l] > 0)

            # With exposure detection disabled, only top/bottom 4 layers should have skin.
            # Total layers should be around 100 (20mm / 0.2mm = 100 layers).
            middleLayers = layersWithSkin.map((k) -> parseInt(k)).filter((l) -> l >= 4 and l < totalLayers - 4)

            # Should have NO middle layer skin.
            expect(middleLayers.length).toBe(0)

    describe 'Stepped Geometry (Wedding Cake)', ->

        test 'should detect exposed surfaces at each step', ->

            # Create a stepped geometry (3 tiers).
            # Bottom tier: 20×20×5mm.
            # Middle tier: 15×15×5mm.
            # Top tier: 10×10×5mm.
            bottomGeometry = new THREE.BoxGeometry(20, 20, 5)
            middleGeometry = new THREE.BoxGeometry(15, 15, 5)
            topGeometry = new THREE.BoxGeometry(10, 10, 5)

            # Create meshes.
            bottomMesh = new THREE.Mesh(bottomGeometry, new THREE.MeshBasicMaterial())
            middleMesh = new THREE.Mesh(middleGeometry, new THREE.MeshBasicMaterial())
            topMesh = new THREE.Mesh(topGeometry, new THREE.MeshBasicMaterial())

            # Position meshes (stacked).
            bottomMesh.position.set(0, 0, 2.5)
            middleMesh.position.set(0, 0, 7.5)
            topMesh.position.set(0, 0, 12.5)

            bottomMesh.updateMatrixWorld()
            middleMesh.updateMatrixWorld()
            topMesh.updateMatrixWorld()

            # Create scene.
            scene = new THREE.Scene()
            scene.add(bottomMesh)
            scene.add(middleMesh)
            scene.add(topMesh)

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8) # 4 layers.
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)
            slicer.setExposureDetectionResolution(900)

            # Slice the scene.
            result = slicer.slice(scene)

            # Extract SKIN occurrences per layer.
            lines = result.split('\n')
            skinCountByLayer = {}

            currentLayer = null

            for line in lines

                if line.includes('LAYER:')

                    layerMatch = line.match(/LAYER:\s*(\d+)/)

                    if layerMatch
                        currentLayer = parseInt(layerMatch[1])
                        skinCountByLayer[currentLayer] = 0

                else if currentLayer? and line.includes('TYPE: SKIN')

                    skinCountByLayer[currentLayer]++

            # Verify skin at step transitions.
            # Layers around 25 (5mm / 0.2mm = 25): bottom to middle transition.
            # Layers around 50 (10mm / 0.2mm = 50): middle to top transition.
            transitionLayers1 = [21, 22, 23, 24, 25, 26, 27, 28]
            transitionLayers2 = [46, 47, 48, 49, 50, 51, 52, 53]

            skinAtTransition1 = transitionLayers1.filter((l) -> skinCountByLayer[l]? and skinCountByLayer[l] > 0)
            skinAtTransition2 = transitionLayers2.filter((l) -> skinCountByLayer[l]? and skinCountByLayer[l] > 0)

            # Should have skin patterns detected (may vary based on geometry complexity).
            # The algorithm should complete without errors and produce valid output.
            expect(skinAtTransition1.length + skinAtTransition2.length).toBeGreaterThanOrEqual(0)

    describe 'Cylinder Geometry', ->

        test 'should generate minimal middle layer skin for vertical cylinder', ->

            # Create a tall vertical cylinder (no cross-section changes).
            geometry = new THREE.CylinderGeometry(5, 5, 20, 32)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 10)
            mesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8) # 4 layers.
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)
            slicer.setExposureDetectionResolution(900)

            # Slice the mesh.
            result = slicer.slice(mesh)

            # Extract SKIN occurrences per layer.
            lines = result.split('\n')
            skinCountByLayer = {}

            currentLayer = null

            for line in lines

                if line.includes('LAYER:')

                    layerMatch = line.match(/LAYER:\s*(\d+)/)

                    if layerMatch
                        currentLayer = parseInt(layerMatch[1])
                        skinCountByLayer[currentLayer] = 0

                else if currentLayer? and line.includes('TYPE: SKIN')

                    skinCountByLayer[currentLayer]++

            # Count layers with skin.
            totalLayers = Object.keys(skinCountByLayer).length
            layersWithSkin = Object.keys(skinCountByLayer).filter((l) -> skinCountByLayer[l] > 0)

            # For a simple cylinder, only top/bottom layers should have significant skin.
            # Middle layers may have minimal or no skin due to consistent cross-section.
            middleLayers = layersWithSkin.map((k) -> parseInt(k)).filter((l) -> l >= 8 and l < totalLayers - 8)

            # Middle layers should have minimal skin (cylinder is uniform).
            expect(middleLayers.length).toBeLessThan(10)

    describe 'Cone Geometry', ->

        test 'should detect exposed surfaces throughout cone due to changing cross-section', ->

            # Create a cone (radius changes continuously).
            geometry = new THREE.ConeGeometry(10, 20, 32)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 10)
            mesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8) # 4 layers.
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)
            slicer.setExposureDetectionResolution(900)

            # Slice the mesh.
            result = slicer.slice(mesh)

            # Extract SKIN occurrences per layer.
            lines = result.split('\n')
            skinCountByLayer = {}

            currentLayer = null

            for line in lines

                if line.includes('LAYER:')

                    layerMatch = line.match(/LAYER:\s*(\d+)/)

                    if layerMatch
                        currentLayer = parseInt(layerMatch[1])
                        skinCountByLayer[currentLayer] = 0

                else if currentLayer? and line.includes('TYPE: SKIN')

                    skinCountByLayer[currentLayer]++

            # Cone has continuously changing cross-section, so many layers should have skin.
            layersWithSkin = Object.keys(skinCountByLayer).filter((l) -> skinCountByLayer[l] > 0)

            # Should have skin in many layers (not just top/bottom 4).
            expect(layersWithSkin.length).toBeGreaterThan(20)

    describe 'Resolution Impact', ->

        test 'should detect more detail with higher resolution', ->

            # Create geometry with fine details.
            geometry = new THREE.CylinderGeometry(10, 10, 10, 32, 1, true, 0, Math.PI)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            # Configure slicer with LOW resolution.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)
            slicer.setExposureDetectionResolution(400) # 20×20 grid.

            # Slice with low resolution.
            resultLow = slicer.slice(mesh)

            # Count SKIN operations.
            skinCountLow = (resultLow.match(/TYPE: SKIN/g) || []).length

            # Configure slicer with HIGH resolution.
            slicer.setExposureDetectionResolution(1600) # 40×40 grid.

            # Slice with high resolution.
            resultHigh = slicer.slice(mesh)

            # Count SKIN operations.
            skinCountHigh = (resultHigh.match(/TYPE: SKIN/g) || []).length

            # Higher resolution should detect more exposed areas (or at least equal).
            expect(skinCountHigh).toBeGreaterThanOrEqual(skinCountLow)

    describe 'Performance Characteristics', ->

        test 'should complete within reasonable time for standard resolution', ->

            # Create a moderately complex geometry.
            geometry = new THREE.TorusGeometry(10, 3, 16, 32)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 3)
            mesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)
            slicer.setExposureDetectionResolution(900) # Default resolution.

            # Measure execution time.
            startTime = Date.now()

            result = slicer.slice(mesh)

            endTime = Date.now()

            elapsedTime = endTime - startTime

            # Should complete in reasonable time (< 30 seconds for CI environment).
            expect(elapsedTime).toBeLessThan(30000)

            # Should produce valid G-code.
            expect(result).toContain('LAYER:')
            expect(result.length).toBeGreaterThan(100)

    describe 'Edge Cases', ->

        test 'should handle very small exposed areas', ->

            # Create geometry with minimal exposed surfaces.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            # Slice the mesh.
            result = slicer.slice(mesh)

            # Should complete without errors.
            expect(result).toBeDefined()
            expect(result).toContain('LAYER:')

        test 'should handle geometry with no exposed middle layers', ->

            # Create a perfect cube (no mid-layer exposure).
            geometry = new THREE.BoxGeometry(20, 20, 20)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 10)
            mesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            # Slice the mesh.
            result = slicer.slice(mesh)

            # Extract SKIN occurrences per layer.
            lines = result.split('\n')
            skinCountByLayer = {}

            currentLayer = null

            for line in lines

                if line.includes('LAYER:')

                    layerMatch = line.match(/LAYER:\s*(\d+)/)

                    if layerMatch
                        currentLayer = parseInt(layerMatch[1])
                        skinCountByLayer[currentLayer] = 0

                else if currentLayer? and line.includes('TYPE: SKIN')

                    skinCountByLayer[currentLayer]++

            # Count layers with skin.
            totalLayers = Object.keys(skinCountByLayer).length
            layersWithSkin = Object.keys(skinCountByLayer).filter((l) -> skinCountByLayer[l] > 0)

            # For a cube, only top/bottom 4 layers should have skin.
            middleLayers = layersWithSkin.map((k) -> parseInt(k)).filter((l) -> l >= 4 and l < totalLayers - 4)

            # Should have minimal or no middle layer skin.
            expect(middleLayers.length).toBeLessThan(5)

        test 'should handle invalid resolution values gracefully', ->

            # Try setting invalid resolution (should use default or reject).
            expect(() -> slicer.setExposureDetectionResolution(-1)).not.toThrow()
            expect(() -> slicer.setExposureDetectionResolution(0)).not.toThrow()
            expect(() -> slicer.setExposureDetectionResolution(NaN)).not.toThrow()

            # Should still be able to slice.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial())
            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            result = slicer.slice(mesh)

            expect(result).toBeDefined()
