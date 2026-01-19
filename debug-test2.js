const { Polyslice } = require('./src/index');
const THREE = require('three');

function createCylinder(x, y, radius, height, segments = 32) {
    const geometry = new THREE.CylinderGeometry(radius, radius, height, segments);
    const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial());
    mesh.rotation.x = Math.PI / 2;
    mesh.position.set(x, y, height / 2);
    mesh.updateMatrixWorld();
    return mesh;
}

const pillar1 = createCylinder(-5, 0, 3, 1.2, 32);
const pillar2 = createCylinder(5, 0, 3, 1.2, 32);

const group = new THREE.Group();
group.add(pillar1);
group.add(pillar2);

const slicer = new Polyslice();
slicer.setLayerHeight(0.2);
slicer.setShellSkinThickness(0.4);  // 2 layers top/bottom
slicer.setExposureDetection(true);
slicer.setVerbose(true);

const result = slicer.slice(group);

// Find all layers
const lines = result.split('\n');
const layerStarts = [];
for (let i = 0; i < lines.length; i++) {
    if (lines[i].includes('LAYER:')) {
        layerStarts.push(i);
    }
}

console.log(`Total layers: ${layerStarts.length}`);

// Check last layer (top layer)
const lastLayerIdx = layerStarts.length - 1;
const lastLayerStart = layerStarts[lastLayerIdx];
const lastLayerEnd = lines.length;

console.log(`\nLast layer (Layer ${lastLayerIdx + 1}) starts at line ${lastLayerStart}`);

const lastLayerLines = lines.slice(lastLayerStart, lastLayerEnd);
console.log('\nLast layer TYPE annotations:');
lastLayerLines.forEach((line, idx) => {
    if (line.includes('TYPE:')) {
        console.log(`  ${idx}: ${line.trim()}`);
    }
});

// Analyze pattern
let pattern = [];
for (const line of lastLayerLines) {
    if (line.includes('TYPE:')) {
        const type = line.match(/TYPE: (\S+)/)?.[1];
        pattern.push(type);
    }
}
console.log('\nPattern:', pattern.join(' → '));
