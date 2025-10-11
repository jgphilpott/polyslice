/**
 * Cubic Infill Pattern Demonstration
 *
 * This example demonstrates the cubic infill pattern, which creates a 3D cubic
 * lattice structure by rotating diagonal lines across layers. The pattern
 * repeats every 3 layers:
 * - Layer 0 (mod 3 = 0): Both +45° and -45° lines (crosshatch)
 * - Layer 1 (mod 3 = 1): Only +45° lines
 * - Layer 2 (mod 3 = 2): Only -45° lines
 *
 * This creates a more efficient 3D structure compared to grid pattern,
 * using approximately 30% less material while maintaining strength.
 */

const Polyslice = require('../../src/index.js');
const THREE = require('three');

console.log('Cubic Infill Pattern Demonstration');
console.log('===================================\n');

// Create a slicer instance with cubic infill pattern.
const slicer = new Polyslice({
    autohome: true,
    workspacePlane: 'XY',
    lengthUnit: 'millimeters',
    nozzleTemperature: 210,
    bedTemperature: 60,
    fanSpeed: 80,
    layerHeight: 0.2,
    nozzleDiameter: 0.4,
    shellWallThickness: 0.8,  // 2 walls
    shellSkinThickness: 0.4,  // 2 bottom + 2 top layers
    infillDensity: 20,
    infillPattern: 'cubic',  // Use cubic pattern
    verbose: true
});

console.log('Slicer Configuration:');
console.log(`- Infill Pattern: ${slicer.getInfillPattern()}`);
console.log(`- Infill Density: ${slicer.getInfillDensity()}%`);
console.log(`- Layer Height: ${slicer.getLayerHeight()}mm`);
console.log(`- Nozzle Diameter: ${slicer.getNozzleDiameter()}mm`);
console.log(`- Shell Walls: ${slicer.getShellWallThickness() / slicer.getNozzleDiameter()} walls`);
console.log(`- Shell Skin: ${slicer.getShellSkinThickness() / slicer.getLayerHeight()} layers\n`);

// Create a 20mm test cube.
console.log('Creating test cube (20x20x10mm):');
const geometry = new THREE.BoxGeometry(20, 20, 10);
const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial());
mesh.position.set(0, 0, 5);  // Center at z=5 (half height)
mesh.updateMatrixWorld();

console.log(`- Dimensions: 20mm x 20mm x 10mm`);
console.log(`- Expected layers: ${Math.ceil(10 / slicer.getLayerHeight())}\n`);

// Slice the mesh.
console.log('Slicing with cubic infill pattern...\n');
const gcode = slicer.slice(mesh);

// Analyze the G-code output.
const lines = gcode.split('\n');
let layerCount = 0;
let infillLayerCount = 0;
let totalInfillMoves = 0;
let currentLayer = null;
let inFill = false;
let layerInfillMoves = {};

for (const line of lines) {
    if (line.includes('LAYER:')) {
        const match = line.match(/LAYER: (\d+)/);
        if (match) {
            currentLayer = parseInt(match[1]);
            layerCount++;
            layerInfillMoves[currentLayer] = 0;
        }
    }

    if (line.includes('; TYPE: FILL')) {
        inFill = true;
        infillLayerCount++;
    }

    if (line.includes('; TYPE:') && !line.includes('FILL')) {
        inFill = false;
    }

    if (inFill && line.includes('G1') && line.includes('E') && currentLayer !== null) {
        totalInfillMoves++;
        layerInfillMoves[currentLayer]++;
    }
}

console.log('Slicing Results:');
console.log(`- Total layers: ${layerCount}`);
console.log(`- Layers with infill: ${infillLayerCount}`);
console.log(`- Total infill moves: ${totalInfillMoves}\n`);

// Analyze the 3-layer pattern cycle.
console.log('Cubic Pattern Analysis (3-layer cycle):');
console.log('Layer | Cycle | Infill Moves | Pattern');
console.log('------|-------|--------------|---------------------------');

// Get middle layers (skip skin layers at top and bottom).
const skinLayers = Math.ceil(slicer.getShellSkinThickness() / slicer.getLayerHeight());
const startLayer = skinLayers;
const endLayer = layerCount - skinLayers;

let layer0Total = 0;
let layer1Total = 0;
let layer2Total = 0;
let layer0Count = 0;
let layer1Count = 0;
let layer2Count = 0;

for (let i = startLayer; i < Math.min(startLayer + 12, endLayer); i++) {
    const moves = layerInfillMoves[i] || 0;
    const cycle = i % 3;
    let pattern = '';
    
    if (cycle === 0) {
        pattern = 'Both +45° and -45° (crosshatch)';
        layer0Total += moves;
        layer0Count++;
    } else if (cycle === 1) {
        pattern = 'Only +45° diagonal';
        layer1Total += moves;
        layer1Count++;
    } else if (cycle === 2) {
        pattern = 'Only -45° diagonal';
        layer2Total += moves;
        layer2Count++;
    }
    
    console.log(`${String(i).padStart(5)} | ${cycle}     | ${String(moves).padStart(12)} | ${pattern}`);
}

console.log('\nPattern Statistics:');
if (layer0Count > 0 && layer1Count > 0 && layer2Count > 0) {
    const avg0 = Math.round(layer0Total / layer0Count);
    const avg1 = Math.round(layer1Total / layer1Count);
    const avg2 = Math.round(layer2Total / layer2Count);
    
    console.log(`- Layer 0 (mod 3 = 0) average: ${avg0} moves (crosshatch)`);
    console.log(`- Layer 1 (mod 3 = 1) average: ${avg1} moves (one diagonal)`);
    console.log(`- Layer 2 (mod 3 = 2) average: ${avg2} moves (one diagonal)`);
    console.log(`- Ratio (Layer 0 : Layer 1): ${(avg0 / avg1).toFixed(2)}:1`);
    console.log('  (Layer 0 should have ~2x moves since it has both directions)\n');
}

// Compare with grid pattern.
console.log('Comparison with Grid Pattern:');
const slicerGrid = new Polyslice({
    layerHeight: 0.2,
    nozzleDiameter: 0.4,
    shellWallThickness: 0.8,
    shellSkinThickness: 0.4,
    infillDensity: 20,
    infillPattern: 'grid',
    verbose: true
});

const gcodeGrid = slicerGrid.slice(mesh);
const linesGrid = gcodeGrid.split('\n');
let totalGridMoves = 0;
let inFillGrid = false;

for (const line of linesGrid) {
    if (line.includes('; TYPE: FILL')) {
        inFillGrid = true;
    }
    if (line.includes('; TYPE:') && !line.includes('FILL')) {
        inFillGrid = false;
    }
    if (inFillGrid && line.includes('G1') && line.includes('E')) {
        totalGridMoves++;
    }
}

const efficiency = ((1 - (totalInfillMoves / totalGridMoves)) * 100).toFixed(1);
console.log(`- Grid pattern infill moves: ${totalGridMoves}`);
console.log(`- Cubic pattern infill moves: ${totalInfillMoves}`);
console.log(`- Material savings: ${efficiency}% (cubic uses less material)\n`);

console.log('G-code Output Summary:');
console.log(`- Total lines: ${lines.length}`);
console.log(`- Output size: ${(gcode.length / 1024).toFixed(2)} KB\n`);

// Save example to file (optional).
const fs = require('fs');
const outputPath = '/tmp/cubic-infill-example.gcode';
fs.writeFileSync(outputPath, gcode);
console.log(`G-code saved to: ${outputPath}`);
console.log('\nCubic infill pattern demonstration complete!');
