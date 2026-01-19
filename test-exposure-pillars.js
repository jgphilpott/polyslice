/**
 * Test script to demonstrate the issue with exposure detection and travel optimization
 */
const { Polyslice, Printer, Filament } = require('./src/index');
const THREE = require('three');

console.log('Testing Exposure Detection Impact on Travel Optimization\n');

// Create printer and filament
const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

/**
 * Create 2x2 pillar array for testing
 */
function createPillarArray(pillarRadius = 3, pillarHeight = 1.2, gridSize = 2) {
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

/**
 * Merge all meshes in a group into a single mesh
 */
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

/**
 * Analyze G-code pattern to understand travel behavior
 */
function analyzeGCode(gcode) {
    const lines = gcode.split('\n');
    const layers = [];
    let currentLayer = null;
    let pillarChanges = 0;
    let lastPillarCenter = null;

    for (const line of lines) {
        if (line.includes('LAYER:')) {
            if (currentLayer) {
                currentLayer.pillarChanges = pillarChanges;
                layers.push(currentLayer);
            }
            currentLayer = { 
                name: line.match(/LAYER: \d+/)?.[0] || 'Unknown',
                types: [],
                pillarChanges: 0
            };
            pillarChanges = 0;
            lastPillarCenter = null;
        } else if (line.includes('TYPE:')) {
            const type = line.match(/TYPE: (\w+)/)?.[1];
            if (type && !currentLayer.types.includes(type)) {
                currentLayer.types.push(type);
            }
        } else if (line.match(/^G[01]\s/) && line.includes('X') && line.includes('Y')) {
            // Parse X Y coordinates
            const xMatch = line.match(/X([-\d.]+)/);
            const yMatch = line.match(/Y([-\d.]+)/);
            if (xMatch && yMatch) {
                const x = parseFloat(xMatch[1]);
                const y = parseFloat(yMatch[1]);
                // Detect pillar changes (when we move more than 5mm from last pillar center)
                if (lastPillarCenter) {
                    const dist = Math.sqrt(Math.pow(x - lastPillarCenter.x, 2) + Math.pow(y - lastPillarCenter.y, 2));
                    if (dist > 5) {
                        pillarChanges++;
                        lastPillarCenter = { x, y };
                    }
                } else {
                    lastPillarCenter = { x, y };
                }
            }
        }
    }

    if (currentLayer) {
        currentLayer.pillarChanges = pillarChanges;
        layers.push(currentLayer);
    }

    return layers;
}

(async () => {
    const group = createPillarArray(3, 1.2, 2);
    const mergedMesh = await toMergedMesh(group);

    console.log('Test 1: Exposure Detection DISABLED (current working behavior)');
    console.log('================================================================\n');
    
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
        verbose: true,
        exposureDetection: false  // DISABLED
    });

    const startTime1 = Date.now();
    const gcode1 = slicer1.slice(mergedMesh);
    const endTime1 = Date.now();
    const analysis1 = analyzeGCode(gcode1);

    console.log(`Slicing time: ${endTime1 - startTime1}ms`);
    console.log(`Total G-code lines: ${gcode1.split('\n').length}`);
    console.log('\nLayer-by-layer analysis:');
    analysis1.forEach(layer => {
        console.log(`  ${layer.name}: ${layer.types.join(' → ')} (pillar changes: ${layer.pillarChanges})`);
    });

    console.log('\n\nTest 2: Exposure Detection ENABLED (problematic behavior)');
    console.log('==========================================================\n');
    
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
        verbose: true,
        exposureDetection: true  // ENABLED
    });

    const startTime2 = Date.now();
    const gcode2 = slicer2.slice(mergedMesh);
    const endTime2 = Date.now();
    const analysis2 = analyzeGCode(gcode2);

    console.log(`Slicing time: ${endTime2 - startTime2}ms`);
    console.log(`Total G-code lines: ${gcode2.split('\n').length}`);
    console.log('\nLayer-by-layer analysis:');
    analysis2.forEach(layer => {
        console.log(`  ${layer.name}: ${layer.types.join(' → ')} (pillar changes: ${layer.pillarChanges})`);
    });

    console.log('\n\nComparison:');
    console.log('===========');
    console.log(`Time difference: ${endTime2 - startTime2 - (endTime1 - startTime1)}ms (${Math.round((endTime2 - startTime2) / (endTime1 - startTime1) * 100)}%)`);
    console.log(`Size difference: ${gcode2.length - gcode1.length} bytes (${Math.round(gcode2.length / gcode1.length * 100)}%)`);
    
    console.log('\nExpected with travel optimization:');
    console.log('  Each pillar should be COMPLETED (walls + skin/infill) before moving to next');
    console.log('  Pattern: WALL-OUTER → WALL-INNER → SKIN → FILL (repeat for each pillar)');
    
    console.log('\nActual with exposure detection enabled:');
    console.log('  All walls generated first, then all skin/infill');
    console.log('  Pattern: All WALL-OUTER → All WALL-INNER → All SKIN → All FILL');
    console.log('  This causes excessive travel between pillars!');

})();
