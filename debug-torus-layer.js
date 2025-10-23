const THREE = require('three');
const Polytree = require('@jgphilpott/polytree');

// Create the same torus as resources
const size = 30;
const geometry = new THREE.TorusGeometry(size/3, size/6, 16, 32);
const material = new THREE.MeshBasicMaterial({ color: 0x808080 });
const mesh = new THREE.Mesh(geometry, material);

// Get bounding box and adjust to build plate
const boundingBox = new THREE.Box3().setFromObject(mesh);
const minZ = boundingBox.min.z;

if (minZ < 0) {
    const zOffset = -minZ;
    mesh.position.z += zOffset;
    mesh.updateMatrixWorld();
}

// Recalculate after adjustment
const newBbox = new THREE.Box3().setFromObject(mesh);
const newMinZ = newBbox.min.z;
const newMaxZ = newBbox.max.z;

console.log(`Adjusted mesh Z range: ${newMinZ.toFixed(2)} to ${newMaxZ.toFixed(2)}`);

// Slice into layers
const layerHeight = 0.2;
const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, newMinZ, newMaxZ);

console.log(`\nTotal layers: ${allLayers.length}`);

// Import helpers to process segments
const helpers = require('./src/slicer/geometry/helpers.js');

// Check specific layers around Z=2.0mm
const targetLayers = [9, 10, 11]; // 0-indexed

targetLayers.forEach(layerIndex => {
    if (layerIndex >= allLayers.length) return;
    
    const layerSegments = allLayers[layerIndex];
    const currentZ = newMinZ + layerIndex * layerHeight;
    const layerPaths = helpers.connectSegmentsToPaths(layerSegments);
    
    console.log(`\nLayer ${layerIndex} (display as Layer ${layerIndex + 1}) at Z=${currentZ.toFixed(2)}:`);
    console.log(`  Segments: ${layerSegments.length}`);
    console.log(`  Paths: ${layerPaths.length}`);
    
    // Analyze each path
    layerPaths.forEach((path, pathIdx) => {
        const xs = path.map(p => p.x);
        const ys = path.map(p => p.y);
        const minX = Math.min(...xs);
        const maxX = Math.max(...xs);
        const minY = Math.min(...ys);
        const maxY = Math.max(...ys);
        const width = maxX - minX;
        const height = maxY - minY;
        
        // Check if this path is a hole (contained in another path)
        let isHole = false;
        for (let j = 0; j < layerPaths.length; j++) {
            if (j === pathIdx) continue;
            if (helpers.pointInPolygon(path[0], layerPaths[j])) {
                isHole = true;
                break;
            }
        }
        
        console.log(`  Path ${pathIdx}: ${path.length} points`);
        console.log(`    Bounds: X[${minX.toFixed(2)}, ${maxX.toFixed(2)}] Y[${minY.toFixed(2)}, ${maxY.toFixed(2)}]`);
        console.log(`    Size: ${width.toFixed(2)} x ${height.toFixed(2)} mm`);
        console.log(`    Is hole: ${isHole}`);
    });
});
