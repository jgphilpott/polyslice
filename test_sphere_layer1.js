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

// Parse G-code to check layer 1
const lines = result.split('\n');
let currentLayer = null;
let inSkin = false;
let layer1HasSkin = false;

for (const line of lines) {
    if (line.includes('LAYER:')) {
        const layerMatch = line.match(/LAYER: (\d+)/);
        currentLayer = layerMatch ? parseInt(layerMatch[1]) : null;
        inSkin = false;
    }
    
    if (line.includes('; TYPE: SKIN')) {
        inSkin = true;
        if (currentLayer === 1) {
            layer1HasSkin = true;
        }
    }
    
    if (line.includes('; TYPE:') && !line.includes('SKIN')) {
        inSkin = false;
    }
}

console.log('Layer 1 has skin:', layer1HasSkin);

// Check first few layers
console.log('\nChecking first few layers for skin:');
currentLayer = null;
let layerSkinStatus = {};

for (const line of lines) {
    if (line.includes('LAYER:')) {
        const layerMatch = line.match(/LAYER: (\d+)/);
        currentLayer = layerMatch ? parseInt(layerMatch[1]) : null;
        if (currentLayer !== null && currentLayer <= 5) {
            layerSkinStatus[currentLayer] = false;
        }
    }
    
    if (line.includes('; TYPE: SKIN') && currentLayer !== null && currentLayer <= 5) {
        layerSkinStatus[currentLayer] = true;
    }
}

for (let i = 0; i <= 5; i++) {
    console.log(`  Layer ${i}: ${layerSkinStatus[i] ? 'HAS SKIN' : 'NO SKIN'}`);
}
