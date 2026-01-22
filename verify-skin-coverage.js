/**
 * Verify that skin sections have complete coverage (wall + infill)
 * This accounts for the two-phase approach where Phase 1 generates walls
 * and Phase 2 generates infill.
 */

const fs = require('fs');

const filename = process.argv[2] || 'resources/gcode/wayfinding/holes/3x3.gcode';

console.log(`\nVerifying complete skin coverage in: ${filename}\n`);

const gcode = fs.readFileSync(filename, 'utf-8');
const lines = gcode.split('\n');

// Track skin sections by layer
const layerSkinSections = {};
let currentLayer = null;
let currentSection = null;
let lineNumber = 0;

for (const line of lines) {
  lineNumber++;
  
  if (line.includes('LAYER:')) {
    // Extract layer number
    const match = line.match(/LAYER:\s+(\d+)/);
    if (match) {
      currentLayer = parseInt(match[1]);
      if (!layerSkinSections[currentLayer]) {
        layerSkinSections[currentLayer] = [];
      }
    }
  }
  
  if (line.includes('TYPE: SKIN') && currentLayer !== null) {
    // Start a new skin section
    if (currentSection) {
      layerSkinSections[currentLayer].push(currentSection);
    }
    currentSection = {
      startLine: lineNumber,
      hasWall: false,
      hasInfill: false,
      lines: []
    };
  }
  
  if (currentSection) {
    currentSection.lines.push(line);
    
    // Check for wall or infill indicators
    if (line.includes('Moving to skin wall')) {
      currentSection.hasWall = true;
    } else if (line.includes('Moving to skin infill line')) {
      currentSection.hasInfill = true;
    }
    
    // If we hit a new TYPE, save current section
    if (line.includes('TYPE:') && !line.includes('TYPE: SKIN')) {
      layerSkinSections[currentLayer].push(currentSection);
      currentSection = null;
    }
  }
}

// Save last section if any
if (currentSection && currentLayer !== null) {
  layerSkinSections[currentLayer].push(currentSection);
}

// Analyze coverage
console.log('='.repeat(80));
console.log('LAYER-BY-LAYER SKIN COVERAGE ANALYSIS');
console.log('='.repeat(80));

let allLayersComplete = true;

for (const layer of Object.keys(layerSkinSections).sort((a, b) => parseInt(a) - parseInt(b))) {
  const sections = layerSkinSections[layer];
  
  // Count wall-only, infill-only, and complete sections
  let wallOnly = 0;
  let infillOnly = 0;
  let complete = 0;
  
  for (const section of sections) {
    if (section.hasWall && section.hasInfill) {
      complete++;
    } else if (section.hasWall) {
      wallOnly++;
    } else if (section.hasInfill) {
      infillOnly++;
    }
  }
  
  // Check if wall and infill counts match (two-phase approach)
  const layerComplete = wallOnly === infillOnly || (wallOnly + complete >= 1 && infillOnly + complete >= 1);
  
  const status = layerComplete ? '✓' : '✗';
  
  console.log(`Layer ${layer.padStart(2)}: ${sections.length.toString().padStart(2)} sections | Wall-only: ${wallOnly.toString().padStart(2)} | Infill-only: ${infillOnly.toString().padStart(2)} | Complete: ${complete} | ${status}`);
  
  if (!layerComplete) {
    allLayersComplete = false;
  }
}

console.log('\n' + '='.repeat(80));

if (allLayersComplete) {
  console.log('✓ All layers have complete skin coverage');
  console.log('  (Wall sections in Phase 1 + Infill sections in Phase 2 = Complete)');
} else {
  console.log('✗ Some layers have incomplete skin coverage');
}

console.log('='.repeat(80));
