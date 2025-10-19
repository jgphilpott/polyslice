const Polyslice = require('./src/index.js');
const THREE = require('three');

const slicer = new Polyslice();

// Create a cylinder (circular cross-section).
const geometry = new THREE.CylinderGeometry(5, 5, 10, 32);
const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial());
mesh.position.set(0, 0, 5);
mesh.updateMatrixWorld();

slicer.setNozzleDiameter(0.4);
slicer.setShellWallThickness(0.8);
slicer.setShellSkinThickness(0.4);
slicer.setLayerHeight(0.2);
slicer.setInfillDensity(20);
slicer.setInfillPattern('grid');
slicer.setVerbose(true);

const result = slicer.slice(mesh);

// Find layer 10 infill coordinates
const lines = result.split('\n');
let inFill = false;
let currentLayer = null;
const infillCoords = [];

for (const line of lines) {
    if (line.includes('LAYER:')) {
        const layerMatch = line.match(/LAYER: (\d+)/);
        currentLayer = layerMatch ? parseInt(layerMatch[1]) : null;
    }
    
    if (currentLayer !== 10) continue;
    
    if (line.includes('; TYPE: FILL')) {
        inFill = true;
        continue;
    }
    
    if (line.includes('; TYPE:') && !line.includes('FILL')) {
        inFill = false;
    }
    
    if (inFill && line.includes('G1') && line.includes('X') && line.includes('Y')) {
        const xMatch = line.match(/X([\d.]+)/);
        const yMatch = line.match(/Y([\d.]+)/);
        
        if (xMatch && yMatch) {
            infillCoords.push({
                x: parseFloat(xMatch[1]),
                y: parseFloat(yMatch[1])
            });
        }
    }
    
    if (line.includes("LAYER: 11")) break;
}

console.log(`Found ${infillCoords.length} infill coordinates on layer 10`);
if (infillCoords.length > 0) {
    console.log('First 10 coordinates:');
    for (let i = 0; i < Math.min(10, infillCoords.length); i++) {
        const coord = infillCoords[i];
        const dx = coord.x - 100;
        const dy = coord.y - 100;
        const distance = Math.sqrt(dx * dx + dy * dy);
        console.log(`  (${coord.x.toFixed(2)}, ${coord.y.toFixed(2)}) - distance from (100,100): ${distance.toFixed(2)}`);
    }
    
    // Find min/max to understand the coordinate range
    const xs = infillCoords.map(c => c.x);
    const ys = infillCoords.map(c => c.y);
    console.log(`\nX range: ${Math.min(...xs).toFixed(2)} to ${Math.max(...xs).toFixed(2)}`);
    console.log(`Y range: ${Math.min(...ys).toFixed(2)} to ${Math.max(...ys).toFixed(2)}`);
    
    // Calculate center
    const centerX = (Math.min(...xs) + Math.max(...xs)) / 2;
    const centerY = (Math.min(...ys) + Math.max(...ys)) / 2;
    console.log(`\nCalculated center: (${centerX.toFixed(2)}, ${centerY.toFixed(2)})`);
}
