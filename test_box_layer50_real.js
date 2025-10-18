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
const minZ = boundingBox.min.z;
const maxZ = boundingBox.max.z;

console.log('Box bounds:', minZ, 'to', maxZ);

// Slice the mesh
const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ, maxZ);

console.log('Total layers:', allLayers.length);

// Check layer 50 (index 49)
if (allLayers.length > 49) {
    const layer49Segments = allLayers[49];
    console.log('Layer 50 (index 49) segments:', layer49Segments.length);
    
    const layer49Paths = helpers.connectSegmentsToPaths(layer49Segments);
    console.log('Layer 50 paths:', layer49Paths.length);
    
    if (layer49Paths.length > 0) {
        const path = layer49Paths[0];
        console.log('First path points:', path.length);
        
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
        console.log(`Path bounds: ${width.toFixed(2)} x ${height.toFixed(2)}`);
        
        // Try insets
        let currentPath = path;
        for (let i = 0; i < 4; i++) {
            const insetPath = helpers.createInsetPath(currentPath, 0.4);
            console.log(`Inset ${i}: ${insetPath.length} points`);
            
            if (insetPath.length === 0) {
                console.log('  ⚠️  Path became degenerate at inset', i);
                
                // Debug the current path
                let centroidX = 0, centroidY = 0;
                for (const pt of currentPath) {
                    centroidX += pt.x;
                    centroidY += pt.y;
                }
                centroidX /= currentPath.length;
                centroidY /= currentPath.length;
                
                let avgDist = 0;
                for (const pt of currentPath) {
                    const dx = pt.x - centroidX;
                    const dy = pt.y - centroidY;
                    avgDist += Math.sqrt(dx * dx + dy * dy);
                }
                avgDist /= currentPath.length;
                
                console.log(`  Current path avg distance from centroid: ${avgDist.toFixed(3)}`);
                console.log(`  Inset distance: 0.4`);
                console.log(`  Expected reduction: ${(0.4 * 0.5).toFixed(3)}`);
                break;
            }
            
            currentPath = insetPath;
        }
    }
}
