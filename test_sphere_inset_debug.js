const THREE = require('three');
const Polytree = require('@jgphilpott/polytree');
const helpers = require('./src/slicer/geometry/helpers.js');

// Create a sphere
const geometry = new THREE.SphereGeometry(5, 32, 32);
const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial());
mesh.position.set(0, 0, 5);
mesh.updateMatrixWorld();

const layerHeight = 0.2;
const nozzleDiameter = 0.4;

// Get bounding box
const boundingBox = new THREE.Box3().setFromObject(mesh);
let minZ = boundingBox.min.z;
const maxZ = boundingBox.max.z;

if (minZ < 0) {
    mesh.position.z += -minZ;
    mesh.updateMatrixWorld();
    const newBox = new THREE.Box3().setFromObject(mesh);
    minZ = newBox.min.z;
}

// Slice the mesh
const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ, maxZ + (-boundingBox.min.z));

// Check layer 1
const layer1Segments = allLayers[1];
const paths = helpers.connectSegmentsToPaths(layer1Segments);
let path = paths[0];

// First inset (outer wall)
path = helpers.createInsetPath(path, nozzleDiameter);
console.log('After outer wall inset:', path.length, 'points');

// Calculate bounds
let minX = Infinity, maxX = -Infinity;
let minY = Infinity, maxY = -Infinity;
for (const point of path) {
    minX = Math.min(minX, point.x);
    maxX = Math.max(maxX, point.x);
    minY = Math.min(minY, point.y);
    maxY = Math.max(maxY, point.y);
}

const origWidth = maxX - minX;
const origHeight = maxY - minY;
console.log(`Bounds: ${origWidth.toFixed(3)} x ${origHeight.toFixed(3)}`);

// Try second inset (inner wall) - but manually calculate what WOULD happen
// Get access to the internal inset calculation
const insetPath = helpers.createInsetPath(path, nozzleDiameter);

if (insetPath.length > 0) {
    console.log('Second inset succeeded:', insetPath.length, 'points');
    
    let minX2 = Infinity, maxX2 = -Infinity;
    let minY2 = Infinity, maxY2 = -Infinity;
    for (const point of insetPath) {
        minX2 = Math.min(minX2, point.x);
        maxX2 = Math.max(maxX2, point.x);
        minY2 = Math.min(minY2, point.y);
        maxY2 = Math.max(maxY2, point.y);
    }
    
    const insetWidth = maxX2 - minX2;
    const insetHeight = maxY2 - minY2;
    console.log(`Inset bounds: ${insetWidth.toFixed(3)} x ${insetHeight.toFixed(3)}`);
    
    const widthReduction = origWidth - insetWidth;
    const heightReduction = origHeight - insetHeight;
    const expectedReduction = nozzleDiameter * 2 * 0.1;
    
    console.log(`Width reduction: ${widthReduction.toFixed(3)}, expected: >= ${expectedReduction.toFixed(3)}`);
    console.log(`Height reduction: ${heightReduction.toFixed(3)}, expected: >= ${expectedReduction.toFixed(3)}`);
} else {
    console.log('Second inset failed (rejected by validation)');
    
    // The inset calculation must have been rejected
    // Let's see what the issue is by examining the path size
    console.log(`\nPath dimensions: ${origWidth.toFixed(3)} x ${origHeight.toFixed(3)}`);
    console.log(`Inset distance: ${nozzleDiameter.toFixed(3)}`);
    console.log(`Expected reduction (10%): >= ${(nozzleDiameter * 2 * 0.1).toFixed(3)}`);
    console.log(`\nThis path is too small for another ${nozzleDiameter}mm inset`);
}
