const fs = require('fs');

const gcode = fs.readFileSync('/home/runner/work/polyslice/polyslice/resources/gcode/infill/grid/torus/50%.gcode', 'utf8');
const lines = gcode.split('\n');

function analyzeLayer(layerNum) {
    let start = -1;
    let end = -1;
    
    for (let i = 0; i < lines.length; i++) {
        if (lines[i].includes(`LAYER: ${layerNum}`)) {
            start = i;
        }
        if (start >= 0 && lines[i].includes(`LAYER: ${layerNum + 1}`)) {
            end = i;
            break;
        }
    }
    
    if (start < 0) return;
    if (end < 0) end = lines.length;
    
    const layerContent = lines.slice(start, end).join('\n');
    
    // Extract X, Y coordinates from G1 commands
    const xCoords = [];
    const yCoords = [];
    const g1Regex = /G1 X([\d.]+) Y([\d.]+)/g;
    let match;
    while ((match = g1Regex.exec(layerContent)) !== null) {
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
        const centerX = (minX + maxX) / 2;
        const centerY = (minY + maxY) / 2;
        
        // Check Z height
        const zMatch = layerContent.match(/Z([\d.]+)/);
        const z = zMatch ? parseFloat(zMatch[1]) : 'N/A';
        
        console.log(`Layer ${layerNum} (Z=${z}):`);
        console.log(`  X: ${minX.toFixed(2)} to ${maxX.toFixed(2)} (width: ${width.toFixed(2)}mm)`);
        console.log(`  Y: ${minY.toFixed(2)} to ${maxY.toFixed(2)} (height: ${height.toFixed(2)}mm)`);
        console.log(`  Center: (${centerX.toFixed(2)}, ${centerY.toFixed(2)})`);
        console.log(`  Diameter: ${width.toFixed(2)}mm`);
        
        // Check for multiple disconnected regions
        const hasWallOuter = layerContent.includes('WALL-OUTER');
        const wallOuterCount = (layerContent.match(/; TYPE: WALL-OUTER/g) || []).length;
        console.log(`  Wall outer count: ${wallOuterCount}`);
        
        if (width < 10) {
            console.log(`  ❌ BUG: Only printing small circle (hole), not full torus!`);
        } else {
            console.log(`  ✓ Appears to be full torus ring`);
        }
        console.log();
    }
}

analyzeLayer(9);
analyzeLayer(10);
analyzeLayer(11);
