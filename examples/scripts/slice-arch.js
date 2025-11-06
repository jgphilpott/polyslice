/**
 * Example showing how to slice an "arch" using CSG (default) or an STL with support structures.
 * This demonstrates support generation with either a procedurally-built arch (box - cylinder)
 * or a provided STL. The default is the CSG arch.
 *
 * Usage:
 *   node examples/scripts/slice-arch.js                # uses CSG arch (default)
 *   node examples/scripts/slice-arch.js --use-stl      # loads block.test.stl instead
 *
 * You can change the STL path or CSG params below.
 */

const { Polyslice, Printer, Filament } = require("../../src/index");
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

// Toggle: default to CSG arch; enable STL via flag/env
const useStl = process.argv.includes("--use-stl") || process.env.ARCH_USE_STL === "1";

// CSG Arch parameters
const ARCH_WIDTH = 40;     // X dimension (mm)
const ARCH_HEIGHT = 10;    // Y dimension (mm)
const ARCH_THICKNESS = 20; // Z dimension (mm)
const ARCH_RADIUS = 15;    // Radius of semi-circular cut (mm)

// STL path (if --use-stl)
const stlPath = path.join(__dirname, "..", "..", "resources", "support", "block.test.stl");

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
    finalMesh.rotation.y = Math.PI;
    return finalMesh;
}

// Main async function to create or load the model and slice
async function main() {
    let mesh;

    if (useStl) {
        console.log("Loading STL file...");
        console.log(`- Path: ${stlPath}\n`);
        try {
            const { STLLoader } = await import("three/examples/jsm/loaders/STLLoader.js");
            const buffer = fs.readFileSync(stlPath);
            const loader = new STLLoader();
            const geometry = loader.parse(buffer.buffer);
            const material = new THREE.MeshPhongMaterial({ color: 0x808080, specular: 0x111111, shininess: 200 });
            mesh = new THREE.Mesh(geometry, material);
            console.log("✅ STL file loaded successfully");
            console.log(`- Geometry type: ${mesh.geometry.type}`);
            console.log(`- Vertices: ${mesh.geometry.attributes.position.count}`);
            console.log(`- Triangles: ${mesh.geometry.attributes.position.count / 3}\n`);
        } catch (error) {
            console.error("❌ Failed to load STL file:", error.message);
            console.error(error.stack);
            process.exit(1);
        }
    } else {
        console.log("Building CSG arch (box minus cylinder) ...\n");
        mesh = await createArchMesh();
        // Simple inspection
        const pos = mesh.geometry.attributes.position;
        console.log("✅ Arch mesh created via CSG");
        console.log(`- Geometry type: ${mesh.geometry.type}`);
        console.log(`- Vertices: ${pos ? pos.count : "(unknown)"}`);
        if (pos) console.log(`- Triangles (approx): ${(pos.count / 3) | 0}\n`);
    }

    // Create slicer instance with support enabled.
    const slicer = new Polyslice({
        printer: printer,
        filament: filament,
        shellSkinThickness: 0.8,
        shellWallThickness: 0.8,
        lengthUnit: "millimeters",
        timeUnit: "seconds",
        infillPattern: "hexagons",
        infillDensity: 30,
        bedTemperature: 0,
        layerHeight: 0.2,
        testStrip: false,
        verbose: true,
        supportEnabled: false,
        supportType: "normal",
        supportPlacement: "buildPlate",
        supportThreshold: 45
    });

    console.log("Slicer Configuration:");
    console.log(`- Layer Height: ${slicer.getLayerHeight()}mm`);
    console.log(`- Nozzle Temperature: ${slicer.getNozzleTemperature()}°C`);
    console.log(`- Bed Temperature: ${slicer.getBedTemperature()}°C`);
    console.log(`- Fan Speed: ${slicer.getFanSpeed()}%`);
    console.log(`- Nozzle Diameter: ${slicer.getNozzleDiameter()}mm`);
    console.log(`- Filament Diameter: ${slicer.getFilamentDiameter()}mm`);
    console.log(`- Support Enabled: ${slicer.getSupportEnabled() ? "Yes" : "No"}`);
    console.log(`- Support Type: ${slicer.getSupportType()}`);
    console.log(`- Support Placement: ${slicer.getSupportPlacement()}`);
    console.log(`- Support Threshold: ${slicer.getSupportThreshold()}°`);
    console.log(`- Verbose Comments: ${slicer.getVerbose() ? "Enabled" : "Disabled"}\n`);

    // Slice the model with support generation.
    console.log("Slicing model with support generation...");
    const startTime = Date.now();
    const gcode = slicer.slice(mesh);
    const endTime = Date.now();

    console.log(`Slicing completed in ${endTime - startTime}ms\n`);

    // Analyze the G-code output.
    const lines = gcode.split("\n");
    const layerLines = lines.filter(line => line.includes("LAYER:"));
    const supportLines = lines.filter(line => line.toLowerCase().includes("support"));

    console.log("G-code Analysis:");
    console.log(`- Total lines: ${lines.length}`);
    console.log(`- Layers: ${layerLines.length}`);
    console.log(`- Support-related lines: ${supportLines.length}\n`);

    // Save G-code to file.
    const outputDir = path.join(__dirname, "..", "output");

    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
    }

    const baseName = useStl ? "block-with-supports" : "arch-with-supports";
    const gcodePath = path.join(outputDir, `${baseName}.gcode`);
    const stlPath = path.join(outputDir, `${baseName}.stl`);
    fs.writeFileSync(gcodePath, gcode);

    // Export STL for the mesh used (mirrors slice-holes behavior)
    try {
        await exportMeshAsSTL(mesh, stlPath);
        console.log(`🧊 STL saved to: ${stlPath}`);
    } catch (e) {
        console.warn(`⚠️  Failed to export STL: ${e.message}`);
    }

    console.log(`✅ G-code saved to: ${gcodePath}\n`);

    // Display support generation info.
    if (supportLines.length > 0) {
    console.log("Support Generation Details:");
        supportLines.slice(0, 10).forEach(line => {
            console.log(`  ${line.trim()}`);
        });

        if (supportLines.length > 10) {
            console.log(`  ... (${supportLines.length - 10} more support lines)\n`);
        }
    } else {
    console.log("⚠️  No support structures detected in G-code\n");
    }

    // Display some layer information.
        console.log("Layer Information:");
    const sampleLayers = layerLines.slice(0, 5);
    sampleLayers.forEach(line => {
        console.log(`- ${line.trim()}`);
    });

    if (layerLines.length > 5) {
        console.log(`... (${layerLines.length - 5} more layers)\n`);
    }

        console.log("✅ Support generation example completed successfully!");
        console.log("\nNotes:");
        console.log("- If no supports were generated, the model may not have overhangs");
        if (useStl) {
            console.log("- The block.test.stl is a simple rectangular block without overhangs");
            console.log("- Try the strip.test.stl file which may have overhanging features");
        } else {
            console.log("- The CSG arch subtracts a cylinder to create a semi-circular opening");
            console.log("- Tweak ARCH_* params at top to adjust width/height/radius");
        }
        console.log("\nNext steps:");
        console.log("- Load the G-code in a visualizer to inspect the sliced model");
        console.log("- Try different support thresholds (30°, 45°, 60°) to see the effect");
        console.log("- Create or load models with overhangs to test support generation");
        console.log("- Experiment with supportPlacement: \"buildPlate\" vs \"everywhere\"");
}

// Run the main function
main().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
