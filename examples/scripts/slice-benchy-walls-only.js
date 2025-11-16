/**
 * Fast debug script: Slice Benchy with OUTER WALLS ONLY
 * This skips infill, skin, and support generation for faster iteration during debugging.
 */

const { Polyslice, Printer, Filament } = require("../../src/index");
const fs = require("fs");
const path = require("path");
const THREE = require("three");

async function loadSTLMesh(stlPath) {
  const { STLLoader } = await import("three/examples/jsm/loaders/STLLoader.js");
  const buffer = fs.readFileSync(stlPath);
  const loader = new STLLoader();
  const geometry = loader.parse(buffer.buffer);
  geometry.computeVertexNormals?.();
  const material = new THREE.MeshPhongMaterial({ color: 0x808080 });
  const mesh = new THREE.Mesh(geometry, material);

  // Place bottom at Z=0 (build plate)
  geometry.computeBoundingBox();
  const bb = geometry.boundingBox;
  const zShift = -bb.min.z;
  mesh.position.set(0, 0, zShift);
  mesh.updateMatrixWorld();
  return mesh;
}

async function main() {
  console.log("Polyslice Benchy - WALLS ONLY (Fast Debug Mode)");
  console.log("================================================\n");

  const printer = new Printer("Ender5");
  const filament = new Filament("GenericPLA");

  console.log("Config:");
  console.log(`- Printer: ${printer.model}`);
  console.log(`- Filament: ${filament.name}\n`);

  const stlPath = path.join(__dirname, "../../resources/testing/benchy.test.stl");
  console.log("Loading STL...");

  let mesh;
  try {
    mesh = await loadSTLMesh(stlPath);
  } catch (err) {
    console.error("Failed to load STL:", err.message);
    process.exit(1);
  }

  const pos = mesh.geometry.attributes.position;
  console.log("✅ Mesh loaded");
  console.log(`- Vertices: ${pos ? pos.count : "unknown"}`);
  console.log(`- Triangles: ~${pos ? (pos.count / 3) | 0 : "unknown"}\n`);

  // Configure slicer with MINIMAL settings for fastest slicing
  const slicer = new Polyslice({
    printer,
    filament,
    shellSkinThickness: 0,      // NO top/bottom layers
    shellWallThickness: 0.4,    // Single wall (one line)
    lengthUnit: "millimeters",
    timeUnit: "seconds",
    infillPattern: "grid",
    infillDensity: 0,           // NO infill
    bedTemperature: 0,
    layerHeight: 0.2,
    testStrip: false,
    verbose: true,              // Verbose to see layer progress
    supportEnabled: false       // NO support
  });

  console.log("Slicing (outer walls only)...");
  console.log("- Shell wall thickness: 0.4mm (single wall)");
  console.log("- Shell skin thickness: 0mm (no top/bottom)");
  console.log("- Infill density: 0% (no infill)");
  console.log("- Support: disabled\n");

  const t0 = Date.now();
  const gcode = slicer.slice(mesh);
  const dt = Date.now() - t0;
  
  const minutes = Math.floor(dt / 60000);
  const seconds = ((dt % 60000) / 1000).toFixed(1);
  console.log(`✅ Sliced in ${minutes}m ${seconds}s (${dt}ms)`);

  const outDir = path.join(__dirname, "../output");
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

  const outPath = path.join(outDir, "benchy-walls-only.gcode");
  fs.writeFileSync(outPath, gcode);

  // Analyze output
  const lines = gcode.split("\n");
  const layerLines = lines.filter(line => line.includes("LAYER:"));
  const wallLines = lines.filter(line => line.includes("TYPE: WALL-"));
  const outerWallLines = lines.filter(line => line.includes("TYPE: WALL-OUTER"));

  console.log("\nG-code Analysis:");
  console.log(`- Total lines: ${lines.length}`);
  console.log(`- Layers: ${layerLines.length}`);
  console.log(`- Wall markers: ${wallLines.length}`);
  console.log(`- Outer wall markers: ${outerWallLines.length}`);
  console.log(`- Output: ${outPath}`);
  console.log(`- Size: ${(gcode.length / 1024).toFixed(1)} KB\n`);

  // Show layer 5 outer wall snippet for debugging
  console.log("Sample: Layer 5 outer wall (first 10 moves):");
  let inLayer5 = false;
  let inOuterWall = false;
  let count = 0;
  for (const line of lines) {
    if (line.includes("LAYER: 5")) inLayer5 = true;
    if (line.includes("LAYER: 6")) break;
    if (inLayer5 && line.includes("TYPE: WALL-OUTER")) inOuterWall = true;
    if (inLayer5 && line.includes("TYPE:") && !line.includes("WALL-OUTER")) inOuterWall = false;
    if (inOuterWall && line.startsWith("G1") && count < 10) {
      console.log(`  ${line.substring(0, 80)}`);
      count++;
    }
  }

  console.log("\n✅ Done! Use this file for fast debugging of wall paths.");
}

main().catch(err => {
  console.error("Error:", err);
  process.exit(1);
});
