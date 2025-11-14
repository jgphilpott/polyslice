const fs = require('fs');

const gcode = fs.readFileSync('/tmp/test-pyramid.gcode', 'utf8');
const lines = gcode.split('\n');

let inLayer49 = false;
let inSkinWall = false;
let wallMoves = [];
let infillMoves = [];

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  
  if (line.includes('LAYER: 49')) {
    inLayer49 = true;
  } else if (line.includes('LAYER: 50')) {
    break;
  } else if (inLayer49) {
    if (line.includes('TYPE: SKIN')) {
      // Check next few lines for "skin wall" comment
      let isSkinWall = false;
      for (let j = i; j < Math.min(i + 5, lines.length); j++) {
        if (lines[j].toLowerCase().includes('skin wall')) {
          isSkinWall = true;
          break;
        }
      }
      inSkinWall = isSkinWall;
    } else if (line.includes('TYPE:') && !line.includes('SKIN')) {
      inSkinWall = false;
    } else if (line.includes('TYPE: SKIN') && !inSkinWall) {
      // Regular skin infill
    }
    
    if (line.match(/G[01].*X([\d.]+).*Y([\d.]+)/)) {
      const match = line.match(/X([\d.]+).*Y([\d.]+)/);
      if (match) {
        const x = parseFloat(match[1]);
        const y = parseFloat(match[2]);
        
        if (inSkinWall || line.toLowerCase().includes('skin wall')) {
          wallMoves.push({x, y});
        } else if (line.includes('TYPE: SKIN') || (inLayer49 && lines[i-1] && lines[i-1].includes('TYPE: SKIN'))) {
          infillMoves.push({x, y});
        }
      }
    }
  }
}

console.log('Layer 49 Skin Wall Analysis');
console.log('============================\n');
console.log(`Skin wall moves: ${wallMoves.length}`);
console.log(`Skin infill moves: ${infillMoves.length}`);
console.log(`Total: ${wallMoves.length + infillMoves.length}`);

// Analyze wall moves in center
const centerWalls = wallMoves.filter(m => 
  m.x >= 95 && m.x <= 125 && m.y >= 95 && m.y <= 125
);

console.log(`\nWall moves in center (95-125): ${centerWalls.length}`);
if (centerWalls.length > 0) {
  console.log('⚠️  Skin walls are being drawn in covered center!');
} else {
  console.log('✅ No skin walls in center');
}

// Check if walls trace around the outer boundary
const outerWalls = wallMoves.filter(m =>
  (m.x < 90 || m.x > 130) || (m.y < 90 || m.y > 130)
);
console.log(`\nOuter boundary wall moves: ${outerWalls.length}`);
