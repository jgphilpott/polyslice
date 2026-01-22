/**
 * Analyze skin sections in G-code files to find missing infill
 */

const fs = require('fs');

const filename = process.argv[2] || 'resources/gcode/wayfinding/holes/3x3.gcode';

console.log(`\nAnalyzing: ${filename}\n`);

const gcode = fs.readFileSync(filename, 'utf-8');
const lines = gcode.split('\n');

let skinSections = [];
let currentSection = null;
let lineNumber = 0;

for (const line of lines) {
  lineNumber++;
  
  if (line.includes('TYPE: SKIN')) {
    // Start a new skin section
    if (currentSection) {
      skinSections.push(currentSection);
    }
    currentSection = {
      startLine: lineNumber,
      lines: [],
      wallLines: 0,
      infillLines: 0,
      travelLines: 0
    };
  }
  
  if (currentSection) {
    currentSection.lines.push(line);
    
    // Categorize lines
    if (line.includes('Moving to skin wall')) {
      currentSection.wallLines++;
    } else if (line.includes('Moving to skin infill line')) {
      currentSection.infillLines++;
    } else if (line.includes('G0') || (line.includes('G1') && !line.includes(' E'))) {
      currentSection.travelLines++;
    } else if (line.includes('G1') && line.includes(' E')) {
      // Extrusion move - count as infill if we're past the wall
      if (currentSection.wallLines > 0 && currentSection.lines.length > 10) {
        currentSection.infillLines++;
      } else {
        currentSection.wallLines++;
      }
    }
    
    // If we hit a new TYPE, save current section
    if (line.includes('TYPE:') && !line.includes('TYPE: SKIN')) {
      skinSections.push(currentSection);
      currentSection = null;
    }
  }
}

// Save last section if any
if (currentSection) {
  skinSections.push(currentSection);
}

// Report findings
console.log('='.repeat(80));
console.log(`Total skin sections found: ${skinSections.length}\n`);

let sectionsWithoutInfill = [];
let sectionsWithInfill = [];

for (let i = 0; i < skinSections.length; i++) {
  const section = skinSections[i];
  const hasInfill = section.infillLines > 0;
  const status = hasInfill ? '✓ Has infill' : '✗ NO INFILL';
  
  console.log(`Section ${(i + 1).toString().padStart(2)}: Line ${section.startLine.toString().padStart(4)} | Total: ${section.lines.length.toString().padStart(3)} | Wall: ${section.wallLines.toString().padStart(2)} | Infill: ${section.infillLines.toString().padStart(3)} | ${status}`);
  
  if (!hasInfill) {
    sectionsWithoutInfill.push({ num: i + 1, section });
  } else {
    sectionsWithInfill.push({ num: i + 1, section });
  }
}

console.log('\n' + '='.repeat(80));
if (sectionsWithoutInfill.length > 0) {
  console.log(`⚠️  ISSUE: ${sectionsWithoutInfill.length}/${skinSections.length} skin section(s) missing infill!`);
  console.log(`   Sections: ${sectionsWithoutInfill.map(s => s.num).join(', ')}`);
  
  // Show examples
  console.log('\n' + '='.repeat(80));
  console.log('Example sections WITHOUT infill:\n');
  
  for (let i = 0; i < Math.min(2, sectionsWithoutInfill.length); i++) {
    const { num, section } = sectionsWithoutInfill[i];
    console.log(`Section ${num} (line ${section.startLine}):`);
    console.log(section.lines.slice(0, 20).join('\n'));
    console.log('...\n');
  }
  
  // Compare with sections that DO have infill
  if (sectionsWithInfill.length > 0) {
    console.log('='.repeat(80));
    console.log('Example sections WITH infill (for comparison):\n');
    
    for (let i = 0; i < Math.min(1, sectionsWithInfill.length); i++) {
      const { num, section } = sectionsWithInfill[i];
      console.log(`Section ${num} (line ${section.startLine}):`);
      console.log(section.lines.slice(0, 30).join('\n'));
      console.log('...\n');
    }
  }
} else {
  console.log('✓ All skin sections have infill');
}
console.log('='.repeat(80));
