const helpers = require('./src/slicer/geometry/helpers.js');

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

const radius = 0.3;
const path = createSmallCircularPath(radius, 8);
const insetPath = helpers.createInsetPath(path, 0.4);

console.log('Radius:', radius);
console.log('Inset distance:', 0.4);
console.log('Original path points:', path.length);
console.log('Inset path points:', insetPath.length);

// Calculate bounds
let origMinX = Infinity, origMaxX = -Infinity;
let origMinY = Infinity, origMaxY = -Infinity;
for (const pt of path) {
    origMinX = Math.min(origMinX, pt.x);
    origMaxX = Math.max(origMaxX, pt.x);
    origMinY = Math.min(origMinY, pt.y);
    origMaxY = Math.max(origMaxY, pt.y);
}
console.log(`Original bounds: ${(origMaxX - origMinX).toFixed(3)} x ${(origMaxY - origMinY).toFixed(3)}`);

if (insetPath.length > 0) {
    let insetMinX = Infinity, insetMaxX = -Infinity;
    let insetMinY = Infinity, insetMaxY = -Infinity;
    for (const pt of insetPath) {
        insetMinX = Math.min(insetMinX, pt.x);
        insetMaxX = Math.max(insetMaxX, pt.x);
        insetMinY = Math.min(insetMinY, pt.y);
        insetMaxY = Math.max(insetMaxY, pt.y);
    }
    console.log(`Inset bounds: ${(insetMaxX - insetMinX).toFixed(3)} x ${(insetMaxY - insetMinY).toFixed(3)}`);
    
    const origWidth = origMaxX - origMinX;
    const origHeight = origMaxY - origMinY;
    const insetWidth = insetMaxX - insetMinX;
    const insetHeight = insetMaxY - insetMinY;
    
    const widthReduction = origWidth - insetWidth;
    const heightReduction = origHeight - insetHeight;
    const expectedReduction = 0.4 * 2 * 0.2;
    
    console.log(`Width reduction: ${widthReduction.toFixed(3)}, expected: ${expectedReduction.toFixed(3)}`);
    console.log(`Height reduction: ${heightReduction.toFixed(3)}, expected: ${expectedReduction.toFixed(3)}`);
    
    if (widthReduction < expectedReduction || heightReduction < expectedReduction) {
        console.log('⚠️  Should have been rejected but wasn\'t!');
    }
}
