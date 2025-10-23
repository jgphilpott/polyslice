const THREE = require('three');
const Polyslice = require('./src/index.js');

// Create a torus (similar to the resources example)
// TorusGeometry(radius, tube, radialSegments, tubularSegments)
const size = 30; // 3cm torus
const geometry = new THREE.TorusGeometry(size/3, size/6, 16, 32);
const material = new THREE.MeshBasicMaterial({ color: 0x808080 });
const mesh = new THREE.Mesh(geometry, material);

// Create slicer with same settings as resources
const slicer = new Polyslice.Polyslice({
    layerHeight: 0.2,
    infillDensity: 50,
    verbose: true
});

// Slice the torus
const gcode = slicer.slice({ mesh });

// Find and extract Layer 10 content
const lines = gcode.split('\n');
let layer10Start = -1;
let layer11Start = -1;

for (let i = 0; i < lines.length; i++) {
    if (lines[i].includes('LAYER: 10')) {
        layer10Start = i;
    }
    if (lines[i].includes('LAYER: 11')) {
        layer11Start = i;
        break;
    }
}

if (layer10Start >= 0 && layer11Start >= 0) {
    const layer10Content = lines.slice(layer10Start, layer11Start).join('\n');
    console.log('=== LAYER 10 CONTENT ===');
    console.log(layer10Content);
    console.log('\n=== ANALYSIS ===');
    
    // Check what types of movements are present
    const hasWallOuter = layer10Content.includes('WALL-OUTER');
    const hasWallInner = layer10Content.includes('WALL-INNER');
    const hasFill = layer10Content.includes('TYPE: FILL');
    
    console.log(`Has WALL-OUTER: ${hasWallOuter}`);
    console.log(`Has WALL-INNER: ${hasWallInner}`);
    console.log(`Has FILL: ${hasFill}`);
    
    // Count G1 movements (actual printing)
    const g1Count = (layer10Content.match(/^G1 /gm) || []).length;
    console.log(`G1 movement commands: ${g1Count}`);
    
    // Check if it's only printing a small circle (the hole)
    const xCoords = [];
    const yCoords = [];
    const g1Regex = /G1 X([\d.]+) Y([\d.]+)/g;
    let match;
    while ((match = g1Regex.exec(layer10Content)) !== null) {
        xCoords.push(parseFloat(match[1]));
        yCoords.push(parseFloat(match[2]));
    }
    
    if (xCoords.length > 0) {
        const minX = Math.min(...xCoords);
        const maxX = Math.max(...xCoords);
        const minY = Math.min(...yCoords);
        const maxY = Math.max(...yCoords);
        const width = maxX - minX;
        const height = maxY - minY;
        
        console.log(`\nPrinting area:`);
        console.log(`  X range: ${minX.toFixed(2)} to ${maxX.toFixed(2)} (width: ${width.toFixed(2)}mm)`);
        console.log(`  Y range: ${minY.toFixed(2)} to ${maxY.toFixed(2)} (height: ${height.toFixed(2)}mm)`);
        console.log(`  Center: (${((minX + maxX) / 2).toFixed(2)}, ${((minY + maxY) / 2).toFixed(2)})`);
        
        // For a 3cm torus, the outer ring should be much wider than ~6mm
        if (width < 10 && height < 10) {
            console.log(`\n❌ BUG CONFIRMED: Layer 10 only prints the hole (${width.toFixed(2)}mm wide), not the torus ring!`);
        } else {
            console.log(`\n✓ Layer appears to print the full torus ring`);
        }
    }
}
