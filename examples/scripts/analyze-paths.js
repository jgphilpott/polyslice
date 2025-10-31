/**
 * Analyze the actual path coordinates from the slice
 */

const { Polyslice, Printer, Filament } = require('../../src/index');
const THREE = require('three');
const helpers = require('../../src/slicer/geometry/helpers');

// Patch the slice method to intercept paths
const originalGenerateLayerGCode = require('../../src/slicer/slice').generateLayerGCode;

console.log('Creating torus mesh...');
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
  infillDensity: 0,
  bedTemperature: 0,
  layerHeight: 0.2,
  wipeNozzle: false,
  testStrip: false,
  metadata: false,
  verbose: false
});

console.log('Slicing to intercept paths...');

// Monkey patch to intercept layer generation
let layer0Paths = null;
const sliceModule = require('../../src/slicer/slice');
const originalGenerate = sliceModule.generateLayerGCode;

sliceModule.generateLayerGCode = function(slicer, paths, z, layerIndex, ...args) {
  if (layerIndex === 0) {
    layer0Paths = paths;
    console.log(`\nLayer 0 has ${paths.length} paths`);
    
    for (let i = 0; i < paths.length; i++) {
      const path = paths[i];
      console.log(`\nPath ${i}: ${path.length} points`);
      
      if (path.length > 0) {
        // Calculate bounding box
        let minX = Infinity, maxX = -Infinity;
        let minY = Infinity, maxY = -Infinity;
        
        for (const point of path) {
          minX = Math.min(minX, point.x);
          maxX = Math.max(maxX, point.x);
          minY = Math.min(minY, point.y);
          maxY = Math.max(maxY, point.y);
        }
        
        const centerX = (minX + maxX) / 2;
        const centerY = (minY + maxY) / 2;
        const width = maxX - minX;
        const height = maxY - minY;
        
        console.log(`  Center: (${centerX.toFixed(2)}, ${centerY.toFixed(2)})`);
        console.log(`  Size: ${width.toFixed(2)} x ${height.toFixed(2)}mm`);
        
        // Calculate average radius from center
        let sumRadius = 0;
        for (const point of path) {
          const dx = point.x - centerX;
          const dy = point.y - centerY;
          sumRadius += Math.sqrt(dx * dx + dy * dy);
        }
        const avgRadius = sumRadius / path.length;
        console.log(`  Avg radius: ${avgRadius.toFixed(2)}mm`);
      }
    }
    
    // Calculate distance between paths
    if (paths.length === 2) {
      const dist = helpers.calculateMinimumDistanceBetweenPaths(paths[0], paths[1]);
      console.log(`\nDistance between original paths: ${dist.toFixed(3)}mm`);
    }
  }
  
  return originalGenerate.call(this, slicer, paths, z, layerIndex, ...args);
};

const gcode = slicer.slice(mesh);

console.log('\nSlicing complete');
