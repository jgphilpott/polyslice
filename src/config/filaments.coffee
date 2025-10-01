# Filament configuration library.
# Contains pre-configured settings for popular 3D printing filaments.

filaments =

    # Generic PLA - Most popular filament type.
    "GenericPLA":
        type: "pla"
        name: "Generic PLA"
        description: "Standard PLA filament for general purpose printing"
        brand: "Generic"
        color: "#FFFFFF"
        diameter: 1.75
        density: 1.24
        weight: 1000
        cost: 20
        fan: 100
        temperature:
            bed: 60
            nozzle: 200
            standby: 180
        retraction:
            speed: 45
            distance: 5

    # Generic PETG - Durable and flexible alternative.
    "GenericPETG":
        type: "petg"
        name: "Generic PETG"
        description: "Durable PETG filament with good layer adhesion"
        brand: "Generic"
        color: "#FFFFFF"
        diameter: 1.75
        density: 1.27
        weight: 1000
        cost: 25
        fan: 50
        temperature:
            bed: 80
            nozzle: 240
            standby: 220
        retraction:
            speed: 40
            distance: 6

    # Generic ABS - High temperature strength.
    "GenericABS":
        type: "abs"
        name: "Generic ABS"
        description: "Strong ABS filament for functional parts"
        brand: "Generic"
        color: "#FFFFFF"
        diameter: 1.75
        density: 1.04
        weight: 1000
        cost: 22
        fan: 0
        temperature:
            bed: 100
            nozzle: 240
            standby: 220
        retraction:
            speed: 40
            distance: 5

    # Generic TPU - Flexible filament.
    "GenericTPU":
        type: "tpu"
        name: "Generic TPU"
        description: "Flexible TPU filament for elastic parts"
        brand: "Generic"
        color: "#FFFFFF"
        diameter: 1.75
        density: 1.21
        weight: 1000
        cost: 35
        fan: 50
        temperature:
            bed: 60
            nozzle: 220
            standby: 200
        retraction:
            speed: 25
            distance: 2

    # Generic Nylon - Engineering grade.
    "GenericNylon":
        type: "nylon"
        name: "Generic Nylon"
        description: "Strong and flexible engineering filament"
        brand: "Generic"
        color: "#FFFFFF"
        diameter: 1.75
        density: 1.14
        weight: 1000
        cost: 40
        fan: 20
        temperature:
            bed: 80
            nozzle: 250
            standby: 230
        retraction:
            speed: 40
            distance: 6

    # Hatchbox PLA - Popular brand.
    "HatchboxPLA":
        type: "pla"
        name: "Hatchbox PLA"
        description: "High quality PLA from Hatchbox"
        brand: "Hatchbox"
        color: "#000000"
        diameter: 1.75
        density: 1.24
        weight: 1000
        cost: 23
        fan: 100
        temperature:
            bed: 60
            nozzle: 205
            standby: 185
        retraction:
            speed: 45
            distance: 5

    # eSun PLA+ - Enhanced PLA.
    "eSunPLAPlus":
        type: "pla"
        name: "eSun PLA+"
        description: "Enhanced PLA with improved strength"
        brand: "eSun"
        color: "#000000"
        diameter: 1.75
        density: 1.24
        weight: 1000
        cost: 24
        fan: 100
        temperature:
            bed: 60
            nozzle: 210
            standby: 190
        retraction:
            speed: 45
            distance: 5

    # Overture PLA - Quality budget option.
    "OverturePLA":
        type: "pla"
        name: "Overture PLA"
        description: "Reliable PLA with consistent quality"
        brand: "Overture"
        color: "#000000"
        diameter: 1.75
        density: 1.24
        weight: 1000
        cost: 20
        fan: 100
        temperature:
            bed: 60
            nozzle: 200
            standby: 180
        retraction:
            speed: 45
            distance: 5

    # Prusament PLA - Prusa's premium PLA.
    "PrusamentPLA":
        type: "pla"
        name: "Prusament PLA"
        description: "Premium PLA with tight tolerances"
        brand: "Prusa"
        color: "#000000"
        diameter: 1.75
        density: 1.24
        weight: 1000
        cost: 25
        fan: 100
        temperature:
            bed: 60
            nozzle: 215
            standby: 190
        retraction:
            speed: 45
            distance: 5

    # Prusament PETG - Prusa's premium PETG.
    "PrusamentPETG":
        type: "petg"
        name: "Prusament PETG"
        description: "Premium PETG with excellent layer adhesion"
        brand: "Prusa"
        color: "#000000"
        diameter: 1.75
        density: 1.27
        weight: 1000
        cost: 28
        fan: 50
        temperature:
            bed: 85
            nozzle: 245
            standby: 225
        retraction:
            speed: 40
            distance: 6

    # Polymaker PolyLite PLA - Popular choice.
    "PolymakerPolyLitePLA":
        type: "pla"
        name: "Polymaker PolyLite PLA"
        description: "Easy to print PLA for beginners"
        brand: "Polymaker"
        color: "#000000"
        diameter: 1.75
        density: 1.24
        weight: 1000
        cost: 22
        fan: 100
        temperature:
            bed: 60
            nozzle: 210
            standby: 190
        retraction:
            speed: 45
            distance: 5

    # Polymaker PolyTerra PLA - Eco-friendly.
    "PolymakerPolyTerraPLA":
        type: "pla"
        name: "Polymaker PolyTerra PLA"
        description: "Eco-friendly matte finish PLA"
        brand: "Polymaker"
        color: "#000000"
        diameter: 1.75
        density: 1.24
        weight: 1000
        cost: 20
        fan: 100
        temperature:
            bed: 60
            nozzle: 210
            standby: 190
        retraction:
            speed: 45
            distance: 5

    # Bambu Lab PLA Basic - Bambu's standard PLA.
    "BambuLabPLABasic":
        type: "pla"
        name: "Bambu Lab PLA Basic"
        description: "Standard PLA optimized for Bambu printers"
        brand: "Bambu Lab"
        color: "#000000"
        diameter: 1.75
        density: 1.24
        weight: 1000
        cost: 20
        fan: 100
        temperature:
            bed: 60
            nozzle: 210
            standby: 190
        retraction:
            speed: 45
            distance: 5

    # Bambu Lab PETG-HF - High flow PETG.
    "BambuLabPETGHF":
        type: "petg"
        name: "Bambu Lab PETG-HF"
        description: "High flow PETG for fast printing"
        brand: "Bambu Lab"
        color: "#000000"
        diameter: 1.75
        density: 1.27
        weight: 1000
        cost: 30
        fan: 50
        temperature:
            bed: 80
            nozzle: 250
            standby: 230
        retraction:
            speed: 40
            distance: 6

    # Sunlu PLA - Budget friendly.
    "SunluPLA":
        type: "pla"
        name: "Sunlu PLA"
        description: "Budget-friendly PLA with good quality"
        brand: "Sunlu"
        color: "#000000"
        diameter: 1.75
        density: 1.24
        weight: 1000
        cost: 18
        fan: 100
        temperature:
            bed: 60
            nozzle: 205
            standby: 185
        retraction:
            speed: 45
            distance: 5

    # ColorFabb PLA/PHA - High quality blend.
    "ColorFabbPLAPHA":
        type: "pla"
        name: "ColorFabb PLA/PHA"
        description: "Premium PLA blend with enhanced properties"
        brand: "ColorFabb"
        color: "#000000"
        diameter: 1.75
        density: 1.24
        weight: 750
        cost: 35
        fan: 100
        temperature:
            bed: 60
            nozzle: 210
            standby: 190
        retraction:
            speed: 45
            distance: 5

    # NinjaFlex TPU - Premium flexible.
    "NinjaFlexTPU":
        type: "tpu"
        name: "NinjaFlex TPU"
        description: "Premium flexible filament"
        brand: "NinjaFlex"
        color: "#000000"
        diameter: 1.75
        density: 1.19
        weight: 500
        cost: 50
        fan: 50
        temperature:
            bed: 40
            nozzle: 225
            standby: 205
        retraction:
            speed: 20
            distance: 1

    # SainSmart TPU - Budget flexible.
    "SainSmartTPU":
        type: "tpu"
        name: "SainSmart TPU"
        description: "Affordable flexible filament"
        brand: "SainSmart"
        color: "#000000"
        diameter: 1.75
        density: 1.21
        weight: 800
        cost: 28
        fan: 50
        temperature:
            bed: 60
            nozzle: 220
            standby: 200
        retraction:
            speed: 25
            distance: 2

    # 3DXTech CarbonX - Carbon fiber nylon.
    "3DXTechCarbonX":
        type: "nylon"
        name: "3DXTech CarbonX"
        description: "Carbon fiber reinforced nylon"
        brand: "3DXTech"
        color: "#000000"
        diameter: 1.75
        density: 1.15
        weight: 500
        cost: 60
        fan: 20
        temperature:
            bed: 90
            nozzle: 260
            standby: 240
        retraction:
            speed: 40
            distance: 6

    # Ultimaker PLA - 2.85mm for Ultimaker.
    "UltimakerPLA":
        type: "pla"
        name: "Ultimaker PLA"
        description: "2.85mm PLA for Ultimaker printers"
        brand: "Ultimaker"
        color: "#000000"
        diameter: 2.85
        density: 1.24
        weight: 750
        cost: 30
        fan: 100
        temperature:
            bed: 60
            nozzle: 210
            standby: 190
        retraction:
            speed: 45
            distance: 6

    # Ultimaker Tough PLA - Impact resistant.
    "UltimakerToughPLA":
        type: "pla"
        name: "Ultimaker Tough PLA"
        description: "Impact resistant technical PLA"
        brand: "Ultimaker"
        color: "#000000"
        diameter: 2.85
        density: 1.24
        weight: 750
        cost: 45
        fan: 100
        temperature:
            bed: 60
            nozzle: 215
            standby: 195
        retraction:
            speed: 45
            distance: 6

module.exports = filaments
