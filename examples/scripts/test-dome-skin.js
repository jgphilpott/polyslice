/**
 * Test script to verify that the dome cavity receives proper skin generation.
 * This test validates the fix for the adaptive skin generation algorithm.
 */

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
  console.log("Testing Dome Skin Generation");
  console.log("=============================\n");

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
    verbose: true, // Enable verbose to get layer markers
    supportEnabled: true,
    supportType: "normal",
    supportPlacement: "buildPlate",
    supportThreshold: 45,
    exposureDetection: true,
    exposureDetectionResolution: 900
  });

  console.log("Slicing dome mesh...");
  const gcode = slicer.slice(mesh);
  
  // Analyze G-code for skin generation
  const lines = gcode.split("\n");
  const layerLines = lines.filter(line => line.includes("LAYER:"));
  const skinLines = lines.filter(line => line.includes("TYPE: SKIN"));
  
  // Extract layer numbers that have skin
  const layersWithSkin = new Set();
  let currentLayer = null;
  
  for (const line of lines) {
    if (line.includes("LAYER:")) {
      const match = line.match(/LAYER:\s*(\d+)/);
      if (match) {
        currentLayer = parseInt(match[1]);
      }
    } else if (line.includes("TYPE: SKIN") && currentLayer !== null) {
      layersWithSkin.add(currentLayer);
    }
  }
  
  const sortedLayers = Array.from(layersWithSkin).sort((a, b) => a - b);
  
  console.log(`\nResults:`);
  console.log(`- Total layers: ${layerLines.length}`);
  console.log(`- Layers with skin: ${sortedLayers.length}`);
  console.log(`- Skin type occurrences: ${skinLines.length}\n`);
  
  console.log("Layers with skin:");
  console.log(sortedLayers.join(", "));
  console.log();
  
  // Validate expectations
  const shellSkinThickness = slicer.getShellSkinThickness();
  const layerHeight = slicer.getLayerHeight();
  const skinLayerCount = Math.max(1, Math.floor((shellSkinThickness / layerHeight) + 0.0001));
  const totalLayers = layerLines.length;
  
  const hasBottomSkin = sortedLayers.some(l => l < skinLayerCount);
  const hasTopSkin = sortedLayers.some(l => l >= totalLayers - skinLayerCount);
  const hasMiddleSkin = sortedLayers.some(l => l >= skinLayerCount && l < totalLayers - skinLayerCount);
  
  console.log("Validation:");
  console.log(`✓ Bottom skin (layers 0-${skinLayerCount-1}): ${hasBottomSkin ? "PASS" : "FAIL"}`);
  console.log(`✓ Top skin (layers ${totalLayers-skinLayerCount}-${totalLayers-1}): ${hasTopSkin ? "PASS" : "FAIL"}`);
  console.log(`✓ Middle skin (cavity closure): ${hasMiddleSkin ? "PASS" : "FAIL"}`);
  
  if (hasMiddleSkin) {
    const middleLayers = sortedLayers.filter(l => l >= skinLayerCount && l < totalLayers - skinLayerCount);
    console.log(`  - Detected cavity closure on layers: ${middleLayers.join(", ")}`);
    console.log(`  - Range: layers ${Math.min(...middleLayers)}-${Math.max(...middleLayers)}`);
  }
  
  console.log();
  
  if (hasBottomSkin && hasTopSkin && hasMiddleSkin) {
    console.log("✅ All tests PASSED!");
    console.log("The adaptive skin generation correctly detects the closing dome cavity.");
  } else {
    console.log("❌ Some tests FAILED!");
    process.exit(1);
  }
}

main().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
