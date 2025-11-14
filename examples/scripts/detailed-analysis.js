const fs = require('fs');

const gcode = fs.readFileSync('/tmp/test-pyramid.gcode', 'utf8');
const lines = gcode.split('\n');

let inLayer49 = false;
let allMoves = [];
let skinInfillMoves = [];

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  
  if (line.includes('LAYER: 49')) {
    inLayer49 = true;
  } else if (line.includes('LAYER: 50')) {
    break;
  } else if (inLayer49 && line.match(/G1.*X([\d.]+).*Y([\d.]+).*E/)) {
    const match = line.match(/X([\d.]+).*Y([\d.]+)/);
    if (match) {
      const x = parseFloat(match[1]);
      const y = parseFloat(match[2]);
      allMoves.push({x, y, line: line.substring(0, 80)});
      
      // Check if it's after "TYPE: SKIN"
      let isSkinInfill = false;
      for (let j = i - 1; j >= Math.max(0, i - 20); j--) {
        if (lines[j].includes('TYPE: SKIN')) {
          isSkinInfill = true;
          break;
        }
        if (lines[j].includes('TYPE:') && !lines[j].includes('SKIN')) {
          break;
        }
      }
      
      if (isSkinInfill) {
        skinInfillMoves.push({x, y, line: line.substring(0, 80)});
      }
    }
  }
}

console.log('Layer 49 Detailed Analysis');
console.log('===========================\n');
console.log(`Total moves with extrusion: ${allMoves.length}`);
console.log(`Skin infill moves: ${skinInfillMoves.length}`);

// Check center region
const centerMoves = skinInfillMoves.filter(m => 
  m.x >= 95 && m.x <= 125 && m.y >= 95 && m.y <= 125
);

console.log(`\nSkin moves in center region (95-125):`);
console.log(`  Count: ${centerMoves.length}`);
console.log(`  Percentage: ${(centerMoves.length / skinInfillMoves.length * 100).toFixed(1)}%`);

if (centerMoves.length > 0) {
  console.log('\n⚠️  PROBLEM: Skin infill in covered center!');
  console.log('\nSample moves in center:');
  centerMoves.slice(0, 5).forEach(m => {
    console.log(`  (${m.x.toFixed(1)}, ${m.y.toFixed(1)}): ${m.line}`);
  });
} else {
  console.log('\n✅ No skin infill in center - properly excluded');
}

// Check the boundary
const boundaryMoves = skinInfillMoves.filter(m =>
  (m.x >= 86 && m.x <= 95) || (m.x >= 125 && m.x <= 134) ||
  (m.y >= 86 && m.y <= 95) || (m.y >= 125 && m.y <= 134)
);
console.log(`\nSkin moves in ring boundary (86-95 or 125-134): ${boundaryMoves.length}`);
console.log(`  Percentage: ${(boundaryMoves.length / skinInfillMoves.length * 100).toFixed(1)}%`);
