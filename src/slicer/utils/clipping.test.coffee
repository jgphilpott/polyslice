# Tests for polygon clipping operations.

clipping = require('./clipping')

describe 'Clipping', ->

    describe 'clipLineToPolygon', ->

        test 'should return full line when completely inside square', ->

            lineStart = { x: 2, y: 5 }
            lineEnd = { x: 8, y: 5 }

            # Square polygon.
            polygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            segments = clipping.clipLineToPolygon(lineStart, lineEnd, polygon)

            expect(segments.length).toBe(1)
            expect(segments[0].start.x).toBeCloseTo(2, 6)
            expect(segments[0].start.y).toBeCloseTo(5, 6)
            expect(segments[0].end.x).toBeCloseTo(8, 6)
            expect(segments[0].end.y).toBeCloseTo(5, 6)

        test 'should clip line that extends outside square', ->

            lineStart = { x: -5, y: 5 }
            lineEnd = { x: 15, y: 5 }

            # Square polygon.
            polygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            segments = clipping.clipLineToPolygon(lineStart, lineEnd, polygon)

            expect(segments.length).toBe(1)
            expect(segments[0].start.x).toBeCloseTo(0, 1)
            expect(segments[0].start.y).toBeCloseTo(5, 1)
            expect(segments[0].end.x).toBeCloseTo(10, 1)
            expect(segments[0].end.y).toBeCloseTo(5, 1)

        test 'should return empty array when line is completely outside', ->

            lineStart = { x: 20, y: 5 }
            lineEnd = { x: 25, y: 5 }

            # Square polygon.
            polygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            segments = clipping.clipLineToPolygon(lineStart, lineEnd, polygon)

            expect(segments.length).toBe(0)

        test 'should clip line to circular polygon approximation', ->

            lineStart = { x: -10, y: 0 }
            lineEnd = { x: 10, y: 0 }

            # Octagon (approximation of circle with radius ~7).
            polygon = [
                { x: 7, y: 0 }
                { x: 5, y: 5 }
                { x: 0, y: 7 }
                { x: -5, y: 5 }
                { x: -7, y: 0 }
                { x: -5, y: -5 }
                { x: 0, y: -7 }
                { x: 5, y: -5 }
            ]

            segments = clipping.clipLineToPolygon(lineStart, lineEnd, polygon)

            # Should have one segment clipped to the octagon.
            expect(segments.length).toBe(1)

            # The clipped segment should be approximately from x=-7 to x=7.
            expect(segments[0].start.x).toBeCloseTo(-7, 1)
            expect(segments[0].end.x).toBeCloseTo(7, 1)
            expect(segments[0].start.y).toBeCloseTo(0, 1)
            expect(segments[0].end.y).toBeCloseTo(0, 1)

        test 'should handle diagonal line across square', ->

            lineStart = { x: -5, y: -5 }
            lineEnd = { x: 15, y: 15 }

            # Square polygon.
            polygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            segments = clipping.clipLineToPolygon(lineStart, lineEnd, polygon)

            expect(segments.length).toBe(1)
            expect(segments[0].start.x).toBeCloseTo(0, 1)
            expect(segments[0].start.y).toBeCloseTo(0, 1)
            expect(segments[0].end.x).toBeCloseTo(10, 1)
            expect(segments[0].end.y).toBeCloseTo(10, 1)

    describe 'clipLineWithHoles', ->

        test 'should return full line when no holes provided', ->

            lineStart = { x: 2, y: 5 }
            lineEnd = { x: 8, y: 5 }

            # Square polygon.
            inclusionPolygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            segments = clipping.clipLineWithHoles(lineStart, lineEnd, inclusionPolygon, [])

            expect(segments.length).toBe(1)
            expect(segments[0].start.x).toBeCloseTo(2, 6)
            expect(segments[0].start.y).toBeCloseTo(5, 6)
            expect(segments[0].end.x).toBeCloseTo(8, 6)
            expect(segments[0].end.y).toBeCloseTo(5, 6)

        test 'should exclude segment completely inside hole', ->

            lineStart = { x: 4.5, y: 5 }
            lineEnd = { x: 5.5, y: 5 }

            # Outer square 0-10.
            inclusionPolygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Inner hole square 4-6.
            holePolygon = [
                { x: 4, y: 4 }
                { x: 6, y: 4 }
                { x: 6, y: 6 }
                { x: 4, y: 6 }
            ]

            segments = clipping.clipLineWithHoles(lineStart, lineEnd, inclusionPolygon, [holePolygon])

            # Line is completely inside hole, should be excluded.
            expect(segments.length).toBe(0)

        test 'should clip line that crosses through hole', ->

            lineStart = { x: 2, y: 5 }
            lineEnd = { x: 8, y: 5 }

            # Outer square 0-10.
            inclusionPolygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Inner hole square 4-6.
            holePolygon = [
                { x: 4, y: 4 }
                { x: 6, y: 4 }
                { x: 6, y: 6 }
                { x: 4, y: 6 }
            ]

            segments = clipping.clipLineWithHoles(lineStart, lineEnd, inclusionPolygon, [holePolygon])

            # Line should be split into two segments: (2,5)-(4,5) and (6,5)-(8,5).
            expect(segments.length).toBe(2)

            # First segment: left side of hole.
            expect(segments[0].start.x).toBeCloseTo(2, 1)
            expect(segments[0].start.y).toBeCloseTo(5, 1)
            expect(segments[0].end.x).toBeCloseTo(4, 1)
            expect(segments[0].end.y).toBeCloseTo(5, 1)

            # Second segment: right side of hole.
            expect(segments[1].start.x).toBeCloseTo(6, 1)
            expect(segments[1].start.y).toBeCloseTo(5, 1)
            expect(segments[1].end.x).toBeCloseTo(8, 1)
            expect(segments[1].end.y).toBeCloseTo(5, 1)

        test 'should handle multiple holes', ->

            lineStart = { x: 1, y: 5 }
            lineEnd = { x: 9, y: 5 }

            # Outer square 0-10.
            inclusionPolygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # First hole at x=2-3.
            hole1 = [
                { x: 2, y: 4 }
                { x: 3, y: 4 }
                { x: 3, y: 6 }
                { x: 2, y: 6 }
            ]

            # Second hole at x=7-8.
            hole2 = [
                { x: 7, y: 4 }
                { x: 8, y: 4 }
                { x: 8, y: 6 }
                { x: 7, y: 6 }
            ]

            segments = clipping.clipLineWithHoles(lineStart, lineEnd, inclusionPolygon, [hole1, hole2])

            # Line should be split into three segments: (1,5)-(2,5), (3,5)-(7,5), and (8,5)-(9,5).
            expect(segments.length).toBe(3)

            # First segment: before first hole.
            expect(segments[0].start.x).toBeCloseTo(1, 1)
            expect(segments[0].end.x).toBeCloseTo(2, 1)

            # Second segment: between holes.
            expect(segments[1].start.x).toBeCloseTo(3, 1)
            expect(segments[1].end.x).toBeCloseTo(7, 1)

            # Third segment: after second hole.
            expect(segments[2].start.x).toBeCloseTo(8, 1)
            expect(segments[2].end.x).toBeCloseTo(9, 1)

        test 'should handle line that does not intersect hole', ->

            lineStart = { x: 2, y: 2 }
            lineEnd = { x: 8, y: 2 }

            # Outer square 0-10.
            inclusionPolygon = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Hole at different Y position.
            holePolygon = [
                { x: 4, y: 6 }
                { x: 6, y: 6 }
                { x: 6, y: 8 }
                { x: 4, y: 8 }
            ]

            segments = clipping.clipLineWithHoles(lineStart, lineEnd, inclusionPolygon, [holePolygon])

            # Line does not intersect hole, should remain intact.
            expect(segments.length).toBe(1)
            expect(segments[0].start.x).toBeCloseTo(2, 1)
            expect(segments[0].start.y).toBeCloseTo(2, 1)
            expect(segments[0].end.x).toBeCloseTo(8, 1)
            expect(segments[0].end.y).toBeCloseTo(2, 1)

        test 'should handle circular hole with torus-like geometry', ->

            lineStart = { x: -10, y: 0 }
            lineEnd = { x: 10, y: 0 }

            # Outer octagon (approximate circle, radius ~7).
            inclusionPolygon = [
                { x: 7, y: 0 }
                { x: 5, y: 5 }
                { x: 0, y: 7 }
                { x: -5, y: 5 }
                { x: -7, y: 0 }
                { x: -5, y: -5 }
                { x: 0, y: -7 }
                { x: 5, y: -5 }
            ]

            # Inner octagon hole (approximate circle, radius ~3).
            holePolygon = [
                { x: 3, y: 0 }
                { x: 2, y: 2 }
                { x: 0, y: 3 }
                { x: -2, y: 2 }
                { x: -3, y: 0 }
                { x: -2, y: -2 }
                { x: 0, y: -3 }
                { x: 2, y: -2 }
            ]

            segments = clipping.clipLineWithHoles(lineStart, lineEnd, inclusionPolygon, [holePolygon])

            # Line should be split into two segments: left side and right side of the hole.
            # Expected: approximately (-7,0) to (-3,0) and (3,0) to (7,0).
            expect(segments.length).toBe(2)

            # First segment: left side.
            expect(segments[0].start.x).toBeCloseTo(-7, 1)
            expect(segments[0].end.x).toBeCloseTo(-3, 1)

            # Second segment: right side.
            expect(segments[1].start.x).toBeCloseTo(3, 1)
            expect(segments[1].end.x).toBeCloseTo(7, 1)

    describe 'subtractSkinAreasFromInfill', ->

        it 'returns original boundary when no skin areas provided', ->

            infillBoundary = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            result = clipping.subtractSkinAreasFromInfill(infillBoundary, [])

            expect(result).toHaveLength(1)
            expect(result[0]).toHaveLength(4)
            expect(result[0][0].x).toBeCloseTo(0, 5)
            expect(result[0][0].y).toBeCloseTo(0, 5)

        it 'subtracts a single skin area from infill boundary', ->

            # Infill boundary: 10x10 square.
            infillBoundary = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Skin area: 5x5 square in the center (offset by 2.5 from edges).
            skinArea = [
                { x: 2.5, y: 2.5 }
                { x: 7.5, y: 2.5 }
                { x: 7.5, y: 7.5 }
                { x: 2.5, y: 7.5 }
            ]

            result = clipping.subtractSkinAreasFromInfill(infillBoundary, [skinArea])

            # Result should be a single polygon with a hole.
            # polygon-clipping returns the outer boundary with the hole subtracted.
            expect(result.length).toBeGreaterThan(0)

            # The result should have points (outer boundary).
            expect(result[0].length).toBeGreaterThan(0)

        it 'subtracts multiple skin areas from infill boundary', ->

            # Infill boundary: 20x20 square.
            infillBoundary = [
                { x: 0, y: 0 }
                { x: 20, y: 0 }
                { x: 20, y: 20 }
                { x: 0, y: 20 }
            ]

            # Two skin areas: two 5x5 squares.
            skinArea1 = [
                { x: 2, y: 2 }
                { x: 7, y: 2 }
                { x: 7, y: 7 }
                { x: 2, y: 7 }
            ]

            skinArea2 = [
                { x: 13, y: 13 }
                { x: 18, y: 13 }
                { x: 18, y: 18 }
                { x: 13, y: 18 }
            ]

            result = clipping.subtractSkinAreasFromInfill(infillBoundary, [skinArea1, skinArea2])

            # Result should have at least one polygon.
            expect(result.length).toBeGreaterThan(0)

        it 'returns empty array when skin area covers entire infill boundary', ->

            # Infill boundary: 10x10 square.
            infillBoundary = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Skin area: same 10x10 square (complete coverage).
            skinArea = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            result = clipping.subtractSkinAreasFromInfill(infillBoundary, [skinArea])

            # Result should be empty when skin covers entire infill.
            expect(result).toHaveLength(0)

        it 'handles degenerate skin areas gracefully', ->

            # Infill boundary: 10x10 square.
            infillBoundary = [
                { x: 0, y: 0 }
                { x: 10, y: 0 }
                { x: 10, y: 10 }
                { x: 0, y: 10 }
            ]

            # Degenerate skin area: line (not a valid polygon).
            skinArea = [
                { x: 5, y: 5 }
                { x: 5, y: 5 }
            ]

            result = clipping.subtractSkinAreasFromInfill(infillBoundary, [skinArea])

            # Should return original boundary when skin area is degenerate.
            expect(result).toHaveLength(1)
            expect(result[0]).toHaveLength(4)
