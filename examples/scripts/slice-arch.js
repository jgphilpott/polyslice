/**
 * Example showing how to slice an arch shape with support structures
 * This demonstrates the support generation functionality of Polyslice
 */

const { Polyslice, Printer, Filament } = require('../../src/index');
const THREE = require('three');
const fs = require('fs');
const path = require('path');

console.log('Polyslice Arch Slicing Example with Supports');
console.log('===========================================\n');

// Create printer and filament configuration objects.
const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

console.log('Printer & Filament Configuration:');
console.log(`- Printer: ${printer.model}`);
console.log(`- Build Volume: ${printer.getSizeX()}x${printer.getSizeY()}x${printer.getSizeZ()}mm`);
console.log(`- Filament: ${filament.name} (${filament.type.toUpperCase()})`);
console.log(`- Brand: ${filament.brand}\n`);

// Create an arch shape using THREE.js geometry.
// This creates a simple bridge with overhangs that will need support.
function createArchGeometry() {
    // Create the main geometry group.
    const archGroup = new THREE.Group();

    // Left pillar (10mm x 10mm x 20mm).
    const leftPillarGeometry = new THREE.BoxGeometry(10, 10, 20);
    const leftPillar = new THREE.Mesh(leftPillarGeometry, new THREE.MeshBasicMaterial());
    leftPillar.position.set(-20, 0, 10); // Position at left side.
    archGroup.add(leftPillar);

    // Right pillar (10mm x 10mm x 20mm).
    const rightPillarGeometry = new THREE.BoxGeometry(10, 10, 20);
    const rightPillar = new THREE.Mesh(rightPillarGeometry, new THREE.MeshBasicMaterial());
    rightPillar.position.set(20, 0, 10); // Position at right side.
    archGroup.add(rightPillar);

    // Bridge with overhang - wider than the pillars to create overhangs.
    // The bridge is 50mm wide but pillars are only 30mm apart (center to center).
    // This creates 10mm overhangs on each side that need support.
    const bridgeGeometry = new THREE.BoxGeometry(50, 10, 8);
    const bridge = new THREE.Mesh(bridgeGeometry, new THREE.MeshBasicMaterial());
    bridge.position.set(0, 0, 24); // Position on top of pillars.
    archGroup.add(bridge);

    // Update world matrices before merging.
    archGroup.updateMatrixWorld(true);
    
    // Merge all geometries into a single mesh for slicing.
    const mergedGeometry = new THREE.BufferGeometry();
    const geometries = [];

    archGroup.children.forEach(child => {
        const clonedGeometry = child.geometry.clone();
        clonedGeometry.applyMatrix4(child.matrixWorld);
        geometries.push(clonedGeometry);
    });

    // Merge geometries.
    const positionArrays = [];
    let totalVertices = 0;

    geometries.forEach(geo => {
        const positions = geo.attributes.position.array;
        positionArrays.push(positions);
        totalVertices += positions.length;
    });

    const mergedPositions = new Float32Array(totalVertices);
    let offset = 0;

    positionArrays.forEach(positions => {
        mergedPositions.set(positions, offset);
        offset += positions.length;
    });

    mergedGeometry.setAttribute('position', new THREE.BufferAttribute(mergedPositions, 3));
    
    // Compute normals which are required by Polytree.
    mergedGeometry.computeVertexNormals();

    return mergedGeometry;
}

const archGeometry = createArchGeometry();
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const arch = new THREE.Mesh(archGeometry, material);

// Update matrix for proper transformation.
arch.updateMatrixWorld();

console.log('Created arch/bridge shape:');
console.log(`- Two pillars: 10mm x 10mm x 20mm each, 40mm apart`);
console.log(`- Bridge span: 50mm x 10mm x 8mm`);
console.log(`- Overhangs: 10mm on each side (needs support)`);
console.log(`- Total height: ~28mm`);
console.log(`- Position: centered on build plate`);
console.log(`- Vertices: ${archGeometry.attributes.position.count}\n`);

// Create slicer instance with support enabled.
const slicer = new Polyslice({
    printer: printer,
    filament: filament,
    shellSkinThickness: 0.8,
    shellWallThickness: 0.8,
    lengthUnit: 'millimeters',
    timeUnit: 'seconds',
    bedTemperature: 0,
    layerHeight: 0.2,
    testStrip: false,
    verbose: true,
    supportEnabled: true,
    supportType: 'normal',
    supportPlacement: 'buildPlate',
    supportThreshold: 45
});

console.log('Slicer Configuration:');
console.log(`- Layer Height: ${slicer.getLayerHeight()}mm`);
console.log(`- Nozzle Temperature: ${slicer.getNozzleTemperature()}°C`);
console.log(`- Bed Temperature: ${slicer.getBedTemperature()}°C`);
console.log(`- Fan Speed: ${slicer.getFanSpeed()}%`);
console.log(`- Nozzle Diameter: ${slicer.getNozzleDiameter()}mm`);
console.log(`- Filament Diameter: ${slicer.getFilamentDiameter()}mm`);
console.log(`- Support Enabled: ${slicer.getSupportEnabled() ? 'Yes' : 'No'}`);
console.log(`- Support Type: ${slicer.getSupportType()}`);
console.log(`- Support Placement: ${slicer.getSupportPlacement()}`);
console.log(`- Support Threshold: ${slicer.getSupportThreshold()}°`);
console.log(`- Verbose Comments: ${slicer.getVerbose() ? 'Enabled' : 'Disabled'}\n`);

// Slice the arch.
console.log('Slicing arch with support generation...');
const startTime = Date.now();
const gcode = slicer.slice(arch);
const endTime = Date.now();

console.log(`Slicing completed in ${endTime - startTime}ms\n`);

// Analyze the G-code output.
const lines = gcode.split('\n');
const layerLines = lines.filter(line => line.includes('LAYER:'));
const supportLines = lines.filter(line => line.toLowerCase().includes('support'));

console.log('G-code Analysis:');
console.log(`- Total lines: ${lines.length}`);
console.log(`- Layers: ${layerLines.length}`);
console.log(`- Support-related lines: ${supportLines.length}\n`);

// Save G-code to file.
const outputDir = path.join(__dirname, '..', 'output');

if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
}

const outputPath = path.join(outputDir, 'arch-with-supports.gcode');
fs.writeFileSync(outputPath, gcode);

console.log(`✅ G-code saved to: ${outputPath}\n`);

// Display support generation info.
if (supportLines.length > 0) {
    console.log('Support Generation Details:');
    supportLines.slice(0, 10).forEach(line => {
        console.log(`  ${line.trim()}`);
    });
    
    if (supportLines.length > 10) {
        console.log(`  ... (${supportLines.length - 10} more support lines)\n`);
    }
} else {
    console.log('⚠️  No support structures detected in G-code\n');
}

// Display some layer information.
console.log('Layer Information:');
const sampleLayers = layerLines.slice(0, 5);
sampleLayers.forEach(line => {
    console.log(`- ${line.trim()}`);
});

if (layerLines.length > 5) {
    console.log(`... (${layerLines.length - 5} more layers)\n`);
}

console.log('✅ Arch slicing example with supports completed successfully!');
console.log('\nNext steps:');
console.log('- Load the G-code in a visualizer to inspect support structures');
console.log('- Test print the arch to verify support quality');
console.log('- Try different support thresholds (30°, 45°, 60°) to see the effect');
console.log('- Experiment with different arch shapes and overhangs');
