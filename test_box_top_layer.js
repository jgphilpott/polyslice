const THREE = require('three');
const Polytree = require('@jgphilpott/polytree');
const helpers = require('./src/slicer/geometry/helpers.js');

// Create a box geometry (same as test)
const geometry = new THREE.BoxGeometry(10, 10, 10);
const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial());
mesh.position.set(0, 0, 5);
mesh.updateMatrixWorld();

const layerHeight = 0.2;

// Get bounding box
const boundingBox = new THREE.Box3().setFromObject(mesh);
let minZ = boundingBox.min.z;
const maxZ = boundingBox.max.z;

// Handle negative Z (like the slicer does)
if (minZ < 0) {
    const zOffset = -minZ;
    mesh.position.z += zOffset;
    mesh.updateMatrixWorld();
    const newBox = new THREE.Box3().setFromObject(mesh);
    minZ = newBox.min.z;
}

console.log('Adjusted Z range:', minZ, 'to', maxZ + (-boundingBox.min.z));

// Slice the mesh
const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ, maxZ + (-boundingBox.min.z));

console.log('Total layers:', allLayers.length);

// Check last few layers
for (let i = Math.max(0, allLayers.length - 3); i < allLayers.length; i++) {
    const layerSegments = allLayers[i];
    const z = minZ + i * layerHeight;
    console.log(`\nLayer ${i} (z=${z.toFixed(2)}): ${layerSegments.length} segments`);
    
    const paths = helpers.connectSegmentsToPaths(layerSegments);
    console.log(`  Paths: ${paths.length}`);
    
    if (paths.length > 0) {
        const path = paths[0];
        console.log(`  First path: ${path.length} points`);
        
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
        console.log(`  Bounds: ${width.toFixed(2)} x ${height.toFixed(2)}`);
        
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
        console.log(`  Avg distance from centroid: ${avgDist.toFixed(3)}`);
        
        // Try insets
        let currentPath = path;
        let insetCount = 0;
        for (let j = 0; j < 4; j++) {
            const insetPath = helpers.createInsetPath(currentPath, 0.4);
            if (insetPath.length === 0) {
                console.log(`  ⚠️  Failed at inset ${j}`);
                
                // Debug
                let cX = 0, cY = 0;
                for (const pt of currentPath) {
                    cX += pt.x;
                    cY += pt.y;
                }
                cX /= currentPath.length;
                cY /= currentPath.length;
                
                let avgD = 0;
                for (const pt of currentPath) {
                    const dx = pt.x - cX;
                    const dy = pt.y - cY;
                    avgD += Math.sqrt(dx * dx + dy * dy);
                }
                avgD /= currentPath.length;
                
                console.log(`    Before-inset avg dist: ${avgD.toFixed(3)}, expected reduction: ${(0.4 * 0.5).toFixed(3)}`);
                break;
            }
            insetCount++;
            currentPath = insetPath;
        }
        console.log(`  Successful insets: ${insetCount}`);
    }
}
