const helpers = require('./src/slicer/geometry/helpers.js');

// Simulate a very small circular path near the cone tip
// This represents what we'd get from slicing near the top
function createSmallCircularPath(radius, segments = 8) {
    const path = [];
    for (let i = 0; i < segments; i++) {
        const angle = (i / segments) * Math.PI * 2;
        path.push({
            x: Math.cos(angle) * radius,
            y: Math.sin(angle) * radius,
            z: 0
        });
    }
    return path;
}

// Test with progressively smaller radii
const radii = [5, 2, 1, 0.5, 0.3, 0.2];
const nozzleDiameter = 0.4;

console.log('Testing inset path creation with small radii:');
console.log('Nozzle diameter:', nozzleDiameter);
console.log('');

for (const radius of radii) {
    const originalPath = createSmallCircularPath(radius, 8);
    const insetPath = helpers.createInsetPath(originalPath, nozzleDiameter);
    
    // Calculate the "radius" of the inset path by measuring distance from origin
    let maxInsetRadius = 0;
    let minInsetRadius = Infinity;
    
    for (const point of insetPath) {
        const r = Math.sqrt(point.x * point.x + point.y * point.y);
        maxInsetRadius = Math.max(maxInsetRadius, r);
        minInsetRadius = Math.min(minInsetRadius, r);
    }
    
    const avgInsetRadius = (maxInsetRadius + minInsetRadius) / 2;
    const expectedRadius = radius - nozzleDiameter;
    
    console.log(`Original radius: ${radius.toFixed(2)}, Expected inset: ${expectedRadius.toFixed(2)}, Actual inset: ${avgInsetRadius.toFixed(2)}, Points: ${insetPath.length}`);
    
    // Check if inset is larger than original (this is the bug!)
    if (avgInsetRadius > radius) {
        console.log('  ⚠️  ERROR: Inset path is LARGER than original path!');
    } else if (expectedRadius <= 0 && insetPath.length > 0) {
        console.log('  ⚠️  WARNING: Expected degenerate path (radius would be negative) but got', insetPath.length, 'points');
    } else if (expectedRadius > 0 && insetPath.length < 3) {
        console.log('  ✓ OK: Path correctly became degenerate when too small');
    } else if (Math.abs(avgInsetRadius - expectedRadius) > 0.2) {
        console.log('  ⚠️  WARNING: Inset radius differs significantly from expected');
    } else {
        console.log('  ✓ OK');
    }
}
