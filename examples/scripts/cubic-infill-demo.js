/**
 * Cubic Infill Pattern Demonstration
 *
 * This example demonstrates the cubic infill pattern, which creates a TRUE 3D cubic
 * lattice structure by SHIFTING diagonal lines across layers. Unlike grid pattern
 * which repeats the same crosshatch on every layer, cubic pattern progressively
 * shifts the line positions to create interlocking 3D cubes.
 *
 * Pattern behavior:
 * - Uses both +45° and -45° diagonal lines on EVERY layer
 * - Lines shift their XY position as Z increases (pattern repeats every 4 layers)
 * - Layer 0: Lines at base positions
 * - Layer 1: Lines shift by 1/4 of spacing
 * - Layer 2: Lines shift by 1/2 of spacing
 * - Layer 3: Lines shift by 3/4 of spacing
 * - Layer 4: Back to base (cycle repeats)
 *
 * This creates a helical/staggered pattern where lines from different layers
 * connect diagonally in 3D space, forming actual cube edges rather than
 * flat 2D layers. Uses approximately 30% less material than grid while
 * maintaining strength.
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

// Analyze the 4-layer pattern cycle with progressive shift.
console.log('Cubic Pattern Analysis (4-layer cycle with progressive shift):');
console.log('Layer | Cycle | Infill Moves | Shift Phase');
console.log('------|-------|--------------|---------------------------');

// Get middle layers (skip skin layers at top and bottom).
const skinLayers = Math.ceil(slicer.getShellSkinThickness() / slicer.getLayerHeight());
const startLayer = skinLayers;
const endLayer = layerCount - skinLayers;

let cycleTotals = [0, 0, 0, 0];
let cycleCounts = [0, 0, 0, 0];

for (let i = startLayer; i < Math.min(startLayer + 16, endLayer); i++) {
    const moves = layerInfillMoves[i] || 0;
    const cycle = i % 4;
    let phase = '';
    
    if (cycle === 0) {
        phase = 'Base position (0/4)';
    } else if (cycle === 1) {
        phase = 'Shift by 1/4 spacing';
    } else if (cycle === 2) {
        phase = 'Shift by 1/2 spacing';
    } else if (cycle === 3) {
        phase = 'Shift by 3/4 spacing';
    }
    
    cycleTotals[cycle] += moves;
    cycleCounts[cycle]++;
    
    console.log(`${String(i).padStart(5)} | ${cycle}     | ${String(moves).padStart(12)} | ${phase}`);
}

console.log('\nPattern Statistics:');
console.log('All layers use both +45° and -45° diagonals, but shifted:');
for (let i = 0; i < 4; i++) {
    if (cycleCounts[i] > 0) {
        const avg = Math.round(cycleTotals[i] / cycleCounts[i]);
        console.log(`- Cycle ${i} average: ${avg} moves`);
    }
}
const totalAvg = cycleTotals.reduce((a, b) => a + b) / cycleCounts.reduce((a, b) => a + b);
console.log(`- Overall average: ${Math.round(totalAvg)} moves per layer`);
console.log('- Pattern shifts create 3D interlocking structure\n');

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
