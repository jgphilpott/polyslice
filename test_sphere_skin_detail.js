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

// Parse G-code to extract skin wall and infill (same as test)
const lines = result.split('\n');
let inSkinWall = false;
let inSkinInfill = false;
let skinWallCoords = [];
let skinInfillCoords = [];
let currentLayer = null;

for (const line of lines) {
    if (line.includes('LAYER:')) {
        const layerMatch = line.match(/LAYER: (\d+)/);
        currentLayer = layerMatch ? parseInt(layerMatch[1]) : null;
        inSkinWall = false;
        inSkinInfill = false;
    }
    
    // Detect skin wall (right after TYPE: SKIN)
    if (line.includes('; TYPE: SKIN')) {
        inSkinWall = true;
        inSkinInfill = false;
    }
    
    // Skin infill starts after "Moving to skin infill line"
    if (line.includes('Moving to skin infill line')) {
        inSkinWall = false;
        inSkinInfill = true;
    }
    
    // Exit skin section
    if (line.includes('; TYPE:') && !line.includes('SKIN')) {
        inSkinWall = false;
        inSkinInfill = false;
    }
    
    // Extract coordinates from G1 moves
    if ((inSkinWall || inSkinInfill) && line.includes('G1')) {
        const xMatch = line.match(/X([\d.]+)/);
        const yMatch = line.match(/Y([\d.]+)/);
        
        if (xMatch && yMatch && currentLayer === 1) { // Only check first skin layer
            const x = parseFloat(xMatch[1]);
            const y = parseFloat(yMatch[1]);
            
            if (inSkinWall) {
                skinWallCoords.push({ x, y });
            }
            
            if (inSkinInfill) {
                skinInfillCoords.push({ x, y });
            }
        }
    }
}

console.log('Layer 1 skin wall coords:', skinWallCoords.length);
console.log('Layer 1 skin infill coords:', skinInfillCoords.length);

if (skinWallCoords.length === 0) {
    // Check if there's skin at all in layer 1
    console.log('\nLooking for layer 1 skin TYPE markers:');
    currentLayer = null;
    for (const line of lines) {
        if (line.includes('LAYER:')) {
            const layerMatch = line.match(/LAYER: (\d+)/);
            currentLayer = layerMatch ? parseInt(layerMatch[1]) : null;
        }
        
        if (currentLayer === 1 && line.includes('TYPE')) {
            console.log('  ', line.trim());
        }
    }
}
