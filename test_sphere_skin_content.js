const THREE = require('three');
const Polyslice = require('./src/polyslice.js');

// Create a sphere (same as test)
const geometry = new THREE.SphereGeometry(5, 32, 32);
const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial());
mesh.position.set(0, 0, 5);
mesh.updateMatrixWorld();

const slicer = new Polyslice({
    nozzleDiameter: 0.4,
    shellWallThickness: 0.8,
    shellSkinThickness: 0.4, // 2 layers
    layerHeight: 0.2,
    verbose: true
});

const result = slicer.slice(mesh);

// Find layer 1 skin section
const lines = result.split('\n');
let currentLayer = null;
let inLayer1 = false;
let inSkin = false;
let skinLines = [];

for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    if (line.includes('LAYER:')) {
        const layerMatch = line.match(/LAYER: (\d+)/);
        currentLayer = layerMatch ? parseInt(layerMatch[1]) : null;
        inLayer1 = (currentLayer === 1);
        inSkin = false;
    }
    
    if (inLayer1) {
        if (line.includes('; TYPE: SKIN')) {
            inSkin = true;
        }
        
        if (inSkin) {
            skinLines.push(line);
            
            // Stop at next TYPE marker
            if (line.includes('; TYPE:') && !line.includes('SKIN') && skinLines.length > 1) {
                break;
            }
        }
    }
}

console.log('Layer 1 SKIN section content:');
for (const line of skinLines) {
    console.log(line);
}
