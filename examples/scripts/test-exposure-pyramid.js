// Test script to demonstrate exposure detection with a pyramid
// Pyramids have changing cross-sections that should trigger middle layer skin
const { Polyslice, Printer, Filament } = require("../../src/index");
const THREE = require("three");

function createPyramidMesh(baseSize = 30, height = 20) {
    // Create a pyramid using ConeGeometry
    const geometry = new THREE.ConeGeometry(baseSize / 2, height, 4); // 4 sides = pyramid
    const material = new THREE.MeshBasicMaterial();
    const mesh = new THREE.Mesh(geometry, material);
    
    // Position so bottom is at Z=0
    mesh.position.set(0, 0, height / 2);
    mesh.updateMatrixWorld();
    return mesh;
}

async function main() {
    console.log("\n=== Testing Exposure Detection with Pyramid ===\n");
    console.log("Pyramids have layers with sudden cross-section changes,");
    console.log("which should trigger middle layer skin generation.\n");
    
    const mesh = createPyramidMesh();
    
    const printer = new Printer("Ender5");
    const filament = new Filament("GenericPLA");
    
    // Test with exposure detection ENABLED (new default)
    console.log("1. Slicing pyramid with exposureDetection = TRUE (default)...");
    const slicerEnabled = new Polyslice({
        printer: printer,
        filament: filament,
        shellSkinThickness: 0.8,  // 4 layers
        shellWallThickness: 0.8,
        infillDensity: 20,
        layerHeight: 0.2,
        verbose: false,  // Reduce output
    });
    
    console.log(`   Exposure detection: ${slicerEnabled.getExposureDetection()}`);
    
    const gcodeEnabled = slicerEnabled.slice(mesh);
    const linesEnabled = gcodeEnabled.split('\n');
    
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
    
    const totalLayers = Object.keys(layerSkinCount).length;
    console.log(`   Total SKIN lines: ${linesEnabled.filter(l => l.includes('TYPE: SKIN')).length}`);
    console.log(`   Layers with SKIN: ${totalLayers}`);
    console.log(`   Layers: ${Object.keys(layerSkinCount).sort((a,b) => a-b).join(', ')}\n`);
    
    // Test with exposure detection DISABLED
    console.log("2. Slicing pyramid with exposureDetection = FALSE...");
    const slicerDisabled = new Polyslice({
        printer: printer,
        filament: filament,
        shellSkinThickness: 0.8,  // 4 layers
        shellWallThickness: 0.8,
        infillDensity: 20,
        layerHeight: 0.2,
        verbose: false,
        exposureDetection: false
    });
    
    console.log(`   Exposure detection: ${slicerDisabled.getExposureDetection()}`);
    
    const gcodeDisabled = slicerDisabled.slice(mesh);
    const linesDisabled = gcodeDisabled.split('\n');
    
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
    
    const totalLayersDisabled = Object.keys(layerSkinCount).length;
    console.log(`   Total SKIN lines: ${linesDisabled.filter(l => l.includes('TYPE: SKIN')).length}`);
    console.log(`   Layers with SKIN: ${totalLayersDisabled}`);
    console.log(`   Layers: ${Object.keys(layerSkinCount).sort((a,b) => a-b).join(', ')}\n`);
    
    console.log("=== Analysis ===");
    const skinEnabled = linesEnabled.filter(l => l.includes('TYPE: SKIN')).length;
    const skinDisabled = linesDisabled.filter(l => l.includes('TYPE: SKIN')).length;
    const diff = skinEnabled - skinDisabled;
    
    console.log(`Difference: ${diff} SKIN lines (${totalLayers - totalLayersDisabled} more layers with skin)\n`);
    
    if (diff > 0) {
        console.log("✓ SUCCESS! Exposure detection is generating middle layer skin!");
        console.log("  The pyramid's changing cross-sections trigger the algorithm.");
        console.log("  Layers near the top have exposed surfaces as the pyramid narrows.");
    } else if (diff < 0) {
        console.log("✓ Exposure detection reduced skin (optimization working)");
    } else {
        console.log("⚠️  No difference detected.");
        console.log("  The pyramid geometry may still have sufficient layer-to-layer coverage.");
        console.log("  Try adjusting coverageThreshold or using a steeper pyramid.");
    }
}

main().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
