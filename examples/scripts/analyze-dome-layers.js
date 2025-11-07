const { Polyslice, Printer, Filament } = require("../../src/index");
const THREE = require("three");
const { Polytree } = require("@jgphilpott/polytree");
const helpers = require("../../src/slicer/geometry/helpers");

const DOME_WIDTH = 25;
const DOME_DEPTH = 25;
const DOME_THICKNESS = 12;
const DOME_RADIUS = 10;

async function createDomeMesh(width = DOME_WIDTH, depth = DOME_DEPTH, thickness = DOME_THICKNESS, radius = DOME_RADIUS) {
  const maxRadiusXY = Math.min(width, depth) * 0.49;
  const maxRadiusZ = thickness;
  const r = Math.min(radius, maxRadiusXY, maxRadiusZ);

  const boxGeo = new THREE.BoxGeometry(width, depth, thickness);
  const boxMesh = new THREE.Mesh(boxGeo, new THREE.MeshBasicMaterial());

  const sphereGeo = new THREE.SphereGeometry(r, 64, 48);
  const sphereMesh = new THREE.Mesh(sphereGeo, new THREE.MeshBasicMaterial());
  sphereMesh.position.set(0, 0, -(thickness / 2));
  sphereMesh.updateMatrixWorld();

  const resultMesh = await Polytree.subtract(boxMesh, sphereMesh);
  const finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material);
  finalMesh.position.set(0, 0, thickness / 2);
  finalMesh.updateMatrixWorld();
  return finalMesh;
}

async function main() {
  const mesh = await createDomeMesh();
  
  const pos = mesh.geometry.attributes.position;
  const positions = pos.array;
  
  // Find the Z range
  let minZ = Infinity, maxZ = -Infinity;
  for (let i = 0; i < positions.length; i += 3) {
    const z = positions[i + 2];
    if (z < minZ) minZ = z;
    if (z > maxZ) maxZ = z;
  }
  
  const layerHeight = 0.2;
  
  // Analyze a few layers in the middle where the dome cavity should be
  console.log("Analyzing layers where dome cavity is present...\n");
  
  for (let layerIdx of [40, 45, 49, 50, 54]) {
    const z = minZ + (layerIdx + 0.5) * layerHeight;
    
    // Slice the mesh at this Z height
    const segments = [];
    const indices = mesh.geometry.index ? mesh.geometry.index.array : null;
    const vertexCount = positions.length / 3;
    
    for (let i = 0; i < (indices ? indices.length : vertexCount); i += 3) {
      const idx0 = indices ? indices[i] : i;
      const idx1 = indices ? indices[i + 1] : i + 1;
      const idx2 = indices ? indices[i + 2] : i + 2;
      
      const v0z = positions[idx0 * 3 + 2];
      const v1z = positions[idx1 * 3 + 2];
      const v2z = positions[idx2 * 3 + 2];
      
      const intersections = [];
      
      // Check each edge
      const edges = [
        [idx0, idx1], [idx1, idx2], [idx2, idx0]
      ];
      
      for (const [i1, i2] of edges) {
        const z1 = positions[i1 * 3 + 2];
        const z2 = positions[i2 * 3 + 2];
        
        if ((z1 <= z && z2 >= z) || (z1 >= z && z2 <= z)) {
          if (Math.abs(z1 - z2) > 0.0001) {
            const t = (z - z1) / (z2 - z1);
            const x = positions[i1 * 3] + t * (positions[i2 * 3] - positions[i1 * 3]);
            const y = positions[i1 * 3 + 1] + t * (positions[i2 * 3 + 1] - positions[i1 * 3 + 1]);
            intersections.push({ x, y });
          }
        }
      }
      
      if (intersections.length === 2) {
        segments.push({ start: intersections[0], end: intersections[1] });
      }
    }
    
    // Connect segments to paths
    const paths = helpers.connectSegmentsToPaths(segments);
    
    console.log(`Layer ${layerIdx} (z=${z.toFixed(2)}): ${paths.length} path(s)`);
    for (let p = 0; p < paths.length; p++) {
      const path = paths[p];
      const bounds = helpers.calculatePathBounds(path);
      const area = (bounds.maxX - bounds.minX) * (bounds.maxY - bounds.minY);
      console.log(`  Path ${p}: ${path.length} points, bounds area ~${area.toFixed(1)}`);
    }
  }
}

main().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
