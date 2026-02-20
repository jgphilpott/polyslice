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
