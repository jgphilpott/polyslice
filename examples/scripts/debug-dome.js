const { Polyslice, Printer, Filament } = require("../../src/index");
const THREE = require("three");
const { Polytree } = require("@jgphilpott/polytree");

const DOME_WIDTH = 25;
const DOME_DEPTH = 25;
const DOME_THICKNESS = 12;
const DOME_RADIUS = 10;

async function createDomeMesh(width = DOME_WIDTH, depth = DOME_DEPTH, thickness = DOME_THICKNESS, radius = DOME_RADIUS) {
  const maxRadiusXY = Math.min(width, depth) * 0.49;
  const maxRadiusZ = thickness;
  const r = Math.min(radius, maxRadiusXY, maxRadiusZ);

  const boxGeo = new THREE.BoxGeometry(width, depth, thickness);
  const boxMesh = new THREE.Mesh(boxGeo, new THREE.MeshBasicMaterial());

  const sphereGeo = new THREE.SphereGeometry(r, 64, 48);
  const sphereMesh = new THREE.Mesh(sphereGeo, new THREE.MeshBasicMaterial());
  sphereMesh.position.set(0, 0, -(thickness / 2));
  sphereMesh.updateMatrixWorld();

  const resultMesh = await Polytree.subtract(boxMesh, sphereMesh);
  const finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material);
  finalMesh.position.set(0, 0, thickness / 2);
  finalMesh.updateMatrixWorld();
  return finalMesh;
}

async function main() {
  const printer = new Printer("Ender5");
  const filament = new Filament("GenericPLA");
  const mesh = await createDomeMesh();

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
    exposureDetection: true,
    exposureDetectionResolution: 900
  });

  console.log("Exposure Detection:", slicer.getExposureDetection());
  console.log("Layer Height:", slicer.getLayerHeight());
  console.log("Shell Skin Thickness:", slicer.getShellSkinThickness());
  console.log("Skin Layer Count:", Math.max(1, Math.floor((0.8 / 0.2) + 0.0001)));
  
  const pos = mesh.geometry.attributes.position;
  const positions = pos.array;
  
  // Find the Z range of the mesh
  let minZ = Infinity, maxZ = -Infinity;
  for (let i = 0; i < positions.length; i += 3) {
    const z = positions[i + 2];
    if (z < minZ) minZ = z;
    if (z > maxZ) maxZ = z;
  }
  
  console.log("\nMesh Z-range:", minZ, "to", maxZ);
  console.log("Total Z span:", maxZ - minZ);
  console.log("Expected layers:", Math.ceil((maxZ - minZ) / 0.2));
  
  // Look at top layers structure
  console.log("\n--- Examining layer structure near top ---");
  const layerHeight = 0.2;
  const totalLayers = 60;
  const skinLayerCount = 4;
  
  for (let i = totalLayers - 10; i < totalLayers; i++) {
    const z = minZ + (i + 0.5) * layerHeight;
    const checkIdxAbove = i + skinLayerCount;
    console.log(`Layer ${i}: z=${z.toFixed(2)}, checkAbove=${checkIdxAbove} (${checkIdxAbove < totalLayers ? 'exists' : 'OUT OF BOUNDS - should expose'})`);
  }
}

main().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
