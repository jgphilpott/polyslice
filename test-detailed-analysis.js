/**
 * Detailed analysis of G-code patterns
 */
const { Polyslice, Printer, Filament } = require('./src/index');
const THREE = require('three');

const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

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

function analyzeLayerPattern(gcode, layerNum) {
    const lines = gcode.split('\n');
    let inLayer = false;
    let layerLines = [];
    
    for (const line of lines) {
        if (line.includes(`LAYER: ${layerNum}`)) {
            inLayer = true;
            continue;
        }
        if (inLayer && line.includes('LAYER:')) {
            break;
        }
        if (inLayer) {
            layerLines.push(line);
        }
    }

    // Analyze pattern
    const pattern = [];
    let currentType = null;
    let currentPillar = 0;
    let lastPos = null;

    for (const line of layerLines) {
        if (line.includes('TYPE:')) {
            const type = line.match(/TYPE: (\S+)/)?.[1];
            if (type !== currentType) {
                pattern.push(type);
                currentType = type;
            }
        } else if (line.match(/^G[01]\s/) && line.includes('X') && line.includes('Y')) {
            const xMatch = line.match(/X([-\d.]+)/);
            const yMatch = line.match(/Y([-\d.]+)/);
            if (xMatch && yMatch) {
                const x = parseFloat(xMatch[1]);
                const y = parseFloat(yMatch[1]);
                if (lastPos) {
                    const dist = Math.sqrt(Math.pow(x - lastPos.x, 2) + Math.pow(y - lastPos.y, 2));
                    if (dist > 5) {
                        currentPillar++;
                    }
                }
                lastPos = { x, y };
            }
        }
    }

    return { pattern: pattern.join(' → '), pillars: currentPillar };
}

(async () => {
    const group = createPillarArray(3, 1.2, 2);
    const mergedMesh = await toMergedMesh(group);

    console.log('Detailed Layer-by-Layer Analysis\n');

    const slicer1 = new Polyslice({
        printer: printer,
        filament: filament,
        shellSkinThickness: 0.4,
        shellWallThickness: 0.8,
        infillPattern: 'grid',
        infillDensity: 50,
        bedTemperature: 0,
        layerHeight: 0.2,
        testStrip: false,
        metadata: false,
        verbose: true,
        exposureDetection: false
    });

    const gcode1 = slicer1.slice(mergedMesh);

    const slicer2 = new Polyslice({
        printer: printer,
        filament: filament,
        shellSkinThickness: 0.4,
        shellWallThickness: 0.8,
        infillPattern: 'grid',
        infillDensity: 50,
        bedTemperature: 0,
        layerHeight: 0.2,
        testStrip: false,
        metadata: false,
        verbose: true,
        exposureDetection: true
    });

    const gcode2 = slicer2.slice(mergedMesh);

    console.log('Exposure Detection: OFF');
    console.log('=======================');
    for (let i = 1; i <= 6; i++) {
        const analysis = analyzeLayerPattern(gcode1, i);
        console.log(`Layer ${i}: ${analysis.pattern} (${analysis.pillars} pillar changes)`);
    }

    console.log('\nExposure Detection: ON');
    console.log('======================');
    for (let i = 1; i <= 6; i++) {
        const analysis = analyzeLayerPattern(gcode2, i);
        console.log(`Layer ${i}: ${analysis.pattern} (${analysis.pillars} pillar changes)`);
    }

    console.log('\nExpected Sequential Pattern (per pillar):');
    console.log('  WALL-OUTER → WALL-INNER → SKIN/FILL');
    console.log('  Then move to next pillar and repeat');
    
    console.log('\nTwo-Phase Pattern (all walls first):');
    console.log('  All WALL-OUTER → All WALL-INNER → All SKIN/FILL');
    console.log('  More travel between pillars');

})();
