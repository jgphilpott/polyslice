/**
 * Test with taller pillars to verify middle layer handling
 */
const { Polyslice, Printer, Filament } = require('./src/index');
const THREE = require('three');

console.log('Testing Middle Layer Exposure Detection\n');

const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

/**
 * Create 2x2 tall pillar array (10mm height = 50 layers)
 */
function createTallPillarArray(pillarRadius = 3, pillarHeight = 10, gridSize = 2) {
    const group = new THREE.Group();
    const spacing = (pillarRadius * 2 + 4);
    const totalWidth = spacing * (gridSize - 1);
    const offsetX = -totalWidth / 2;
    const offsetY = -totalWidth / 2;

    for (let row = 0; row < gridSize; row++) {
        for (let col = 0; col < gridSize; col++) {
            const x = offsetX + col * spacing;
            const y = offsetY + row * spacing;
            const pillarGeometry = new THREE.CylinderGeometry(pillarRadius, pillarRadius, pillarHeight, 32);
            const pillarMesh = new THREE.Mesh(pillarGeometry, new THREE.MeshBasicMaterial());
            pillarMesh.rotation.x = Math.PI / 2;
            pillarMesh.position.set(x, y, pillarHeight / 2);
            pillarMesh.updateMatrixWorld();
            group.add(pillarMesh);
        }
    }
    return group;
}

async function toMergedMesh(object) {
    object.updateMatrixWorld(true);
    const geometries = [];
    object.traverse((child) => {
        if (!child || !child.isMesh || !child.geometry) return;
        child.updateMatrixWorld(true);
        const geometryClone = child.geometry.clone();
        geometryClone.applyMatrix4(child.matrixWorld);
        geometries.push(geometryClone);
    });

    const mod = await import('three/examples/jsm/utils/BufferGeometryUtils.js');
    const mergeGeometries = mod.mergeGeometries || mod.BufferGeometryUtils?.mergeGeometries;
    const mergedGeometry = mergeGeometries(geometries, false);
    const mergedMesh = new THREE.Mesh(mergedGeometry, new THREE.MeshBasicMaterial());
    mergedMesh.updateMatrixWorld(true);
    return mergedMesh;
}

function countPillarChanges(gcode) {
    const lines = gcode.split('\n');
    let totalChanges = 0;
    let lastPillarCenter = null;

    for (const line of lines) {
        if (line.match(/^G[01]\s/) && line.includes('X') && line.includes('Y')) {
            const xMatch = line.match(/X([-\d.]+)/);
            const yMatch = line.match(/Y([-\d.]+)/);
            if (xMatch && yMatch) {
                const x = parseFloat(xMatch[1]);
                const y = parseFloat(yMatch[1]);
                if (lastPillarCenter) {
                    const dist = Math.sqrt(Math.pow(x - lastPillarCenter.x, 2) + Math.pow(y - lastPillarCenter.y, 2));
                    if (dist > 5) {
                        totalChanges++;
                        lastPillarCenter = { x, y };
                    }
                } else {
                    lastPillarCenter = { x, y };
                }
            }
        }
    }

    return totalChanges;
}

(async () => {
    const group = createTallPillarArray(3, 10, 2);
    const mergedMesh = await toMergedMesh(group);

    console.log('Creating 2x2 array of 10mm tall pillars (50 layers)\n');

    console.log('Test 1: Exposure Detection DISABLED');
    console.log('====================================');
    
    const slicer1 = new Polyslice({
        printer: printer,
        filament: filament,
        shellSkinThickness: 0.4,
        shellWallThickness: 0.8,
        lengthUnit: 'millimeters',
        timeUnit: 'seconds',
        infillPattern: 'grid',
        infillDensity: 50,
        bedTemperature: 0,
        layerHeight: 0.2,
        testStrip: false,
        metadata: false,
        verbose: false,
        exposureDetection: false
    });

    const startTime1 = Date.now();
    const gcode1 = slicer1.slice(mergedMesh);
    const endTime1 = Date.now();
    const changes1 = countPillarChanges(gcode1);

    console.log(`Slicing time: ${endTime1 - startTime1}ms`);
    console.log(`Total pillar changes: ${changes1}`);
    console.log(`Avg pillar changes per layer: ${(changes1 / 50).toFixed(1)}\n`);

    console.log('Test 2: Exposure Detection ENABLED');
    console.log('===================================');
    
    const slicer2 = new Polyslice({
        printer: printer,
        filament: filament,
        shellSkinThickness: 0.4,
        shellWallThickness: 0.8,
        lengthUnit: 'millimeters',
        timeUnit: 'seconds',
        infillPattern: 'grid',
        infillDensity: 50,
        bedTemperature: 0,
        layerHeight: 0.2,
        testStrip: false,
        metadata: false,
        verbose: false,
        exposureDetection: true
    });

    const startTime2 = Date.now();
    const gcode2 = slicer2.slice(mergedMesh);
    const endTime2 = Date.now();
    const changes2 = countPillarChanges(gcode2);

    console.log(`Slicing time: ${endTime2 - startTime2}ms`);
    console.log(`Total pillar changes: ${changes2}`);
    console.log(`Avg pillar changes per layer: ${(changes2 / 50).toFixed(1)}\n`);

    console.log('Improvement:');
    console.log('============');
    console.log(`Pillar changes reduced by: ${changes1 - changes2} (${Math.round((1 - changes2/changes1) * 100)}%)`);
    console.log(`\nNote: Top/bottom 2 layers use optimized path (sequential completion)`);
    console.log(`Middle 46 layers use two-phase approach (for complex geometries with exposure)`);

})();
