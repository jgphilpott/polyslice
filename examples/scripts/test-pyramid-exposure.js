/**
 * Test to investigate exposure detection issues with pyramid geometry
 */

const { Polyslice, Printer, Filament } = require("/home/runner/work/polyslice/polyslice/src/index");
const THREE = require("three");
const { Polytree } = require("@jgphilpott/polytree");

async function buildSimplePyramid() {
  const mat = new THREE.MeshStandardMaterial({ color: 0x888888 });
  
  // Bottom slab: 50mm x 50mm x 10mm
  const baseSlab = new THREE.BoxGeometry(50, 50, 10);
  const baseSlabMesh = new THREE.Mesh(baseSlab, mat);
  baseSlabMesh.position.set(0, 0, 0);
  baseSlabMesh.updateMatrixWorld();
  
  // Top slab: 30mm x 30mm x 10mm (smaller, centered on top)
  const topSlab = new THREE.BoxGeometry(30, 30, 10);
  const topSlabMesh = new THREE.Mesh(topSlab, mat);
  topSlabMesh.position.set(0, 0, 10);
  topSlabMesh.updateMatrixWorld();
  
  const pyramidMesh = await Polytree.unite(baseSlabMesh, topSlabMesh);
  
  const finalMesh = new THREE.Mesh(pyramidMesh.geometry, mat);
  finalMesh.position.set(0, 0, 0);
  finalMesh.updateMatrixWorld();
  
  return finalMesh;
}

async function main() {
  console.log("Testing Pyramid Exposure Detection");
  console.log("===================================\n");
  
  const mesh = await buildSimplePyramid();
  console.log("Created 2-layer pyramid (50x50 base, 30x30 top)\n");
  
  const slicer = new Polyslice({
    layerHeight: 0.2,
    shellSkinThickness: 0.8,
    shellWallThickness: 0.8,
    verbose: true,
    exposureDetection: true,
    exposureDetectionResolution: 961,
    infillDensity: 0, // No infill to make skin easier to see
    testStrip: false,
    autohome: false
  });
  
  console.log("Slicing with exposure detection enabled...");
  const gcode = slicer.slice(mesh);
  
  // Analyze layers
  const lines = gcode.split('\n');
  let currentLayer = null;
  let skinLines = {};
  let layerData = {};
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    if (line.includes('LAYER:')) {
      const match = line.match(/LAYER:\s*(\d+)/);
      if (match) {
        currentLayer = parseInt(match[1]);
        layerData[currentLayer] = { skin: 0, wallOuter: 0, wallInner: 0 };
        skinLines[currentLayer] = [];
      }
    } else if (currentLayer !== null) {
      if (line.includes('TYPE: SKIN')) {
        layerData[currentLayer].skin++;
        // Capture next 10 lines as sample
        for (let j = i + 1; j < Math.min(i + 11, lines.length); j++) {
          if (lines[j].includes('TYPE:')) break;
          if (lines[j].match(/G[01]/)) {
            skinLines[currentLayer].push(lines[j]);
          }
        }
      } else if (line.includes('TYPE: WALL-OUTER')) {
        layerData[currentLayer].wallOuter++;
      } else if (line.includes('TYPE: WALL-INNER')) {
        layerData[currentLayer].wallInner++;
      }
    }
  }
  
  // Report findings
  console.log("\nLayer Analysis:");
  console.log("===============");
  
  // Focus on bottom slab layers (0-49, which is 0-9.8mm)
  // The top slab starts at layer 50 (10mm)
  console.log("\nBottom Slab (layers 0-49, Z=0 to Z=9.8mm):");
  const criticalLayers = [0, 1, 2, 3, 45, 46, 47, 48, 49];
  
  for (const layerNum of criticalLayers) {
    const data = layerData[layerNum];
    if (data) {
      console.log(`  Layer ${layerNum} (Z=${(layerNum * 0.2).toFixed(1)}mm): SKIN=${data.skin}, WALL-OUTER=${data.wallOuter}, WALL-INNER=${data.wallInner}`);
      
      // Show some skin G-code for layer 49 (top of bottom slab)
      if (layerNum === 49 && skinLines[layerNum].length > 0) {
        console.log(`    Sample skin G-code (first 3 lines):`);
        skinLines[layerNum].slice(0, 3).forEach(line => {
          console.log(`      ${line.trim()}`);
        });
      }
    }
  }
  
  console.log("\nTop Slab (layers 50-99, Z=10mm to Z=19.8mm):");
  for (let layerNum = 50; layerNum <= 55; layerNum++) {
    const data = layerData[layerNum];
    if (data) {
      console.log(`  Layer ${layerNum} (Z=${(layerNum * 0.2).toFixed(1)}mm): SKIN=${data.skin}, WALL-OUTER=${data.wallOuter}, WALL-INNER=${data.wallInner}`);
    }
  }
  
  // Issue expectations:
  console.log("\n\nExpected Issues:");
  console.log("================");
  console.log("1. Layer 49 (top of bottom slab) should have skin ONLY on the exposed outer edges");
  console.log("   - The center (30x30 area) is covered by the top slab and should NOT have skin");
  console.log("   - The outer perimeter (50x50 - 30x30) IS exposed and SHOULD have skin");
  console.log("\n2. The skin patch boundaries should align perfectly with the slab edges");
  console.log("   - Not have 'sun ray' spikes or irregular boundaries");
  console.log("   - Should extend all the way to the 50x50 outer edge");
}

main().catch(err => {
  console.error("Error:", err);
  process.exit(1);
});
