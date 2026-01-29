# Tests for slice helpers module

helpers = require('./helpers')

describe 'Slice Helpers', ->

    describe 'calculatePathCentroid', ->

        test 'should calculate centroid of a square path', ->

            path = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            centroid = helpers.calculatePathCentroid(path)

            expect(centroid).toBeDefined()
            expect(centroid.x).toBe(5)
            expect(centroid.y).toBe(5)

        test 'should return null for empty path', ->

            result = helpers.calculatePathCentroid([])

            expect(result).toBeNull()

    describe 'calculateDistance', ->

        test 'should calculate distance between two points', ->

            pointA = { x: 0, y: 0 }
            pointB = { x: 3, y: 4 }

            distance = helpers.calculateDistance(pointA, pointB)

            expect(distance).toBe(5)

        test 'should return large number for null points', ->

            distance = helpers.calculateDistance(null, { x: 0, y: 0 })

            expect(distance).toBe(1000000)

    describe 'detectNesting', ->

        test 'should detect simple outer boundary (level 0)', ->

            paths = [
                [
                    { x: 0, y: 0 }
                    { x: 10, y: 0 }
                    { x: 10, y: 10 }
                    { x: 0, y: 10 }
                ]
            ]

            result = helpers.detectNesting(paths)

            expect(result.pathNestingLevel).toEqual([0])
            expect(result.pathIsHole).toEqual([false])

        test 'should detect hole inside boundary (level 1)', ->

            paths = [
                # Outer boundary
                [
                    { x: 0, y: 0 }
                    { x: 20, y: 0 }
                    { x: 20, y: 20 }
                    { x: 0, y: 20 }
                ]
                # Inner hole
                [
                    { x: 5, y: 5 }
                    { x: 15, y: 5 }
                    { x: 15, y: 15 }
                    { x: 5, y: 15 }
                ]
            ]

            result = helpers.detectNesting(paths)

            expect(result.pathNestingLevel).toEqual([0, 1])
            expect(result.pathIsHole).toEqual([false, true])

    describe 'filterHolesByNestingLevel', ->

        test 'should filter direct children only', ->

            holeWalls = [
                [{ x: 5, y: 5 }]   # Level 1 hole
                [{ x: 10, y: 10 }] # Level 2 hole
                [{ x: 15, y: 15 }] # Level 1 hole
            ]
            nestingLevels = [1, 2, 1]
            parentLevel = 0

            result = helpers.filterHolesByNestingLevel(holeWalls, nestingLevels, parentLevel)

            expect(result.length).toBe(2)
            expect(result[0]).toEqual([{ x: 5, y: 5 }])
            expect(result[1]).toEqual([{ x: 15, y: 15 }])

    describe 'sortByNearestNeighbor', ->

        test 'should sort paths by proximity', ->

            paths = [
                [{ x: 100, y: 100 }] # Far from origin
                [{ x: 10, y: 10 }]   # Medium distance
                [{ x: 5, y: 5 }]     # Closest
            ]
            indices = [0, 1, 2]
            lastPosition = { x: 0, y: 0 }

            result = helpers.sortByNearestNeighbor(indices, paths, lastPosition)

            expect(result).toEqual([2, 1, 0]) # Sorted by distance
