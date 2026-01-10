#!/usr/bin/env node

/**
 * Smart Wipe Nozzle Example
 * 
 * This example demonstrates the smart wipe nozzle feature, which intelligently
 * moves the nozzle away from the print surface at the end of a print to prevent
 * marks or filament threads on the finished part.
 */

const THREE = require('three');
const { Polyslice, Printer, Filament } = require('../../src/index');

// Create printer and filament objects
const printer = new Printer('Ender3');
const filament = new Filament('GenericPLA');

console.log('=== Smart Wipe Nozzle Example ===\n');

// Example 1: Smart wipe enabled (default)
console.log('1. Smart Wipe Enabled (Default)');
console.log('   - Analyzes mesh boundaries');
console.log('   - Finds shortest path away from print');
console.log('   - Includes retraction during wipe\n');

const slicer1 = new Polyslice({
    printer: printer,
    filament: filament,
    layerHeight: 0.2,
    wipeNozzle: true,        // Enable wipe
    smartWipeNozzle: true,   // Use smart wipe (default)
    verbose: false,
    metadata: false,
    testStrip: false,
    buzzer: false
});

// Create a simple cube
const geometry1 = new THREE.BoxGeometry(10, 10, 10);
const material1 = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const cube1 = new THREE.Mesh(geometry1, material1);

const gcode1 = slicer1.slice(cube1);

// Extract post-print section
const postPrintStart1 = gcode1.indexOf('G91');
const postPrintSection1 = gcode1.substring(postPrintStart1, postPrintStart1 + 200);
const lines1 = postPrintSection1.split('\n').slice(0, 4);

console.log('Generated G-code (post-print):');
lines1.forEach(line => console.log('  ' + line));
console.log('  ...\n');

// Example 2: Simple wipe (smart wipe disabled)
console.log('2. Simple Wipe (smartWipeNozzle = false)');
console.log('   - Always moves X+5, Y+5');
console.log('   - Fixed distance regardless of mesh');
console.log('   - No retraction during wipe\n');

const slicer2 = new Polyslice({
    printer: printer,
    filament: filament,
    layerHeight: 0.2,
    wipeNozzle: true,
    smartWipeNozzle: false,  // Disable smart wipe
    verbose: false,
    metadata: false,
    testStrip: false,
    buzzer: false
});

const geometry2 = new THREE.BoxGeometry(10, 10, 10);
const material2 = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const cube2 = new THREE.Mesh(geometry2, material2);

const gcode2 = slicer2.slice(cube2);

const postPrintStart2 = gcode2.indexOf('G91');
const postPrintSection2 = gcode2.substring(postPrintStart2, postPrintStart2 + 200);
const lines2 = postPrintSection2.split('\n').slice(0, 4);

console.log('Generated G-code (post-print):');
lines2.forEach(line => console.log('  ' + line));
console.log('  ...\n');

// Example 3: Wipe disabled
console.log('3. Wipe Disabled (wipeNozzle = false)');
console.log('   - No wipe move');
console.log('   - Direct retract and Z raise\n');

const slicer3 = new Polyslice({
    printer: printer,
    filament: filament,
    layerHeight: 0.2,
    wipeNozzle: false,       // Disable wipe entirely
    smartWipeNozzle: true,
    verbose: false,
    metadata: false,
    testStrip: false,
    buzzer: false
});

const geometry3 = new THREE.BoxGeometry(10, 10, 10);
const material3 = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const cube3 = new THREE.Mesh(geometry3, material3);

const gcode3 = slicer3.slice(cube3);

const postPrintStart3 = gcode3.indexOf('G91');
const postPrintSection3 = gcode3.substring(postPrintStart3, postPrintStart3 + 200);
const lines3 = postPrintSection3.split('\n').slice(0, 4);

console.log('Generated G-code (post-print):');
lines3.forEach(line => console.log('  ' + line));
console.log('  ...\n');

// Summary
console.log('=== Summary ===');
console.log('Smart wipe provides several benefits:');
console.log('  ✓ Avoids wiping on flat top surfaces');
console.log('  ✓ Retracts during wipe to prevent oozing');
console.log('  ✓ Adapts to different mesh geometries');
console.log('  ✓ Moves beyond mesh boundary before raising Z');
console.log('  ✓ Safe fallback to simple wipe if needed\n');

console.log('Configuration:');
console.log('  wipeNozzle: true/false    - Enable/disable wipe feature');
console.log('  smartWipeNozzle: true/false - Use smart vs simple wipe\n');
