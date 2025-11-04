/**
 * Validation script for skin wall generation behavior.
 * This script verifies that:
 * 1. Skin walls for holes are generated immediately after regular walls (PR #54 behavior)
 * 2. Spacing validation still works to prevent overlapping walls (PR #55 behavior)
 */

const { Polyslice, Printer, Filament } = require('../../src/index');
const THREE = require('three');
const { Polytree } = require('@jgphilpott/polytree');

console.log('Skin Wall Generation Validation');
console.log('================================\n');

// Test 1: Verify single-pass generation for holes on skin layers
async function testSinglePassGeneration() {
  console.log('Test 1: Single-pass generation for holes on skin layers');
  console.log('-'.repeat(60));

  const sheetGeometry = new THREE.BoxGeometry(50, 50, 5);
  const sheetMesh = new THREE.Mesh(sheetGeometry, new THREE.MeshBasicMaterial());

  const holeRadius = 3;
  const holeGeometry = new THREE.CylinderGeometry(holeRadius, holeRadius, 10, 32);
  const holeMesh = new THREE.Mesh(holeGeometry, new THREE.MeshBasicMaterial());
  holeMesh.rotation.x = Math.PI / 2;
  holeMesh.position.set(0, 0, 0);
  holeMesh.updateMatrixWorld();

  const resultMesh = await Polytree.subtract(sheetMesh, holeMesh);
  const finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material);
  finalMesh.position.set(0, 0, 2.5);
  finalMesh.updateMatrixWorld();

  const printer = new Printer('Ender5');
  const filament = new Filament('GenericPLA');

  const slicer = new Polyslice({
    printer: printer,
    filament: filament,
    shellSkinThickness: 0.8,
    shellWallThickness: 0.8,
    layerHeight: 0.2,
    testStrip: false,
    metadata: false,
    verbose: true
  });

  const gcode = slicer.slice(finalMesh);

  // Check layer 0 (skin layer)
  const parts = gcode.split('LAYER: 0');
  if (parts.length < 2) {
    console.log('  ❌ FAILED: Could not find LAYER: 0');
    return false;
  }

  const layer0 = parts[1].split('LAYER: 1')[0];
  const typeMatches = layer0.match(/TYPE: (WALL-OUTER|WALL-INNER|SKIN)/g) || [];
  const types = typeMatches.map(m => m.replace('TYPE: ', ''));

  console.log('  Layer 0 wall sequence:');
  types.forEach((type, idx) => {
    console.log(`    ${idx + 1}. ${type}`);
  });

  // Expected pattern: outer walls (2), hole walls (2), hole skin (1), outer skin (1)
  // Total: 6 wall types
  if (types.length !== 6) {
    console.log(`  ❌ FAILED: Expected 6 wall types, got ${types.length}`);
    return false;
  }

  // Check that the 5th element (index 4) is SKIN (hole skin immediately after hole walls)
  if (types[4] !== 'SKIN') {
    console.log('  ❌ FAILED: Hole skin wall not generated immediately after hole walls');
    console.log(`     Expected SKIN at position 5, got ${types[4]}`);
    return false;
  }

  // Check that we have exactly 2 SKIN entries
  const skinCount = types.filter(t => t === 'SKIN').length;
  if (skinCount !== 2) {
    console.log(`  ❌ FAILED: Expected 2 SKIN entries, got ${skinCount}`);
    return false;
  }

  console.log('  ✅ PASSED: Skin walls generated in single pass\n');
  return true;
}

