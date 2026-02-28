# Tests for exposure detection of cavities and holes (Issue: dome cavity detection).

Polyslice = require('../../../index')

THREE = require('three')

{ Polytree } = require('@jgphilpott/polytree')

describe 'Exposure Detection - Cavity and Hole Detection', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice({progressCallback: null})

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

                    layerMatch = line.match(/LAYER:\s*(\d+) of/)

                    if layerMatch
                        currentLayer = parseInt(layerMatch[1])

                else if currentLayer? and line.includes('TYPE: SKIN')

                    skinLayersSet.add(currentLayer)

            skinLayers = Array.from(skinLayersSet).sort((a, b) -> a - b)

            # Total layers: 60 (12mm / 0.2mm = 60 layers).
            # Expected skin layers (1-based numbering):
            # - Bottom 4 layers (1-4): absolute bottom.
            # - Top 4 layers (57-60): absolute top.
            # - Middle layers with cavity (approximately 5-51): adaptive skin above cavity.
            # The cavity extends from Z=0 to Z=10mm (layers 1-50).
            # Layers above the cavity should detect exposure from below.
            expect(skinLayers.length).toBeGreaterThan(20)

            # Verify bottom layers have skin.
            expect(skinLayers).toContain(1)
            expect(skinLayers).toContain(2)
            expect(skinLayers).toContain(3)
            expect(skinLayers).toContain(4)

            # Verify top layers have skin.
            expect(skinLayers).toContain(57)
            expect(skinLayers).toContain(58)
            expect(skinLayers).toContain(59)
            expect(skinLayers).toContain(60)

            # Verify middle layers with cavity have adaptive skin.
            # Layers around the cavity (e.g., 11-51) should have skin.
            middleLayersWithSkin = skinLayers.filter((l) -> l >= 11 and l <= 51)

            expect(middleLayersWithSkin.length).toBeGreaterThan(10)

    describe 'Through-Hole Detection', ->

        test 'should NOT generate hole skin walls for vertical through-holes on middle layers', ->

            # Create a sheet with a cylindrical hole through it (vertical hole).
            # Middle layers should NOT get hole skin walls because the hole goes straight through.
            # Only top and bottom layers should have skin for through-holes.
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

                    layerMatch = line.match(/LAYER:\s*(\d+) of/)

                    if layerMatch
                        currentLayer = parseInt(layerMatch[1])

                else if currentLayer? and line.includes('TYPE: SKIN')

                    skinLayersSet.add(currentLayer)

            skinLayers = Array.from(skinLayersSet).sort((a, b) -> a - b)

            # Total layers: 25 (5mm / 0.2mm = 25 layers).
            # Expected skin layers (CORRECTED, 1-based numbering):
            # - Bottom 4 layers (1-4): absolute bottom - HAVE skin.
            # - Top 4 layers (22-25): absolute top - HAVE skin.
            # - Middle layers (5-21): NO skin (vertical hole, not exposed).
            # Total: 8 layers with skin (4 bottom + 4 top).
            expect(skinLayers.length).toBe(8)

            # Verify bottom layers have skin.
            expect(skinLayers).toContain(1)
            expect(skinLayers).toContain(2)
            expect(skinLayers).toContain(3)
            expect(skinLayers).toContain(4)

            # Verify middle layers DO NOT have skin (through-holes don't expose middle layers).
            middleLayersWithSkin = skinLayers.filter((l) -> l >= 5 and l <= 21)

            expect(middleLayersWithSkin.length).toBe(0)

            # Verify top layers have skin.
            expect(skinLayers).toContain(22)
            expect(skinLayers).toContain(23)
            expect(skinLayers).toContain(24)
            expect(skinLayers).toContain(25)

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
            # Cavity box: more skin due to exposed areas from cavity.
            # UPDATED expectations after fixing vertical hole bug:
            # - Solid: 8 skin sections (4 bottom + 4 top layers only)
            # - Cavity: ~30-40 skin sections (bottom, top, plus exposed areas above cavity)
            # - Ratio: ~4-5x (cavity has significantly more skin than solid)
            expect(solidSkinCount).toBeLessThan(15)

            expect(cavitySkinCount).toBeGreaterThan(25)

            expect(cavitySkinCount).toBeGreaterThan(solidSkinCount * 3)

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

                    layerMatch = line.match(/LAYER:\s*(\d+) of/)

                    if layerMatch
                        currentLayer = parseInt(layerMatch[1])

                else if currentLayer? and line.includes('TYPE: SKIN')

                    skinLayersSet.add(currentLayer)

            skinLayers = Array.from(skinLayersSet).sort((a, b) -> a - b)

            # Should only have skin on top and bottom 4 layers (no adaptive skin).
            expect(skinLayers.length).toBeLessThanOrEqual(8)

            # Verify only top and bottom layers have skin (1-based numbering).
            for layer in skinLayers

                expect(layer < 5 or layer >= 57).toBe(true)

    describe 'Skin Infill Generation with Covering Regions', ->

        test 'should generate skin infill even when covering regions are present', ->

            # Regression test for issue where skin patches above dome had walls but no infill.
            # This test ensures that covering regions (used for exposure detection) don't prevent
            # skin infill from being generated.
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

            # Slice the mesh.
            result = slicer.slice(finalMesh)

            # Count skin wall and skin infill occurrences.
            skinWallCount = (result.match(/Moving to skin wall/g) || []).length
            skinInfillCount = (result.match(/Moving to skin infill line/g) || []).length

            # Verify that skin sections have both walls AND infill.
            # Before the fix, skin patches would have walls but no infill.
            expect(skinWallCount).toBeGreaterThan(0)
            expect(skinInfillCount).toBeGreaterThan(0)

            # The ratio of infill lines to walls should be reasonable.
            # Skin infill should have many more lines than walls (typically 10-50x).
            expect(skinInfillCount).toBeGreaterThan(skinWallCount * 5)

            # Verify that skin sections actually generate extrusion moves (not just travel).
            # This confirms that infill is being laid down, not just walls.
            lines = result.split('\n')
            inSkinSection = false
            skinSectionHasExtrusion = false
            skinSectionsWithExtrusion = 0

            for line in lines

                if line.includes('TYPE: SKIN')

                    # If we were tracking a previous skin section and it had extrusion, count it.
                    if inSkinSection and skinSectionHasExtrusion
                        skinSectionsWithExtrusion += 1

                    # Start tracking new skin section.
                    inSkinSection = true
                    skinSectionHasExtrusion = false

                else if line.includes('TYPE:')

                    # End of skin section.
                    if inSkinSection and skinSectionHasExtrusion
                        skinSectionsWithExtrusion += 1

                    inSkinSection = false
                    skinSectionHasExtrusion = false

                else if inSkinSection and line.includes(' E')

                    # Found extrusion command in skin section.
                    skinSectionHasExtrusion = true

            # Check the last section if needed.
            if inSkinSection and skinSectionHasExtrusion
                skinSectionsWithExtrusion += 1

            # Most skin sections should have extrusion (walls + infill).
            # At minimum, we should have many skin sections with extrusion.
            expect(skinSectionsWithExtrusion).toBeGreaterThan(20)

    describe 'Fully Covered Areas Exclusion', ->

        test 'should NOT generate skin infill in fully covered areas (Pyramid case)', ->

            # Test for issue where skin patches at the top of pyramid slabs had infill
            # in the center area that is fully covered both above and below.
            # This test ensures that fully covered areas are excluded from skin infill.
            # Create a simplified pyramid: 5x5 base slab + 3x3 top slab.
            cubeSize = 10

            baseSlab = new THREE.BoxGeometry(5 * cubeSize, 5 * cubeSize, cubeSize)
            baseSlabMesh = new THREE.Mesh(baseSlab, new THREE.MeshBasicMaterial())

            baseSlabMesh.position.set(0, 0, 0)
            baseSlabMesh.updateMatrixWorld()

            topSlab = new THREE.BoxGeometry(3 * cubeSize, 3 * cubeSize, cubeSize)
            topSlabMesh = new THREE.Mesh(topSlab, new THREE.MeshBasicMaterial())

            topSlabMesh.position.set(0, 0, cubeSize)
            topSlabMesh.updateMatrixWorld()

            # Unite the two slabs to create a simple pyramid.
            pyramidMesh = await Polytree.unite(baseSlabMesh, topSlabMesh)

            finalMesh = new THREE.Mesh(pyramidMesh.geometry, pyramidMesh.material)
            finalMesh.position.set(0, 0, 0)
            finalMesh.updateMatrixWorld()

            # Configure slicer with exposure detection enabled.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8)  # 4 skin layers.
            slicer.setShellWallThickness(0.8)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            # Slice the mesh.
            result = slicer.slice(finalMesh)

            # The base slab is 10mm tall = 50 layers (0-49).
            # The top slab is 10mm tall = 50 layers (51-100).
            # Top 4 layers of base slab (47-50) should have adaptive skin.
            # The center 3x3 area (covered by top slab above) should NOT have skin infill.
            # The outer ring (exposed area) should have skin infill.
            # Parse the G-code to find layer 47 skin section.
            lines = result.split('\n')
            layer47Started = false
            layer48Started = false
            layer47SkinInfillLines = []

            for line in lines

                if line.includes('LAYER: 47 of')

                    layer47Started = true

                else if line.includes('LAYER: 48 of')

                    layer48Started = true
                    break

                else if layer47Started and line.includes('Moving to skin infill line')

                    layer47SkinInfillLines.push(line)

            # Verify that layer 47 has skin infill.
            expect(layer47SkinInfillLines.length).toBeGreaterThan(0)

            # Extract X and Y coordinates from skin infill lines.
            # Check that NO infill lines are in the fully covered center area (95-125).
            # The 3x3 slab covers X=[95, 125] and Y=[95, 125] (approximately).
            # Skin infill should only be in the outer ring, not the center.
            centerInfillCount = 0

            for line in layer47SkinInfillLines

                # Extract X and Y coordinates from the line.
                # Format: "G0 X... Y... Z... F...; Moving to skin infill line"
                xMatch = line.match(/X([\d.]+)/)
                yMatch = line.match(/Y([\d.]+)/)

                if xMatch and yMatch

                    xCoord = parseFloat(xMatch[1])
                    yCoord = parseFloat(yMatch[1])

                    # Check if this coordinate is in the center area (95-125).
                    # Allow small tolerance for rounding.
                    if xCoord > 95 and xCoord < 125 and yCoord > 95 and yCoord < 125

                        centerInfillCount += 1

            # Verify that NO skin infill lines are in the fully covered center area.
            # All skin infill should be in the exposed outer ring only.
            expect(centerInfillCount).toBe(0)

            # Verify that skin infill exists in the outer ring (exposed area).
            # This ensures we're not accidentally excluding all infill.
            expect(layer47SkinInfillLines.length).toBeGreaterThan(100)

        test 'should generate skin walls for fully covered regions', ->

            # Test that fully covered regions get skin wall perimeters.
            # Create a pyramid with overlapping slabs to create fully covered areas.
            cubeSize = 10

            baseSlab = new THREE.BoxGeometry(5 * cubeSize, 5 * cubeSize, cubeSize)
            baseSlabMesh = new THREE.Mesh(baseSlab, new THREE.MeshBasicMaterial())
            baseSlabMesh.position.set(0, 0, 0)
            baseSlabMesh.updateMatrixWorld()

            topSlab = new THREE.BoxGeometry(3 * cubeSize, 3 * cubeSize, cubeSize)
            topSlabMesh = new THREE.Mesh(topSlab, new THREE.MeshBasicMaterial())
            topSlabMesh.position.set(0, 0, cubeSize)
            topSlabMesh.updateMatrixWorld()

            pyramidMesh = await Polytree.unite(baseSlabMesh, topSlabMesh)

            finalMesh = new THREE.Mesh(pyramidMesh.geometry, pyramidMesh.material)
            finalMesh.position.set(0, 0, 0)
            finalMesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8)
            slicer.setShellWallThickness(0.8)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            result = slicer.slice(finalMesh)

            # Layer 47 should have skin type sections for both exposed areas and covered regions.
            # Parse G-code to count skin sections with walls.
            lines = result.split('\n')
            layer47Started = false
            layer48Started = false
            skinSectionCount = 0
            inSkinSection = false

            for line in lines

                if line.includes('LAYER: 47 of')
                    layer47Started = true
                else if line.includes('LAYER: 48 of')
                    layer48Started = true
                    break
                else if layer47Started
                    if line.includes('TYPE: SKIN')
                        inSkinSection = true
                        skinSectionCount += 1
                    else if inSkinSection and line.includes('TYPE:')
                        inSkinSection = false

            # Should have multiple skin sections:
            # 1. For the exposed outer ring
            # 2. For the fully covered center region(s)
            # Expect at least 2 skin sections (may be more depending on how regions are split).
            expect(skinSectionCount).toBeGreaterThanOrEqual(2)

        test 'should generate regular infill inside fully covered region walls', ->

            # Test that regular infill is generated inside fully covered regions.
            cubeSize = 10

            baseSlab = new THREE.BoxGeometry(5 * cubeSize, 5 * cubeSize, cubeSize)
            baseSlabMesh = new THREE.Mesh(baseSlab, new THREE.MeshBasicMaterial())
            baseSlabMesh.position.set(0, 0, 0)
            baseSlabMesh.updateMatrixWorld()

            topSlab = new THREE.BoxGeometry(3 * cubeSize, 3 * cubeSize, cubeSize)
            topSlabMesh = new THREE.Mesh(topSlab, new THREE.MeshBasicMaterial())
            topSlabMesh.position.set(0, 0, cubeSize)
            topSlabMesh.updateMatrixWorld()

            pyramidMesh = await Polytree.unite(baseSlabMesh, topSlabMesh)

            finalMesh = new THREE.Mesh(pyramidMesh.geometry, pyramidMesh.material)
            finalMesh.position.set(0, 0, 0)
            finalMesh.updateMatrixWorld()

            # Configure slicer with infill enabled.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8)
            slicer.setShellWallThickness(0.8)
            slicer.setInfillDensity(20)  # Enable infill.
            slicer.setInfillPattern('grid')
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            result = slicer.slice(finalMesh)

            # Layer 47 should have regular infill in the covered center area.
            # Parse G-code to find infill extrusion lines in TYPE: FILL sections.
            lines = result.split('\n')
            layer47Started = false
            layer48Started = false
            inFillSection = false
            layer47FillLines = []

            for line in lines

                if line.includes('LAYER: 47 of')
                    layer47Started = true
                else if line.includes('LAYER: 48 of')
                    layer48Started = true
                    break
                else if layer47Started
                    if line.includes('TYPE: FILL')
                        inFillSection = true
                    else if line.includes('TYPE:')
                        inFillSection = false
                    else if inFillSection and line.includes('G1') and line.includes(' E')
                        # This is an extrusion line in a fill section.
                        layer47FillLines.push(line)

            # Count infill lines in the covered center area (95-125 in X and Y).
            centerFillCount = 0

            for line in layer47FillLines

                xMatch = line.match(/X([\d.]+)/)
                yMatch = line.match(/Y([\d.]+)/)

                if xMatch and yMatch

                    xCoord = parseFloat(xMatch[1])
                    yCoord = parseFloat(yMatch[1])

                    # Check if in center covered area.
                    if xCoord > 95 and xCoord < 125 and yCoord > 95 and yCoord < 125
                        centerFillCount += 1

            # Verify that regular infill IS generated in the covered center area.
            # This ensures structural support in fully covered regions.
            expect(centerFillCount).toBeGreaterThan(0)

            # Also verify that we found some fill lines total.
            expect(layer47FillLines.length).toBeGreaterThan(0)

        test 'should maintain proper gap between skin walls and infill in fully covered regions', ->

            # Test that the gap between fully covered region walls and infill is correct.
            cubeSize = 10

            baseSlab = new THREE.BoxGeometry(5 * cubeSize, 5 * cubeSize, cubeSize)
            baseSlabMesh = new THREE.Mesh(baseSlab, new THREE.MeshBasicMaterial())
            baseSlabMesh.position.set(0, 0, 0)
            baseSlabMesh.updateMatrixWorld()

            topSlab = new THREE.BoxGeometry(3 * cubeSize, 3 * cubeSize, cubeSize)
            topSlabMesh = new THREE.Mesh(topSlab, new THREE.MeshBasicMaterial())
            topSlabMesh.position.set(0, 0, cubeSize)
            topSlabMesh.updateMatrixWorld()

            pyramidMesh = await Polytree.unite(baseSlabMesh, topSlabMesh)

            finalMesh = new THREE.Mesh(pyramidMesh.geometry, pyramidMesh.material)
            finalMesh.position.set(0, 0, 0)
            finalMesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8)
            slicer.setShellWallThickness(0.8)
            slicer.setNozzleDiameter(0.4)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('grid')
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            result = slicer.slice(finalMesh)

            # The covered region boundary is at the 3x3 slab edge.
            # The 3x3 slab covers X=[95, 125], Y=[95, 125].
            # With user's checkpoint setting infillGap=0, the gap is just skinWallInset.
            # Parse layer 47 to find fill lines near the covered region boundary.
            lines = result.split('\n')
            layer47Started = false
            layer48Started = false
            inFillSection = false
            layer47FillLines = []

            for line in lines

                if line.includes('LAYER: 47 of')
                    layer47Started = true
                else if line.includes('LAYER: 48 of')
                    layer48Started = true
                    break
                else if layer47Started
                    if line.includes('TYPE: FILL')
                        inFillSection = true
                    else if line.includes('TYPE:')
                        inFillSection = false
                    else if inFillSection and line.includes('G1') and line.includes(' E')
                        layer47FillLines.push(line)

            # Find infill lines closest to the covered region boundary (X or Y near 95 or 125).
            minDistFromBoundary = Infinity

            for line in layer47FillLines

                xMatch = line.match(/X([\d.]+)/)
                yMatch = line.match(/Y([\d.]+)/)

                if xMatch and yMatch

                    xCoord = parseFloat(xMatch[1])
                    yCoord = parseFloat(yMatch[1])

                    # Check distance from boundaries.
                    distFromLeft = Math.abs(xCoord - 95)
                    distFromRight = Math.abs(xCoord - 125)
                    distFromBottom = Math.abs(yCoord - 95)
                    distFromTop = Math.abs(yCoord - 125)

                    minDist = Math.min(distFromLeft, distFromRight, distFromBottom, distFromTop)

                    if minDist < minDistFromBoundary
                        minDistFromBoundary = minDist

            # With the user's checkpoint (infillGap=0), the gap should be just skinWallInset.
            # skinWallInset = 0.4mm (nozzleDiameter).
            # The test should verify that infill respects this gap.
            # Allow tolerance for path generation and discretization.
            expectedMinGap = 0.3  # Should be at least some gap from boundary.

            # Verify that infill lines don't get too close to the boundary.
            expect(minDistFromBoundary).toBeGreaterThan(expectedMinGap)

        test 'should use covered area boundaries directly without offset for exclusion', ->

            # Test that covered area boundaries are used as-is for skin infill exclusion.
            # This verifies the fix where we removed the double offset issue.
            cubeSize = 10

            baseSlab = new THREE.BoxGeometry(5 * cubeSize, 5 * cubeSize, cubeSize)
            baseSlabMesh = new THREE.Mesh(baseSlab, new THREE.MeshBasicMaterial())
            baseSlabMesh.position.set(0, 0, 0)
            baseSlabMesh.updateMatrixWorld()

            topSlab = new THREE.BoxGeometry(3 * cubeSize, 3 * cubeSize, cubeSize)
            topSlabMesh = new THREE.Mesh(topSlab, new THREE.MeshBasicMaterial())
            topSlabMesh.position.set(0, 0, cubeSize)
            topSlabMesh.updateMatrixWorld()

            pyramidMesh = await Polytree.unite(baseSlabMesh, topSlabMesh)

            finalMesh = new THREE.Mesh(pyramidMesh.geometry, pyramidMesh.material)
            finalMesh.position.set(0, 0, 0)
            finalMesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8)
            slicer.setShellWallThickness(0.8)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            result = slicer.slice(finalMesh)

            # Parse to verify that NO skin infill appears in the covered center area.
            # The covered area boundary (from layer above) should be used directly
            # as the exclusion zone, preventing any skin infill from entering.
            lines = result.split('\n')
            layer47Started = false
            layer48Started = false
            layer47SkinInfillLines = []

            for line in lines

                if line.includes('LAYER: 47 of')
                    layer47Started = true
                else if line.includes('LAYER: 48 of')
                    layer48Started = true
                    break
                else if layer47Started and line.includes('Moving to skin infill line')
                    layer47SkinInfillLines.push(line)

            # Count infill in covered center area.
            centerInfillCount = 0

            for line in layer47SkinInfillLines

                xMatch = line.match(/X([\d.]+)/)
                yMatch = line.match(/Y([\d.]+)/)

                if xMatch and yMatch

                    xCoord = parseFloat(xMatch[1])
                    yCoord = parseFloat(yMatch[1])

                    # Covered area is approximately X=[95, 125], Y=[95, 125].
                    if xCoord > 95 and xCoord < 125 and yCoord > 95 and yCoord < 125
                        centerInfillCount += 1

            # Verify exact exclusion - no infill in covered area.
            # This confirms that covered area boundaries are used directly without offset.
            expect(centerInfillCount).toBe(0)

            # Verify skin infill exists in exposed areas.
            expect(layer47SkinInfillLines.length).toBeGreaterThan(100)

        test 'should NOT generate extra skin walls for structural arch pillar regions', ->

            # Regression test for the flipped arch issue (layers 22-25).
            # When a model has an arch opening at the top (flipped arch), the arch
            # splits into two separate column paths in the checking layer above.
            # These columns must NOT be treated as "fully covered" interior cavity
            # features, since they touch the outer boundary of the current path.
            # Before the fix, each transition layer generated 3 skin sections
            # (two spurious side patches + one correct center patch).
            # After the fix, each transition layer should generate exactly 1.
            archWidth = 40
            archHeight = 10
            archThickness = 20
            archRadius = 15

            boxGeometry = new THREE.BoxGeometry(archWidth, archHeight, archThickness)
            boxMesh = new THREE.Mesh(boxGeometry, new THREE.MeshBasicMaterial())

            cylGeo = new THREE.CylinderGeometry(archRadius, archRadius, archWidth * 1.25, 48)
            cylMesh = new THREE.Mesh(cylGeo, new THREE.MeshBasicMaterial())
            cylMesh.position.z = -archHeight
            cylMesh.updateMatrixWorld()

            archResult = await Polytree.subtract(boxMesh, cylMesh)
            archMesh = new THREE.Mesh(archResult.geometry, archResult.material)
            archMesh.position.set(0, 0, archThickness / 2)
            archMesh.updateMatrixWorld()

            # Flip the arch so the opening is at the top (solid base at bottom).
            flippedMesh = new THREE.Mesh(archMesh.geometry.clone(), archMesh.material)
            flippedMesh.position.copy(archMesh.position)
            flippedMesh.rotation.y = Math.PI
            flippedMesh.updateMatrixWorld(true)

            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8)
            slicer.setShellWallThickness(0.8)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            result = slicer.slice(flippedMesh)

            # Parse skin sections per layer.
            lines = result.split('\n')
            skinCountByLayer = {}
            currentLayer = null

            for line in lines

                if line.includes('LAYER:')

                    layerMatch = line.match(/LAYER:\s*(\d+) of/)

                    if layerMatch
                        currentLayer = parseInt(layerMatch[1])

                else if currentLayer? and line.includes('TYPE: SKIN')

                    skinCountByLayer[currentLayer] = (skinCountByLayer[currentLayer] or 0) + 1

            # Layers 22-25 (1-indexed) are the arch transition layers.
            # Each should have exactly 1 skin section (the center arch opening).
            # Before the fix they had 3 (two spurious side patches + one center patch).
            for layerNum in [22, 23, 24, 25]

                expect(skinCountByLayer[layerNum]).toBe(1)

        test 'should handle multiple covered areas on same layer', ->

            # Test that multiple covered areas are all properly excluded.
            cubeSize = 10

            # Create base layer with two separate covered regions.
            baseSlab = new THREE.BoxGeometry(10 * cubeSize, 5 * cubeSize, cubeSize)
            baseSlabMesh = new THREE.Mesh(baseSlab, new THREE.MeshBasicMaterial())
            baseSlabMesh.position.set(0, 0, 0)
            baseSlabMesh.updateMatrixWorld()

            # Two small top slabs creating two covered areas.
            topSlab1 = new THREE.BoxGeometry(2 * cubeSize, 2 * cubeSize, cubeSize)
            topSlabMesh1 = new THREE.Mesh(topSlab1, new THREE.MeshBasicMaterial())
            topSlabMesh1.position.set(-3 * cubeSize, 0, cubeSize)
            topSlabMesh1.updateMatrixWorld()

            topSlab2 = new THREE.BoxGeometry(2 * cubeSize, 2 * cubeSize, cubeSize)
            topSlabMesh2 = new THREE.Mesh(topSlab2, new THREE.MeshBasicMaterial())
            topSlabMesh2.position.set(3 * cubeSize, 0, cubeSize)
            topSlabMesh2.updateMatrixWorld()

            # Unite all three slabs.
            tempMesh = await Polytree.unite(baseSlabMesh, topSlabMesh1)
            pyramidMesh = await Polytree.unite(tempMesh, topSlabMesh2)

            finalMesh = new THREE.Mesh(pyramidMesh.geometry, pyramidMesh.material)
            finalMesh.position.set(0, 0, 0)
            finalMesh.updateMatrixWorld()

            # Configure slicer.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8)
            slicer.setShellWallThickness(0.8)
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            result = slicer.slice(finalMesh)

            # Count skin sections - should have multiple for exposed areas and covered areas.
            skinSectionCount = (result.match(/TYPE: SKIN/g) || []).length

            # Should have skin sections for:
            # 1. Multiple exposed regions between covered areas
            # 2. Each covered region
            # Expect multiple skin sections.
            expect(skinSectionCount).toBeGreaterThan(3)

        test 'should detect fully covered region when smaller region is from BELOW (inverted pyramid)', ->

            # Regression test for inverted pyramid case.
            # When the shape is inverted (small base, large top), the fully covered region
            # comes from below the transition layer, not above.
            # On transition layers, the center area (covered by the small slab below) should
            # be detected as "fully covered" and get a skin wall + regular infill,
            # while the outer ring should get O-shaped skin infill only.
            cubeSize = 10

            # Inverted: small base slab (3x3) at bottom, large top slab (5x5) on top.
            baseSlab = new THREE.BoxGeometry(3 * cubeSize, 3 * cubeSize, cubeSize)
            baseSlabMesh = new THREE.Mesh(baseSlab, new THREE.MeshBasicMaterial())
            baseSlabMesh.position.set(0, 0, 0)
            baseSlabMesh.updateMatrixWorld()

            topSlab = new THREE.BoxGeometry(5 * cubeSize, 5 * cubeSize, cubeSize)
            topSlabMesh = new THREE.Mesh(topSlab, new THREE.MeshBasicMaterial())
            topSlabMesh.position.set(0, 0, cubeSize)
            topSlabMesh.updateMatrixWorld()

            invertedMesh = await Polytree.unite(baseSlabMesh, topSlabMesh)

            finalMesh = new THREE.Mesh(invertedMesh.geometry, invertedMesh.material)
            finalMesh.position.set(0, 0, 0)
            finalMesh.updateMatrixWorld()

            # Configure slicer with exposure detection enabled.
            slicer.setLayerHeight(0.2)
            slicer.setShellSkinThickness(0.8)  # 4 skin layers.
            slicer.setShellWallThickness(0.8)
            slicer.setInfillDensity(20)
            slicer.setInfillPattern('grid')
            slicer.setVerbose(true)
            slicer.setAutohome(false)
            slicer.setExposureDetection(true)

            result = slicer.slice(finalMesh)

            # The base slab is 10mm tall = 50 layers (1-50).
            # The top slab is 10mm tall = 50 layers (51-100).
            # First 4 layers of top slab (51-54) should have adaptive skin.
            # Center 3x3 area (covered by small slab below) should NOT have skin infill.
            # Outer ring (exposed area) should have skin infill.
            # Build plate center = 110x110 (220x220 bed).
            # 3x3 slab covers X=[95,125], Y=[95,125].
            # 5x5 slab covers X=[85,135], Y=[85,135].
            lines = result.split('\n')
            layer51Started = false
            layer51SkinInfillLines = []
            layer51FillLines = []
            inFillSection = false

            for line in lines

                if line.includes('LAYER: 51 of')
                    layer51Started = true
                    inFillSection = false
                else if line.includes('LAYER: 52 of')
                    break
                else if layer51Started
                    if line.includes('TYPE: FILL')
                        inFillSection = true
                    else if line.includes('TYPE:')
                        inFillSection = false

                    if line.includes('Moving to skin infill line')
                        layer51SkinInfillLines.push(line)
                    else if inFillSection and line.includes('G1') and line.includes(' E')
                        layer51FillLines.push(line)

            # Verify that layer 51 has skin infill (outer ring exposed area).
            expect(layer51SkinInfillLines.length).toBeGreaterThan(0)

            # Verify NO skin infill lines are in the fully covered center area (95-125).
            # The 3x3 slab below covers X=[95,125] and Y=[95,125].
            # Skin infill should only be in the exposed outer ring, not the center.
            centerSkinInfillCount = 0

            for line in layer51SkinInfillLines

                xMatch = line.match(/X([\d.]+)/)
                yMatch = line.match(/Y([\d.]+)/)

                if xMatch and yMatch

                    xCoord = parseFloat(xMatch[1])
                    yCoord = parseFloat(yMatch[1])

                    if xCoord > 95 and xCoord < 125 and yCoord > 95 and yCoord < 125
                        centerSkinInfillCount += 1

            expect(centerSkinInfillCount).toBe(0)

            # Verify that regular infill IS generated in the covered center area.
            # This ensures structural support in fully covered regions.
            centerFillCount = 0

            for line in layer51FillLines

                xMatch = line.match(/X([\d.]+)/)
                yMatch = line.match(/Y([\d.]+)/)

                if xMatch and yMatch

                    xCoord = parseFloat(xMatch[1])
                    yCoord = parseFloat(yMatch[1])

                    if xCoord > 95 and xCoord < 125 and yCoord > 95 and yCoord < 125
                        centerFillCount += 1

            expect(centerFillCount).toBeGreaterThan(0)
