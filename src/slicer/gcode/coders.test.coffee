# Tests for G-code generation methods

Polyslice = require('../../index')

describe 'G-code Generation (Coders)', ->

    slicer = null

    beforeEach ->

        slicer = new Polyslice()

    describe 'Movement Commands', ->

        test 'should generate autohome G-code', ->

            gcode = slicer.codeAutohome()
            expect(gcode).toBe('G28\n')

            xcodeHome = slicer.codeAutohome(true, false, false)
            expect(xcodeHome).toBe('G28 X\n')

        test 'should generate workspace plane G-code', ->

            expect(slicer.codeWorkspacePlane()).toBe('G17\n') # XY plane.

            slicer.setWorkspacePlane('XZ')
            expect(slicer.codeWorkspacePlane()).toBe('G18\n')

            slicer.setWorkspacePlane('YZ')
            expect(slicer.codeWorkspacePlane()).toBe('G19\n')

        test 'should generate linear movement G-code', ->

            moveCode = slicer.codeLinearMovement(10, 20, 5)
            expect(moveCode).toBe('G0 X10 Y20 Z5\n') # G0 for non-extruding move.

            extrudeCode = slicer.codeLinearMovement(10, 20, 5, 0.1, 1500) # Feedrate in mm/min.
            expect(extrudeCode).toBe('G1 X10 Y20 Z5 E0.1 F1500\n') # G1 for extruding move.

        test 'should generate arc movement G-code', ->

            # Test clockwise arc.
            arcCode = slicer.codeArcMovement("clockwise", 10, 10, null, null, null, null, 5, 0)
            expect(arcCode).toBe('G2 X10 Y10 I5 J0\n')

            # Test counterclockwise arc.
            arcCode = slicer.codeArcMovement("counterclockwise", 5, 5, null, null, null, null, 2, 2)
            expect(arcCode).toBe('G3 X5 Y5 I2 J2\n')

    describe 'Unit Commands', ->

        test 'should generate length unit G-code', ->

            expect(slicer.codeLengthUnit()).toBe('G21\n') # millimeters.

            slicer.setLengthUnit('inches')
            expect(slicer.codeLengthUnit()).toBe('G20\n')

        test 'should generate temperature unit G-code', ->

            expect(slicer.codeTemperatureUnit()).toBe('M149 C\n') # celsius.

            slicer.setTemperatureUnit('fahrenheit')
            expect(slicer.codeTemperatureUnit()).toBe('M149 F\n')

            slicer.setTemperatureUnit('kelvin')
            expect(slicer.codeTemperatureUnit()).toBe('M149 K\n')

    describe 'Temperature Commands', ->

        test 'should generate temperature G-code', ->

            nozzleCode = slicer.codeNozzleTemperature(200, false)
            expect(nozzleCode).toBe('M104 S200\n') # Set without waiting.

            bedCode = slicer.codeBedTemperature(60, false)
            expect(bedCode).toBe('M140 S60\n') # Set without waiting.

    describe 'Fan Commands', ->

        test 'should generate fan speed G-code', ->

            fanCode = slicer.codeFanSpeed(50)
            expect(fanCode).toBe('M106 S127\n') # 50% * 2.55 = 127.5, rounded to 127.

            fanOffCode = slicer.codeFanSpeed(0)
            expect(fanOffCode).toBe('M107\n') # Fan off.

    describe 'Control Commands', ->

        test 'should generate message G-code', ->

            messageCode = slicer.codeMessage("Test Message")
            expect(messageCode).toBe('M117 Test Message\n')

        test 'should generate wait G-code', ->

            waitCode = slicer.codeWait()
            expect(waitCode).toBe('M400\n')

        test 'should generate dwell G-code', ->

            dwellCode = slicer.codeDwell(1000)
            expect(dwellCode).toBe('M0 P1000\n') # Interruptible dwell for 1000ms.

            nonInterruptibleDwell = slicer.codeDwell(500, false)
            expect(nonInterruptibleDwell).toBe('G4 P500\n') # Non-interruptible dwell for 500ms.

    describe 'Retraction Commands', ->

        test 'should generate retraction G-code', ->

            result = slicer.codeRetract()
            expect(result).toBe('G1 E-1 F2400\n') # Default 1mm at 40mm/s (2400mm/min).

            # Test custom values.
            result = slicer.codeRetract(2.0, 50)
            expect(result).toBe('G1 E-2 F3000\n')

            # Test zero retraction.
            result = slicer.codeRetract(0, 50)
            expect(result).toBe('') # Should return empty string.

        test 'should generate unretract G-code', ->

            result = slicer.codeUnretract()
            expect(result).toBe('G1 E1 F2400\n') # Default 1mm at 40mm/s.

            # Test custom values.
            result = slicer.codeUnretract(1.5, 30)
            expect(result).toBe('G1 E1.5 F1800\n')

    describe 'Print Sequence Commands', ->

        test 'should generate test strip G-code', ->

            result = slicer.codeTestStrip()

            expect(result).toContain('G92 E0') # Reset extruder.
            expect(result).toContain('G0 Z2') # Move Z up.
            expect(result).toContain('G0 X10 Y10 Z0.25') # Move to start (X-axis now).
            expect(result).toContain('E15') # First line extrusion.
            expect(result).toContain('E30') # Second line cumulative extrusion.
            expect(result).toContain('G0 Z2') # Lift nozzle.

        test 'should generate test strip with custom dimensions', ->

            result = slicer.codeTestStrip(80, 0.4, 0.4)

            expect(result).toContain('G0 X10 Y10 Z0.4') # Custom height.
            expect(result).toContain('X90') # Custom length (10 + 80) along X-axis.
            expect(result).toContain('G0 Z2') # Lift nozzle.

        test 'should generate pre-print sequence', ->

            slicer.setNozzleTemperature(200)
            slicer.setBedTemperature(60)
            slicer.setFanSpeed(100)
            slicer.setMetadata(false) # Disable metadata for simpler test.
            slicer.setVerbose(false) # Disable verbose for simpler test.

            result = slicer.codePrePrint()

            expect(result).toContain('M104 S200') # Start heating nozzle.
            expect(result).toContain('M140 S60') # Start heating bed.
            expect(result).toContain('G28') # Autohome (while heating).
            expect(result).toContain('G0 Z10') # Back off bed.
            expect(result).toContain('M109 R200') # Wait for nozzle temperature.
            expect(result).toContain('M190 R60') # Wait for bed temperature.
            expect(result).toContain('M82') # Absolute extrusion mode.
            expect(result).toContain('G17') # Workspace plane.
            expect(result).toContain('G21') # Length unit.
            expect(result).toContain('G92 E0') # Reset extruder.
            expect(result).toContain('E-5') # Final retract before print.

        test 'should generate pre-print without test strip', ->

            slicer.setTestStrip(false)
            slicer.setVerbose(false)
            result = slicer.codePrePrint()

            expect(result).not.toContain('X10 Y10') # Test strip starting position.

        test 'should generate pre-print with test strip', ->

            slicer.setTestStrip(true)
            slicer.setVerbose(false)
            result = slicer.codePrePrint()

            expect(result).toContain('X10 Y10') # Test strip starting position (X-axis).

        test 'should generate pre-print with simultaneous heating and autohome', ->

            slicer.setNozzleTemperature(200)
            slicer.setBedTemperature(60)
            slicer.setMetadata(false)
            slicer.setVerbose(false)

            result = slicer.codePrePrint()

            expect(result).toContain('M104 S200') # Start nozzle heating (no wait).
            expect(result).toContain('M140 S60') # Start bed heating (no wait).
            expect(result).toContain('G28') # Autohome (simultaneous with heating).
            expect(result).toContain('M109 R200') # Wait for nozzle.
            expect(result).toContain('M190 R60') # Wait for bed.

        test 'should generate post-print sequence', ->

            slicer.setVerbose(false)
            result = slicer.codePostPrint()

            expect(result).toContain('M107') # Turn off fan.
            expect(result).toContain('G91') # Relative positioning.
            expect(result).toContain('G0 X5 Y5') # Wipe move (default is now true).
            expect(result).toContain('E-2') # Retract.
            expect(result).toContain('G1 Z10') # Raise nozzle.
            expect(result).toContain('G90') # Absolute positioning.
            expect(result).toContain('G28 X Y') # Home X and Y.
            expect(result).toContain('M104 S0') # Turn off nozzle.
            expect(result).toContain('M140 S0') # Turn off bed.
            expect(result).toContain('M84 X Y E') # Disable steppers.
            expect(result).toContain('M300') # Buzzer command present (triple beep).
            expect(result).toContain('S420') # Frequency 420Hz.

        test 'should generate post-print without buzzer', ->

            slicer.setBuzzer(false)
            slicer.setVerbose(false)
            result = slicer.codePostPrint()

            expect(result).not.toContain('M300') # No buzzer.
            expect(result).toContain('M84 X Y E') # Disable steppers.

        test 'should generate post-print with wipe nozzle', ->

            slicer.setWipeNozzle(true)
            slicer.setVerbose(false)
            result = slicer.codePostPrint()

            expect(result).toContain('G0 X5 Y5') # Wipe move.

            # Verify wipe comes before retract and raise Z.
            wipeIndex = result.indexOf('G0 X5 Y5')
            retractIndex = result.indexOf('G1 Z10 E-2')

            expect(wipeIndex).toBeGreaterThan(-1)
            expect(retractIndex).toBeGreaterThan(-1)
            expect(wipeIndex).toBeLessThan(retractIndex) # Wipe should come before retract/raise.

        test 'should generate post-print without wipe nozzle', ->

            slicer.setWipeNozzle(false)
            slicer.setVerbose(false)
            result = slicer.codePostPrint()

            expect(result).not.toContain('G0 X5 Y5') # No wipe move.

        test 'should generate metadata header', ->

            Printer = require('../../config/printer/printer')
            Filament = require('../../config/filament/filament')

            printer = new Printer('Ender3')
            filament = new Filament('GenericPLA')

            metadataSlicer = new Polyslice({
                printer: printer
                filament: filament
                metadata: true
            })

            result = metadataSlicer.codeMetadata()

            expect(result).toContain('; Generated by Polyslice')
            expect(result).toContain('; Version:')
            expect(result).toContain('; Timestamp:')
            expect(result).toContain('; Repository: https://github.com/jgphilpott/polyslice')
            expect(result).toContain('; Printer: Ender3')
            expect(result).toContain('; Filament: Generic PLA (pla)')
            expect(result).toContain('; Nozzle Temp:')
            expect(result).toContain('; Bed Temp:')
            expect(result).toContain('; Layer Height:')

        test 'should include metadata in pre-print when enabled', ->

            slicer.setMetadata(true)
            result = slicer.codePrePrint()

            expect(result).toContain('; Generated by Polyslice')

        test 'should not include metadata in pre-print when disabled', ->

            slicer.setMetadata(false)
            result = slicer.codePrePrint()

            expect(result).not.toContain('; Generated by Polyslice')

    describe 'Coder Methods Side Effects', ->

        test 'should not modify slicer state when generating temperature G-code', ->

            # Set initial values.
            slicer.setNozzleTemperature(200)
            slicer.setBedTemperature(60)

            # Generate G-code with different values.
            slicer.codeNozzleTemperature(0, false)
            slicer.codeBedTemperature(0, false)

            # Verify original values are preserved.
            expect(slicer.nozzleTemperature).toBe(200)
            expect(slicer.bedTemperature).toBe(60)

        test 'should not modify slicer state when generating fan G-code', ->

            # Set initial value.
            slicer.setFanSpeed(100)

            # Generate G-code with different value.
            slicer.codeFanSpeed(0)

            # Verify original value is preserved.
            expect(slicer.fanSpeed).toBe(100)

        test 'should use passed values instead of config for G-code generation', ->

            # Set config values.
            slicer.setNozzleTemperature(200)
            slicer.setBedTemperature(60)
            slicer.setFanSpeed(100)

            # Generate G-code with different values.
            nozzleCode = slicer.codeNozzleTemperature(150, false)
            bedCode = slicer.codeBedTemperature(40, false)
            fanCode = slicer.codeFanSpeed(50)

            # Verify G-code uses passed values, not config values.
            expect(nozzleCode).toBe('M104 S150\n')
            expect(bedCode).toBe('M140 S40\n')
            expect(fanCode).toBe('M106 S127\n')  # 50% = 127

            # Verify config values are still unchanged.
            expect(slicer.nozzleTemperature).toBe(200)
            expect(slicer.bedTemperature).toBe(60)
            expect(slicer.fanSpeed).toBe(100)

        test 'should preserve temperature and fan settings across multiple slice calls', ->

            THREE = require('three')

            # Create a simple cube mesh.
            geometry = new THREE.BoxGeometry(10, 10, 10)
            material = new THREE.MeshBasicMaterial()
            mesh = new THREE.Mesh(geometry, material)

            mesh.position.set(0, 0, 5)
            mesh.updateMatrixWorld()

            # Configure slicer with specific temperatures and fan speed.
            slicer.setNozzleTemperature(200)
            slicer.setBedTemperature(60)
            slicer.setFanSpeed(100)

            # First slice.
            result1 = slicer.slice(mesh)

            # Verify first slice has correct heating commands.
            expect(result1).toContain('M104 S200')  # Start heating nozzle.
            expect(result1).toContain('M109 R200')  # Wait for nozzle temp.
            expect(result1).toContain('M140 S60')   # Start heating bed.
            expect(result1).toContain('M190 R60')   # Wait for bed temp.
            expect(result1).toContain('M106 S255')  # Fan on (100% = 255).

            # Second slice (should have identical pre-print sequence).
            result2 = slicer.slice(mesh)

            # Verify second slice has the SAME heating commands.
            expect(result2).toContain('M104 S200')  # Start heating nozzle.
            expect(result2).toContain('M109 R200')  # Wait for nozzle temp.
            expect(result2).toContain('M140 S60')   # Start heating bed.
            expect(result2).toContain('M190 R60')   # Wait for bed temp.
            expect(result2).toContain('M106 S255')  # Fan on (100% = 255).

            # Verify slicer settings are still correct after both slices.
            expect(slicer.nozzleTemperature).toBe(200)
            expect(slicer.bedTemperature).toBe(60)
            expect(slicer.fanSpeed).toBe(100)
