const { Polyslice, Printer, Filament } = require('../../dist/index.js');
const THREE = require('three');

const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');
const geometry = new THREE.BoxGeometry(10, 10, 10);
const cube = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial());
cube.position.set(0, 0, 5);
cube.updateMatrixWorld();

const slicer = new Polyslice({
  printer: printer,
  filament: filament,
  shellSkinThickness: 0.8,
  shellWallThickness: 0.8,
  infillPattern: 'triangles',
  infillDensity: 30,
  bedTemperature: 0,
  layerHeight: 0.2,
  testStrip: false,
  verbose: true
});

console.log('Slicing cube with 30% triangles infill...');
const gcode = slicer.slice(cube);

// Count total infill moves
const lines = gcode.split('\n');
let inFill = false;
let totalFillMoves = 0;
let layerCounts = {};
let currentLayer = null;

for (const line of lines) {
  if (line.includes('LAYER:')) {
    const match = line.match(/LAYER: (\d+)/);
    if (match) currentLayer = parseInt(match[1]);
  }
  
  if (line.includes('; TYPE: FILL')) {
    inFill = true;
    if (currentLayer && !layerCounts[currentLayer]) {
      layerCounts[currentLayer] = 0;
    }
  }
  
  if (line.includes('; TYPE:') && !line.includes('FILL')) {
    inFill = false;
  }
  
  if (inFill && line.includes('G1') && line.includes('E')) {
    totalFillMoves++;
    if (currentLayer) layerCounts[currentLayer]++;
  }
}

console.log(`\nTotal infill moves: ${totalFillMoves}`);
console.log(`Layers with infill: ${Object.keys(layerCounts).length}`);

// Show sample layer counts
const sampleLayers = [5, 10, 15, 20, 25];
console.log('\nInfill moves per layer (sample):');
for (const layer of sampleLayers) {
  if (layerCounts[layer]) {
    console.log(`  Layer ${layer}: ${layerCounts[layer]} moves`);
  }
}

console.log('\n✓ Slicing completed successfully with triangles pattern at 30%!');
