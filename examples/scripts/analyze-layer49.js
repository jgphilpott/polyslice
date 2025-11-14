const fs = require('fs');

const Polyslice = require('/home/runner/work/polyslice/polyslice/src/index').Polyslice;
const THREE = require('three');
const { Polytree } = require('@jgphilpott/polytree');

async function buildSimplePyramid() {
  const mat = new THREE.MeshStandardMaterial({ color: 0x888888 });
  
  const baseSlab = new THREE.BoxGeometry(50, 50, 10);
  const baseSlabMesh = new THREE.Mesh(baseSlab, mat);
  baseSlabMesh.position.set(0, 0, 0);
  baseSlabMesh.updateMatrixWorld();
  
  const topSlab = new THREE.BoxGeometry(30, 30, 10);
  const topSlabMesh = new THREE.Mesh(topSlab, mat);
  topSlabMesh.position.set(0, 0, 10);
  topSlabMesh.updateMatrixWorld();
  
  const pyramidMesh = await Polytree.unite(baseSlabMesh, topSlabMesh);
  const finalMesh = new THREE.Mesh(pyramidMesh.geometry, mat);
  finalMesh.position.set(0, 0, 0);
  finalMesh.updateMatrixWorld();
  
  return finalMesh;
}

async function main() {
  const mesh = await buildSimplePyramid();
  
  const slicer = new Polyslice({
    layerHeight: 0.2,
    shellSkinThickness: 0.8,
    shellWallThickness: 0.8,
    verbose: true,
    exposureDetection: true,
    exposureDetectionResolution: 961,
    infillDensity: 0,
    testStrip: false,
    autohome: false
  });
  
  const gcode = slicer.slice(mesh);
  
  // Extract layer 49 G-code
  const lines = gcode.split('\n');
  let inLayer49 = false;
  let layer49Lines = [];
  let inSkin = false;
  let skinCount = 0;
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    if (line.includes('LAYER: 49')) {
      inLayer49 = true;
    } else if (line.includes('LAYER: 50')) {
      break;
    } else if (inLayer49) {
      layer49Lines.push(line);
      
      if (line.includes('TYPE: SKIN')) {
        skinCount++;
        inSkin = true;
        layer49Lines.push(`--- SKIN SECTION ${skinCount} START ---`);
      } else if (line.includes('TYPE:') && !line.includes('SKIN')) {
        if (inSkin) {
          layer49Lines.push(`--- SKIN SECTION ${skinCount} END ---`);
          inSkin = false;
        }
      }
    }
  }
  
  console.log('Layer 49 G-code Analysis');
  console.log('========================\n');
  console.log(`Total skin sections: ${skinCount}\n`);
  
  // Parse G1 commands to extract coordinates
  const skinMoves = [];
  inSkin = false;
  let currentSkinSection = 0;
  
  for (const line of layer49Lines) {
    if (line.includes('--- SKIN SECTION') && line.includes('START')) {
      currentSkinSection++;
      inSkin = true;
    } else if (line.includes('--- SKIN SECTION') && line.includes('END')) {
      inSkin = false;
    } else if (inSkin && line.match(/G1.*X([\d.]+).*Y([\d.]+)/)) {
      const match = line.match(/X([\d.]+).*Y([\d.]+)/);
      if (match) {
        const x = parseFloat(match[1]);
        const y = parseFloat(match[2]);
        skinMoves.push({section: currentSkinSection, x, y});
      }
    }
  }
  
  console.log(`Parsed ${skinMoves.length} skin G1 moves\n`);
  
  // Analyze X/Y ranges for each skin section
  for (let section = 1; section <= skinCount; section++) {
    const sectionMoves = skinMoves.filter(m => m.section === section);
    if (sectionMoves.length > 0) {
      const xValues = sectionMoves.map(m => m.x);
      const yValues = sectionMoves.map(m => m.y);
      const minX = Math.min(...xValues);
      const maxX = Math.max(...xValues);
      const minY = Math.min(...yValues);
      const maxY = Math.max(...yValues);
      
      console.log(`Skin Section ${section}:`);
      console.log(`  Moves: ${sectionMoves.length}`);
      console.log(`  X range: ${minX.toFixed(2)} to ${maxX.toFixed(2)} (width: ${(maxX - minX).toFixed(2)}mm)`);
      console.log(`  Y range: ${minY.toFixed(2)} to ${maxY.toFixed(2)} (height: ${(maxY - minY).toFixed(2)}mm)`);
      console.log(`  Center: (${((minX + maxX) / 2).toFixed(2)}, ${((minY + maxY) / 2).toFixed(2)})`);
      console.log();
    }
  }
  
  // Expected: Build plate center is at (110, 110)
  // Bottom slab 50x50 should cover X: 85-135, Y: 85-135
  // Top slab 30x30 should cover X: 95-125, Y: 95-125
  // Exposed ring should be the difference
  console.log('Expected Values (with slicer centering on 220x220 bed):');
  console.log('  Build plate center: (110, 110)');
  console.log('  Bottom slab (50x50): X: 85-135, Y: 85-135');
  console.log('  Top slab (30x30): X: 95-125, Y: 95-125');
  console.log('  Exposed ring should avoid center 30x30 area');
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
