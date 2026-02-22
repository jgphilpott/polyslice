/**
 * Example showing how to slice arch and dome shapes with support structures enabled.
 * This script outputs G-code to resources/gcode/support for version control and study.
 *
 * Shapes:
 * - Arch: Box minus horizontal cylinder (semi-circular opening)
 * - Dome: Box minus hemisphere (dome ceiling cavity)
 * - Strip: Test strip with various threshold values
 *
 * Each shape is sliced in three orientations:
 * - upright (0°)
 * - flipped (180°)
 * - sideways (90°)
 *
 * Both support types are generated for arch and dome:
 * - normal: resources/gcode/support/normal/arch and resources/gcode/support/normal/dome
 * - tree:   resources/gcode/support/tree/arch   and resources/gcode/support/tree/dome
 *
 * The strip is sliced with threshold values from 0 to 100 (step 10).
 *
 * Usage:
 *   node examples/scripts/slice-supports.js
 */

const { Polyslice, Printer, Filament, Loader } = require("../../src/index");
const fs = require("fs");
const path = require("path");
const THREE = require("three");
const { Polytree } = require("@jgphilpott/polytree");

// Export a mesh as an STL (binary) using three's STLExporter (ESM-only)
async function exportMeshAsSTL(object, outPath) {
    const mod = await import("three/examples/jsm/exporters/STLExporter.js");
    const STLExporter = mod.STLExporter || mod.default?.STLExporter || mod.default;
    const exporter = new STLExporter();
    const data = exporter.parse(object, { binary: true });

    let nodeBuffer;
    if (typeof data === "string") {
        nodeBuffer = Buffer.from(data, "utf8");
    } else if (ArrayBuffer.isView(data)) {
        nodeBuffer = Buffer.from(data.buffer, data.byteOffset || 0, data.byteLength);
    } else if (data instanceof ArrayBuffer) {
        nodeBuffer = Buffer.from(data);
    } else {
        throw new Error("Unexpected STLExporter output type");
    }

    fs.writeFileSync(outPath, nodeBuffer);
    return outPath;
}

console.log("Polyslice Support Generation Example");
console.log("====================================\n");

// Create printer and filament configuration objects.
const printer = new Printer("Ender5");
const filament = new Filament("GenericPLA");

console.log("Printer & Filament Configuration:");
console.log(`- Printer: ${printer.model}`);
console.log(`- Build Volume: ${printer.getSizeX()}x${printer.getSizeY()}x${printer.getSizeZ()}mm`);
console.log(`- Filament: ${filament.name} (${filament.type.toUpperCase()})`);
console.log(`- Brand: ${filament.brand}\n`);

// Arch parameters
const ARCH_WIDTH = 40;     // X dimension (mm)
const ARCH_HEIGHT = 10;    // Y dimension (mm)
const ARCH_THICKNESS = 20; // Z dimension (mm)
const ARCH_RADIUS = 15;    // Radius of semi-circular cut (mm)

// Dome parameters
const DOME_WIDTH = 25;       // X dimension (mm)
const DOME_DEPTH = 25;       // Y dimension (mm)
const DOME_THICKNESS = 12;   // Z dimension (mm)
const DOME_RADIUS = 10;      // Radius of hemispherical cut (mm)

/**
 * Build an arch by subtracting a horizontal cylinder (lying flat) from a box.
 * Box is centered at origin; cylinder axis along X (flat), offset +Y by half height to form a semi-circle cut.
 * Final mesh is lifted so the bottom sits on Z=0 for printing.
 */
async function createArchMesh(width = ARCH_WIDTH, height = ARCH_HEIGHT, thickness = ARCH_THICKNESS, radius = ARCH_RADIUS) {
    // Base box
    const boxGeo = new THREE.BoxGeometry(width, height, thickness);
    const boxMesh = new THREE.Mesh(boxGeo, new THREE.MeshBasicMaterial());

    // Cylinder lying flat along X: default cylinder axis is Y, rotate about Z by 90° -> axis becomes X
    const cylLength = width * 1.25; // ensure it spans the box width
    const cylGeo = new THREE.CylinderGeometry(radius, radius, cylLength, 48);
    const cylMesh = new THREE.Mesh(cylGeo, new THREE.MeshBasicMaterial());
    cylMesh.position.z = -height;
    cylMesh.updateMatrixWorld();

    // Subtract cylinder from box to form arch opening using Polytree
    const resultMesh = await Polytree.subtract(boxMesh, cylMesh);

    // Wrap in a new THREE.Mesh to ensure full compatibility with three.js tools.
    const finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material);
    finalMesh.position.set(0, 0, thickness / 2);
    finalMesh.updateMatrixWorld();
    return finalMesh;
}

