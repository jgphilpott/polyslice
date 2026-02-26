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
  const skinLayerCount = 4;
  const totalLayers = allLayers.length;
  
  // Check layers 4-18 (no spurious patches per gcode analysis)
  for (let layerIndex = 4; layerIndex <= 18; layerIndex++) {
    const layerSegments = allLayers[layerIndex];
    const layerPaths = pathsUtils.connectSegmentsToPaths(layerSegments);
    
    const pathIsHole = [];
    let holeCount = 0;
    for (let i = 0; i < layerPaths.length; i++) {
      let nestingLevel = 0;
      for (let j = 0; j < layerPaths.length; j++) {
        if (i === j) continue;
        if (layerPaths[i].length > 0 && primitives.pointInPolygon(layerPaths[i][0], layerPaths[j])) nestingLevel++;
      }
      const isHole = nestingLevel % 2 === 1;
      pathIsHole.push(isHole);
      if (isHole) holeCount++;
    }
    
    let exposedCount = 0;
    for (let pi = 0; pi < layerPaths.length; pi++) {
      if (!pathIsHole[pi] && layerPaths[pi].length > 0) {
        const exposureResult = exposureModule.calculateExposedAreasForLayer(
          layerPaths[pi], layerIndex, skinLayerCount, totalLayers, allLayers, 961
        );
        exposedCount += exposureResult.exposedAreas.length;
      }
    }
    console.log("Layer " + (layerIndex+1) + ": paths=" + layerPaths.length + ", holes=" + holeCount + ", exposedAreas=" + exposedCount);
  }
}

main().catch(console.error);
