const { Polyslice, Printer, Filament } = require("./src/index");
const THREE = require("three");
const { Polytree } = require("@jgphilpott/polytree");
const paths = require("./src/slicer/utils/paths");
const boundsModule = require("./src/slicer/utils/bounds");
const exposureModule = require("./src/slicer/skin/exposure/exposure");

const ARCH_WIDTH = 40, ARCH_HEIGHT = 10, ARCH_THICKNESS = 20, ARCH_RADIUS = 15;

async function main() {
    const boxGeo = new THREE.BoxGeometry(ARCH_WIDTH, ARCH_HEIGHT, ARCH_THICKNESS);
    const boxMesh = new THREE.Mesh(boxGeo, new THREE.MeshBasicMaterial());
    const cylGeo = new THREE.CylinderGeometry(ARCH_RADIUS, ARCH_RADIUS, ARCH_WIDTH*1.25, 48);
    const cylMesh = new THREE.Mesh(cylGeo, new THREE.MeshBasicMaterial());
    cylMesh.position.z = -ARCH_HEIGHT;
    cylMesh.updateMatrixWorld();
    const result = await Polytree.subtract(boxMesh, cylMesh);
    const mesh = new THREE.Mesh(result.geometry, result.material);
    mesh.position.set(0, 0, ARCH_THICKNESS/2);
    mesh.updateMatrixWorld();

    const variant = new THREE.Mesh(mesh.geometry.clone(), mesh.material);
    variant.position.copy(mesh.position);
    variant.rotation.copy(mesh.rotation);
    variant.rotation.y += Math.PI;
    variant.updateMatrixWorld(true);
    
    const bb = new THREE.Box3().setFromObject(variant);
    let minZ = bb.min.z, maxZ = bb.max.z;
    if (minZ < 0) { variant.position.z += -minZ; variant.updateMatrixWorld(); const bb2 = new THREE.Box3().setFromObject(variant); minZ = bb2.min.z; maxZ = bb2.max.z; }
    
    const layerHeight = 0.2;
    const adjustedMinZ = minZ + layerHeight/2;
    const allLayers = Polytree.sliceIntoLayers(variant, layerHeight, adjustedMinZ, maxZ);
    const totalLayers = allLayers.length;
    const skinLayerCount = Math.floor(0.8/layerHeight + 0.0001);
    
    console.log(`Layers: ${totalLayers}, skinLayerCount: ${skinLayerCount}`);
    
    for (let li = 19; li <= 30; li++) {
        const z = adjustedMinZ + li*layerHeight;
        const segs = allLayers[li];
        if (!segs || !segs.length) { console.log(`Layer ${li+1} z=${z.toFixed(3)}: empty`); continue; }
        const ps = paths.connectSegmentsToPaths(segs);
        process.stdout.write(`Layer ${li+1} z=${z.toFixed(3)}: ${ps.length} path(s)`);
        for (const p of ps) { const b = boundsModule.calculatePathBounds(p); if (b) process.stdout.write(` [${b.minX.toFixed(1)},${b.maxX.toFixed(1)}]x[${b.minY.toFixed(1)},${b.maxY.toFixed(1)}] area=${((b.maxX-b.minX)*(b.maxY-b.minY)).toFixed(0)}`); }
        console.log();
    }
    
    console.log("\n--- TRACE for layerIdx=21 (LAYER:22) ---");
    const li = 21;
    const ps = paths.connectSegmentsToPaths(allLayers[li]);
    const cp = ps[0];
    const cpb = boundsModule.calculatePathBounds(cp);
    const cpArea = (cpb.maxX-cpb.minX)*(cpb.maxY-cpb.minY);
    console.log(`currentPath: [${cpb.minX.toFixed(2)},${cpb.maxX.toFixed(2)}]x[${cpb.minY.toFixed(2)},${cpb.maxY.toFixed(2)}] area=${cpArea.toFixed(1)}`);
    
    const er = exposureModule.calculateExposedAreasForLayer(cp, li, skinLayerCount, totalLayers, allLayers, 961);
    
    let totalAbove = 0;
    console.log(`\ncoveringRegionsAbove (${er.coveringRegionsAbove.length}):`);
    for (const r of er.coveringRegionsAbove) {
        const b = boundsModule.calculatePathBounds(r);
        if (!b) continue;
        const a = (b.maxX-b.minX)*(b.maxY-b.minY);
        totalAbove += a;
        console.log(`  [${b.minX.toFixed(2)},${b.maxX.toFixed(2)}]x[${b.minY.toFixed(2)},${b.maxY.toFixed(2)}] area=${a.toFixed(1)} ratio=${(a/cpArea).toFixed(3)}`);
    }
    console.log(`  TOTAL above area: ${totalAbove.toFixed(1)}, ratio to current: ${(totalAbove/cpArea).toFixed(3)}`);
    
    console.log(`\ncoveringRegionsBelow (${er.coveringRegionsBelow.length}):`);
    for (const r of er.coveringRegionsBelow) {
        const b = boundsModule.calculatePathBounds(r);
        if (b) console.log(`  [${b.minX.toFixed(2)},${b.maxX.toFixed(2)}]x[${b.minY.toFixed(2)},${b.maxY.toFixed(2)}] area=${((b.maxX-b.minX)*(b.maxY-b.minY)).toFixed(1)}`);
    }
    
    console.log(`\nexposedAreas (${er.exposedAreas.length}):`);
    for (const a of er.exposedAreas) { const b = boundsModule.calculatePathBounds(a); if (b) console.log(`  [${b.minX.toFixed(2)},${b.maxX.toFixed(2)}]x[${b.minY.toFixed(2)},${b.maxY.toFixed(2)}]`); }
    
    const fcr = exposureModule.identifyFullyCoveredRegions(cp, er.coveringRegionsAbove, er.coveringRegionsBelow);
    console.log(`\nfullyCoveredRegions (${fcr.length}) <- THESE ARE THE EXTRA SKIN PATCHES:`);
    for (const r of fcr) {
        const b = boundsModule.calculatePathBounds(r);
        if (b) {
            const a = (b.maxX-b.minX)*(b.maxY-b.minY);
            console.log(`  [${b.minX.toFixed(2)},${b.maxX.toFixed(2)}]x[${b.minY.toFixed(2)},${b.maxY.toFixed(2)}] area=${a.toFixed(1)} ratio=${(a/cpArea).toFixed(3)}`);
            console.log(`    touchesLeft=${b.minX <= cpb.minX} touchesRight=${b.maxX >= cpb.maxX} touchesTop=${b.maxY >= cpb.maxY} touchesBottom=${b.minY <= cpb.minY}`);
        }
    }
}

main().catch(e => { console.error(e); process.exit(1); });
