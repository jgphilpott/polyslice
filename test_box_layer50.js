const THREE = require('three');
const helpers = require('./src/slicer/geometry/helpers.js');

// Create a box 10x10 and inset it 3 times with 0.4mm nozzle diameter
// This simulates what happens at layer 50

// Approximate square path (10x10 box)
const path = [
    { x: -5, y: -5, z: 10 },
    { x: 5, y: -5, z: 10 },
    { x: 5, y: 5, z: 10 },
    { x: -5, y: 5, z: 10 }
];

console.log('Testing box inset path (simulating layer 50):');
console.log('Original path: 10x10 square');
console.log('Nozzle diameter: 0.4mm');
console.log('');

let currentPath = path;
for (let i = 0; i < 4; i++) {
    const insetPath = helpers.createInsetPath(currentPath, 0.4);
    console.log(`Inset ${i}: ${insetPath.length} points`);
    
    if (insetPath.length === 0) {
        console.log('  Path became degenerate (too small)');
        break;
    }
    
    // Calculate bounds
    let minX = Infinity, maxX = -Infinity;
    let minY = Infinity, maxY = -Infinity;
    for (const point of insetPath) {
        minX = Math.min(minX, point.x);
        maxX = Math.max(maxX, point.x);
        minY = Math.min(minY, point.y);
        maxY = Math.max(maxY, point.y);
    }
    
    const width = maxX - minX;
    const height = maxY - minY;
    console.log(`  Bounds: ${width.toFixed(2)} x ${height.toFixed(2)}`);
    
    currentPath = insetPath;
}
