# Printer configuration library.
# Contains pre-configured settings for popular 3D printers.

printers =

    # Creality Ender 3 - Most popular budget FDM printer.
    "Ender3":
        size:
            x: 220
            y: 220
            z: 250
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 25
            }
        ]

    # Creality Ender 3 V2 - Updated version with improvements.
    "Ender3V2":
        size:
            x: 220
            y: 220
            z: 250
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 25
            }
        ]

    # Creality Ender 5 - Cube frame design.
    "Ender5":
        size:
            x: 220
            y: 220
            z: 300
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 25
            }
        ]

    # Prusa i3 MK3S+ - Popular open-source printer.
    "PrusaI3MK3S":
        size:
            x: 250
            y: 210
            z: 210
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 30
            }
        ]

    # Prusa Mini+ - Compact version.
    "PrusaMini":
        size:
            x: 180
            y: 180
            z: 180
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 25
            }
        ]

    # Anycubic i3 Mega - Popular budget option.
    "AnycubicI3Mega":
        size:
            x: 210
            y: 210
            z: 205
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 25
            }
        ]

    # Creality CR-10 - Large format printer.
    "CR10":
        size:
            x: 300
            y: 300
            z: 400
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 30
            }
        ]

    # Artillery Sidewinder X1 - Direct drive extruder.
    "ArtillerySidewinderX1":
        size:
            x: 300
            y: 300
            z: 400
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 30
            }
        ]

    # Ultimaker S5 - Professional grade printer.
    "UltimakerS5":
        size:
            x: 330
            y: 240
            z: 300
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 2.85
                diameter: 0.4
                gantry: 35
            }
        ]

    # FlashForge Creator Pro - Dual extruder.
    "FlashForgeCreatorPro":
        size:
            x: 225
            y: 145
            z: 150
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 25
            }
            {
                filament: 1.75
                diameter: 0.4
                gantry: 25
            }
        ]

    # Raise3D Pro2 - Professional printer with large build volume.
    "Raise3DPro2":
        size:
            x: 305
            y: 305
            z: 300
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 30
            }
        ]

module.exports = printers
