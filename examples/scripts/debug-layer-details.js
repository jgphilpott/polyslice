const { Polyslice, Printer, Filament } = require('../../src/index');
const THREE = require('three');

// Create a torus mesh
const geometry = new THREE.TorusGeometry(5, 2, 16, 32);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const mesh = new THREE.Mesh(geometry, material);
mesh.position.set(0, 0, 2);
mesh.updateMatrixWorld();

const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

const slicer = new Polyslice({
  printer: printer,
  filament: filament,
  shellSkinThickness: 0.8,
  shellWallThickness: 0.8,
  lengthUnit: 'millimeters',
  timeUnit: 'seconds',
  infillPattern: 'grid',
  infillDensity: 10,
  bedTemperature: 0,
  layerHeight: 0.2,
  wipeNozzle: false,
  testStrip: false,
  metadata: false,
  verbose: true
});

console.log('Analyzing torus layer details...');
const gcode = slicer.slice(mesh);

// Parse and analyze each layer
for (let layer = 0; layer <= 3; layer++) {
  const layerStart = gcode.indexOf(`M117 LAYER: ${layer}`);
  const layerEnd = gcode.indexOf(`M117 LAYER: ${layer + 1}`);
  
  if (layerStart === -1) break;
  
  const layerCode = layerEnd === -1 ? gcode.substring(layerStart) : gcode.substring(layerStart, layerEnd);
  
  const outerCount = (layerCode.match(/TYPE: WALL-OUTER/g) || []).length;
  const innerCount = (layerCode.match(/TYPE: WALL-INNER/g) || []).length;
  const skinCount = (layerCode.match(/TYPE: SKIN/g) || []).length;
  const fillCount = (layerCode.match(/TYPE: FILL/g) || []).length;
  
  console.log(`\nLayer ${layer}:`);
  console.log(`  Outer: ${outerCount}, Inner: ${innerCount}, Skin: ${skinCount}, Fill: ${fillCount}`);
  
  if (layer === 1) {
    // On layer 1, if we have inner walls but some paths don't have skin,
    // we shouldn't have fill for those paths either
    if (innerCount > 0 && skinCount < outerCount / 2 && fillCount > 0) {
      console.log(`  ⚠️  Layer 1 has ${fillCount} FILL sections but only ${skinCount} SKIN sections`);
      console.log(`     This suggests infill is being generated for paths without skin`);
    }
  }
}
