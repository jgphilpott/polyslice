const { Polyslice } = require('./src/index');
const THREE = require('three');

async function mergeGeometries(geometries) {
    const mod = await import('three/examples/jsm/utils/BufferGeometryUtils.js');
    const mergeFunc = mod.mergeGeometries || mod.BufferGeometryUtils?.mergeGeometries;
    return mergeFunc(geometries, false);
}

async function createMergedPillars() {
    // Create two separate cylinders
    const geometry1 = new THREE.CylinderGeometry(3, 3, 1.2, 32);
    const mesh1 = new THREE.Mesh(geometry1, new THREE.MeshBasicMaterial());
    mesh1.rotation.x = Math.PI / 2;
    mesh1.position.set(-5, 0, 0.6);
    mesh1.updateMatrixWorld();
    const geo1 = mesh1.geometry.clone();
    geo1.applyMatrix4(mesh1.matrixWorld);

    const geometry2 = new THREE.CylinderGeometry(3, 3, 1.2, 32);
    const mesh2 = new THREE.Mesh(geometry2, new THREE.MeshBasicMaterial());
    mesh2.rotation.x = Math.PI / 2;
    mesh2.position.set(5, 0, 0.6);
    mesh2.updateMatrixWorld();
    const geo2 = mesh2.geometry.clone();
    geo2.applyMatrix4(mesh2.matrixWorld);

    // Merge them
    const mergedGeometry = await mergeGeometries([geo1, geo2]);
    const mergedMesh = new THREE.Mesh(mergedGeometry, new THREE.MeshBasicMaterial());
    mergedMesh.updateMatrixWorld();
    return mergedMesh;
}

(async () => {
    const mergedMesh = await createMergedPillars();

    console.log('TEST with MERGED pillars (like the pillars example)');
    console.log('====================================================\n');

    console.log('TEST 1: Exposure Detection DISABLED');
    const slicer1 = new Polyslice();
    slicer1.setLayerHeight(0.2);
    slicer1.setShellSkinThickness(0.4);
    slicer1.setExposureDetection(false);
    slicer1.setVerbose(true);

    const result1 = slicer1.slice(mergedMesh);
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

    const result2 = slicer2.slice(mergedMesh);
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

    console.log('\nExpected with sequential completion:');
    console.log('  WALL-OUTER → WALL-INNER → SKIN → WALL-OUTER → WALL-INNER → SKIN');
    console.log('  (complete each pillar before moving to next)');
})();
