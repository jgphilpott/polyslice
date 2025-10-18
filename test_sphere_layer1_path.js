const THREE = require('three');
const Polytree = require('@jgphilpott/polytree');
const helpers = require('./src/slicer/geometry/helpers.js');

// Create a sphere (same as test)
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

// Adjust for negative Z
if (minZ < 0) {
    mesh.position.z += -minZ;
    mesh.updateMatrixWorld();
    const newBox = new THREE.Box3().setFromObject(mesh);
    minZ = newBox.min.z;
}

// Slice the mesh
const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ, maxZ + (-boundingBox.min.z));

console.log('Total layers:', allLayers.length);

// Check layer 1
if (allLayers.length > 1) {
    const layer1Segments = allLayers[1];
    const z = minZ + 1 * layerHeight;
    console.log(`\nLayer 1 (z=${z.toFixed(2)}): ${layer1Segments.length} segments`);
    
    const paths = helpers.connectSegmentsToPaths(layer1Segments);
    console.log(`Paths: ${paths.length}`);
    
    if (paths.length > 0) {
        const path = paths[0];
        console.log(`First path: ${path.length} points`);
        
        // Calculate bounds
        let minX = Infinity, maxX = -Infinity;
        let minY = Infinity, maxY = -Infinity;
        for (const point of path) {
            minX = Math.min(minX, point.x);
            maxX = Math.max(maxX, point.x);
            minY = Math.min(minY, point.y);
            maxY = Math.max(maxY, point.y);
        }
        
        const width = maxX - minX;
        const height = maxY - minY;
        console.log(`Bounds: ${width.toFixed(2)} x ${height.toFixed(2)}`);
        
        // Try insets (2 walls = 2 insets)
        let currentPath = path;
        for (let i = 0; i < 2; i++) {
            const insetPath = helpers.createInsetPath(currentPath, nozzleDiameter);
            console.log(`Wall ${i} inset: ${insetPath.length} points`);
            
            if (insetPath.length === 0) {
                console.log(`  ⚠️  Path became degenerate at wall ${i}`);
                break;
            }
            
            currentPath = insetPath;
        }
        
        // After walls, try skin inset (the innermost path after walls)
        if (currentPath.length > 0) {
            console.log(`\nSkin path before inset: ${currentPath.length} points`);
            
            // Calculate bounds
            minX = Infinity; maxX = -Infinity;
            minY = Infinity; maxY = -Infinity;
            for (const point of currentPath) {
                minX = Math.min(minX, point.x);
                maxX = Math.max(maxX, point.x);
                minY = Math.min(minY, point.y);
                maxY = Math.max(maxY, point.y);
            }
            
            const skinWidth = maxX - minX;
            const skinHeight = maxY - minY;
            console.log(`Skin bounds before inset: ${skinWidth.toFixed(2)} x ${skinHeight.toFixed(2)}`);
        }
    }
}
