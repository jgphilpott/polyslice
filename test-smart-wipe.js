#!/usr/bin/env node

// Test smart wipe nozzle feature with a simple cube mesh

const Polyslice = require('./src/polyslice.js');

// Check if THREE is available
let THREE;
try {
    THREE = require('three');
} catch (e) {
    console.error('three.js is required for this example');
    process.exit(1);
}

// Create a simple cube mesh
function createCube(size = 10) {
    const geometry = new THREE.BoxGeometry(size, size, size);
    const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
    const cube = new THREE.Mesh(geometry, material);
    return cube;
}

// Test 1: Simple wipe (disabled smart wipe)
console.log('=== Test 1: Simple Wipe (smartWipeNozzle = false) ===');
const slicer1 = new Polyslice({
    layerHeight: 0.2,
    nozzleTemperature: 200,
    bedTemperature: 60,
    wipeNozzle: true,
    smartWipeNozzle: false,
    verbose: true,
    metadata: false,
    testStrip: false,
    buzzer: false
});

const cube1 = createCube(10);
const gcode1 = slicer1.slice(cube1);

// Check for simple wipe
if (gcode1.includes('G0 X5 Y5') || gcode1.includes('G0 X5 Y5 F3000')) {
    console.log('✓ Simple wipe found (X+5, Y+5)');
} else {
    console.log('✗ Simple wipe NOT found');
}

// Test 2: Smart wipe (enabled)
console.log('\n=== Test 2: Smart Wipe (smartWipeNozzle = true) ===');
const slicer2 = new Polyslice({
    layerHeight: 0.2,
    nozzleTemperature: 200,
    bedTemperature: 60,
    wipeNozzle: true,
    smartWipeNozzle: true,
    verbose: true,
    metadata: false,
    testStrip: false,
    buzzer: false
});

const cube2 = createCube(10);
const gcode2 = slicer2.slice(cube2);

// Check that simple wipe is NOT present
if (!gcode2.includes('G0 X5 Y5')) {
    console.log('✓ Simple wipe NOT present (as expected)');
} else {
    console.log('✗ Simple wipe found (unexpected)');
}

// Check for smart wipe with retraction
const lines = gcode2.split('\n');
let foundSmartWipe = false;
let smartWipeLine = '';

for (const line of lines) {
    if (line.includes('Smart Wipe Nozzle') || (line.includes('G1') && line.includes('E-') && (line.includes('X') || line.includes('Y')))) {
        foundSmartWipe = true;
        smartWipeLine = line;
        break;
    }
}

if (foundSmartWipe) {
    console.log('✓ Smart wipe with retraction found');
    console.log('  Line: ' + smartWipeLine);
} else {
    console.log('✗ Smart wipe with retraction NOT found');
}

// Check mesh bounds were stored
if (slicer2.meshBounds && slicer2.centerOffsetX !== undefined && slicer2.centerOffsetY !== undefined) {
    console.log('✓ Mesh bounds and center offsets stored');
    console.log('  Mesh bounds:', JSON.stringify(slicer2.meshBounds));
    console.log('  Center offset X:', slicer2.centerOffsetX);
    console.log('  Center offset Y:', slicer2.centerOffsetY);
} else {
    console.log('✗ Mesh bounds or center offsets NOT stored');
}

// Check last layer end point
if (slicer2.lastLayerEndPoint) {
    console.log('✓ Last layer end point tracked');
    console.log('  Position:', JSON.stringify(slicer2.lastLayerEndPoint));
} else {
    console.log('✗ Last layer end point NOT tracked');
}

// Test 3: No wipe
console.log('\n=== Test 3: No Wipe (wipeNozzle = false) ===');
const slicer3 = new Polyslice({
    layerHeight: 0.2,
    nozzleTemperature: 200,
    bedTemperature: 60,
    wipeNozzle: false,
    smartWipeNozzle: true,
    verbose: true,
    metadata: false,
    testStrip: false,
    buzzer: false
});

const cube3 = createCube(10);
const gcode3 = slicer3.slice(cube3);

// Check that no wipe is present
if (!gcode3.includes('Wipe Nozzle') && !gcode3.includes('Smart Wipe')) {
    console.log('✓ No wipe present (as expected)');
} else {
    console.log('✗ Wipe found (unexpected)');
}

console.log('\n=== All Tests Complete ===');
