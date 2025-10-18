const THREE = require('three');
const Polyslice = require('./src/polyslice.js');

// Create a box geometry (same as test)
const geometry = new THREE.BoxGeometry(10, 10, 10);
const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial());
mesh.position.set(0, 0, 5);
mesh.updateMatrixWorld();

const slicer = new Polyslice({
    nozzleDiameter: 0.4,
    shellWallThickness: 1.6, // 4 walls
    layerHeight: 0.2,
    verbose: true
});

const result = slicer.slice(mesh);

// Count wall types per layer - EXACTLY like the test does
const lines = result.split('\n');
const layerWallCounts = [];
let currentLayerOuter = 0;
let currentLayerInner = 0;

for (const line of lines) {
    if (line.includes('LAYER:')) {
        // Save previous layer counts if any.
        if (currentLayerOuter > 0) {
            layerWallCounts.push({ outer: currentLayerOuter, inner: currentLayerInner });
        }
        currentLayerOuter = 0;
        currentLayerInner = 0;
    } else if (line.includes('; TYPE: WALL-OUTER')) {
        currentLayerOuter++;
    } else if (line.includes('; TYPE: WALL-INNER')) {
        currentLayerInner++;
    }
}

// Save last layer.
if (currentLayerOuter > 0) {
    layerWallCounts.push({ outer: currentLayerOuter, inner: currentLayerInner });
}

console.log('Layer wall counts:');
for (let i = 0; i < layerWallCounts.length; i++) {
    const counts = layerWallCounts[i];
    if (counts.inner !== 3) {
        console.log(`Layer index ${i}: ${counts.outer} outer, ${counts.inner} inner ⚠️`);
    }
}

console.log(`\nTotal layers with walls: ${layerWallCounts.length}`);

// Check all layers
let allCorrect = true;
for (const counts of layerWallCounts) {
    if (counts.outer !== 1 || counts.inner !== 3) {
        allCorrect = false;
        break;
    }
}

console.log(`All layers correct: ${allCorrect}`);
