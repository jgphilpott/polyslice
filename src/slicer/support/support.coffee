# Support generation module for Polyslice.

coders = require('../gcode/coders')

module.exports =

    # Generate G-code for support structures.
    generateSupportGCode: (slicer, mesh, allLayers, layerIndex, z, centerOffsetX, centerOffsetY, minZ, layerHeight) ->

        return unless slicer.getSupportEnabled()

        supportType = slicer.getSupportType()
        supportPlacement = slicer.getSupportPlacement()
        supportThreshold = slicer.getSupportThreshold()

        return unless supportType is 'normal'

        # Support 'buildPlate' and 'everywhere' placements.
        return unless supportPlacement in ['buildPlate', 'everywhere']

        if not slicer._overhangRegions?

            slicer._overhangRegions = @detectOverhangs(mesh, supportThreshold, minZ, supportPlacement)

        overhangRegions = slicer._overhangRegions

        return unless overhangRegions.length > 0

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()

        supportsGenerated = 0

        for region in overhangRegions

            interfaceGap = layerHeight * 1.5

            if region.z > (z + interfaceGap)

                @generateSupportColumn(slicer, region, z, centerOffsetX, centerOffsetY, nozzleDiameter)
                supportsGenerated++

        if verbose and supportsGenerated > 0 and layerIndex is 0

            slicer.gcode += "; Support structures detected (#{overhangRegions.length} regions)" + slicer.newline

        return

    # Detect overhanging regions based on support threshold angle.
    detectOverhangs: (mesh, thresholdAngle, buildPlateZ = 0, supportPlacement = 'buildPlate') ->

        return [] unless mesh?.geometry

        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

        geometry = mesh.geometry

        positions = geometry.attributes?.position
        return [] unless positions

        overhangRegions = []
        processedFaces = new Set()

        thresholdRad = thresholdAngle * Math.PI / 180

        faceCount = positions.count / 3

        for faceIndex in [0...faceCount]

            continue if processedFaces.has(faceIndex)

            i0 = faceIndex * 3
            i1 = i0 + 1
            i2 = i0 + 2

            v0 = new THREE.Vector3(
                positions.getX(i0),
                positions.getY(i0),
                positions.getZ(i0)
            )

            v1 = new THREE.Vector3(
                positions.getX(i1),
                positions.getY(i1),
                positions.getZ(i1)
            )

            v2 = new THREE.Vector3(
                positions.getX(i2),
                positions.getY(i2),
                positions.getZ(i2)
            )

            v0.applyMatrix4(mesh.matrixWorld)
            v1.applyMatrix4(mesh.matrixWorld)
            v2.applyMatrix4(mesh.matrixWorld)

            edge1 = new THREE.Vector3().subVectors(v1, v0)
            edge2 = new THREE.Vector3().subVectors(v2, v0)
            normal = new THREE.Vector3().crossVectors(edge1, edge2).normalize()

            # Check downward-facing surfaces.
            if normal.z < 0

                angleFromHorizontal = Math.acos(Math.abs(normal.z))

                angleFromHorizontalDeg = angleFromHorizontal * 180 / Math.PI

                supportAngleLimit = 90 - thresholdAngle

                if angleFromHorizontalDeg < supportAngleLimit

                    centerX = (v0.x + v1.x + v2.x) / 3
                    centerY = (v0.y + v1.y + v2.y) / 3
                    centerZ = (v0.z + v1.z + v2.z) / 3

                    # For 'buildPlate' placement, only generate supports above build plate.
                    # For 'everywhere' placement, support all overhangs regardless of height.
                    shouldGenerateSupport = if supportPlacement is 'everywhere'
                        centerZ > buildPlateZ
                    else
                        centerZ > buildPlateZ + 0.5

                    if shouldGenerateSupport

                        overhangRegions.push({
                            x: centerX
                            y: centerY
                            z: centerZ
                            angle: angleFromHorizontalDeg
                        })

                        processedFaces.add(faceIndex)

        return overhangRegions

    # Generate a support column from build plate to overhang region.
    generateSupportColumn: (slicer, region, currentZ, centerOffsetX, centerOffsetY, nozzleDiameter) ->

        verbose = slicer.getVerbose()

        supportLineWidth = nozzleDiameter * 0.8
        supportSpacing = nozzleDiameter * 2

        patchSize = supportLineWidth * 2

        if verbose

            slicer.gcode += "; TYPE: SUPPORT" + slicer.newline
            slicer.gcode += "; Support column at (#{region.x.toFixed(2)}, #{region.y.toFixed(2)}, z=#{region.z.toFixed(2)})" + slicer.newline

        travelSpeed = slicer.getTravelSpeed() * 60
        supportSpeed = slicer.getPerimeterSpeed() * 60 * 0.5

        offsetX = region.x + centerOffsetX
        offsetY = region.y + centerOffsetY

        slicer.gcode += coders.codeLinearMovement(slicer, offsetX - patchSize, offsetY, currentZ, null, travelSpeed)

        distance1 = patchSize * 2
        extrusion1 = slicer.calculateExtrusion(distance1, supportLineWidth)
        slicer.cumulativeE += extrusion1
        slicer.gcode += coders.codeLinearMovement(slicer, offsetX + patchSize, offsetY, currentZ, slicer.cumulativeE, supportSpeed)

        slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY - patchSize, currentZ, null, travelSpeed)

        distance2 = patchSize * 2
        extrusion2 = slicer.calculateExtrusion(distance2, supportLineWidth)
        slicer.cumulativeE += extrusion2
        slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY + patchSize, currentZ, slicer.cumulativeE, supportSpeed)

        return
