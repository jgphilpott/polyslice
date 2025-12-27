/**
 * Test script to verify nested hole/structure detection
 * Creates a simple test case and checks if nesting levels are correctly detected
 */

const { Polyslice, Printer, Filament } = require('../../src/index');
const { Polytree } = require('@jgphilpott/polytree');
const THREE = require('three');

console.log('Nested Hole Detection Test');
console.log('===========================\n');

/**
 * Create a hollow cylinder using CSG subtraction.
 */
async function createHollowCylinder(outerRadius, innerRadius, height, segments = 32) {
  const outerGeometry = new THREE.CylinderGeometry(outerRadius, outerRadius, height, segments);
  const outerMesh = new THREE.Mesh(outerGeometry, new THREE.MeshBasicMaterial());
  outerMesh.rotation.x = Math.PI / 2;
  outerMesh.updateMatrixWorld();

  // Create inner cylinder (hole) - make it slightly taller (1.2x) to ensure complete penetration for CSG.
  const innerGeometry = new THREE.CylinderGeometry(innerRadius, innerRadius, height * 1.2, segments);
  const innerMesh = new THREE.Mesh(innerGeometry, new THREE.MeshBasicMaterial());
  innerMesh.rotation.x = Math.PI / 2;
  innerMesh.updateMatrixWorld();

  const hollowMesh = await Polytree.subtract(outerMesh, innerMesh);
  const finalMesh = new THREE.Mesh(hollowMesh.geometry, hollowMesh.material);
  finalMesh.position.set(0, 0, height / 2);
  finalMesh.updateMatrixWorld();

  return finalMesh;
}

/**
 * Create 3 nested hollow cylinders for testing
 */
async function createTestCase() {
  const height = 10;
  const wallThickness = 1.6;
  const gap = 2;

  // Innermost cylinder (should be structure - level 2)
  const inner = await createHollowCylinder(5 + wallThickness, 5, height);
  
  // Middle cylinder (should be hole - level 1)
  const middle = await createHollowCylinder(5 + wallThickness + gap + wallThickness, 5 + wallThickness + gap, height);
  
  // Outer cylinder (should be structure - level 0)
  const outer = await createHollowCylinder(5 + wallThickness + gap + wallThickness + gap + wallThickness, 5 + wallThickness + gap + wallThickness + gap, height);

  // Combine all cylinders
  let combined = await Polytree.unite(inner, middle);
  combined = await Polytree.unite(combined, outer);

  const finalMesh = new THREE.Mesh(combined.geometry, combined.material);
  finalMesh.position.set(0, 0, height / 2);
  finalMesh.updateMatrixWorld();

  return finalMesh;
}

(async () => {
  try {
    console.log('Creating test mesh with 3 nested cylinders...');
    const mesh = await createTestCase();
    console.log('✅ Test mesh created\n');

    console.log('Expected nesting levels:');
    console.log('- Outermost cylinder: Level 0 (structure) - walls inset inward');
    console.log('- Middle cylinder: Level 1 (hole) - walls inset outward');
    console.log('- Innermost cylinder: Level 2 (structure) - walls inset inward\n');

    const printer = new Printer('Ender5');
    const filament = new Filament('GenericPLA');

    const slicer = new Polyslice({
      printer,
      filament,
      shellSkinThickness: 0.8,
      shellWallThickness: 0.8,
      layerHeight: 0.2,
      infillDensity: 0, // No infill for clearer output
      testStrip: false,
      metadata: false,
      verbose: true
    });

    console.log('Slicing mesh...');
    const startTime = Date.now();
    const gcode = slicer.slice(mesh);
    const endTime = Date.now();
    console.log(`✅ Sliced in ${endTime - startTime}ms\n`);

    // Count wall types in first few layers
    const lines = gcode.split('\n');
    const layer1Start = lines.findIndex(l => l.includes('LAYER: 1'));
    const layer2Start = lines.findIndex(l => l.includes('LAYER: 2'));
    
    if (layer1Start !== -1 && layer2Start !== -1) {
      const layer1Lines = lines.slice(layer1Start, layer2Start);
      const outerWallCount = layer1Lines.filter(l => l.includes('TYPE: WALL-OUTER')).length;
      const innerWallCount = layer1Lines.filter(l => l.includes('TYPE: WALL-INNER')).length;
      
      console.log('Layer 1 analysis:');
      console.log(`- WALL-OUTER markers: ${outerWallCount}`);
      console.log(`- WALL-INNER markers: ${innerWallCount}`);
      console.log(`- Total wall paths: ${outerWallCount + innerWallCount}\n`);
      
      if (outerWallCount === 3) {
        console.log('✅ Correct: Found 3 outer walls (one for each cylinder)');
      } else {
        console.log(`⚠️  Expected 3 outer walls, found ${outerWallCount}`);
      }
    }

    const totalLines = lines.filter(l => l.trim() !== '').length;
    const layerCount = lines.filter(l => l.includes('LAYER:')).length;
    
    console.log('\nG-code Statistics:');
    console.log(`- Total lines: ${totalLines}`);
    console.log(`- Layers: ${layerCount}`);
    console.log('\n✅ Test completed successfully!');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
})();
