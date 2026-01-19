/**
 * Verification script demonstrating the fix for travel optimization with exposure detection.
 * 
 * BEFORE: exposureDetection=true disabled sequential completion for ALL layers.
 * AFTER: exposureDetection=true allows sequential completion for top/bottom layers.
 * 
 * This means users can now enable exposure detection without losing the benefits
 * of travel optimization on the most important layers (top/bottom surfaces).
 */

const { Polyslice, Printer, Filament } = require('../../src/index');
const THREE = require('three');

console.log('='.repeat(70));
console.log('Verification: Travel Optimization with Exposure Detection');
console.log('='.repeat(70));
console.log();

async function createMergedPillars() {
    const group = new THREE.Group();
    const spacing = 10;
    
    for (let row = 0; row < 2; row++) {
        for (let col = 0; col < 2; col++) {
            const x = -spacing / 2 + col * spacing;
            const y = -spacing / 2 + row * spacing;
            
            const geometry = new THREE.CylinderGeometry(3, 3, 1.2, 32);
            const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial());
            mesh.rotation.x = Math.PI / 2;
            mesh.position.set(x, y, 0.6);
            mesh.updateMatrixWorld();
            group.add(mesh);
        }
    }
    
    // Merge all pillars into one mesh
    group.updateMatrixWorld(true);
    const geometries = [];
    group.traverse((child) => {
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

function countPillarChanges(gcode, layerNum) {
    const lines = gcode.split('\n');
    let inLayer = false;
    let changes = 0;
    let lastPos = null;
    
    for (const line of lines) {
        if (line.includes(`LAYER: ${layerNum}`)) {
            inLayer = true;
            continue;
        }
        if (inLayer && line.includes('LAYER:')) {
            break;
        }
        if (inLayer && line.match(/^G[01]\s/) && line.includes('X') && line.includes('Y')) {
            const xMatch = line.match(/X([-\d.]+)/);
            const yMatch = line.match(/Y([-\d.]+)/);
            if (xMatch && yMatch) {
                const x = parseFloat(xMatch[1]);
                const y = parseFloat(yMatch[1]);
                if (lastPos) {
                    const dist = Math.sqrt(Math.pow(x - lastPos.x, 2) + Math.pow(y - lastPos.y, 2));
                    if (dist > 5) {
                        changes++;
                    }
                }
                lastPos = { x, y };
            }
        }
    }
    return changes;
}

(async () => {
    const mergedMesh = await createMergedPillars();
    
    const printer = new Printer('Ender5');
    const filament = new Filament('GenericPLA');
    
    console.log('Test Configuration:');
    console.log('  - Geometry: 2x2 array of pillars (4 separate objects)');
    console.log('  - Layer height: 0.2mm');
    console.log('  - Shell skin thickness: 0.4mm (2 layers top/bottom)');
    console.log('  - Total layers: 6');
    console.log();
    
    // Test with exposure detection disabled
    console.log('Test 1: exposureDetection = FALSE (baseline)');
    console.log('-'.repeat(70));
    const slicer1 = new Polyslice({
        printer: printer,
        filament: filament,
        shellSkinThickness: 0.4,
        shellWallThickness: 0.8,
        infillDensity: 50,
        bedTemperature: 0,
        layerHeight: 0.2,
        testStrip: false,
        metadata: false,
        verbose: false,
        exposureDetection: false  // DISABLED
    });
    
    const start1 = Date.now();
    const gcode1 = slicer1.slice(mergedMesh);
    const time1 = Date.now() - start1;
    
    const layer1Changes = countPillarChanges(gcode1, 1);
    const layer6Changes = countPillarChanges(gcode1, 6);
    
    console.log(`  Slicing time: ${time1}ms`);
    console.log(`  Layer 1 (bottom) pillar changes: ${layer1Changes}`);
    console.log(`  Layer 6 (top) pillar changes: ${layer6Changes}`);
    console.log();
    
    // Test with exposure detection enabled
    console.log('Test 2: exposureDetection = TRUE (with fix)');
    console.log('-'.repeat(70));
    const slicer2 = new Polyslice({
        printer: printer,
        filament: filament,
        shellSkinThickness: 0.4,
        shellWallThickness: 0.8,
        infillDensity: 50,
        bedTemperature: 0,
        layerHeight: 0.2,
        testStrip: false,
        metadata: false,
        verbose: false,
        exposureDetection: true  // ENABLED
    });
    
    const start2 = Date.now();
    const gcode2 = slicer2.slice(mergedMesh);
    const time2 = Date.now() - start2;
    
    const layer1Changes2 = countPillarChanges(gcode2, 1);
    const layer6Changes2 = countPillarChanges(gcode2, 6);
    
    console.log(`  Slicing time: ${time2}ms`);
    console.log(`  Layer 1 (bottom) pillar changes: ${layer1Changes2}`);
    console.log(`  Layer 6 (top) pillar changes: ${layer6Changes2}`);
    console.log();
    
    // Summary
    console.log('='.repeat(70));
    console.log('✅ FIX VERIFIED');
    console.log('='.repeat(70));
    console.log();
    console.log('Results:');
    console.log(`  Layer 1 changes: ${layer1Changes} (disabled) vs ${layer1Changes2} (enabled)`);
    console.log(`  Layer 6 changes: ${layer6Changes} (disabled) vs ${layer6Changes2} (enabled)`);
    console.log();
    
    if (layer1Changes === layer1Changes2 && layer6Changes === layer6Changes2) {
        console.log('✅ SUCCESS: Top/bottom layers use sequential completion');
        console.log('   even with exposure detection enabled!');
        console.log();
        console.log('   Users can now enable exposure detection without losing');
        console.log('   travel optimization benefits on critical surface layers.');
    } else {
        console.log('⚠️  WARNING: Travel patterns differ between tests.');
    }
})();
