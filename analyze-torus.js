const THREE = require('three');

// Create torus with same parameters as resources
const size = 30; // 3cm
// TorusGeometry(radius, tube, radialSegments, tubularSegments)
// radius = size/3 = 10mm
// tube = size/6 = 5mm
const geometry = new THREE.TorusGeometry(size/3, size/6, 16, 32);

// Get bounding box
const bbox = new THREE.Box3().setFromBufferAttribute(geometry.attributes.position);
console.log('Torus bounding box:');
console.log(`  Min: (${bbox.min.x.toFixed(2)}, ${bbox.min.y.toFixed(2)}, ${bbox.min.z.toFixed(2)})`);
console.log(`  Max: (${bbox.max.x.toFixed(2)}, ${bbox.max.y.toFixed(2)}, ${bbox.max.z.toFixed(2)})`);
console.log(`  Size: ${(bbox.max.x - bbox.min.x).toFixed(2)}mm x ${(bbox.max.y - bbox.min.y).toFixed(2)}mm x ${(bbox.max.z - bbox.min.z).toFixed(2)}mm`);

// Calculate Z height of center
const centerZ = (bbox.min.z + bbox.max.z) / 2;
console.log(`\nCenter Z: ${centerZ.toFixed(2)}mm`);

// With 0.2mm layers starting at minZ, find which layer is at centerZ
const layerHeight = 0.2;
const minZ = bbox.min.z;
const maxZ = bbox.max.z;
const centerLayerIndex = Math.round((centerZ - minZ) / layerHeight);
const centerLayerZ = minZ + centerLayerIndex * layerHeight;

console.log(`\nWith layer height ${layerHeight}mm:`);
console.log(`  Total height: ${(maxZ - minZ).toFixed(2)}mm`);
console.log(`  Total layers: ${Math.ceil((maxZ - minZ) / layerHeight)}`);
console.log(`  Center layer should be: Layer ${centerLayerIndex} at Z=${centerLayerZ.toFixed(2)}mm`);

// For a torus with major radius R and minor radius r:
// - At Z=0 (center plane), the cross-section is:
//   - Inner circle at radius (R - r) = 10 - 5 = 5mm
//   - Outer circle at radius (R + r) = 10 + 5 = 15mm
// - But the torus is centered at (0, 0, 0) so we need to think about it differently

console.log('\nTorus geometry:');
console.log(`  Major radius (R): ${size/3}mm (center of tube)`);
console.log(`  Minor radius (r): ${size/6}mm (tube thickness)`);
console.log(`  At Z=0 (center plane):`);
console.log(`    - Inner edge: radius = R - r = ${size/3 - size/6}mm = ${(size/3 - size/6).toFixed(2)}mm`);
console.log(`    - Outer edge: radius = R + r = ${size/3 + size/6}mm = ${(size/3 + size/6).toFixed(2)}mm`);
console.log(`    - This should create a ring (annulus), NOT a small circle!`);

// Adjust mesh position if needed (mesh might be below Z=0)
const mesh = new THREE.Mesh(geometry);
const meshBbox = new THREE.Box3().setFromObject(mesh);
if (meshBbox.min.z < 0) {
    const zOffset = -meshBbox.min.z;
    mesh.position.z += zOffset;
    mesh.updateMatrixWorld();
    const newBbox = new THREE.Box3().setFromObject(mesh);
    console.log(`\nAfter adjusting to build plate:`);
    console.log(`  Z offset: +${zOffset.toFixed(2)}mm`);
    console.log(`  New Z range: ${newBbox.min.z.toFixed(2)}mm to ${newBbox.max.z.toFixed(2)}mm`);
    console.log(`  Center layer Z: ${(centerZ + zOffset).toFixed(2)}mm`);
    console.log(`  Center layer index: ${Math.round(((centerZ + zOffset) - newBbox.min.z) / layerHeight)}`);
}
