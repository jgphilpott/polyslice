#!/usr/bin/env node
/**
 * Generic file slicing script for Polyslice.
 * Usage: node slice-file.js /path/to/model.(stl|obj) [rotation]
 *
 * Optional rotation argument format: <axis><degrees>
 *   Examples: x90, y-45, z180
 *
 * Saves G-code beside the source model (same directory, same basename + .gcode).
 */

const path = require("path");
const fs = require("fs");
const THREE = require("three");
const { Polyslice, Printer, Filament } = require("../../src/index");

async function loadLocalSTL(filePath) {
  const { STLLoader } = await import("three/examples/jsm/loaders/STLLoader.js");
  const buffer = fs.readFileSync(filePath);
  const loader = new STLLoader();
  const geometry = loader.parse(buffer.buffer);
  geometry.computeVertexNormals?.();
  const material = new THREE.MeshPhongMaterial({ color: 0x808080, specular: 0x111111, shininess: 200 });
  return new THREE.Mesh(geometry, material);
}

async function loadLocalOBJ(filePath) {
  const { OBJLoader } = await import("three/examples/jsm/loaders/OBJLoader.js");
  const text = fs.readFileSync(filePath, "utf8");
  const loader = new OBJLoader();
  const object = loader.parse(text);
  // Collect meshes; if multiple, group.
  const meshes = [];
  object.traverse(child => { if (child.isMesh) meshes.push(child); });
  if (meshes.length === 1) return meshes[0];
  const group = new THREE.Group();
  meshes.forEach(m => group.add(m));
  return group;
}

async function loadMesh(filePath) {
  if (!fs.existsSync(filePath)) throw new Error(`File not found: ${filePath}`);
  const ext = path.extname(filePath).toLowerCase();
  if (ext === ".stl") return loadLocalSTL(filePath);
  if (ext === ".obj") return loadLocalOBJ(filePath);
  throw new Error(`Unsupported extension '${ext}'. Only .stl and .obj are supported.`);
}

function liftToBuildPlate(root) {
  const box = new THREE.Box3().setFromObject(root);
  if (box.min.z < 0) {
    const dz = -box.min.z;
    root.position.z += dz;
    root.updateMatrixWorld();
  }
  return root;
}

/**
 * Parse and apply rotation from command line argument.
 * Format: <axis><degrees> (e.g., x90, y-45, z180)
 */
function applyRotation(mesh, rotationArg) {
  if (!rotationArg) return;

  const match = rotationArg.match(/^([xyz])([-\d.]+)$/i);
  if (!match) {
    console.warn(`Warning: Invalid rotation format '${rotationArg}'. Expected format: x90, y-45, z180`);
    return;
  }

  const axis = match[1].toLowerCase();
  const degrees = parseFloat(match[2]);
  const radians = (degrees * Math.PI) / 180;

  console.log(`Applying rotation: ${degrees}° around ${axis.toUpperCase()}-axis`);

  switch (axis) {
    case 'x':
      mesh.rotateX(radians);
      break;
    case 'y':
      mesh.rotateY(radians);
      break;
    case 'z':
      mesh.rotateZ(radians);
      break;
  }

  mesh.updateMatrixWorld(true);
}

async function main() {
  const argPath = process.argv[2];
  const rotationArg = process.argv[3];

  if (!argPath) {
    console.error("Usage: node slice-file.js /path/to/model.(stl|obj) [rotation]");
    console.error("  rotation format: <axis><degrees> (e.g., x90, y-45, z180)");
    process.exit(1);
  }
  const inputPath = path.resolve(argPath);
  console.log("Polyslice File Slicer\n====================\n");
  console.log(`Input: ${inputPath}`);

  let mesh;
  try {
    mesh = await loadMesh(inputPath);
  } catch (e) {
    console.error("Load error:", e.message);
    process.exit(1);
  }

  // Apply rotation if specified
  applyRotation(mesh, rotationArg);

  liftToBuildPlate(mesh);

  const printer = new Printer("Ender5");
  const filament = new Filament("GenericPLA");

  const slicer = new Polyslice({
    printer,
    filament,
    layerHeight: 0.2,
    shellWallThickness: 0.8,
    shellSkinThickness: 0.8,
    infillDensity: 15,
    infillPattern: "grid",
    verbose: true,
    testStrip: false,
    bedTemperature: 0
  });

  let lastPct = -1;
  console.log("\nSlicing...");
  const t0 = Date.now();
  const gcode = slicer.slice(mesh, {
    onProgress: (pct, phase) => {
      if (typeof pct === "number" && pct !== lastPct) {
        const phaseTxt = phase ? ` (${phase})` : "";
        process.stdout.write(`\rProgress: ${pct.toString().padStart(3, " ")}%${phaseTxt}`);
        lastPct = pct;
      }
    }
  });
  const dt = Date.now() - t0;
  process.stdout.write("\n");
  console.log(`Slice time: ${dt} ms`);

  const dir = path.dirname(inputPath);
  const base = path.basename(inputPath, path.extname(inputPath));
  const outPath = path.join(dir, `${base}.gcode`);
  try { fs.writeFileSync(outPath, gcode); } catch (e) {
    console.error("Failed to write G-code:", e.message); process.exit(1);
  }

  const sizeKB = (fs.statSync(outPath).size / 1024).toFixed(1);
  const layerCount = gcode.split("\n").filter(l => l.includes("LAYER:")).length;
  console.log("\nOutput:");
  console.log(`- G-code: ${outPath}`);
  console.log(`- Size: ${sizeKB} KB`);
  console.log(`- Layers: ${layerCount}`);
  console.log("Done.");
}

main().catch(err => { console.error("Fatal error:", err); process.exit(1); });
