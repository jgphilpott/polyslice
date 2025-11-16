import THREE from "three";
import Polytree from "@jgphilpott/polytree";
import fs from "fs";
import { STLLoader } from "three/examples/jsm/loaders/STLLoader.js";

async function loadSTLMesh(stlPath) {
  const buffer = fs.readFileSync(stlPath);
  const loader = new STLLoader();
  const geometry = loader.parse(buffer.buffer);
  geometry.computeVertexNormals?.();
  const material = new THREE.MeshPhongMaterial({ color: 0x808080 });
  const mesh = new THREE.Mesh(geometry, material);

  // Place bottom at Z=0
  geometry.computeBoundingBox();
  const bb = geometry.boundingBox;
  const zShift = -bb.min.z;
  mesh.position.set(0, 0, zShift);
  mesh.updateMatrixWorld();
  return mesh;
}

async function main() {
  const stlPath = "../../resources/testing/benchy.test.stl";
  console.log("Loading STL:", stlPath);
  const mesh = await loadSTLMesh(stlPath);
  
  const boundingBox = new THREE.Box3().setFromObject(mesh);
  const minZ = boundingBox.min.z;
  const maxZ = boundingBox.max.z;
  const layerHeight = 0.2;
  const SLICE_EPSILON = 0.01;
  const adjustedMinZ = minZ + SLICE_EPSILON;
  
  console.log(`Bounding box: minZ=${minZ}, maxZ=${maxZ}`);
  console.log(`Slicing with layer height ${layerHeight}mm from ${adjustedMinZ} to ${maxZ}`);
  
  const allLayers = Polytree.sliceIntoLayers(mesh, layerHeight, adjustedMinZ, maxZ);
  console.log(`Total layers: ${allLayers.length}`);
  
  // Examine layers 4 and 5
  for (let layerIdx of [4, 5]) {
    const segments = allLayers[layerIdx];
    console.log(`\nLayer ${layerIdx}: ${segments.length} segments`);
    
    // Check connectivity
    const connections = new Map();
    const epsilon = 0.001;
    segments.forEach((seg, idx) => {
      connections.set(idx, []);
      segments.forEach((otherSeg, otherIdx) => {
        if (idx === otherIdx) return;
        
        // Check if seg.end connects to otherSeg.start or otherSeg.end
        const dist1 = Math.sqrt(
          Math.pow(seg.end.x - otherSeg.start.x, 2) +
          Math.pow(seg.end.y - otherSeg.start.y, 2)
        );
        const dist2 = Math.sqrt(
          Math.pow(seg.end.x - otherSeg.end.x, 2) +
          Math.pow(seg.end.y - otherSeg.end.y, 2)
        );
        
        if (dist1 < epsilon || dist2 < epsilon) {
          connections.get(idx).push(otherIdx);
        }
      });
    });
    
    // Find segments with unusual connectivity
    let multiConnect = 0;
    let noConnect = 0;
    connections.forEach((conn, idx) => {
      if (conn.length === 0) noConnect++;
      if (conn.length > 2) multiConnect++;
    });
    
    console.log(`  Segments with no connections: ${noConnect}`);
    console.log(`  Segments with >2 connections: ${multiConnect}`);
    
    // Find all separate paths
    const visited = new Set();
    const paths = [];
    
    for (let startIdx = 0; startIdx < segments.length; startIdx++) {
      if (visited.has(startIdx)) continue;
      
      const path = [startIdx];
      visited.add(startIdx);
      
      let current = startIdx;
      let searching = true;
      let iters = 0;
      const maxIters = segments.length * 2;
      
      while (searching && iters < maxIters) {
        iters++;
        searching = false;
        const conns = connections.get(current);
        
        for (let next of conns) {
          if (!visited.has(next)) {
            path.push(next);
            visited.add(next);
            current = next;
            searching = true;
            break;
          }
        }
      }
      
      if (path.length >= 3) {
        paths.push(path);
      }
    }
    
    console.log(`  Separate paths found: ${paths.length}`);
    paths.forEach((p, i) => {
      if (i < 5) {
        console.log(`    Path ${i}: ${p.length} segments`);
      }
    });
  }
}

main().catch(err => {
  console.error("Error:", err);
  process.exit(1);
});
