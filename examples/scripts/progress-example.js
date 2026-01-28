/**
 * Example: Demonstrate progress callback functionality during slicing.
 *
 * This example shows how to use the progressCallback option to provide
 * real-time feedback during the slicing process. This is especially
 * useful for long slices that might take several minutes.
 *
 * Usage:
 *   node examples/scripts/progress-example.js
 */

const { Polyslice, Printer, Filament } = require("../../src/index");
const THREE = require("three");

// Simple progress bar utility
function createProgressBar(current, total, barLength = 40) {
  const percent = Math.floor((current / total) * 100);
  const filled = Math.floor((current / total) * barLength);
  const empty = barLength - filled;
  const bar = '█'.repeat(filled) + '░'.repeat(empty);
  return `[${bar}] ${percent}%`;
}

// Track last stage to add newlines between stages
let lastStage = null;

function main() {
  console.log("Polyslice Progress Callback Example");
  console.log("====================================\n");

  const printer = new Printer("Ender3");
  const filament = new Filament("GenericPLA");

  console.log("Configuration:");
  console.log(`- Printer: ${printer.model}`);
  console.log(`- Filament: ${filament.name}`);
  console.log();

  // Create a test mesh (20mm cube)
  const geometry = new THREE.BoxGeometry(20, 20, 20);
  const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
  const cube = new THREE.Mesh(geometry, material);

  console.log("Creating slicer with custom progress callback...\n");

  const slicer = new Polyslice({
    printer: printer,
    filament: filament,
    layerHeight: 0.2,
    infillPattern: "hexagons",
    infillDensity: 20,
    testStrip: false,
    verbose: true,
    progressCallback: (progressInfo) => {
      // Add newline when stage changes
      if (lastStage && lastStage !== progressInfo.stage) {
        console.log();
      }
      lastStage = progressInfo.stage;

      // Format the output based on the stage
      if (progressInfo.stage === "slicing" && progressInfo.currentLayer && progressInfo.totalLayers) {
        // Show detailed layer progress
        const bar = createProgressBar(progressInfo.currentLayer, progressInfo.totalLayers);
        process.stdout.write(`\r${progressInfo.stage.toUpperCase()}: ${bar} - ${progressInfo.message || ''}`);
      } else {
        // Show simple progress for other stages
        const bar = createProgressBar(progressInfo.percent, 100);
        process.stdout.write(`\r${progressInfo.stage.toUpperCase()}: ${bar} - ${progressInfo.message || ''}`);
      }

      // Add newline for completion
      if (progressInfo.percent === 100) {
        console.log();
      }
    }
  });

  console.log("Starting slicing process...\n");

  const startTime = Date.now();
  const gcode = slicer.slice(cube);
  const duration = Date.now() - startTime;

  console.log();
  console.log("✅ Slicing Complete!");
  console.log(`   Duration: ${duration} ms`);
  console.log(`   G-code lines: ${gcode.split('\n').length}`);
  console.log(`   G-code size: ${(gcode.length / 1024).toFixed(2)} KB`);
}

main();
