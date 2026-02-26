const THREE = require("three");
const { Polytree } = require("@jgphilpott/polytree");
const pathsUtils = require("./src/slicer/utils/paths");
const exposureModule = require("./src/slicer/skin/exposure/exposure");
const primitives = require("./src/slicer/utils/primitives");

async function createDomeMesh() {
  const width = 25, depth = 25, thickness = 12, radius = 10;
  const boxGeo = new THREE.BoxGeometry(width, depth, thickness);
  const boxMesh = new THREE.Mesh(boxGeo, new THREE.MeshBasicMaterial());
  const sphereGeo = new THREE.SphereGeometry(radius, 64, 48);
  const sphereMesh = new THREE.Mesh(sphereGeo, new THREE.MeshBasicMaterial());
  sphereMesh.position.set(0, 0, -(thickness / 2));
  sphereMesh.updateMatrixWorld();
  const resultMesh = await Polytree.subtract(boxMesh, sphereMesh);
  const finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material);
  finalMesh.position.set(0, 0, thickness / 2);
  finalMesh.updateMatrixWorld();
  const variant = new THREE.Mesh(finalMesh.geometry.clone(), finalMesh.material);
  variant.position.copy(finalMesh.position);
  variant.rotation.copy(finalMesh.rotation);
  variant.scale.copy(finalMesh.scale);
  variant.rotation.y += Math.PI / 2;
  variant.updateMatrixWorld(true);
  return variant;
}

async function main() {
  const mesh = await createDomeMesh();
  
  const layerHeight = 0.2;
  const boundingBox = new THREE.Box3().setFromObject(mesh);
  const minZ = boundingBox.min.z;
  const maxZ = boundingBox.max.z;
  const SLICE_EPSILON = layerHeight / 2;
  const adjustedMinZ = minZ + SLICE_EPSILON;
  
  const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, adjustedMinZ, maxZ);
  console.log("Total layers:", allLayers.length);
  
  const skinLayerCount = 4;
  const totalLayers = allLayers.length;
  
  // Check layers 18-30 (displayed as 19-31)
  for (let layerIndex = 18; layerIndex <= 30; layerIndex++) {
    const layerSegments = allLayers[layerIndex];
    const layerPaths = pathsUtils.connectSegmentsToPaths(layerSegments);
    
    const pathIsHole = [];
    for (let i = 0; i < layerPaths.length; i++) {
      let nestingLevel = 0;
      for (let j = 0; j < layerPaths.length; j++) {
        if (i === j) continue;
        if (layerPaths[i].length > 0 && primitives.pointInPolygon(layerPaths[i][0], layerPaths[j])) nestingLevel++;
      }
      pathIsHole.push(nestingLevel % 2 === 1);
    }
    
    const holeCount = pathIsHole.filter(x=>x).length;
    console.log("Layer " + (layerIndex+1) + ": paths=" + layerPaths.length + ", holes=" + holeCount);
    
    for (let pi = 0; pi < layerPaths.length; pi++) {
      if (!pathIsHole[pi] && layerPaths[pi].length > 0) {
        const exposureResult = exposureModule.calculateExposedAreasForLayer(
          layerPaths[pi], layerIndex, skinLayerCount, totalLayers, allLayers, 961
        );
        if (exposureResult.exposedAreas.length > 0) {
          console.log("  Path " + pi + " (" + layerPaths[pi].length + " pts): " + exposureResult.exposedAreas.length + " exposed areas");
          for (let ea = 0; ea < exposureResult.exposedAreas.length; ea++) {
            const area = exposureResult.exposedAreas[ea];
            if (area.length > 0) {
              const xs = area.map(p => p.x);
              const ys = area.map(p => p.y);
              const minX = Math.min(...xs), maxX = Math.max(...xs);
              const minY = Math.min(...ys), maxY = Math.max(...ys);
              console.log("    Area " + ea + ": " + area.length + " pts, " + (minX.toFixed(2)) + "-" + (maxX.toFixed(2)) + " x " + (minY.toFixed(2)) + "-" + (maxY.toFixed(2)) + " = " + ((maxX-minX)*(maxY-minY)).toFixed(2) + "mm2");
            }
          }
        }
      }
    }
  }
}

main().catch(console.error);
