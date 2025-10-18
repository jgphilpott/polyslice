const THREE = require('three');
const Polyslice = require('./src/polyslice.js');

// Create a cone geometry
const geometry = new THREE.ConeGeometry(20, 40, 32);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const cone = new THREE.Mesh(geometry, material);

// Create a slicer instance
const slicer = new Polyslice({
    layerHeight: 0.2,
    nozzleDiameter: 0.4,
    shellWallThickness: 0.8, // 2 walls
    verbose: true
});

// Slice the cone
const gcode = slicer.slice(cone);

// Look at the top layers to check for the issue
const lines = gcode.split('\n');
let currentLayer = 0;
let layerIssues = [];

for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    if (line.includes('LAYER:')) {
        currentLayer = parseInt(line.match(/LAYER: (\d+)/)[1]);
    }
    
    // Check for walls near the top
    if (currentLayer >= 195 && line.includes('TYPE: WALL')) {
        // Look ahead for coordinates
        let hasOuter = line.includes('WALL-OUTER');
        let hasInner = line.includes('WALL-INNER');
        
        if (hasOuter || hasInner) {
            // Extract coordinates from next few lines
            let coords = [];
            for (let j = i + 1; j < Math.min(i + 20, lines.length); j++) {
                const nextLine = lines[j];
                if (nextLine.includes('TYPE:')) break;
                
                const xMatch = nextLine.match(/X([\d.]+)/);
                const yMatch = nextLine.match(/Y([\d.]+)/);
                if (xMatch && yMatch) {
                    coords.push({ x: parseFloat(xMatch[1]), y: parseFloat(yMatch[1]) });
                }
            }
            
            if (coords.length > 2) {
                // Calculate bounding box
                let minX = Math.min(...coords.map(c => c.x));
                let maxX = Math.max(...coords.map(c => c.x));
                let minY = Math.min(...coords.map(c => c.y));
                let maxY = Math.max(...coords.map(c => c.y));
                
                const width = maxX - minX;
                const height = maxY - minY;
                
                const wallType = hasOuter ? 'OUTER' : 'INNER';
                console.log(`Layer ${currentLayer} ${wallType}: ${width.toFixed(2)} x ${height.toFixed(2)} mm`);
            }
        }
    }
}
