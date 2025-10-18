const THREE = require('three');
const Polytree = require('@jgphilpott/polytree');
const helpers = require('./src/slicer/geometry/helpers.js');

// Create a box geometry
const geometry = new THREE.BoxGeometry(10, 10, 10);
const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial());
mesh.position.set(0, 0, 5);
mesh.updateMatrixWorld();

const layerHeight = 0.2;
const boundingBox = new THREE.Box3().setFromObject(mesh);
let minZ = boundingBox.min.z;
const maxZ = boundingBox.max.z;

if (minZ < 0) {
    mesh.position.z += -minZ;
    mesh.updateMatrixWorld();
    const newBox = new THREE.Box3().setFromObject(mesh);
    minZ = newBox.min.z;
}

const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ, maxZ + (-boundingBox.min.z));

// Check layer 50
const layerSegments = allLayers[50];
const paths = helpers.connectSegmentsToPaths(layerSegments);
const path = paths[0];

console.log('Layer 50 original path:');
console.log('  Points:', path.length);
for (const pt of path) {
    console.log(`    (${pt.x.toFixed(3)}, ${pt.y.toFixed(3)})`);
}

// Calculate centroid and avg distance
let centroidX = 0, centroidY = 0;
for (const pt of path) {
    centroidX += pt.x;
    centroidY += pt.y;
}
centroidX /= path.length;
centroidY /= path.length;

let avgDist = 0;
for (const pt of path) {
    const dx = pt.x - centroidX;
    const dy = pt.y - centroidY;
    avgDist += Math.sqrt(dx * dx + dy * dy);
}
avgDist /= path.length;

console.log(`\nOriginal avg distance from centroid: ${avgDist.toFixed(3)}`);

// Try to create inset
const insetPath = helpers.createInsetPath(path, 0.4);

if (insetPath.length > 0) {
    let insetCentroidX = 0, insetCentroidY = 0;
    for (const pt of insetPath) {
        insetCentroidX += pt.x;
        insetCentroidY += pt.y;
    }
    insetCentroidX /= insetPath.length;
    insetCentroidY /= insetPath.length;
    
    let insetAvgDist = 0;
    for (const pt of insetPath) {
        const dx = pt.x - insetCentroidX;
        const dy = pt.y - insetCentroidY;
        insetAvgDist += Math.sqrt(dx * dx + dy * dy);
    }
    insetAvgDist /= insetPath.length;
    
    console.log(`Inset avg distance from centroid: ${insetAvgDist.toFixed(3)}`);
    console.log(`Actual reduction: ${(avgDist - insetAvgDist).toFixed(3)}`);
    console.log(`Expected reduction (20%): ${(0.4 * 0.2).toFixed(3)}`);
} else {
    console.log('Inset path is empty (rejected by validation)');
}
