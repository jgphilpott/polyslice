/**
 * Example: slice the Benchy test model from an STL and write G-code to examples/output.
 *
 * Usage:
 *   node examples/scripts/slice-benchy.js               # resources/testing/benchy/test.stl (default)
 *   node examples/scripts/slice-benchy.js very-low-poly # resources/testing/benchy/very-low-poly.test.stl
 *   node examples/scripts/slice-benchy.js low-poly      # resources/testing/benchy/low-poly.test.stl
 *   node examples/scripts/slice-benchy.js battle        # resources/testing/benchy/battle.test.stl
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
  const material = new THREE.MeshPhongMaterial({ color: 0x808080, specular: 0x111111, shininess: 200 });
  const mesh = new THREE.Mesh(geometry, material);

  // Place bottom at Z=0 (build plate)
  geometry.computeBoundingBox();
  const bb = geometry.boundingBox;
  const zShift = -bb.min.z;
  mesh.position.set(0, 0, zShift);
  mesh.updateMatrixWorld();
  return mesh;
}

function resolveBenchyPath(arg) {
  const baseDir = path.join(__dirname, "../../resources/testing/benchy");
  const variant = (arg || "").toLowerCase();
  let file, slug;
  switch (variant) {
    case "very-low-poly":
      file = "very-low-poly.test.stl";
      slug = "very-low-poly";
      break;
    case "low-poly":
      file = "low-poly.test.stl";
      slug = "low-poly";
      break;
    case "battle":
      file = "battle.test.stl";
      slug = "battle";
      break;
    case "":
      file = "test.stl";
      slug = "test";
      break;
    default:
      console.warn(`Unknown variant '${arg}', defaulting to 'test.stl'`);
      file = "test.stl";
      slug = "test";
  }
  return { path: path.join(baseDir, file), slug };
}

async function main() {
  console.log("Polyslice Benchy Example");
  console.log("========================\n");

  const variantArg = process.argv[2] || "";
  const { path: stlPath, slug: variantSlug } = resolveBenchyPath(variantArg);

  const printer = new Printer("Ender5");
  const filament = new Filament("GenericPLA");

  console.log("Printer & Filament:");
  console.log(`- Printer: ${printer.model}`);
  console.log(`- Volume: ${printer.getSizeX()}x${printer.getSizeY()}x${printer.getSizeZ()} mm`);
  console.log(`- Filament: ${filament.name} (${filament.type.toUpperCase()})\n`);

  console.log("Loading STL...");
  console.log(`- ${stlPath}`);

  let mesh;
  try {
    mesh = await loadSTLMesh(stlPath);
  } catch (err) {
    console.error("Failed to load STL:", err.message);
    process.exit(1);
  }

  const pos = mesh.geometry.attributes.position;
  const triApprox = pos ? ((pos.count / 3) | 0) : null;
  console.log("✅ Mesh loaded");
  console.log(`- Geometry: ${mesh.geometry.type}`);
  console.log(`- Vertices: ${pos ? pos.count : "unknown"}`);
  if (pos) console.log(`- Triangles (approx): ${triApprox}\n`);

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
    metadata: false,
    verbose: true
  });

  console.log("Slicing model...");
  const t0 = Date.now();
  let gcode = slicer.slice(mesh);
  const dt = Date.now() - t0;
  console.log(`✅ Sliced in ${dt} ms`);

  // Prepend run metadata including selected variant to the G-code as comments
  const meta = [
    "; Run Metadata",
    `; Model: Benchy`,
    `; Variant: ${variantSlug}`,
    `; Source: ${stlPath}`,
    pos ? `; Vertices: ${pos.count}` : null,
    triApprox != null ? `; Triangles(approx): ${triApprox}` : null,
    `; Slice Time(ms): ${dt}`,
    `; Printer: ${printer.model}`,
    `; Filament: ${filament.name} (${filament.type})`,
    ""
  ].filter(Boolean).join("\n");
  if (slicer.getMetadata()) {
    gcode = meta + "\n" + gcode;
  }

  // Save G-code into benchmarks directory
  const outDir = path.join(__dirname, "..", "..", "resources", "gcode", "benchmarks");
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
  const outBase = `benchy.${variantSlug}.gcode`;
  const outPath = path.join(outDir, outBase);
  fs.writeFileSync(outPath, gcode);

  const size = fs.statSync(outPath).size;
  const lines = gcode.split("\n");
  const layers = lines.filter(l => l.includes("LAYER:")).length;

  console.log("G-code Summary:");
  console.log(`- File: ${outPath}`);
  console.log(`- Size: ${(size/1024).toFixed(1)} KB`);
  console.log(`- Lines: ${lines.length}`);
  console.log(`- Layers: ${layers}`);
  console.log("Done.");
}

main().catch(err => {
  console.error("Error:", err);
  process.exit(1);
});