/**
 * Build a dome by subtracting a sphere positioned so its center lies on the box's top face.
 * Box is centered at origin before we raise it; the sphere center is placed at Z=+thickness/2.
 * After CSG, we lift the final mesh so Z=0 is the build plate.
 */
async function createDomeMesh(width = DOME_WIDTH, depth = DOME_DEPTH, thickness = DOME_THICKNESS, radius = DOME_RADIUS) {
    // Clamp radius to fit within the box and look reasonable
    const maxRadiusXY = Math.min(width, depth) * 0.49;
    const maxRadiusZ = thickness; // hemisphere must fit within thickness to avoid a bottom hole
    const r = Math.min(radius, maxRadiusXY, maxRadiusZ);

    // Base box
    const boxGeo = new THREE.BoxGeometry(width, depth, thickness);
    const boxMesh = new THREE.Mesh(boxGeo, new THREE.MeshBasicMaterial());

    // Sphere for dome cavity (high segment counts for smoothness)
    const sphereGeo = new THREE.SphereGeometry(r, 64, 48);
    const sphereMesh = new THREE.Mesh(sphereGeo, new THREE.MeshBasicMaterial());
    // Place the sphere center on the top face plane so the lower hemisphere carves a dome
    sphereMesh.position.set(0, 0, -(thickness / 2));
    sphereMesh.updateMatrixWorld();

    // Subtract sphere from box to form the dome cavity using Polytree
    const resultMesh = await Polytree.subtract(boxMesh, sphereMesh);

    // Wrap in a new THREE.Mesh to ensure full compatibility with three.js tools.
    const finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material);
    finalMesh.position.set(0, 0, thickness / 2);
    finalMesh.updateMatrixWorld();
    return finalMesh;
}

/**
 * Slice a mesh with the given support type and save results to the output directory.
 */
async function sliceWithSupportType(slicer, mesh, meshName, supportType, outputDir, orientations) {
    slicer.setSupportType(supportType);

    console.log(`=== Slicing ${meshName} (support: ${supportType}) ===\n`);

    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
        console.log(`📁 Created directory: ${outputDir}\n`);
    }

    for (const o of orientations) {
        // For sideways orientation, generate two versions: buildPlate and everywhere
        const placements = (o.name === "sideways") ? ["buildPlate", "everywhere"] : ["buildPlate"];

        for (const placement of placements) {
            slicer.setSupportPlacement(placement);

            // Clone mesh to avoid mutating base orientation
            const variant = new THREE.Mesh(mesh.geometry.clone(), mesh.material);
            variant.position.copy(mesh.position);
            variant.rotation.copy(mesh.rotation);
            variant.scale.copy(mesh.scale);
            variant.rotation.y += o.rotY;
            variant.updateMatrixWorld(true);

            const placementSuffix = (o.name === "sideways") ? ((placement === "everywhere") ? "-everywhere" : "-buildPlate") : "";
            console.log(`Slicing ${meshName} (${o.name}${placementSuffix})...`);
            console.log(`  Support type: ${supportType}, placement: ${placement}`);

            const start = Date.now();
            const gcode = slicer.slice(variant);
            const end = Date.now();
            console.log(`- Done in ${end - start}ms`);

            const outPath = path.join(outputDir, `${o.name}${placementSuffix}.gcode`);
            fs.writeFileSync(outPath, gcode);
            console.log(`✅ Saved: ${outPath}`);

            // Brief stats
            const lines = gcode.split("\n");
            const supportLines = lines.filter(line => line.includes("TYPE: SUPPORT"));
            console.log(`- Total lines: ${lines.length}, Support type lines: ${supportLines.length}\n`);
        }
    }
}

