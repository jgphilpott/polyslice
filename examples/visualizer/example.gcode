; Example G-code for visualizer
; Simple test cube print

; Start sequence
G28 ; Home all axes
G0 Z5 ; Move Z up for safety
G0 X110 Y110 ; Move to center

; Heat up
M104 S210 ; Set nozzle temp
M140 S60 ; Set bed temp
M109 S210 ; Wait for nozzle
M190 S60 ; Wait for bed

; Prime line
G0 X10 Y10 Z0.3
G1 X100 Y10 E10 F1200

; First layer - square base
G0 X50 Y50 Z0.2
G1 X70 Y50 E2 F1200
G1 X70 Y70 E2 F1200
G1 X50 Y70 E2 F1200
G1 X50 Y50 E2 F1200

; Second layer
G0 Z0.4
G1 X70 Y50 E2 F1200
G1 X70 Y70 E2 F1200
G1 X50 Y70 E2 F1200
G1 X50 Y50 E2 F1200

; Third layer
G0 Z0.6
G1 X70 Y50 E2 F1200
G1 X70 Y70 E2 F1200
G1 X50 Y70 E2 F1200
G1 X50 Y50 E2 F1200

; End sequence
M104 S0 ; Turn off nozzle
M140 S0 ; Turn off bed
G0 Z20 ; Move Z up
G28 X Y ; Home X and Y
M84 ; Disable motors
