# Tests for normal support generation sub-module.

normalSupport = require('./normal')
THREE = require('three')

describe 'Normal Support Module', ->

    describe 'detectOverhangs', ->

        test 'should detect overhangs on horizontal downward-facing surfaces', ->

            # Create a simple box that's elevated (has underside that needs support).
            geometry = new THREE.BoxGeometry(10, 10, 10)
            geometry.computeVertexNormals() # Required for detection.
            mesh = new THREE.Mesh(geometry)
            mesh.position.set(0, 0, 15) # Elevated 15mm above build plate.
            mesh.updateMatrixWorld()

            overhangs = normalSupport.detectOverhangs(mesh, 45, 0)

            # Should detect the bottom face of the box as an overhang.
            expect(overhangs.length).toBeGreaterThan(0)

        test 'should respect support threshold angle', ->

            # Create a simple box that's elevated.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            geometry.computeVertexNormals() # Required for detection.
            mesh = new THREE.Mesh(geometry)
            mesh.position.set(0, 0, 15) # Elevated 15mm above build plate.
            mesh.updateMatrixWorld()

            # With threshold 0°, should detect all downward faces.
            overhangs0 = normalSupport.detectOverhangs(mesh, 0, 0)
            expect(overhangs0.length).toBeGreaterThan(0)

            # With threshold 90°, should detect nothing (no overhangs).
            overhangs90 = normalSupport.detectOverhangs(mesh, 90, 0)
            expect(overhangs90.length).toBe(0)

    describe 'groupAdjacentFaces', ->

        test 'should group adjacent faces that share edges', ->

            # Create two triangular faces that share an edge.
            overhangFaces = [
                {
                    faceIndex: 0
                    vertices: [
                        { x: 0, y: 0, z: 0 }
                        { x: 1, y: 0, z: 0 }
                        { x: 0, y: 1, z: 0 }
                    ]
                    centerX: 0.33
                    centerY: 0.33
                    centerZ: 0
                }
                {
                    faceIndex: 1
                    vertices: [
                        { x: 1, y: 0, z: 0 }
                        { x: 1, y: 1, z: 0 }
                        { x: 0, y: 1, z: 0 }
                    ]
                    centerX: 0.67
                    centerY: 0.67
                    centerZ: 0
                }
            ]

            regions = normalSupport.groupAdjacentFaces(overhangFaces)

            # Should create one region (faces share edge)
            expect(regions.length).toBe(1)
            expect(regions[0].faces.length).toBe(2)

        test 'should keep separate faces that do not share edges', ->

            # Create two triangular faces that do not share edges.
            overhangFaces = [
                {
                    faceIndex: 0
                    vertices: [
                        { x: 0, y: 0, z: 0 }
                        { x: 1, y: 0, z: 0 }
                        { x: 0, y: 1, z: 0 }
                    ]
                    centerX: 0.33
                    centerY: 0.33
                    centerZ: 0
                }
                {
                    faceIndex: 1
                    vertices: [
                        { x: 10, y: 10, z: 0 }
                        { x: 11, y: 10, z: 0 }
                        { x: 10, y: 11, z: 0 }
                    ]
                    centerX: 10.33
                    centerY: 10.33
                    centerZ: 0
                }
            ]

            regions = normalSupport.groupAdjacentFaces(overhangFaces)

            # Should create two separate regions
            expect(regions.length).toBe(2)
            expect(regions[0].faces.length).toBe(1)
            expect(regions[1].faces.length).toBe(1)

    describe 'isPointInsideSolidGeometry', ->

        test 'should use even-odd winding rule for solid detection', ->

            # Create nested paths (structure with hole inside).
            paths = [
                # Outer boundary (structure).
                [
                    { x: 0, y: 0 }
                    { x: 10, y: 0 }
                    { x: 10, y: 10 }
                    { x: 0, y: 10 }
                ]
                # Inner hole.
                [
                    { x: 2, y: 2 }
                    { x: 8, y: 2 }
                    { x: 8, y: 8 }
                    { x: 2, y: 8 }
                ]
            ]

            pathIsHole = [false, true]

            # Point outside everything (count = 0, even → not solid).
            pointOutside = { x: 15, y: 15 }
            resultOutside = normalSupport.isPointInsideSolidGeometry(pointOutside, paths, pathIsHole)
            expect(resultOutside).toBe(false)

            # Point inside outer boundary but outside hole (count = 1, odd → solid).
            pointInOuter = { x: 1, y: 1 }
            resultInOuter = normalSupport.isPointInsideSolidGeometry(pointInOuter, paths, pathIsHole)
            expect(resultInOuter).toBe(true)

            # Point inside hole (count = 2, even → not solid).
            pointInHole = { x: 5, y: 5 }
            resultInHole = normalSupport.isPointInsideSolidGeometry(pointInHole, paths, pathIsHole)
            expect(resultInHole).toBe(false)

    describe 'canGenerateSupportAt', ->

        # Solid layer data helper for tests.
        solidLayerAt = (layerIndex, z, paths) ->
            return {
                layerIndex: layerIndex
                z: z
                paths: paths
                pathIsHole: paths.map(-> false)
            }

        solidSquare = [
            { x: 0, y: 0 }
            { x: 10, y: 0 }
            { x: 10, y: 10 }
            { x: 0, y: 10 }
        ]

        test 'should block support on first layer (layer 0) when solid geometry exists there in buildPlate mode', ->

            # Simulate layer 0 having solid geometry at the point.
            layerSolidRegions = [
                solidLayerAt(0, 0.1, [solidSquare])
            ]

            point = { x: 5, y: 5 }

            # Should be blocked: solid geometry at layer 0 and we are at layer 0.
            result = normalSupport.canGenerateSupportAt(null, point, 0.1, layerSolidRegions, 'buildPlate', 0, 0.2, 0)

            expect(result).toBe(false)

        test 'should allow support on first layer when no solid geometry exists in buildPlate mode', ->

            # Simulate layer 0 having solid geometry but NOT at the test point.
            layerSolidRegions = [
                solidLayerAt(0, 0.1, [solidSquare])
            ]

            # Point outside the solid square.
            point = { x: 20, y: 20 }

            # Should be allowed: no solid geometry at this XY position.
            result = normalSupport.canGenerateSupportAt(null, point, 0.1, layerSolidRegions, 'buildPlate', 0, 0.2, 0)

            expect(result).toBe(true)

        test 'should block support on first layer (layer 0) when solid geometry exists there in everywhere mode', ->

            # Simulate layer 0 having solid geometry at the point.
            layerSolidRegions = [
                solidLayerAt(0, 0.1, [solidSquare])
            ]

            point = { x: 5, y: 5 }

            # Should be blocked: solid geometry at layer 0, minimumSupportZ > currentZ.
            result = normalSupport.canGenerateSupportAt(null, point, 0.1, layerSolidRegions, 'everywhere', 0, 0.2, 0)

            expect(result).toBe(false)

    describe 'isPointInSupportWedge', ->

        # Helper: build a region face with given vertices.
        makeFace = (v0, v1, v2) ->
            return {
                vertices: [
                    { x: v0[0], y: v0[1], z: v0[2] }
                    { x: v1[0], y: v1[1], z: v1[2] }
                    { x: v2[0], y: v2[1], z: v2[2] }
                ]
            }

        test 'should return true when point is below a horizontal overhang face', ->

            # Horizontal face at Z=10, spanning X=0-10, Y=0-10.
            face = makeFace([0, 0, 10], [10, 0, 10], [0, 10, 10])
            faces = [face]
            interfaceGap = 0.3

            # Point at (5, 5) below the face (currentZ=5 → faceZ=10 > 5+0.3=5.3).
            result = normalSupport.isPointInSupportWedge(5, 5, faces, 5, interfaceGap)

            expect(result).toBe(true)

        test 'should return false when point is above a horizontal overhang face', ->

            # Horizontal face at Z=5, spanning X=0-10, Y=0-10.
            face = makeFace([0, 0, 5], [10, 0, 5], [0, 10, 5])
            faces = [face]
            interfaceGap = 0.3

            # Point at (5, 5) above the face (currentZ=8 → faceZ=5, 5 < 8+0.3=8.3).
            result = normalSupport.isPointInSupportWedge(5, 5, faces, 8, interfaceGap)

            expect(result).toBe(false)

        test 'should return true for point below a slanted overhang face', ->

            # Slanted face: Z=0 at Y=10, Z=10 at Y=0 (tilted 45-ish degrees).
            # Triangle spanning X=0-10, Y=0-10, with Z varying with Y.
            face = makeFace([0, 0, 10], [10, 0, 10], [0, 10, 0])
            faces = [face, makeFace([10, 0, 10], [10, 10, 0], [0, 10, 0])]
            interfaceGap = 0.3

            # At (5, 5), the face Z ≈ 5 (midpoint of slant).
            # currentZ=2 → faceZ≈5 > 2+0.3=2.3 → in wedge.
            result = normalSupport.isPointInSupportWedge(5, 5, faces, 2, interfaceGap)

            expect(result).toBe(true)

        test 'should return false for point above a slanted overhang face', ->

            # Slanted face: Z=0 at Y=10, Z=10 at Y=0.
            face = makeFace([0, 0, 10], [10, 0, 10], [0, 10, 0])
            faces = [face, makeFace([10, 0, 10], [10, 10, 0], [0, 10, 0])]
            interfaceGap = 0.3

            # At (5, 5), face Z ≈ 5.
            # currentZ=8 → faceZ≈5, 5 < 8+0.3=8.3 → not in wedge.
            result = normalSupport.isPointInSupportWedge(5, 5, faces, 8, interfaceGap)

            expect(result).toBe(false)

        test 'should return false for point outside any face 2D projection', ->

            # Face at X=0-5, Y=0-5 only.
            face = makeFace([0, 0, 10], [5, 0, 10], [0, 5, 10])
            faces = [face]
            interfaceGap = 0.3

            # Point at (8, 8) is outside the face's 2D projection.
            result = normalSupport.isPointInSupportWedge(8, 8, faces, 2, interfaceGap)

            expect(result).toBe(false)