// Main async function to create the models and slice with supports enabled
async function main() {
    console.log("Building CSG geometries...\n");

    // Create arch mesh
    console.log("Creating arch (box minus cylinder)...");
    const archMesh = await createArchMesh();
    const archPos = archMesh.geometry.attributes.position;
    console.log("✅ Arch mesh created via CSG");
    console.log(`- Geometry type: ${archMesh.geometry.type}`);
    console.log(`- Vertices: ${archPos ? archPos.count : "(unknown)"}`);
    if (archPos) console.log(`- Triangles (approx): ${(archPos.count / 3) | 0}\n`);

    // Create dome mesh
    console.log("Creating dome (box minus hemisphere)...");
    const domeMesh = await createDomeMesh();
    const domePos = domeMesh.geometry.attributes.position;
    console.log("✅ Dome mesh created via CSG");
    console.log(`- Geometry type: ${domeMesh.geometry.type}`);
    console.log(`- Vertices: ${domePos ? domePos.count : "(unknown)"}`);
    if (domePos) console.log(`- Triangles (approx): ${(domePos.count / 3) | 0}\n`);

    // Create slicer instance with support enabled.
    const slicer = new Polyslice({
        printer: printer,
        filament: filament,
        shellSkinThickness: 0.8,
        shellWallThickness: 0.8,
        lengthUnit: "millimeters",
        timeUnit: "seconds",
        infillPatternCentering: "global",
        infillPattern: "grid",
        infillDensity: 20,
        bedTemperature: 0,
        layerHeight: 0.2,
        testStrip: false,
        metadata: false,
        verbose: true,

        // Support Settings
        supportEnabled: true,
        supportType: "normal",
        supportPlacement: "buildPlate",
        supportThreshold: 55

    });

    console.log("Slicer Configuration:");
    console.log(`- Layer Height: ${slicer.getLayerHeight()}mm`);
    console.log(`- Nozzle Temperature: ${slicer.getNozzleTemperature()}°C`);
    console.log(`- Bed Temperature: ${slicer.getBedTemperature()}°C`);
    console.log(`- Fan Speed: ${slicer.getFanSpeed()}%`);
    console.log(`- Nozzle Diameter: ${slicer.getNozzleDiameter()}mm`);
    console.log(`- Filament Diameter: ${slicer.getFilamentDiameter()}mm`);
    console.log(`- Support Enabled: ${slicer.getSupportEnabled() ? "Yes ✅" : "No"}`);
    console.log(`- Support Placement: ${slicer.getSupportPlacement()}`);
    console.log(`- Support Threshold: ${slicer.getSupportThreshold()}°`);
    console.log(`- Verbose Comments: ${slicer.getVerbose() ? "Enabled" : "Disabled"}\n`);

    // Define orientations (same as skin scripts)
    const orientations = [
        { name: "upright", rotY: 0 },
        { name: "flipped", rotY: Math.PI },
        { name: "sideways", rotY: Math.PI / 2 },
    ];

    const supportDir = path.join(__dirname, "..", "..", "resources", "gcode", "support");

    // Slice arch and dome with normal support type
    await sliceWithSupportType(slicer, archMesh, "arch", "normal", path.join(supportDir, "normal", "arch"), orientations);
    await sliceWithSupportType(slicer, domeMesh, "dome", "normal", path.join(supportDir, "normal", "dome"), orientations);

    // Slice arch and dome with tree support type
    await sliceWithSupportType(slicer, archMesh, "arch", "tree", path.join(supportDir, "tree", "arch"), orientations);
    await sliceWithSupportType(slicer, domeMesh, "dome", "tree", path.join(supportDir, "tree", "dome"), orientations);

    // Slice strip.test.stl with various threshold values
    console.log("=== Slicing Strip with Threshold Variations ===\n");

    const stripStlPath = path.join(__dirname, "..", "..", "resources", "testing", "strip.test.stl");
    console.log(`Loading strip.test.stl from: ${stripStlPath}`);

    let stripMesh = null;
    try {
        stripMesh = await Loader.loadSTL(stripStlPath);
        console.log("✅ Strip mesh loaded successfully");
        const stripPos = stripMesh.geometry.attributes.position;
        console.log(`- Geometry type: ${stripMesh.geometry.type}`);
        console.log(`- Vertices: ${stripPos ? stripPos.count : "(unknown)"}`);
        if (stripPos) console.log(`- Triangles (approx): ${(stripPos.count / 3) | 0}\n`);
    } catch (e) {
        console.warn(`⚠️  Failed to load strip.test.stl: ${e.message}`);
        console.log("Skipping threshold examples.\n");
    }

    // Define threshold output directory (used later for logging)
    const thresholdOutputDir = path.join(supportDir, "threshold");

    if (stripMesh) {
        if (!fs.existsSync(thresholdOutputDir)) {
            fs.mkdirSync(thresholdOutputDir, { recursive: true });
            console.log(`📁 Created directory: ${thresholdOutputDir}\n`);
        }

        // Reset support type and placement for threshold tests
        slicer.setSupportType("normal");
        slicer.setSupportPlacement("buildPlate");

        // Switch to object-centered infill for threshold tests
        slicer.setInfillPatternCentering("object");
        console.log("Switched infill centering to 'object' mode for threshold tests\n");

        // Generate G-code for threshold values from 0 to 100, step 10
        for (let threshold = 0; threshold <= 100; threshold += 10) {
            console.log(`Slicing strip with threshold ${threshold}°...`);
            slicer.setSupportThreshold(threshold);

            const start = Date.now();
            const gcode = slicer.slice(stripMesh);
            const end = Date.now();
            console.log(`- Done in ${end - start}ms`);

            const outPath = path.join(thresholdOutputDir, `${threshold}-degrees.gcode`);
            fs.writeFileSync(outPath, gcode);
            console.log(`✅ Saved: ${outPath}`);

            // Brief stats
            const lines = gcode.split("\n");
            const supportLines = lines.filter(line => line.includes("TYPE: SUPPORT"));
            console.log(`- Total lines: ${lines.length}, Support type lines: ${supportLines.length}\n`);
        }
    }

    // Export STLs to examples/output for reference
    const stlOutDir = path.join(__dirname, "..", "output");
    if (!fs.existsSync(stlOutDir)) {
        fs.mkdirSync(stlOutDir, { recursive: true });
    }

    console.log("=== Exporting STL Files ===\n");

    const archStlPath = path.join(stlOutDir, "arch.stl");
    try {
        await exportMeshAsSTL(archMesh, archStlPath);
        console.log(`🧊 Arch STL saved to: ${archStlPath}`);
    } catch (e) {
        console.warn(`⚠️  Failed to export arch STL: ${e.message}`);
    }

    const domeStlPath = path.join(stlOutDir, "dome.stl");
    try {
        await exportMeshAsSTL(domeMesh, domeStlPath);
        console.log(`🧊 Dome STL saved to: ${domeStlPath}`);
    } catch (e) {
        console.warn(`⚠️  Failed to export dome STL: ${e.message}`);
    }

    console.log("\n✅ Support generation example completed successfully!");
    console.log("\nOutput locations:");
    console.log(`- Normal arch G-code: ${path.join(supportDir, "normal", "arch")}`);
    console.log(`- Normal dome G-code: ${path.join(supportDir, "normal", "dome")}`);
    console.log(`- Tree arch G-code:   ${path.join(supportDir, "tree", "arch")}`);
    console.log(`- Tree dome G-code:   ${path.join(supportDir, "tree", "dome")}`);
    if (stripMesh) {
        console.log(`- Threshold examples: ${thresholdOutputDir}`);
    }
    console.log("\nNotes:");
    console.log("- All shapes sliced with supports enabled (supportEnabled: true)");
    console.log("- Arch and Dome: Support threshold set to 55° (faces angled more than 55° from vertical get supports)");
    console.log("- Tree supports use fine contact grid near overhang and coarse trunk columns below");
    console.log("- Threshold examples: Strip sliced with thresholds from 0° to 100° (step 10°)");
    console.log("- Three orientations per shape: upright, flipped, sideways");
    console.log("- Output is version controlled in resources/gcode/support/ for algorithm study");
}

// Run the main function
main().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
