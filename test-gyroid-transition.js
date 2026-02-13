/**
 * Test script to visualize gyroid transition behavior
 */

const { Polyslice } = require('./src/index');
const THREE = require('three');

console.log('Gyroid Transition Test');
console.log('======================\n');

// Create a simple cube
const geometry = new THREE.BoxGeometry(10, 10, 10);
const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial());
mesh.position.set(0, 0, 5);
mesh.updateMatrixWorld();

// Configure slicer
const slicer = new Polyslice({
    nozzleDiameter: 0.4,
    shellWallThickness: 0.8,
    shellSkinThickness: 0.4,
    layerHeight: 0.2,
    infillDensity: 20,
    infillPattern: 'gyroid',
    verbose: true,
    metadata: false,
    testStrip: false,
    wipeNozzle: false
});

// Generate G-code
console.log('Slicing cube with gyroid infill...');
const gcode = slicer.slice(mesh);

// Analyze layer-by-layer infill
const lines = gcode.split('\n');
const layerData = [];
let currentLayer = -1;
let inFillSection = false;
let fillLineCount = 0;

for (const line of lines) {
    if (line.includes('LAYER:')) {
        if (currentLayer >= 0) {
            layerData.push({
                layer: currentLayer,
                fillLines: fillLineCount
            });
        }
        currentLayer++;
        fillLineCount = 0;
        inFillSection = false;
    }
    
    if (line.includes('; TYPE: FILL')) {
        inFillSection = true;
    } else if (line.includes('; TYPE:') && !line.includes('FILL')) {
        inFillSection = false;
    }
    
    if (inFillSection && line.startsWith('G1') && line.includes('E')) {
        fillLineCount++;
    }
}

if (currentLayer >= 0) {
    layerData.push({
        layer: currentLayer,
        fillLines: fillLineCount
    });
}

console.log('\nLayer-by-Layer Infill Analysis:');
console.log('================================\n');
console.log('Layer | Cycle Pos | Fill Lines | Description');
console.log('------|-----------|------------|------------');

// Skip skin layers (first 2, last 2)
const infillLayers = layerData.filter(d => d.fillLines > 0);

infillLayers.slice(0, 16).forEach((data) => {
    const cyclePos = data.layer % 8;
    let description = '';
    
    if (cyclePos === 0) {
        description = 'Pure X-direction';
    } else if (cyclePos === 7) {
        description = 'Mostly Y-direction';
    } else {
        description = `Blend (${cyclePos}/8 transition)`;
    }
    
    console.log(`${data.layer.toString().padStart(5)} | ${cyclePos.toString().padStart(9)} | ${data.fillLines.toString().padStart(10)} | ${description}`);
});

console.log('\nTransition Pattern:');
console.log('===================');
console.log('- Layer 0: blendRatio = 0/8 = 0.000 → Pure X-direction (horizontal)');
console.log('- Layer 1: blendRatio = 1/8 = 0.125 → Mostly X + some Y');
console.log('- Layer 2: blendRatio = 2/8 = 0.250 → More X + more Y');
console.log('- Layer 3: blendRatio = 3/8 = 0.375 → Balanced blend');
console.log('- Layer 4: blendRatio = 4/8 = 0.500 → Equal X and Y');
console.log('- Layer 5: blendRatio = 5/8 = 0.625 → More Y than X');
console.log('- Layer 6: blendRatio = 6/8 = 0.750 → Mostly Y + some X');
console.log('- Layer 7: blendRatio = 7/8 = 0.875 → Mostly Y-direction (vertical)');
console.log('- Layer 8: blendRatio = 0/8 = 0.000 → Pure X-direction (cycle repeats)');

console.log('\n✅ Test complete!');
console.log('The gradual transition over 8 layers creates smoother layer-to-layer adhesion');
console.log('compared to the previous alternating pattern (X → Y → X → Y...).');
