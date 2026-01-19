const { Polyslice } = require('./src/index');
const THREE = require('three');

// Create two separate cubes (not merged)
const geometry1 = new THREE.BoxGeometry(5, 5, 1.2);
const mesh1 = new THREE.Mesh(geometry1, new THREE.MeshBasicMaterial());
mesh1.position.set(-5, 0, 0.6);
mesh1.updateMatrixWorld();

const geometry2 = new THREE.BoxGeometry(5, 5, 1.2);
const mesh2 = new THREE.Mesh(geometry2, new THREE.MeshBasicMaterial());
mesh2.position.set(5, 0, 0.6);
mesh2.updateMatrixWorld();

const scene = new THREE.Scene();
scene.add(mesh1);
scene.add(mesh2);

console.log('TEST with separate cubes (unmerged)');
console.log('====================================\n');

console.log('TEST 1: Exposure Detection DISABLED');
const slicer1 = new Polyslice();
slicer1.setLayerHeight(0.2);
slicer1.setShellSkinThickness(0.4);
slicer1.setExposureDetection(false);
slicer1.setVerbose(true);

const result1 = slicer1.slice(scene);
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
const slicer2 = new Polyslice();
slicer2.setLayerHeight(0.2);
slicer2.setShellSkinThickness(0.4);
slicer2.setExposureDetection(true);
slicer2.setVerbose(true);

const result2 = slicer2.slice(scene);
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

console.log('\nNote: Scene can only pass first mesh to slicer.');
console.log('The preprocessing extracts only the first mesh from a scene.');
