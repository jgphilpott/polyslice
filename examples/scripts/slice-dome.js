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
//   finalMesh.rotation.y = Math.PI; // flip
  return finalMesh;
}

// Main async function to create the model and slice
async function main() {
  console.log("Building CSG dome (box minus hemispherical cut) ...\n");
  const mesh = await createDomeMesh();

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
    infillPatternCentering: "global",
    infillPattern: "grid",
    infillDensity: 20,
    bedTemperature: 0,
    layerHeight: 0.2,
    testStrip: false,
    verbose: true,
    supportEnabled: false,
    metadata: false,
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

  // Produce three orientations into resources/gcode/skin/dome
  const outputDir = path.join(__dirname, "..", "..", "resources", "gcode", "skin", "dome");
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const orientations = [
    { name: "upright", rotY: 0 },
    { name: "flipped", rotY: Math.PI },
    { name: "sideways", rotY: Math.PI / 2 },
  ];

  for (const o of orientations) {
    // Clone mesh so rotations don't accumulate
    const variant = new THREE.Mesh(mesh.geometry.clone(), mesh.material);
    variant.position.copy(mesh.position);
    variant.rotation.copy(mesh.rotation);
    variant.scale.copy(mesh.scale);
    variant.rotation.y += o.rotY;
    variant.updateMatrixWorld(true);

    console.log(`Slicing (${o.name})...`);
    const start = Date.now();
    const gcode = slicer.slice(variant);
    const end = Date.now();
    console.log(`- Done in ${end - start}ms`);

    const outPath = path.join(outputDir, `${o.name}.gcode`);
    fs.writeFileSync(outPath, gcode);
    console.log(`✅ Saved: ${outPath}`);
  }

  // Export single STL (upright) to examples/output as dome.stl
  const stlOutDir = path.join(__dirname, "..", "output");
  if (!fs.existsSync(stlOutDir)) {
    fs.mkdirSync(stlOutDir, { recursive: true });
  }
  const stlPathOut = path.join(stlOutDir, "dome.stl");
  try {
    await exportMeshAsSTL(mesh, stlPathOut);
    console.log(`🧊 STL saved to: ${stlPathOut}`);
  } catch (e) {
    console.warn(`⚠️  Failed to export STL: ${e.message}`);
  }

  console.log("\n✅ Dome example completed successfully!");
}

// Run the main function
main().catch((error) => {
  console.error("Error:", error);
  process.exit(1);
});
