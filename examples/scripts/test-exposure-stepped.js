// Test script to demonstrate exposure detection with a stepped geometry
// Stepped shapes have clear layer transitions that should trigger exposure detection
const { Polyslice, Printer, Filament } = require("../../src/index");
const THREE = require("three");

function createSteppedMesh() {
    // Create a wedding cake / stepped pyramid shape
    // Wide base, narrow middle, wider top - this creates clear exposed surfaces
    const group = new THREE.Group();
    
    // Bottom step (largest)
    const bottom = new THREE.Mesh(
        new THREE.BoxGeometry(30, 30, 6),
        new THREE.MeshBasicMaterial()
    );
    bottom.position.set(0, 0, 3);
    group.add(bottom);
    
    // Middle step (medium)
    const middle = new THREE.Mesh(
        new THREE.BoxGeometry(20, 20, 6),
        new THREE.MeshBasicMaterial()
    );
    middle.position.set(0, 0, 9);
    group.add(middle);
    
    // Top step (small)
    const top = new THREE.Mesh(
        new THREE.BoxGeometry(10, 10, 6),
        new THREE.MeshBasicMaterial()
    );
    top.position.set(0, 0, 15);
    group.add(top);
    
    // Merge all geometries
    group.updateMatrixWorld(true);
    const mergedGeometry = new THREE.BufferGeometry();
    const geometries = [];
    
    group.traverse((child) => {
        if (child.isMesh) {
            const clonedGeo = child.geometry.clone();
            clonedGeo.applyMatrix4(child.matrixWorld);
            geometries.push(clonedGeo);
        }
    });
    
    const merged = THREE.BufferGeometryUtils.mergeGeometries(geometries);
    return new THREE.Mesh(merged, new THREE.MeshBasicMaterial());
}

async function main() {
    console.log("\n=== Testing Exposure Detection with Stepped Geometry ===\n");
    console.log("This 'wedding cake' shape has three steps:");
    console.log("- Bottom: 30x30mm (layers 0-29)");
    console.log("- Middle: 20x20mm (layers 30-59)");
    console.log("- Top:    10x10mm (layers 60-89)");
    console.log("\nThe steps at layers ~30 and ~60 should trigger exposure detection.\n");
    
    const THREE_UTILS = await import('three/examples/jsm/utils/BufferGeometryUtils.js');
    THREE.BufferGeometryUtils = THREE_UTILS;
    
    const mesh = createSteppedMesh();
    
    const printer = new Printer("Ender5");
    const filament = new Filament("GenericPLA");
    
    // Test with exposure detection ENABLED (new default)
    console.log("1. Slicing stepped shape with exposureDetection = TRUE...");
    const slicerEnabled = new Polyslice({
        printer: printer,
        filament: filament,
        shellSkinThickness: 0.8,  // 4 layers
        shellWallThickness: 0.8,
        infillDensity: 20,
        layerHeight: 0.2,
        verbose: false,
    });
    
    const gcodeEnabled = slicerEnabled.slice(mesh);
    const linesEnabled = gcodeEnabled.split('\n');
    
    // Analyze skin by layer
    let layerSkinCountEnabled = {};
    let currentLayer = null;
    for (const line of linesEnabled) {
        const layerMatch = line.match(/LAYER:\s*(\d+)/);
        if (layerMatch) {
            currentLayer = parseInt(layerMatch[1]);
        }
        if (line.includes('TYPE: SKIN') && currentLayer !== null) {
            layerSkinCountEnabled[currentLayer] = (layerSkinCountEnabled[currentLayer] || 0) + 1;
        }
    }
    
    console.log(`   Layers with SKIN: ${Object.keys(layerSkinCountEnabled).length}`);
    console.log(`   Layers: ${Object.keys(layerSkinCountEnabled).sort((a,b) => a-b).join(', ')}\n`);
    
    // Test with exposure detection DISABLED
    console.log("2. Slicing stepped shape with exposureDetection = FALSE...");
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
    
    const gcodeDisabled = slicerDisabled.slice(mesh);
    const linesDisabled = gcodeDisabled.split('\n');
    
    // Analyze skin by layer
    let layerSkinCountDisabled = {};
    currentLayer = null;
    for (const line of linesDisabled) {
        const layerMatch = line.match(/LAYER:\s*(\d+)/);
        if (layerMatch) {
            currentLayer = parseInt(layerMatch[1]);
        }
        if (line.includes('TYPE: SKIN') && currentLayer !== null) {
            layerSkinCountDisabled[currentLayer] = (layerSkinCountDisabled[currentLayer] || 0) + 1;
        }
    }
    
    console.log(`   Layers with SKIN: ${Object.keys(layerSkinCountDisabled).length}`);
    console.log(`   Layers: ${Object.keys(layerSkinCountDisabled).sort((a,b) => a-b).join(', ')}\n`);
    
    // Analysis
    console.log("=== Analysis ===");
    const totalLayersEnabled = Object.keys(layerSkinCountEnabled).length;
    const totalLayersDisabled = Object.keys(layerSkinCountDisabled).length;
    const diff = totalLayersEnabled - totalLayersDisabled;
    
    console.log(`Difference: ${diff} more layers with skin when enabled\n`);
    
    // Find middle layers (not in first 4 or last 4)
    const allLayers = Math.max(...Object.keys(layerSkinCountEnabled).map(Number), ...Object.keys(layerSkinCountDisabled).map(Number));
    const middleLayersEnabled = Object.keys(layerSkinCountEnabled).filter(l => {
        const n = parseInt(l);
        return n >= 4 && n < allLayers - 3;
    });
    
    if (middleLayersEnabled.length > 0) {
        console.log("✓ SUCCESS! Exposure detection generated middle layer skin!");
        console.log(`  Middle layers with skin: ${middleLayersEnabled.join(', ')}`);
        console.log("  These correspond to the step transitions in the geometry.");
    } else {
        console.log("⚠️  No middle layer skin generated.");
        console.log("  The stepped geometry may need larger transitions or the");
        console.log("  coverage threshold may need adjustment.");
    }
}

main().catch(error => {
    console.error('Error:', error.message);
    console.error(error.stack);
    process.exit(1);
});
