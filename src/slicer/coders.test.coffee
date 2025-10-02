# Tests for G-code generation methods

Polyslice = require('../index')

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

            extrudeCode = slicer.codeLinearMovement(10, 20, 5, 0.1, 1500)
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

            expect(result).toContain('M117 Printing test strip...')
            expect(result).toContain('G0 X10 Y10 Z0.3') # Move to start.
            expect(result).toContain('G1 E1') # Prime nozzle.
            expect(result).toContain('G1 X70 Y10 Z0.3') # First line.
            expect(result).toContain('G1 E-1') # Retract.
            expect(result).toContain('G0 Z2.3') # Lift nozzle.

        test 'should generate test strip with custom dimensions', ->

            result = slicer.codeTestStrip(80, 10, 0.4)

            expect(result).toContain('G0 X10 Y10 Z0.4') # Custom height.
            expect(result).toContain('G1 X90 Y10 Z0.4') # Custom length (10 + 80).
            expect(result).toContain('G0 Z2.4') # Lift nozzle (height + 2).

        test 'should generate pre-print sequence', ->

            slicer.setNozzleTemperature(200)
            slicer.setBedTemperature(60)
            slicer.setFanSpeed(100)

            result = slicer.codePrePrint()

            expect(result).toContain('M117 Starting pre-print sequence...')
            expect(result).toContain('G28') # Autohome.
            expect(result).toContain('G17') # Workspace plane.
            expect(result).toContain('G21') # Length unit.
            expect(result).toContain('G0 Z10') # Raise nozzle.
            expect(result).toContain('M117 Heating nozzle...')
            expect(result).toContain('M109 R200') # Heat nozzle with wait.
            expect(result).toContain('M117 Heating bed...')
            expect(result).toContain('M190 R60') # Heat bed with wait.
            expect(result).toContain('M106 S255') # Fan speed.
            expect(result).toContain('M117 Pre-print sequence complete')

        test 'should generate pre-print without test strip', ->

            slicer.setTestStrip(false)
            result = slicer.codePrePrint()

            expect(result).not.toContain('M117 Printing test strip...')

        test 'should generate pre-print with test strip', ->

            slicer.setTestStrip(true)
            result = slicer.codePrePrint()

            expect(result).toContain('M117 Printing test strip...')

        test 'should generate pre-print with simultaneous heating', ->

            slicer.setNozzleTemperature(200)
            slicer.setBedTemperature(60)

            result = slicer.codePrePrint(10, false)

            expect(result).toContain('M117 Starting nozzle heating...')
            expect(result).toContain('M104 S200') # Start nozzle heating (no wait).
            expect(result).toContain('M117 Starting bed heating...')
            expect(result).toContain('M140 S60') # Start bed heating (no wait).
            expect(result).toContain('M117 Waiting for nozzle temperature...')
            expect(result).toContain('M109 R200') # Wait for nozzle.
            expect(result).toContain('M117 Waiting for bed temperature...')
            expect(result).toContain('M190 R60') # Wait for bed.

        test 'should generate post-print sequence', ->

            result = slicer.codePostPrint()

            expect(result).toContain('M117 Starting post-print sequence...')
            expect(result).toContain('G1 E-1') # Retract.
            expect(result).toContain('G0 Z10') # Raise nozzle.
            expect(result).toContain('G0 X0 Y0') # Move to home.
            expect(result).toContain('M107') # Turn off fan.
            expect(result).toContain('M117 Cooling down nozzle...')
            expect(result).toContain('M104 S0') # Turn off nozzle.
            expect(result).toContain('M117 Cooling down bed...')
            expect(result).toContain('M140 S0') # Turn off bed.
            expect(result).toContain('M117 Print complete!')
            expect(result).toContain('M300') # Buzzer command present.
            expect(result).toContain('S1000') # Frequency 1000Hz.
            expect(result).toContain('M117 Post-print sequence complete')

        test 'should generate post-print without buzzer', ->

            result = slicer.codePostPrint(10, false)

            expect(result).not.toContain('M300') # No buzzer.
            expect(result).toContain('M117 Post-print sequence complete')

        test 'should generate post-print with custom raise height', ->

            result = slicer.codePostPrint(20)

            expect(result).toContain('G0 Z20') # Custom raise height.
