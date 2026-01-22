/**
 * Test script to analyze skin infill generation for sheets with holes
 */

const { Polyslice, Printer, Filament } = require('./src/index');
const THREE = require('three');
const { Polytree } = require('@jgphilpott/polytree');
const fs = require('fs');

console.log('Testing Skin Infill Generation\n');

/**
 * Create a simple test sheet with a single hole
 */
async function createTestSheet() {
  // Create a small sheet: 24mm x 24mm x 1.4mm (fits well within build plate)
  const sheetGeometry = new THREE.BoxGeometry(24, 24, 1.4);
  const sheetMesh = new THREE.Mesh(sheetGeometry, new THREE.MeshBasicMaterial());

  // Create a hole in the center (radius 2mm)
  const holeGeometry = new THREE.CylinderGeometry(2, 2, 2.8, 32);
  const holeMesh = new THREE.Mesh(holeGeometry, new THREE.MeshBasicMaterial());
  holeMesh.rotation.x = Math.PI / 2;
  holeMesh.position.set(0, 0, 0);
  holeMesh.updateMatrixWorld();

  // Subtract hole from sheet
  const resultMesh = await Polytree.subtract(sheetMesh, holeMesh);

  // Position the sheet at build plate
  const finalMesh = new THREE.Mesh(resultMesh.geometry, resultMesh.material);
  finalMesh.position.set(0, 0, 0.7); // Half thickness
  finalMesh.updateMatrixWorld();

  return finalMesh;
}

(async () => {
  try {
    // Create test mesh
    console.log('Creating test sheet with hole...');
    const mesh = await createTestSheet();

    // Configure slicer
    const printer = new Printer('Ender3');
    const filament = new Filament('GenericPLA');

    const slicer = new Polyslice({
      printer: printer,
      filament: filament,
      shellSkinThickness: 0.4,  // 2 layers with 0.2mm height
      shellWallThickness: 0.4,  // 1 wall with 0.4mm nozzle
      lengthUnit: 'millimeters',
      infillPattern: 'grid',
      infillDensity: 20,
      bedTemperature: 0,
      layerHeight: 0.2,
      testStrip: false,
      metadata: false,
      verbose: true
    });

    console.log('Slicing...\n');
    const gcode = slicer.slice(mesh);

    // Analyze the G-code
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
          hasInfillLines: false
        };
      }
      
      if (currentSection) {
        currentSection.lines.push(line);
        
        // Check if this is an infill line (not a travel move, not a skin wall move)
        // Infill lines should have:
        // - Extrusion (E parameter)
        // - Not be immediately after "Moving to skin wall" or "Moving to skin infill line"
        if (line.includes('G1') && line.includes(' E') && 
            !line.includes('Moving to skin') &&
            currentSection.lines.length > 5) {  // Skip the first few lines (skin wall)
          currentSection.hasInfillLines = true;
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
    console.log('SKIN SECTION ANALYSIS');
    console.log('='.repeat(80));
    console.log(`Total skin sections found: ${skinSections.length}\n`);

    let sectionsWithoutInfill = [];
    
    for (let i = 0; i < skinSections.length; i++) {
      const section = skinSections[i];
      const status = section.hasInfillLines ? '✓ Has infill' : '✗ NO INFILL';
      console.log(`Section ${i + 1} (line ${section.startLine}): ${section.lines.length} lines - ${status}`);
      
      if (!section.hasInfillLines) {
        sectionsWithoutInfill.push(i + 1);
      }
    }

    console.log('\n' + '='.repeat(80));
    if (sectionsWithoutInfill.length > 0) {
      console.log(`⚠️  ISSUE FOUND: ${sectionsWithoutInfill.length} skin section(s) missing infill lines!`);
      console.log(`   Sections: ${sectionsWithoutInfill.join(', ')}`);
    } else {
      console.log('✓ All skin sections have infill lines');
    }
    console.log('='.repeat(80));

    // Save output for inspection
    fs.writeFileSync('/home/runner/work/polyslice/polyslice/test-skin-output.gcode', gcode);
    console.log('\n✓ G-code saved to test-skin-output.gcode');

    // Show a few examples of sections without infill
    if (sectionsWithoutInfill.length > 0) {
      console.log('\nExample sections without infill:\n');
      for (let i = 0; i < Math.min(2, sectionsWithoutInfill.length); i++) {
        const sectionIdx = sectionsWithoutInfill[i] - 1;
        const section = skinSections[sectionIdx];
        console.log(`Section ${sectionsWithoutInfill[i]} (starting line ${section.startLine}):`);
        console.log(section.lines.slice(0, 30).join('\n'));
        console.log('...\n');
      }
    }

  } catch (error) {
    console.error('Error:', error.message);
    console.error(error.stack);
  }
})();
