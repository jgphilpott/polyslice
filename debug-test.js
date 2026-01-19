const { Polyslice } = require('./src/index');
const THREE = require('three');

// Create helper to build a simple cylinder (pillar).
function createCylinder(x, y, radius, height, segments = 32) {
    const geometry = new THREE.CylinderGeometry(radius, radius, height, segments);
    const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial());
    mesh.rotation.x = Math.PI / 2;
    mesh.position.set(x, y, height / 2);
    mesh.updateMatrixWorld();
    return mesh;
}

// Create two separate pillars (independent objects, no holes).
const pillar1 = createCylinder(-5, 0, 3, 1.2, 32);
const pillar2 = createCylinder(5, 0, 3, 1.2, 32);

const group = new THREE.Group();
group.add(pillar1);
group.add(pillar2);

// Configure slicer with exposure detection enabled.
const slicer = new Polyslice();
slicer.setLayerHeight(0.2);
slicer.setShellSkinThickness(0.4);  // 2 layers top/bottom
slicer.setExposureDetection(true);  // Exposure detection enabled!
slicer.setVerbose(true);

const result = slicer.slice(group);

// Find first layer
const lines = result.split('\n');
let firstLayerStart = -1;
let secondLayerStart = -1;

for (let i = 0; i < lines.length; i++) {
    if (lines[i].includes('LAYER: 1 of')) {
        firstLayerStart = i;
    } else if (lines[i].includes('LAYER: 2 of')) {
        secondLayerStart = i;
        break;
    }
}

console.log('First layer starts at line', firstLayerStart);
console.log('Second layer starts at line', secondLayerStart);

// Extract first layer content
const firstLayerLines = lines.slice(firstLayerStart, secondLayerStart);
console.log('\nFirst layer TYPE annotations:');
firstLayerLines.forEach((line, idx) => {
    if (line.includes('TYPE:')) {
        console.log(`  ${idx}: ${line.trim()}`);
    }
});
