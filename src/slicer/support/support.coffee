# Support generation module for Polyslice.

coders = require('../gcode/coders')
helpers = require('../geometry/helpers')

module.exports =

    # Generate G-code for support structures.
    # Currently focuses on 'normal' supports from 'buildPlate' placement.
    generateSupportGCode: (slicer, mesh, allLayers, layerIndex, z, centerOffsetX, centerOffsetY, minZ, layerHeight) ->

        # Only generate supports if enabled.
        return unless slicer.getSupportEnabled()

        # Get support configuration.
        supportType = slicer.getSupportType()
        supportPlacement = slicer.getSupportPlacement()
        supportThreshold = slicer.getSupportThreshold()

        # Currently only implement 'normal' supports.
        return unless supportType is 'normal'

        # Currently only implement 'buildPlate' placement.
        return unless supportPlacement is 'buildPlate'

        # Cache overhang detection on first call.
        if not slicer._overhangRegions?
            slicer._overhangRegions = @detectOverhangs(mesh, supportThreshold, minZ)

        overhangRegions = slicer._overhangRegions

        return unless overhangRegions.length > 0

        verbose = slicer.getVerbose()
        nozzleDiameter = slicer.getNozzleDiameter()

        # Generate support on this layer for overhangs that are above this layer.
        supportsGenerated = 0

        for region in overhangRegions

            # Only generate support if the overhang is above the current layer.
            # Leave a small gap (1-2 layers) between support and model.
            interfaceGap = layerHeight * 1.5

            if region.z > (z + interfaceGap)

                @generateSupportColumn(slicer, region, z, centerOffsetX, centerOffsetY, nozzleDiameter)
                supportsGenerated++

        if verbose and supportsGenerated > 0 and layerIndex is 0
            slicer.gcode += "; Support structures detected (#{overhangRegions.length} regions)" + slicer.newline

        return

    # Detect overhanging regions based on support threshold angle.
    detectOverhangs: (mesh, thresholdAngle, buildPlateZ = 0) ->

        return [] unless mesh?.geometry

        THREE = if typeof window isnt 'undefined' then window.THREE else require('three')

        geometry = mesh.geometry
        
        # Get position attribute from geometry.
        positions = geometry.attributes?.position
        return [] unless positions

        overhangRegions = []
        processedFaces = new Set()

        # Support threshold in radians for comparison.
        thresholdRad = thresholdAngle * Math.PI / 180

        # Analyze each triangle face.
        faceCount = positions.count / 3

        for faceIndex in [0...faceCount]

            continue if processedFaces.has(faceIndex)

            # Get triangle vertices.
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

            # Apply mesh transformation to vertices.
            v0.applyMatrix4(mesh.matrixWorld)
            v1.applyMatrix4(mesh.matrixWorld)
            v2.applyMatrix4(mesh.matrixWorld)

            # Calculate face normal.
            edge1 = new THREE.Vector3().subVectors(v1, v0)
            edge2 = new THREE.Vector3().subVectors(v2, v0)
            normal = new THREE.Vector3().crossVectors(edge1, edge2).normalize()

            # Calculate angle of the face from horizontal.
            # A face pointing straight down (0, 0, -1) has angle 0° from down.
            # A face pointing horizontal has angle 90° from down.
            # A face pointing up (0, 0, 1) has angle 180° from down.
            
            # We care about the Z component of the normal.
            # normal.z > 0: face points upward (no support needed)
            # normal.z = 0: face is vertical (no support needed)
            # normal.z < 0: face points downward (may need support)
            
            # For downward-facing surfaces, check the angle from horizontal.
            # supportThreshold = 45° means surfaces angled more than 45° from vertical (or less than 45° from horizontal) need support.
            # A horizontal downward face (normal.z = -1) has angle 0° from horizontal, needs support.
            # A face at 45° from vertical (normal.z = -0.707) has angle 45° from horizontal, at the threshold.
            # A vertical face (normal.z = 0) has angle 90° from horizontal, no support needed.
            
            if normal.z < 0
                
                # Calculate angle from horizontal using Z component.
                # angle = acos(|normal.z|) gives angle from horizontal plane.
                angleFromHorizontal = Math.acos(Math.abs(normal.z))
                
                # Convert to degrees for comparison.
                angleFromHorizontalDeg = angleFromHorizontal * 180 / Math.PI
                
                # Need support if angle from horizontal is less than (90° - threshold).
                # For threshold 45°: need support if angle < 45° from horizontal (more than 45° from vertical).
                supportAngleLimit = 90 - thresholdAngle
                
                if angleFromHorizontalDeg < supportAngleLimit

                    # Calculate center point of the triangle.
                    centerX = (v0.x + v1.x + v2.x) / 3
                    centerY = (v0.y + v1.y + v2.y) / 3
                    centerZ = (v0.z + v1.z + v2.z) / 3

                    # Only consider faces above build plate with significant height.
                    # Need at least 2 layer heights of clearance for support.
                    if centerZ > buildPlateZ + 0.5

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

        # Support column parameters.
        supportLineWidth = nozzleDiameter * 0.8 # Slightly thinner than normal extrusion.
        supportSpacing = nozzleDiameter * 2 # Spacing between support lines.

        # Generate a small support patch (2x2 grid of lines).
        patchSize = supportLineWidth * 2

        if verbose
            slicer.gcode += "; Support column at (#{region.x.toFixed(2)}, #{region.y.toFixed(2)}, z=#{region.z.toFixed(2)})" + slicer.newline

        # Convert speeds to mm/min for G-code.
        travelSpeed = slicer.getTravelSpeed() * 60
        supportSpeed = slicer.getPerimeterSpeed() * 60 * 0.5 # Slower for supports.

        # Create a small cross pattern for support.
        offsetX = region.x + centerOffsetX
        offsetY = region.y + centerOffsetY

        # Move to start position.
        slicer.gcode += coders.codeLinearMovement(slicer, offsetX - patchSize, offsetY, currentZ, null, travelSpeed)

        # Draw first line of cross.
        distance1 = patchSize * 2
        extrusion1 = slicer.calculateExtrusion(distance1, supportLineWidth)
        slicer.cumulativeE += extrusion1
        slicer.gcode += coders.codeLinearMovement(slicer, offsetX + patchSize, offsetY, currentZ, slicer.cumulativeE, supportSpeed)

        # Move to second line start.
        slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY - patchSize, currentZ, null, travelSpeed)

        # Draw second line of cross.
        distance2 = patchSize * 2
        extrusion2 = slicer.calculateExtrusion(distance2, supportLineWidth)
        slicer.cumulativeE += extrusion2
        slicer.gcode += coders.codeLinearMovement(slicer, offsetX, offsetY + patchSize, currentZ, slicer.cumulativeE, supportSpeed)

        return
