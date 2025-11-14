const fs = require('fs');

const gcode = fs.readFileSync('/tmp/test-pyramid.gcode', 'utf8');
const lines = gcode.split('\n');

let inLayer49 = false;
let inSkin = false;
let skinMoves = [];

for (const line of lines) {
  if (line.includes('LAYER: 49')) {
    inLayer49 = true;
  } else if (line.includes('LAYER: 50')) {
    break;
  } else if (inLayer49) {
    if (line.includes('TYPE: SKIN')) {
      inSkin = true;
    } else if (line.includes('TYPE:') && !line.includes('SKIN')) {
      inSkin = false;
    } else if (inSkin && line.match(/G1.*X([\d.]+).*Y([\d.]+)/)) {
      const match = line.match(/X([\d.]+).*Y([\d.]+)/);
      if (match) {
        const x = parseFloat(match[1]);
        const y = parseFloat(match[2]);
        skinMoves.push({x, y});
      }
    }
  }
}

console.log('Layer 49 Skin Analysis');
console.log('=====================\n');
console.log(`Total skin moves: ${skinMoves.length}`);

// Center region (30x30 top slab) at X: 95-125, Y: 95-125
const centerMoves = skinMoves.filter(m => 
  m.x >= 95 && m.x <= 125 && m.y >= 95 && m.y <= 125
);

console.log(`\nCovered center region (95-125, 95-125):`);
console.log(`  Moves in center: ${centerMoves.length}`);
console.log(`  Percentage: ${(centerMoves.length / skinMoves.length * 100).toFixed(1)}%`);

if (centerMoves.length > 0) {
  console.log('\n⚠️  ISSUE: Center is still getting skin!');
  console.log('Expected: 0 moves in covered center (should be a hole in the skin)');
  console.log('\nSample center moves:');
  centerMoves.slice(0, 5).forEach(m => {
    console.log(`  X=${m.x.toFixed(2)}, Y=${m.y.toFixed(2)}`);
  });
} else {
  console.log('\n✅ CENTER EXCLUDED: No moves in covered center');
}

// Check boundary moves
const boundaryMoves = skinMoves.filter(m => 
  (m.x < 95 || m.x > 125) || (m.y < 95 || m.y > 125)
);
console.log(`\nExposed boundary moves: ${boundaryMoves.length}`);
console.log(`  Percentage: ${(boundaryMoves.length / skinMoves.length * 100).toFixed(1)}%`);
