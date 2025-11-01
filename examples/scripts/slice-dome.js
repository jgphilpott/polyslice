/**
 * Example showing how to slice a "dome" using CSG only (no STL option).
 * The dome is created by subtracting a half-sphere from the top of a box,
 * producing a hemispherical cavity (a dome ceiling) that demonstrates overhangs/supports.
 *
 * Usage:
 *   node examples/scripts/slice-dome.js
 */

const { Polyslice, Printer, Filament } = require("../../src/index");
const fs = require("fs");
const path = require("path");
const THREE = require("three");
const { Brush, Evaluator, SUBTRACTION } = require("three-bvh-csg");

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

console.log("Polyslice Dome (CSG) Example");
console.log("============================\n");

// Create printer and filament configuration objects.
const printer = new Printer("Ender5");
const filament = new Filament("GenericPLA");

console.log("Printer & Filament Configuration:");
console.log(`- Printer: ${printer.model}`);
console.log(`- Build Volume: ${printer.getSizeX()}x${printer.getSizeY()}x${printer.getSizeZ()}mm`);
console.log(`- Filament: ${filament.name} (${filament.type.toUpperCase()})`);
console.log(`- Brand: ${filament.brand}\n`);

// Dome parameters (box in X/Y/Z, sphere radius for dome cavity)
const DOME_WIDTH = 25;       // X dimension (mm)
const DOME_DEPTH = 25;       // Y dimension (mm)
const DOME_THICKNESS = 12;   // Z dimension (mm)
const DOME_RADIUS = 10;      // Radius of hemispherical cut (mm)

/**
 * Build a dome by subtracting a sphere positioned so its center lies on the box's top face.
 * Box is centered at origin before we raise it; the sphere center is placed at Z=+thickness/2.
 * After CSG, we lift the final mesh so Z=0 is the build plate.
 */
function createDomeMesh(width = DOME_WIDTH, depth = DOME_DEPTH, thickness = DOME_THICKNESS, radius = DOME_RADIUS) {
  // Clamp radius to fit within the box and look reasonable
  const maxRadiusXY = Math.min(width, depth) * 0.49;
  const maxRadiusZ = thickness; // hemisphere must fit within thickness to avoid a bottom hole
  const r = Math.min(radius, maxRadiusXY, maxRadiusZ);

  // Base box
  const boxGeo = new THREE.BoxGeometry(width, depth, thickness);
  const boxBrush = new Brush(boxGeo);
  boxBrush.updateMatrixWorld();

  // Sphere for dome cavity (high segment counts for smoothness)
  const sphereGeo = new THREE.SphereGeometry(r, 64, 48);
  const sphereBrush = new Brush(sphereGeo);
  // Place the sphere center on the top face plane so the lower hemisphere carves a dome
  sphereBrush.position.set(0, 0, -(thickness / 2));
  sphereBrush.updateMatrixWorld();

  // Subtract sphere from box to form the dome cavity
  const evalCSG = new Evaluator();
  const resultBrush = evalCSG.evaluate(boxBrush, sphereBrush, SUBTRACTION);

  // Create mesh and place on build plate
  const mat = new THREE.MeshBasicMaterial();
  const domeMesh = new THREE.Mesh(resultBrush.geometry, mat);
  domeMesh.position.set(0, 0, thickness / 2);
  domeMesh.updateMatrixWorld();
  return domeMesh;
}

// Main async function to create the model and slice
async function main() {
  console.log("Building CSG dome (box minus hemispherical cut) ...\n");
  const mesh = createDomeMesh();

  // Inspect geometry briefly
  const pos = mesh.geometry.attributes.position;
  console.log("✅ Dome mesh created via CSG");
  console.log(`- Geometry type: ${mesh.geometry.type}`);
  console.log(`- Vertices: ${pos ? pos.count : "(unknown)"}`);
  if (pos) console.log(`- Triangles (approx): ${(pos.count / 3) | 0}\n`);

  // Create slicer instance (supports enabled to highlight overhangs under the dome)
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
    supportEnabled: true,
    supportType: "normal",
    supportPlacement: "buildPlate",
    supportThreshold: 45,
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

  // Slice the model
  console.log("Slicing model with support generation...");
  const startTime = Date.now();
  const gcode = slicer.slice(mesh);
  const endTime = Date.now();

  console.log(`Slicing completed in ${endTime - startTime}ms\n`);

  // Analyze the G-code output.
  const lines = gcode.split("\n");
  const layerLines = lines.filter((line) => line.includes("LAYER:"));
  const supportLines = lines.filter((line) => line.toLowerCase().includes("support"));

  console.log("G-code Analysis:");
  console.log(`- Total lines: ${lines.length}`);
  console.log(`- Layers: ${layerLines.length}`);
  console.log(`- Support-related lines: ${supportLines.length}\n`);

  // Save G-code to file.
  const outputDir = path.join(__dirname, "..", "output");

  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const baseName = "dome-with-supports";
  const gcodePath = path.join(outputDir, `${baseName}.gcode`);
  const stlPath = path.join(outputDir, `${baseName}.stl`);
  fs.writeFileSync(gcodePath, gcode);

  try {
    await exportMeshAsSTL(mesh, stlPath);
    console.log(`🧊 STL saved to: ${stlPath}`);
  } catch (e) {
    console.warn(`⚠️  Failed to export STL: ${e.message}`);
  }

  console.log(`✅ G-code saved to: ${gcodePath}\n`);

  // Support details preview
  if (supportLines.length > 0) {
    console.log("Support Generation Details:");
    supportLines.slice(0, 10).forEach((line) => {
      console.log(`  ${line.trim()}`);
    });
    if (supportLines.length > 10) {
      console.log(`  ... (${supportLines.length - 10} more support lines)\n`);
    }
  } else {
    console.log("⚠️  No support structures detected in G-code\n");
  }

  // Layer info preview
  console.log("Layer Information:");
  const sampleLayers = layerLines.slice(0, 5);
  sampleLayers.forEach((line) => {
    console.log(`- ${line.trim()}`);
  });
  if (layerLines.length > 5) {
    console.log(`... (${layerLines.length - 5} more layers)\n`);
  }

  console.log("✅ Dome example completed successfully!");
}

// Run the main function
main().catch((error) => {
  console.error("Error:", error);
  process.exit(1);
});
