# Geometry helper functions for slicing operations.
# This module re-exports functions from specialized submodules for backward compatibility.
#
# The helpers have been refactored into focused modules:
# - primitives: Basic point/line operations (pointsMatch, lineIntersection, pointInPolygon, etc.)
# - bounds: Bounding box calculations (calculatePathBounds, boundsOverlap, etc.)
# - clipping: Polygon clipping operations (clipLineToPolygon, clipLineWithHoles, etc.)
# - paths: Path manipulation (connectSegmentsToPaths, createInsetPath, etc.)
# - coverage: Region coverage detection (calculateRegionCoverage, calculateExposedAreas, etc.)
# - combing: Travel path optimization (findCombingPath, travelPathCrossesHoles, etc.)

primitives = require('../utils/primitives')
bounds = require('../utils/bounds')
clipping = require('../utils/clipping')
paths = require('../utils/paths')
coverage = require('./coverage')
combing = require('./combing')

module.exports =

    # ============================================
    # Re-exported from primitives module
    # ============================================

    pointsMatch: primitives.pointsMatch.bind(primitives)
    pointsEqual: primitives.pointsEqual.bind(primitives)
    lineIntersection: primitives.lineIntersection.bind(primitives)
    lineSegmentIntersection: primitives.lineSegmentIntersection.bind(primitives)
    pointInPolygon: primitives.pointInPolygon.bind(primitives)
    distanceFromPointToLineSegment: primitives.distanceFromPointToLineSegment.bind(primitives)
    manhattanDistance: primitives.manhattanDistance.bind(primitives)
    deduplicateIntersections: primitives.deduplicateIntersections.bind(primitives)
    lineSegmentCrossesPolygon: primitives.lineSegmentCrossesPolygon.bind(primitives)

    # ============================================
    # Re-exported from bounds module
    # ============================================

    calculatePathBounds: bounds.calculatePathBounds.bind(bounds)
    boundsOverlap: bounds.boundsOverlap.bind(bounds)
    calculateOverlapArea: bounds.calculateOverlapArea.bind(bounds)

    # ============================================
    # Re-exported from clipping module
    # ============================================

    clipLineToPolygon: clipping.clipLineToPolygon.bind(clipping)
    clipLineWithHoles: clipping.clipLineWithHoles.bind(clipping)
    subtractSkinAreasFromInfill: clipping.subtractSkinAreasFromInfill.bind(clipping)

    # ============================================
    # Re-exported from paths module
    # ============================================

    connectSegmentsToPaths: paths.connectSegmentsToPaths.bind(paths)
    createInsetPath: paths.createInsetPath.bind(paths)
    calculateMinimumDistanceBetweenPaths: paths.calculateMinimumDistanceBetweenPaths.bind(paths)

    # ============================================
    # Re-exported from coverage module
    # ============================================

    calculateRegionCoverage: coverage.calculateRegionCoverage.bind(coverage)
    isSkinAreaInsideHole: coverage.isSkinAreaInsideHole.bind(coverage)
    isAreaInsideAnyHoleWall: coverage.isAreaInsideAnyHoleWall.bind(coverage)
    calculateExposedAreas: coverage.calculateExposedAreas.bind(coverage)
    calculateNonExposedAreas: coverage.calculateNonExposedAreas.bind(coverage)
    floodFillNonExposedRegion: coverage.floodFillNonExposedRegion.bind(coverage)
    floodFillExposedRegion: coverage.floodFillExposedRegion.bind(coverage)
    marchingSquares: coverage.marchingSquares.bind(coverage)
    smoothContour: coverage.smoothContour.bind(coverage)
    doesHoleExistInLayer: coverage.doesHoleExistInLayer.bind(coverage)

    # ============================================
    # Re-exported from combing module
    # ============================================

    travelPathCrossesHoles: combing.travelPathCrossesHoles.bind(combing)
    findCombingPath: combing.findCombingPath.bind(combing)
    backOffFromHoles: combing.backOffFromHoles.bind(combing)
    findSimpleCombingPath: combing.findSimpleCombingPath.bind(combing)
    findAStarCombingPath: combing.findAStarCombingPath.bind(combing)
    getQuadrant: combing.getQuadrant.bind(combing)
    findBoundaryCorner: combing.findBoundaryCorner.bind(combing)
    simplifyPath: combing.simplifyPath.bind(combing)
    buildSafePathSegment: combing.buildSafePathSegment.bind(combing)
    addSafeEndpoint: combing.addSafeEndpoint.bind(combing)
    findOptimalStartPoint: combing.findOptimalStartPoint.bind(combing)
