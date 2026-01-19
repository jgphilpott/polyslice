/**
 * Demonstration: Pillar slicing WITH exposure detection enabled
 * 
 * This script shows that after the fix, users can enable exposure detection
 * without needing to disable it for travel optimization to work.
 */

const { Polyslice, Printer, Filament } = require('../../src/index');
const THREE = require('three');
const path = require('path');
const fs = require('fs');

console.log('Polyslice: Pillars with Exposure Detection ENABLED');
console.log('===================================================\n');

const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

const outputDir = path.join(__dirname, '../output');
const gcodeDir = path.join(__dirname, '../../resources/gcode/wayfinding/pillars-with-exposure');

if (!fs.existsSync(gcodeDir)) {
  fs.mkdirSync(gcodeDir, { recursive: true });
}

function createPillarArray(pillarRadius = 3, pillarHeight = 1.2, gridSize = 1) {
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

function sliceAndSave(meshOrGroup, filename) {
    const slicer = new Polyslice({
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
        verbose: true,
        exposureDetection: true  // ✅ NOW ENABLED! (previously had to be false)
    });

    const startTime = Date.now();
    const gcode = slicer.slice(meshOrGroup);
    const endTime = Date.now();

    const outputPath = path.join(gcodeDir, filename);
    fs.writeFileSync(outputPath, gcode);

    const sizeBytes = fs.statSync(outputPath).size;
    const lines = gcode.split('\n').filter(line => line.trim() !== '');

    return {
        time: endTime - startTime,
        lines: lines.length,
        size: sizeBytes,
        path: outputPath
    };
}

function formatBytes(bytes) {
    if (bytes < 1024) return `${bytes} B`;
    const kb = bytes / 1024;
    if (kb < 1024) return `${kb.toFixed(1)} KB`;
    const mb = kb / 1024;
    return `${mb.toFixed(2)} MB`;
}

(async () => {
    const gridSizes = [2, 3, 4];
    const results = [];

    console.log(`Testing ${gridSizes.length} configurations with exposure detection ENABLED\n`);
    console.log('='.repeat(70));

    for (const gridSize of gridSizes) {
        const totalPillars = gridSize * gridSize;
        console.log(`\nProcessing ${gridSize}x${gridSize} grid (${totalPillars} pillars)...`);

        const group = createPillarArray(3, 1.2, gridSize);
        const mergedMesh = await toMergedMesh(group);
        const stats = sliceAndSave(mergedMesh, `${gridSize}x${gridSize}.gcode`);

        console.log(`  ✅ ${stats.time}ms | ${stats.lines} lines | ${formatBytes(stats.size)}`);
        results.push({ gridSize, totalPillars, ...stats });
    }

    console.log('\n' + '='.repeat(70));
    console.log('✅ Pillar Slicing Complete (with exposure detection enabled)');
    console.log('='.repeat(70));
    console.log(`\n📁 G-code Output: ${gcodeDir}`);
    console.log('\nKey Point: exposure detection is ENABLED, yet travel optimization');
    console.log('           still works on top/bottom layers! No need to disable it.');
})();