// Test 2: Verify spacing validation still works (torus test)
async function testSpacingValidation() {
  console.log('Test 2: Spacing validation for tight geometries');
  console.log('-'.repeat(60));

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
    layerHeight: 0.2,
    testStrip: false,
    metadata: false,
    verbose: true
  });

  const gcode = slicer.slice(mesh);

  // Check layer 0 (where spacing is tight)
  const parts = gcode.split('LAYER: 0');
  if (parts.length < 2) {
    console.log('  ❌ FAILED: Could not find LAYER: 0');
    return false;
  }

  const layer0 = parts[1].split('LAYER: 1')[0];
  const outerCount = (layer0.match(/TYPE: WALL-OUTER/g) || []).length;
  const innerCount = (layer0.match(/TYPE: WALL-INNER/g) || []).length;
  const skinCount = (layer0.match(/TYPE: SKIN/g) || []).length;

  console.log(`  Layer 0 counts: ${outerCount} outer, ${innerCount} inner, ${skinCount} skin`);

  // Inner and skin walls should be suppressed on layer 0 due to tight spacing
  if (innerCount !== 0 || skinCount !== 0) {
    console.log('  ❌ FAILED: Inner/skin walls not properly suppressed');
    return false;
  }

  // But outer walls should be present
  if (outerCount === 0) {
    console.log('  ❌ FAILED: No outer walls generated');
    return false;
  }

  console.log('  ✅ PASSED: Spacing validation working correctly\n');
  return true;
}

// Test 3: Verify non-skin layers don't generate skin walls
async function testNonSkinLayers() {
  console.log('Test 3: Non-skin layers should not generate skin walls');
  console.log('-'.repeat(60));

  const sheetGeometry = new THREE.BoxGeometry(50, 50, 5);
  const sheetMesh = new THREE.Mesh(sheetGeometry, new THREE.MeshBasicMaterial());

  const holeRadius = 3;
  const holeGeometry = new THREE.CylinderGeometry(holeRadius, holeRadius, 10, 32);
  const holeMesh = new THREE.Mesh(holeGeometry, new THREE.MeshBasicMaterial());
  holeMesh.rotation.x = Math.PI / 2;
  holeMesh.position.set(0, 0, 0);
  holeMesh.updateMatrixWorld();

  const resultMesh = await Polytree.subtract(sheetMesh, holeMesh);
  const finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material);
  finalMesh.position.set(0, 0, 2.5);
  finalMesh.updateMatrixWorld();

  const printer = new Printer('Ender5');
  const filament = new Filament('GenericPLA');

  const slicer = new Polyslice({
    printer: printer,
    filament: filament,
    shellSkinThickness: 0.8,
    shellWallThickness: 0.8,
    layerHeight: 0.2,
    testStrip: false,
    metadata: false,
    verbose: true
  });

  const gcode = slicer.slice(finalMesh);

  // Check layer 10 (middle layer, not a skin layer)
  const parts = gcode.split('LAYER: 10');
  if (parts.length < 2) {
    console.log('  ❌ FAILED: Could not find LAYER: 10');
    return false;
  }

  const layer10 = parts[1].split('LAYER: 11')[0];
  const skinCount = (layer10.match(/TYPE: SKIN/g) || []).length;

  console.log(`  Layer 10 SKIN count: ${skinCount}`);

  // No skin walls should be generated on middle layers
  if (skinCount !== 0) {
    console.log('  ❌ FAILED: Skin walls generated on non-skin layer');
    return false;
  }

  console.log('  ✅ PASSED: No skin walls on non-skin layers\n');
  return true;
}

// Run all tests
(async () => {
  const results = [];
  
  try {
    results.push(await testSinglePassGeneration());
  } catch (error) {
    console.log('  ❌ FAILED: ' + error.message);
    results.push(false);
  }

  try {
    results.push(await testSpacingValidation());
  } catch (error) {
    console.log('  ❌ FAILED: ' + error.message);
    results.push(false);
  }

  try {
    results.push(await testNonSkinLayers());
  } catch (error) {
    console.log('  ❌ FAILED: ' + error.message);
    results.push(false);
  }

  console.log('='.repeat(60));
  console.log('Validation Summary');
  console.log('='.repeat(60));
  
  const passed = results.filter(r => r === true).length;
  const total = results.length;
  
  console.log(`Tests passed: ${passed}/${total}`);
  
  if (passed === total) {
    console.log('\n✅ ALL TESTS PASSED!');
    console.log('   - Single-pass generation working correctly (PR #54)');
    console.log('   - Spacing validation working correctly (PR #55)');
    process.exit(0);
  } else {
    console.log('\n❌ SOME TESTS FAILED');
    process.exit(1);
  }
})();
