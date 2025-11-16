/**
 * Detailed diagnostic for layer 5 path connection
 */

const path = require("path");
const fs = require("fs");
const THREE = require("three");
const Polytree = require("@jgphilpott/polytree");
const helpers = require("../../src/slicer/geometry/helpers");

async function loadSTLMesh(stlPath) {
  const { STLLoader } = await import("three/examples/jsm/loaders/STLLoader.js");
  const buffer = fs.readFileSync(stlPath);
  const loader = new STLLoader();
  const geometry = loader.parse(buffer.buffer);
  geometry.computeVertexNormals?.();
  const material = new THREE.MeshPhongMaterial({ color: 0x808080 });
  const mesh = new THREE.Mesh(geometry, material);

  geometry.computeBoundingBox();
  const bb = geometry.boundingBox;
  const zShift = -bb.min.z;
  mesh.position.set(0, 0, zShift);
  mesh.updateMatrixWorld();
  return mesh;
}

async function main() {
  console.log("Layer 5 Detailed Diagnostic");
  console.log("===========================\n");

  const stlPath = path.join(__dirname, "../../resources/testing/benchy.test.stl");
  const mesh = await loadSTLMesh(stlPath);

  const boundingBox = new THREE.Box3().setFromObject(mesh);
  const minZ = boundingBox.min.z;
  const layerHeight = 0.2;
  const SLICE_EPSILON = 0.01;

  // Slice up to layer 6
  const maxZ = minZ + (6 * layerHeight);
  const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, minZ + SLICE_EPSILON, maxZ);

  const layer5Segments = allLayers[5];
  console.log(`Layer 5 has ${layer5Segments.length} segments\n`);

  // Analyze segment connectivity
  const epsilon = 0.001;
  const pointMap = new Map();

  for (let i = 0; i < layer5Segments.length; i++) {
    const seg = layer5Segments[i];
    const startKey = `${seg.start.x.toFixed(6)},${seg.start.y.toFixed(6)}`;
    const endKey = `${seg.end.x.toFixed(6)},${seg.end.y.toFixed(6)}`;

    if (!pointMap.has(startKey)) pointMap.set(startKey, []);
    if (!pointMap.has(endKey)) pointMap.set(endKey, []);

    pointMap.get(startKey).push({ segIdx: i, type: 'start' });
    pointMap.get(endKey).push({ segIdx: i, type: 'end' });
  }

  // Find branching points (points with more than 2 connections)
  const branchPoints = [];
  for (const [pointKey, connections] of pointMap.entries()) {
    if (connections.length > 2) {
      branchPoints.push({ point: pointKey, connections: connections.length });
    }
  }

  console.log(`Branching points (>2 connections): ${branchPoints.length}`);
  if (branchPoints.length > 0) {
    console.log("First 10 branching points:");
    branchPoints.slice(0, 10).forEach(bp => {
      console.log(`  ${bp.point}: ${bp.connections} connections`);
    });
  }

  // Find isolated segments (segments that don't connect to others)
  let isolated = 0;
  for (let i = 0; i < layer5Segments.length; i++) {
    const seg = layer5Segments[i];
    const startKey = `${seg.start.x.toFixed(6)},${seg.start.y.toFixed(6)}`;
    const endKey = `${seg.end.x.toFixed(6)},${seg.end.y.toFixed(6)}`;

    if (pointMap.get(startKey).length === 1 || pointMap.get(endKey).length === 1) {
      isolated++;
    }
  }

  console.log(`\nIsolated segments (dead ends): ${isolated}`);

  // Run path connection
  const paths = helpers.connectSegmentsToPaths(layer5Segments);
  console.log(`\nPaths created: ${paths.length}`);

  paths.forEach((path, idx) => {
    const firstPt = path[0];
    const lastPt = path[path.length - 1];
    const dist = Math.sqrt(
      Math.pow(lastPt.x - firstPt.x, 2) + 
      Math.pow(lastPt.y - firstPt.y, 2)
    );
    const isClosed = dist < epsilon;
    console.log(`\nPath ${idx}: ${path.length} points, ${isClosed ? "CLOSED" : "OPEN (" + dist.toFixed(4) + "mm gap)"}`);
    console.log(`  First: (${firstPt.x.toFixed(2)}, ${firstPt.y.toFixed(2)})`);
    console.log(`  Last:  (${lastPt.x.toFixed(2)}, ${lastPt.y.toFixed(2)})`);

    // Check for large internal gaps
    let maxGap = 0;
    let maxGapIdx = -1;
    for (let i = 0; i < path.length - 1; i++) {
      const p1 = path[i];
      const p2 = path[i + 1];
      const gap = Math.sqrt(
        Math.pow(p2.x - p1.x, 2) + 
        Math.pow(p2.y - p1.y, 2)
      );
      if (gap > maxGap) {
        maxGap = gap;
        maxGapIdx = i;
      }
    }
    console.log(`  Max internal gap: ${maxGap.toFixed(4)}mm at segment ${maxGapIdx}`);
  });
}

main().catch(err => {
  console.error("Error:", err);
  process.exit(1);
});
