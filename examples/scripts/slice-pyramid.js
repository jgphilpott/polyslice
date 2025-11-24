/**
 * Example: slice a block "pyramid" built from unit cubes (no STL input).
 * Layers:
 *   - Top: 1x1 cubes
 *   - Mid: 3x3 cubes
 *   - Base: 5x5 cubes
 *
 * Outputs:
 *   - examples/output/block-pyramid.gcode
 *   - examples/output/block-pyramid.stl
 */

const { Polyslice, Printer, Filament } = require("../../src/index");
const fs = require("fs");
const path = require("path");
const THREE = require("three");
const { Polytree } = require("@jgphilpott/polytree");

// Reusable STL export helper (binary) using three's STLExporter (ESM-only)
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

function formatBytes(bytes) {
  if (!Number.isFinite(bytes)) return `${bytes}`;
  if (bytes < 1024) return `${bytes} B`;
  const units = ["KB", "MB", "GB"];
  let i = -1;
  do {
    bytes = bytes / 1024;
    i++;
  } while (bytes >= 1024 && i < units.length - 1);
  return `${bytes.toFixed(1)} ${units[i]}`;
}

/**
 * Build a block pyramid mesh using Polytree CSG by subtracting recesses from the largest slab.
 * We start with a tall 5x5x(3*cubeSize) block then carve out outer material above each smaller footprint
 * so remaining solid appears as stacked 5x5, 3x3, 1x1 slabs (upright, base at Z=0).
 */
async function buildBlockPyramidMesh(cubeSize = 10) {
  const mat = new THREE.MeshStandardMaterial({ color: 0x888888 });

  const baseSlab = new THREE.BoxGeometry(5 * cubeSize, 5 * cubeSize, cubeSize);
  const baseSlabMesh = new THREE.Mesh(baseSlab, mat);
  baseSlabMesh.position.set(0, 0, 0);
  baseSlabMesh.updateMatrixWorld();

  const midSlab = new THREE.BoxGeometry(3 * cubeSize, 3 * cubeSize, cubeSize);
  const midSlabMesh = new THREE.Mesh(midSlab, mat);
  midSlabMesh.position.set(0, 0, cubeSize);
  midSlabMesh.updateMatrixWorld();

  const tobSlab = new THREE.BoxGeometry(cubeSize, cubeSize, cubeSize);
  const tobSlabMesh = new THREE.Mesh(tobSlab, mat);
  tobSlabMesh.position.set(0, 0, cubeSize * 2); // second layer region to carve perimeter leaving 3x3
  tobSlabMesh.updateMatrixWorld();

  const pyramidMeshTemp = await Polytree.unite(baseSlabMesh, midSlabMesh);
  const pyramidMesh = await Polytree.unite(pyramidMeshTemp, tobSlabMesh);

  const finalMesh = new THREE.Mesh(pyramidMesh.geometry, mat);
  finalMesh.position.set(0, 0, 0);
  finalMesh.updateMatrixWorld();
//   finalMesh.rotation.y = Math.PI; // flip
  return finalMesh;
}

async function main() {
  console.log("Polyslice Block Pyramid Example");
  console.log("================================\n");

  // Printer & filament setup
  const printer = new Printer("Ender5");
  const filament = new Filament("GenericPLA");

  console.log("Printer & Filament:");
  console.log(`- Printer: ${printer.model}`);
  console.log(`- Volume: ${printer.getSizeX()}x${printer.getSizeY()}x${printer.getSizeZ()} mm`);
  console.log(`- Filament: ${filament.name} (${filament.type.toUpperCase()})\n`);

  // Build mesh
  console.log("Building pyramid mesh from cubes (1x1, 3x3, 5x5)...");
  const mesh = await buildBlockPyramidMesh(10);
  const pos = mesh.geometry.attributes.position;
  console.log("✅ Mesh created");
  console.log(`- Geometry: ${mesh.geometry.type}`);
  console.log(`- Vertices: ${pos ? pos.count : "unknown"}`);
  if (pos) console.log(`- Triangles (approx): ${(pos.count / 3) | 0}\n`);

  // Slicer configuration
  const slicer = new Polyslice({
    printer,
    filament,
    shellSkinThickness: 0.8,
    shellWallThickness: 0.8,
    lengthUnit: "millimeters",
    timeUnit: "seconds",
    infillPattern: "grid",
    infillDensity: 20,
    bedTemperature: 0,
    layerHeight: 0.2,
    testStrip: false,
    verbose: true,
    supportEnabled: false
  });

  console.log("Slicer Configuration:");
  console.log(`- Layer Height: ${slicer.getLayerHeight()} mm`);
  console.log(`- Nozzle: ${slicer.getNozzleDiameter()} mm`);
  console.log(`- Infill: ${slicer.getInfillPattern()} ${slicer.getInfillDensity()}%`);
  console.log(`- Verbose: ${slicer.getVerbose() ? "On" : "Off"}\n`);

  // Slice
  console.log("Slicing pyramid...");
  const t0 = Date.now();
  const gcode = slicer.slice(mesh);
  const dt = Date.now() - t0;
  console.log(`✅ Sliced in ${dt} ms`);

  // Save outputs
  const outDir = path.join(__dirname, "..", "output");
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

  const baseName = "block-pyramid";
  const gcodePath = path.join(outDir, `${baseName}.gcode`);
  const stlPath = path.join(outDir, `${baseName}.stl`);
  fs.writeFileSync(gcodePath, gcode);

  try {
    await exportMeshAsSTL(mesh, stlPath);
    const gsz = fs.statSync(gcodePath).size;
    const ssz = fs.statSync(stlPath).size;
    console.log(`🧾 G-code: ${gcodePath} (${formatBytes(gsz)})`);
    console.log(`🧊 STL:    ${stlPath} (${formatBytes(ssz)})\n`);
  } catch (e) {
    console.warn(`⚠️  STL export failed: ${e.message}`);
    const gsz = fs.statSync(gcodePath).size;
    console.log(`🧾 G-code: ${gcodePath} (${formatBytes(gsz)})\n`);
  }

  // Quick G-code stats
  const lines = gcode.split("\n");
  const layers = lines.filter(l => l.includes("LAYER:")).length;
  console.log("G-code Summary:");
  console.log(`- Lines: ${lines.length}`);
  console.log(`- Layers: ${layers}`);
  console.log("Done.");
}

// Run
main().catch(err => {
  console.error("Error:", err);
  process.exit(1);
});
