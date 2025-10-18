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

// Count wall types per layer
const lines = result.split('\n');
let currentLayer = -1;
let layerWallCounts = [];
let currentLayerOuter = 0;
let currentLayerInner = 0;

for (const line of lines) {
    if (line.includes('LAYER:')) {
        // Save previous layer counts if any
        if (currentLayerOuter > 0) {
            layerWallCounts.push({ 
                layer: currentLayer,
                outer: currentLayerOuter, 
                inner: currentLayerInner 
            });
        }
        currentLayer = parseInt(line.match(/LAYER: (\d+)/)[1]);
        currentLayerOuter = 0;
        currentLayerInner = 0;
    } else if (line.includes('; TYPE: WALL-OUTER')) {
        currentLayerOuter++;
    } else if (line.includes('; TYPE: WALL-INNER')) {
        currentLayerInner++;
    }
}

// Save last layer
if (currentLayerOuter > 0) {
    layerWallCounts.push({ 
        layer: currentLayer,
        outer: currentLayerOuter, 
        inner: currentLayerInner 
    });
}

console.log('Wall counts per layer:');
for (const counts of layerWallCounts) {
    console.log(`  Layer ${counts.layer}: ${counts.outer} outer, ${counts.inner} inner`);
    if (counts.inner === 0) {
        console.log('    ⚠️  ERROR: No inner walls!');
    }
}
console.log(`Total layers: ${layerWallCounts.length}`);
console.log(`Expected: 1 outer + 3 inner per layer`);
