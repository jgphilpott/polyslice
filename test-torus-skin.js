/**
 * Test script to reproduce the missing skin wall issue in torus slicing
 */

const { Polyslice, Printer, Filament } = require('./src/index');
const THREE = require('three');
const fs = require('fs');

console.log('Testing Torus Skin Wall Generation\n');

// Create printer and filament configuration
const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

// Create a torus mesh
function createTorus(radius = 5, tube = 2) {
  const geometry = new THREE.TorusGeometry(radius, tube, 16, 32);
  const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
  const mesh = new THREE.Mesh(geometry, material);
  
  // Position torus so the bottom is at Z=0
  mesh.position.set(0, 0, tube);
  mesh.updateMatrixWorld();
  
  return mesh;
}

// Slice the torus
const slicer = new Polyslice({
  printer: printer,
  filament: filament,
  shellSkinThickness: 0.4,
  shellWallThickness: 0.8,  // 2 walls
  lengthUnit: 'millimeters',
  timeUnit: 'seconds',
  infillPatternCentering: 'global',
  infillPattern: 'grid',
  infillDensity: 20,
  bedTemperature: 60,  // Match original
  layerHeight: 0.2,
  testStrip: true,   // Match original
  metadata: false,   // Match original
  verbose: true
});

const mesh = createTorus(5, 2);
const gcode = slicer.slice(mesh);

// Save to file
fs.writeFileSync('/tmp/test-torus.gcode', gcode);

// Analyze specific layers
const lines = gcode.split('\n');

console.log('Analyzing layers 3, 4, 5, 6, 15, 16...\n');

function analyzeLayers(lines, layerNums) {
  for (const layerNum of layerNums) {
    const z = (layerNum * 0.2 + 0.1).toFixed(1); // Layer height 0.2, starting at 0.1
    console.log(`\n=== Layer ${layerNum} (Z${z}) ===`);
    
    let inLayer = false;
    let typeAnnotations = [];
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      
      // Check if we're in the target layer
      if (line.includes(`Z${z} `)) {
        inLayer = true;
      } else if (inLayer && line.match(/Z\d+\.\d+ /)) {
        // Moved to next layer
        break;
      }
      
      // Collect TYPE annotations in this layer
      if (inLayer && line.startsWith('; TYPE:')) {
        typeAnnotations.push(line);
      }
    }
    
    console.log(`Type annotations found: ${typeAnnotations.length}`);
    typeAnnotations.forEach((annotation, idx) => {
      console.log(`  ${idx + 1}. ${annotation}`);
    });
    
    // Count skin annotations
    const skinCount = typeAnnotations.filter(a => a.includes('SKIN')).length;
    const wallCount = typeAnnotations.filter(a => a.includes('WALL')).length;
    
    console.log(`Summary: ${wallCount} WALL annotations, ${skinCount} SKIN annotations`);
    
    if (skinCount === 1) {
      console.log('  ⚠️  WARNING: Only 1 SKIN annotation found (expected 2)');
    } else if (skinCount === 2) {
      console.log('  ✅ Correct: 2 SKIN annotations found');
    }
  }
}

analyzeLayers(lines, [3, 4, 5, 6, 15, 16]);

console.log('\n\nTest complete. G-code saved to /tmp/test-torus.gcode');
