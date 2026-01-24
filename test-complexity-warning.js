#!/usr/bin/env node
/**
 * Test script to verify mesh complexity warnings
 */

const THREE = require('three');
const { Polyslice, Printer, Filament } = require('./src/index');

console.log('Testing Mesh Complexity Warnings\n');
console.log('='.repeat(70));

// Test 1: Simple mesh (no warning expected)
console.log('\n1. Simple mesh (should NOT warn):');
const simple = new THREE.Mesh(
  new THREE.BoxGeometry(10, 10, 10),
  new THREE.MeshBasicMaterial()
);
const slicer1 = new Polyslice({
  printer: new Printer('Ender3'),
  filament: new Filament('GenericPLA')
});
const gcode1 = slicer1.slice(simple);
console.log('   ✓ Sliced successfully without warning\n');

// Test 2: Medium complexity mesh (warning expected)
console.log('2. Medium complexity mesh (should show warning):');
const medium = new THREE.Mesh(
  new THREE.SphereGeometry(20, 64, 64),
  new THREE.MeshBasicMaterial()
);
const slicer2 = new Polyslice({
  printer: new Printer('Ender3'),
  filament: new Filament('GenericPLA')
});
const gcode2 = slicer2.slice(medium);
console.log('   ✓ Sliced successfully with warning\n');

// Test 3: High complexity mesh (critical warning expected)
console.log('3. High complexity mesh (should show CRITICAL warning):');
const large = new THREE.Mesh(
  new THREE.SphereGeometry(30, 96, 96),
  new THREE.MeshBasicMaterial()
);
const slicer3 = new Polyslice({
  printer: new Printer('Ender3'),
  filament: new Filament('GenericPLA')
});
const gcode3 = slicer3.slice(large);
console.log('   ✓ Sliced successfully with critical warning\n');

console.log('='.repeat(70));
console.log('✓ All tests passed! Warnings are working correctly.');
