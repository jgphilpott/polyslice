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

    # Creality Ender 3 Pro - Enhanced Ender 3 with better components.
    "Ender3Pro":
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

    # Creality Ender 3 S1 - Direct drive extruder and auto-leveling.
    "Ender3S1":
        size:
            x: 220
            y: 220
            z: 270
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

    # Creality CR-10 S5 - Extra large build volume.
    "CR10S5":
        size:
            x: 500
            y: 500
            z: 500
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

    # Prusa XL - Multi-tool head system.
    "PrusaXL":
        size:
            x: 360
            y: 360
            z: 360
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 35
            }
        ]

    # Bambu Lab X1 Carbon - High-speed enclosed printer.
    "BambuLabX1Carbon":
        size:
            x: 256
            y: 256
            z: 256
        shape: "rectangular"
        centred: false
        heated:
            volume: true
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 28
            }
        ]

    # Bambu Lab P1P - High-speed open-frame printer.
    "BambuLabP1P":
        size:
            x: 256
            y: 256
            z: 256
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 28
            }
        ]

    # Anycubic Kobra - Auto-leveling budget printer.
    "AnycubicKobra":
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

    # Anycubic Vyper - Auto-leveling with direct drive.
    "AnycubicVyper":
        size:
            x: 245
            y: 245
            z: 260
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

    # Elegoo Neptune 3 - Budget-friendly with Klipper firmware.
    "ElegooNeptune3":
        size:
            x: 220
            y: 220
            z: 280
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

    # Elegoo Neptune 3 Pro - Upgraded Neptune with better features.
    "ElegooNeptune3Pro":
        size:
            x: 225
            y: 225
            z: 280
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

    # Sovol SV06 - Direct drive with auto-leveling.
    "SovolSV06":
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

    # Voron 2.4 - DIY CoreXY printer.
    "Voron24":
        size:
            x: 350
            y: 350
            z: 350
        shape: "rectangular"
        centred: false
        heated:
            volume: true
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 30
            }
        ]

    # Makerbot Replicator+ - Professional desktop printer.
    "MakerbotReplicatorPlus":
        size:
            x: 295
            y: 195
            z: 165
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

    # Qidi X-Plus - Enclosed industrial printer.
    "QidiXPlus":
        size:
            x: 270
            y: 200
            z: 200
        shape: "rectangular"
        centred: false
        heated:
            volume: true
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 28
            }
        ]

    # Flashforge Adventurer 3 - Compact enclosed printer.
    "FlashforgeAdventurer3":
        size:
            x: 150
            y: 150
            z: 150
        shape: "rectangular"
        centred: false
        heated:
            volume: true
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 20
            }
        ]

    # Monoprice Select Mini V2 - Ultra-compact budget printer.
    "MonopriceSelectMiniV2":
        size:
            x: 120
            y: 120
            z: 120
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 20
            }
        ]

    # Artillery Genius - Titan direct drive extruder.
    "ArtilleryGenius":
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

    # LulzBot Mini 2 - Open-source auto-leveling printer.
    "LulzBotMini2":
        size:
            x: 160
            y: 160
            z: 180
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 2.85
                diameter: 0.5
                gantry: 25
            }
        ]

    # LulzBot TAZ 6 - Large format open-source printer.
    "LulzBotTAZ6":
        size:
            x: 280
            y: 280
            z: 250
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 2.85
                diameter: 0.5
                gantry: 30
            }
        ]

    # Creality Ender 6 - CoreXY design with enclosed frame.
    "Ender6":
        size:
            x: 250
            y: 250
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
                gantry: 28
            }
        ]

    # Creality CR-6 SE - Auto-leveling with silicone nozzle.
    "CR6SE":
        size:
            x: 235
            y: 235
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

    # Anycubic Photon Mono X - Resin printer (for reference).
    "AnycubicPhotonMonoX":
        size:
            x: 192
            y: 120
            z: 245
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: false
        nozzles: [
            {
                filament: 0
                diameter: 0.05
                gantry: 20
            }
        ]

    # Prusa MK4 - Latest Prusa i3 variant with input shaping.
    "PrusaMK4":
        size:
            x: 250
            y: 210
            z: 220
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

    # Bambu Lab A1 Mini - Compact affordable option.
    "BambuLabA1Mini":
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

    # Bambu Lab A1 - Mid-size option.
    "BambuLabA1":
        size:
            x: 256
            y: 256
            z: 256
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 28
            }
        ]

    # Kingroon KP3S - Compact budget printer.
    "KingroonKP3S":
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
                gantry: 22
            }
        ]

    # Creality K1 - High-speed Core XY printer.
    "CrealityK1":
        size:
            x: 220
            y: 220
            z: 250
        shape: "rectangular"
        centred: false
        heated:
            volume: true
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 25
            }
        ]

    # Creality K1 Max - Larger high-speed printer.
    "CrealityK1Max":
        size:
            x: 300
            y: 300
            z: 300
        shape: "rectangular"
        centred: false
        heated:
            volume: true
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 30
            }
        ]

    # AnkerMake M5 - Fast consumer printer.
    "AnkerMakeM5":
        size:
            x: 235
            y: 235
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
                gantry: 26
            }
        ]

    # Elegoo Neptune 4 - Updated Neptune with Klipper.
    "ElegooNeptune4":
        size:
            x: 225
            y: 225
            z: 265
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

    # Elegoo Neptune 4 Pro - Pro version with improvements.
    "ElegooNeptune4Pro":
        size:
            x: 225
            y: 225
            z: 265
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

    # Sidewinder X2 - Updated Artillery model.
    "ArtillerySidewinderX2":
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

    # Sovol SV06 Plus - Larger SV06.
    "SovolSV06Plus":
        size:
            x: 300
            y: 300
            z: 340
        shape: "rectangular"
        centred: false
        heated:
            volume: false
            bed: true
        nozzles: [
            {
                filament: 1.75
                diameter: 0.4
                gantry: 28
            }
        ]

module.exports = printers
