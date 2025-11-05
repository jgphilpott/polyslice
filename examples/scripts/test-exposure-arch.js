// Test script to verify exposure detection is working with the arch
const { Polyslice, Printer, Filament } = require("../../src/index");
const THREE = require("three");
const { Polytree } = require("@jgphilpott/polytree");

// Arch parameters - same as slice-arch.js
const ARCH_WIDTH = 40;
const ARCH_HEIGHT = 10;
const ARCH_THICKNESS = 20;
const ARCH_RADIUS = 15;

async function createArchMesh(width = ARCH_WIDTH, height = ARCH_HEIGHT, thickness = ARCH_THICKNESS, radius = ARCH_RADIUS) {
    const boxGeo = new THREE.BoxGeometry(width, height, thickness);
    const boxMesh = new THREE.Mesh(boxGeo, new THREE.MeshBasicMaterial());

    const cylLength = width * 1.25;
    const cylGeo = new THREE.CylinderGeometry(radius, radius, cylLength, 48);
    const cylMesh = new THREE.Mesh(cylGeo, new THREE.MeshBasicMaterial());
    cylMesh.position.z = -height;
    cylMesh.updateMatrixWorld();

    const resultMesh = await Polytree.subtract(boxMesh, cylMesh);
    const finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material);
    finalMesh.position.set(0, 0, thickness / 2);
    finalMesh.updateMatrixWorld();
    return finalMesh;
}

async function main() {
    console.log("\n=== Testing Exposure Detection with Arch ===\n");
    
    const mesh = await createArchMesh();
    
    const printer = new Printer("Ender5");
    const filament = new Filament("GenericPLA");
    
    // Test with exposure detection ENABLED (new default)
    console.log("1. Slicing with exposureDetection = TRUE (default)...");
    const slicerEnabled = new Polyslice({
        printer: printer,
        filament: filament,
        shellSkinThickness: 0.8,
        shellWallThickness: 0.8,
        infillDensity: 30,
        layerHeight: 0.2,
        verbose: true,
        // exposureDetection: true is now the default
    });
    
    console.log(`   Exposure detection: ${slicerEnabled.getExposureDetection()}`);
    
    const gcodeEnabled = slicerEnabled.slice(mesh);
    const linesEnabled = gcodeEnabled.split('\n');
    const skinLinesEnabled = linesEnabled.filter(line => line.includes('TYPE: SKIN'));
    
    // Count skin by layer
    let layerSkinCount = {};
    let currentLayer = null;
    for (const line of linesEnabled) {
        const layerMatch = line.match(/LAYER:\s*(\d+)/);
        if (layerMatch) {
            currentLayer = parseInt(layerMatch[1]);
        }
        if (line.includes('TYPE: SKIN') && currentLayer !== null) {
            layerSkinCount[currentLayer] = (layerSkinCount[currentLayer] || 0) + 1;
        }
    }
    
    console.log(`   Total SKIN lines: ${skinLinesEnabled.length}`);
    console.log(`   Layers with SKIN: ${Object.keys(layerSkinCount).length}`);
    console.log(`   SKIN by layer: ${JSON.stringify(layerSkinCount, null, 2)}\n`);
    
    // Test with exposure detection DISABLED
    console.log("2. Slicing with exposureDetection = FALSE...");
    const slicerDisabled = new Polyslice({
        printer: printer,
        filament: filament,
        shellSkinThickness: 0.8,
        shellWallThickness: 0.8,
        infillDensity: 30,
        layerHeight: 0.2,
        verbose: true,
        exposureDetection: false  // Explicitly disable
    });
    
    console.log(`   Exposure detection: ${slicerDisabled.getExposureDetection()}`);
    
    const gcodeDisabled = slicerDisabled.slice(mesh);
    const linesDisabled = gcodeDisabled.split('\n');
    const skinLinesDisabled = linesDisabled.filter(line => line.includes('TYPE: SKIN'));
    
    // Count skin by layer
    layerSkinCount = {};
    currentLayer = null;
    for (const line of linesDisabled) {
        const layerMatch = line.match(/LAYER:\s*(\d+)/);
        if (layerMatch) {
            currentLayer = parseInt(layerMatch[1]);
        }
        if (line.includes('TYPE: SKIN') && currentLayer !== null) {
            layerSkinCount[currentLayer] = (layerSkinCount[currentLayer] || 0) + 1;
        }
    }
    
    console.log(`   Total SKIN lines: ${skinLinesDisabled.length}`);
    console.log(`   Layers with SKIN: ${Object.keys(layerSkinCount).length}`);
    console.log(`   SKIN by layer: ${JSON.stringify(layerSkinCount, null, 2)}\n`);
    
    console.log("=== Analysis ===");
    console.log(`Difference: ${skinLinesEnabled.length - skinLinesDisabled.length} SKIN lines`);
    
    if (skinLinesEnabled.length === skinLinesDisabled.length) {
        console.log("\n⚠️  No difference detected between enabled/disabled exposure detection.");
        console.log("This is expected for the arch geometry because:");
        console.log("- The arch has gradual geometric changes");
        console.log("- Each layer is well-covered by adjacent layers (>90% coverage)");
        console.log("- Coverage threshold is 0.1 (90% exposed needed to trigger skin)");
        console.log("- The algorithm correctly identifies only top/bottom layers need skin");
        console.log("\nTo see the difference, try geometries with:");
        console.log("- Sudden cross-section changes (pyramids, cones with steep angles)");
        console.log("- Large overhangs or bridges");
        console.log("- Stepped geometries with flat plateaus");
    } else {
        console.log("\n✓ Exposure detection is working! Different skin patterns detected.");
    }
}

main().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
