# Tests for smart wipe nozzle utilities

wipeUtils = require('./wipe')

describe 'Smart Wipe Nozzle', ->

    describe 'calculateSmartWipeDirection', ->

        test 'should wipe left when near right edge', ->

            lastPosition = { x: 5, y: 0, z: 5 }
            meshBounds = { min: { x: -5, y: -5 }, max: { x: 5, y: 5 } }
            centerOffsetX = 100
            centerOffsetY = 100

            # Last position in build plate coordinates: (105, 100)
            # Mesh bounds in build plate coordinates: (95, 95) to (105, 105)
            # Near right edge, should wipe right (positive X).

            direction = wipeUtils.calculateSmartWipeDirection(
                lastPosition,
                meshBounds,
                centerOffsetX,
                centerOffsetY,
                10
            )

            expect(direction.x).toBeGreaterThan(0) # Should move in positive X.
            expect(direction.y).toBe(0)

        test 'should wipe right when near left edge', ->

            lastPosition = { x: -5, y: 0, z: 5 }
            meshBounds = { min: { x: -5, y: -5 }, max: { x: 5, y: 5 } }
            centerOffsetX = 100
            centerOffsetY = 100

            # Last position in build plate coordinates: (95, 100)
            # Mesh bounds in build plate coordinates: (95, 95) to (105, 105)
            # At left edge, should wipe left (negative X).

            direction = wipeUtils.calculateSmartWipeDirection(
                lastPosition,
                meshBounds,
                centerOffsetX,
                centerOffsetY,
                10
            )

            expect(direction.x).toBeLessThan(0) # Should move in negative X.
            expect(direction.y).toBe(0)

        test 'should wipe forward when near back edge', ->

            lastPosition = { x: 0, y: 5, z: 5 }
            meshBounds = { min: { x: -5, y: -5 }, max: { x: 5, y: 5 } }
            centerOffsetX = 100
            centerOffsetY = 100

            # Last position in build plate coordinates: (100, 105)
            # Mesh bounds in build plate coordinates: (95, 95) to (105, 105)
            # At back edge, should wipe backward (positive Y).

            direction = wipeUtils.calculateSmartWipeDirection(
                lastPosition,
                meshBounds,
                centerOffsetX,
                centerOffsetY,
                10
            )

            expect(direction.x).toBe(0)
            expect(direction.y).toBeGreaterThan(0) # Should move in positive Y.

        test 'should wipe backward when near front edge', ->

            lastPosition = { x: 0, y: -5, z: 5 }
            meshBounds = { min: { x: -5, y: -5 }, max: { x: 5, y: 5 } }
            centerOffsetX = 100
            centerOffsetY = 100

            # Last position in build plate coordinates: (100, 95)
            # Mesh bounds in build plate coordinates: (95, 95) to (105, 105)
            # At front edge, should wipe forward (negative Y).

            direction = wipeUtils.calculateSmartWipeDirection(
                lastPosition,
                meshBounds,
                centerOffsetX,
                centerOffsetY,
                10
            )

            expect(direction.x).toBe(0)
            expect(direction.y).toBeLessThan(0) # Should move in negative Y.

        test 'should fall back to simple wipe when no data available', ->

            direction = wipeUtils.calculateSmartWipeDirection(null, null, 0, 0, 10)

            expect(direction.x).toBe(5)
            expect(direction.y).toBe(5)

        test 'should include backoff distance', ->

            lastPosition = { x: 5, y: 0, z: 5 }
            meshBounds = { min: { x: -5, y: -5 }, max: { x: 5, y: 5 } }
            centerOffsetX = 100
            centerOffsetY = 100

            # Distance from position (105) to right edge (105) = 0
            # Should move at least backoff distance (3mm) beyond boundary.

            direction = wipeUtils.calculateSmartWipeDirection(
                lastPosition,
                meshBounds,
                centerOffsetX,
                centerOffsetY,
                10
            )

            expect(direction.x).toBeGreaterThanOrEqual(3) # At least backoff distance.

    describe 'isPointInsideMeshBounds', ->

        test 'should detect point inside bounds', ->

            meshBounds = { min: { x: -5, y: -5 }, max: { x: 5, y: 5 } }
            centerOffsetX = 100
            centerOffsetY = 100

            # Bounds in build plate coordinates: (95, 95) to (105, 105)

            isInside = wipeUtils.isPointInsideMeshBounds(100, 100, meshBounds, centerOffsetX, centerOffsetY)

            expect(isInside).toBe(true)

        test 'should detect point outside bounds', ->

            meshBounds = { min: { x: -5, y: -5 }, max: { x: 5, y: 5 } }
            centerOffsetX = 100
            centerOffsetY = 100

            # Bounds in build plate coordinates: (95, 95) to (105, 105)

            isInside = wipeUtils.isPointInsideMeshBounds(90, 90, meshBounds, centerOffsetX, centerOffsetY)

            expect(isInside).toBe(false)

        test 'should handle null bounds', ->

            isInside = wipeUtils.isPointInsideMeshBounds(100, 100, null, 0, 0)

            expect(isInside).toBe(false)
