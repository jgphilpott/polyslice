const THREE = require('three');
const Polytree = require('@jgphilpott/polytree');
const helpers = require('./src/slicer/geometry/helpers.js');

function createTorus(radius = 5, tube = 2) {
  const geometry = new THREE.TorusGeometry(radius, tube, 16, 32);
  const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
  const mesh = new THREE.Mesh(geometry, material);
  mesh.position.set(0, 0, tube);
  mesh.updateMatrixWorld();
  return mesh;
}

const mesh = createTorus(5, 2);

const boundingBox = new THREE.Box3().setFromObject(mesh);
const minZ = boundingBox.min.z;
const maxZ = boundingBox.max.z;

console.log(`Torus Z range: ${minZ.toFixed(2)} to ${maxZ.toFixed(2)}`);

const layerHeight = 0.2;
const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ, maxZ);

console.log(`Total layers: ${allLayers.length}\n`);

// Check layers around Z=2.0mm
const targetIndices = [8, 9, 10]; // Layers 9, 10, 11 (displayed as 10, 11, 12)

targetIndices.forEach(layerIndex => {
    if (layerIndex >= allLayers.length) return;
    
    const layerSegments = allLayers[layerIndex];
    const currentZ = minZ + layerIndex * layerHeight;
    const layerPaths = helpers.connectSegmentsToPaths(layerSegments);
    
    console.log(`Layer ${layerIndex} (display Layer ${layerIndex + 1}) at Z=${currentZ.toFixed(4)}:`);
    console.log(`  Segments: ${layerSegments.length}`);
    console.log(`  Paths: ${layerPaths.length}`);
    
    // Check hole detection
    layerPaths.forEach((path, pathIdx) => {
        const xs = path.map(p => p.x);
        const ys = path.map(p => p.y);
        const minX = Math.min(...xs);
        const maxX = Math.max(...xs);
        const minY = Math.min(...ys);
        const maxY = Math.max(...ys);
        const width = maxX - minX;
        
        let isHole = false;
        for (let j = 0; j < layerPaths.length; j++) {
            if (j === pathIdx) continue;
            if (helpers.pointInPolygon(path[0], layerPaths[j])) {
                isHole = true;
                break;
            }
        }
        
        console.log(`  Path ${pathIdx}: ${path.length} points, width ${width.toFixed(2)}mm, isHole=${isHole}`);
    });
    console.log();
});
