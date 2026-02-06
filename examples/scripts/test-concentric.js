// Example script to test concentric infill pattern with various shapes

const Polyslice = require('../../src/index.js');
const THREE = require('three');
const fs = require('fs');
const path = require('path');

console.log('Testing concentric infill pattern...\n');

// Helper function to save G-code
function saveGCode(gcode, filename) {
    const outputPath = path.join(__dirname, '../output', filename);
    fs.mkdirSync(path.dirname(outputPath), { recursive: true });
    fs.writeFileSync(outputPath, gcode);
    console.log(`Saved: ${filename}`);
}

// Test 1: Cube with concentric pattern
console.log('1. Slicing cube with concentric infill...');
const slicer1 = new Polyslice({
    nozzleDiameter: 0.4,
    layerHeight: 0.2,
    infillDensity: 20,
    infillPattern: 'concentric',
    shellWallThickness: 0.8,
    shellSkinThickness: 0.4,
    verbose: true
});

const cubeGeometry = new THREE.BoxGeometry(20, 20, 10);
const cubeMesh = new THREE.Mesh(cubeGeometry, new THREE.MeshBasicMaterial());
cubeMesh.position.set(0, 0, 5);
cubeMesh.updateMatrixWorld();

const cubeGCode = slicer1.slice(cubeMesh);
saveGCode(cubeGCode, 'concentric-cube.gcode');

// Count infill lines
const cubeLines = cubeGCode.split('\n');
const cubeInfillCount = cubeLines.filter(line => line.includes('; TYPE: FILL')).length;
console.log(`   - Infill layers: ${cubeInfillCount}\n`);

// Test 2: Cylinder with concentric pattern (ideal for concentric)
console.log('2. Slicing cylinder with concentric infill...');
const slicer2 = new Polyslice({
    nozzleDiameter: 0.4,
    layerHeight: 0.2,
    infillDensity: 20,
    infillPattern: 'concentric',
    shellWallThickness: 0.8,
    shellSkinThickness: 0.4,
    verbose: true
});

const cylinderGeometry = new THREE.CylinderGeometry(10, 10, 10, 32);
const cylinderMesh = new THREE.Mesh(cylinderGeometry, new THREE.MeshBasicMaterial());
cylinderMesh.rotation.x = Math.PI / 2; // Orient along Z axis
cylinderMesh.position.set(0, 0, 5);
cylinderMesh.updateMatrixWorld();

const cylinderGCode = slicer2.slice(cylinderMesh);
saveGCode(cylinderGCode, 'concentric-cylinder.gcode');

const cylinderLines = cylinderGCode.split('\n');
const cylinderInfillCount = cylinderLines.filter(line => line.includes('; TYPE: FILL')).length;
console.log(`   - Infill layers: ${cylinderInfillCount}\n`);

// Test 3: Comparison with grid pattern
console.log('3. Comparing concentric vs grid pattern on cube...');
const slicer3 = new Polyslice({
    nozzleDiameter: 0.4,
    layerHeight: 0.2,
    infillDensity: 20,
    infillPattern: 'grid',
    shellWallThickness: 0.8,
    shellSkinThickness: 0.4,
    verbose: true
});

const gridGCode = slicer3.slice(cubeMesh);
saveGCode(gridGCode, 'grid-cube.gcode');

const gridLines = gridGCode.split('\n');
const gridInfillCount = gridLines.filter(line => line.includes('; TYPE: FILL')).length;

console.log(`   - Concentric infill layers: ${cubeInfillCount}`);
console.log(`   - Grid infill layers: ${gridInfillCount}\n`);

// Test 4: Different densities
console.log('4. Testing different densities...');
for (const density of [10, 20, 50]) {
    const slicer = new Polyslice({
        nozzleDiameter: 0.4,
        layerHeight: 0.2,
        infillDensity: density,
        infillPattern: 'concentric',
        shellWallThickness: 0.8,
        shellSkinThickness: 0.4,
        verbose: false
    });
    
    const gcode = slicer.slice(cubeMesh);
    const lines = gcode.split('\n');
    const extrusionLines = lines.filter(line => 
        line.includes('G1') && 
        line.includes('E') && 
        !line.includes('; TYPE:')
    ).length;
    
    console.log(`   - ${density}% density: ${extrusionLines} extrusion moves`);
}

console.log('\nAll tests completed successfully!');
console.log('G-code files saved to: examples/output/');
