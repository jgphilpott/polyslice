/**
 * Example: slice a block "pyramid" built from unit cubes (no STL input) and a cylindrical stack variant.
 * Layers (pyramid):
 *   - Top: 1x1 cubes
 *   - Mid: 3x3 cubes
 *   - Base: 5x5 cubes
 *
 * Variants produced (G-code only):
 *   - block.gcode                (upright pyramid)
 *   - block-inverted.gcode       (pyramid rotated 180° about Y)
 *   - cylindrical.gcode          (stack of 3 cylinders: large, medium, small)
 *   - cylindrical-inverted.gcode (cylindrical variant rotated 180° about Y)
 *
 * Output directory:
 *   resources/gcode/skin/pyramid
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
  return finalMesh;
}

/**
 * Build a cylindrical "pyramid" (three stacked cylinders decreasing in radius).
 */
async function buildCylindricalStackMesh(unit = 5) {
  const mat = new THREE.MeshStandardMaterial({ color: 0x777777 });
  const large = new THREE.CylinderGeometry(unit * 5, unit * 5, unit, 64);
  const largeMesh = new THREE.Mesh(large, mat);
  largeMesh.position.set(0, 0, 0); // base: centered, height unit
  largeMesh.updateMatrixWorld();
  largeMesh.rotation.x = Math.PI / 2;

  const mid = new THREE.CylinderGeometry(unit * 3, unit * 3, unit, 64);
  const midMesh = new THREE.Mesh(mid, mat);
  midMesh.position.set(0, 0, unit);
  midMesh.updateMatrixWorld();
  midMesh.rotation.x = Math.PI / 2;

  const top = new THREE.CylinderGeometry(unit, unit, unit, 64);
  const topMesh = new THREE.Mesh(top, mat);
  topMesh.position.set(0, 0, unit * 2);
  topMesh.updateMatrixWorld();
  topMesh.rotation.x = Math.PI / 2;

  // Unite the three cylinders into one mesh
  const temp = await Polytree.unite(largeMesh, midMesh);
  const full = await Polytree.unite(temp, topMesh);
  const finalMesh = new THREE.Mesh(full.geometry, mat);
  finalMesh.position.set(0, 0, 0);
  finalMesh.updateMatrixWorld();

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
    supportEnabled: false,
    metadata: false
  });

  console.log("Slicer Configuration:");
  console.log(`- Layer Height: ${slicer.getLayerHeight()} mm`);
  console.log(`- Nozzle: ${slicer.getNozzleDiameter()} mm`);
  console.log(`- Infill: ${slicer.getInfillPattern()} ${slicer.getInfillDensity()}%`);
  console.log(`- Verbose: ${slicer.getVerbose() ? "On" : "Off"}\n`);

  // Build cylinder variant
  console.log("Building cylindrical stack (three decreasing cylinders)...");
  const cylMesh = await buildCylindricalStackMesh();
  const cpos = cylMesh.geometry.attributes.position;
  console.log("✅ Cylindrical mesh created");
  console.log(`- Geometry: ${cylMesh.geometry.type}`);
  console.log(`- Vertices: ${cpos ? cpos.count : "unknown"}`);
  if (cpos) console.log(`- Triangles (approx): ${(cpos.count / 3) | 0}\n`);

  // Output directory for G-code variants
  const outDir = path.join(__dirname, "..", "..", "resources", "gcode", "skin", "pyramid");
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

  const variants = [
    { name: "block", mesh: mesh, rotY: 0 },
    { name: "block-inverted", mesh: mesh, rotY: Math.PI },
    { name: "cylindrical", mesh: cylMesh, rotY: 0 },
    { name: "cylindrical-inverted", mesh: cylMesh, rotY: Math.PI },
  ];

  for (const v of variants) {
    console.log(`Slicing variant: ${v.name}`);
    // Clone geometry + material (avoid mutating originals)
    const variant = new THREE.Mesh(v.mesh.geometry.clone(), v.mesh.material);
    variant.position.copy(v.mesh.position);
    variant.rotation.copy(v.mesh.rotation);
    variant.scale.copy(v.mesh.scale);
    variant.rotation.y += v.rotY;
    variant.updateMatrixWorld(true);
    const tStart = Date.now();
    const gcodeLocal = slicer.slice(variant);
    const tEnd = Date.now();
    console.log(`- Sliced in ${tEnd - tStart} ms`);
    const filePath = path.join(outDir, `${v.name}.gcode`);
    fs.writeFileSync(filePath, gcodeLocal);
    const size = fs.statSync(filePath).size;
    const lines = gcodeLocal.split("\n");
    const layers = lines.filter(l => l.includes("LAYER:")).length;
    console.log(`- Saved: ${filePath} (${formatBytes(size)})`);
    console.log(`  Lines: ${lines.length}, Layers: ${layers}`);
  }

  console.log("\n✅ All variants sliced successfully.");
}

// Run
main().catch(err => {
  console.error("Error:", err);
  process.exit(1);
});
