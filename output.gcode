; Sample G-code for testing
G28 ; Home all axes
G0 Z5 ; Move Z up
G0 X50 Y50 ; Move to center
M104 S200 ; Set nozzle temp
M140 S60 ; Set bed temp
M109 S200 ; Wait for nozzle
M190 S60 ; Wait for bed
G1 X100 Y100 E5 F1500 ; Extrude line
M104 S0 ; Turn off nozzle
M140 S0 ; Turn off bed
G28 ; Home
