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

console.log('TEST 1: Exposure Detection DISABLED');
console.log('====================================');
const slicer1 = new Polyslice();
slicer1.setLayerHeight(0.2);
slicer1.setShellSkinThickness(0.4);
slicer1.setExposureDetection(false);  // DISABLED
slicer1.setVerbose(true);

const result1 = slicer1.slice(group);
const lines1 = result1.split('\n');
const lastLayerPattern1 = [];
let inLastLayer1 = false;
for (const line of lines1) {
    if (line.includes('LAYER: 6 of')) inLastLayer1 = true;
    if (inLastLayer1 && line.includes('TYPE:')) {
        const type = line.match(/TYPE: (\S+)/)?.[1];
        lastLayerPattern1.push(type);
    }
}
console.log('Last layer pattern:', lastLayerPattern1.join(' → '));

console.log('\nTEST 2: Exposure Detection ENABLED');
console.log('===================================');
const slicer2 = new Polyslice();
slicer2.setLayerHeight(0.2);
slicer2.setShellSkinThickness(0.4);
slicer2.setExposureDetection(true);  // ENABLED
slicer2.setVerbose(true);

const result2 = slicer2.slice(group);
const lines2 = result2.split('\n');
const lastLayerPattern2 = [];
let inLastLayer2 = false;
for (const line of lines2) {
    if (line.includes('LAYER: 6 of')) inLastLayer2 = true;
    if (inLastLayer2 && line.includes('TYPE:')) {
        const type = line.match(/TYPE: (\S+)/)?.[1];
        lastLayerPattern2.push(type);
    }
}
console.log('Last layer pattern:', lastLayerPattern2.join(' → '));

console.log('\nExpected with sequential completion (both pillars completed before moving):');
console.log('  WALL-OUTER → WALL-INNER → SKIN → WALL-OUTER → WALL-INNER → SKIN');
console.log('\nActual results show they should match when the fix is working correctly.');
