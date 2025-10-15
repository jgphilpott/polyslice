/**
 * Example showing how to slice an STL model with support structures
 * This demonstrates the support generation functionality of Polyslice
 * by loading an STL file from the resources folder
 *
 * Usage:
 *   node examples/scripts/slice-arch.js
 *
 * The example loads block.test.stl by default. You can modify the script
 * to load strip.test.stl or other STL files with overhanging features.
 */

const { Polyslice, Printer, Filament } = require('../../src/index');
const fs = require('fs');
const path = require('path');

console.log('Polyslice Support Generation Example');
console.log('====================================\n');

// Create printer and filament configuration objects.
const printer = new Printer('Ender5');
const filament = new Filament('GenericPLA');

console.log('Printer & Filament Configuration:');
console.log(`- Printer: ${printer.model}`);
console.log(`- Build Volume: ${printer.getSizeX()}x${printer.getSizeY()}x${printer.getSizeZ()}mm`);
console.log(`- Filament: ${filament.name} (${filament.type.toUpperCase()})`);
console.log(`- Brand: ${filament.brand}\n`);

// Main async function to load STL and slice
async function main() {
    // Load the test STL file with overhangs
    const stlPath = path.join(__dirname, '..', '..', 'resources', 'support', 'block.test.stl');

    console.log('Loading STL file...');
    console.log(`- Path: ${stlPath}\n`);

    let mesh;

    try {
        // Load STL using three.js STLLoader with parse method
        // This is more reliable in Node.js than using the URL-based load method
        const THREE = require('three');
        const { STLLoader } = await import('three/examples/jsm/loaders/STLLoader.js');

        const buffer = fs.readFileSync(stlPath);
        const loader = new STLLoader();
        const geometry = loader.parse(buffer.buffer);
        // geometry.rotateX(Math.PI);

        // Create mesh with the loaded geometry
        const material = new THREE.MeshPhongMaterial({ color: 0x808080, specular: 0x111111, shininess: 200 });
        mesh = new THREE.Mesh(geometry, material);

        console.log('✅ STL file loaded successfully');
        console.log(`- Geometry type: ${mesh.geometry.type}`);
        console.log(`- Vertices: ${mesh.geometry.attributes.position.count}`);
        console.log(`- Triangles: ${mesh.geometry.attributes.position.count / 3}\n`);
    } catch (error) {
        console.error('❌ Failed to load STL file:', error.message);
        console.error(error.stack);
        process.exit(1);
    }

    // Create slicer instance with support enabled.
    const slicer = new Polyslice({
        printer: printer,
        filament: filament,
        shellSkinThickness: 0.8,
        shellWallThickness: 0.8,
        lengthUnit: 'millimeters',
        timeUnit: 'seconds',
        bedTemperature: 0,
        layerHeight: 0.2,
        testStrip: false,
        verbose: true,
        supportEnabled: true,
        supportType: 'normal',
        supportPlacement: 'buildPlate',
        supportThreshold: 45
    });

    console.log('Slicer Configuration:');
    console.log(`- Layer Height: ${slicer.getLayerHeight()}mm`);
    console.log(`- Nozzle Temperature: ${slicer.getNozzleTemperature()}°C`);
    console.log(`- Bed Temperature: ${slicer.getBedTemperature()}°C`);
    console.log(`- Fan Speed: ${slicer.getFanSpeed()}%`);
    console.log(`- Nozzle Diameter: ${slicer.getNozzleDiameter()}mm`);
    console.log(`- Filament Diameter: ${slicer.getFilamentDiameter()}mm`);
    console.log(`- Support Enabled: ${slicer.getSupportEnabled() ? 'Yes' : 'No'}`);
    console.log(`- Support Type: ${slicer.getSupportType()}`);
    console.log(`- Support Placement: ${slicer.getSupportPlacement()}`);
    console.log(`- Support Threshold: ${slicer.getSupportThreshold()}°`);
    console.log(`- Verbose Comments: ${slicer.getVerbose() ? 'Enabled' : 'Disabled'}\n`);

    // Slice the model with support generation.
    console.log('Slicing model with support generation...');
    const startTime = Date.now();
    const gcode = slicer.slice(mesh);
    const endTime = Date.now();

    console.log(`Slicing completed in ${endTime - startTime}ms\n`);

    // Analyze the G-code output.
    const lines = gcode.split('\n');
    const layerLines = lines.filter(line => line.includes('LAYER:'));
    const supportLines = lines.filter(line => line.toLowerCase().includes('support'));

    console.log('G-code Analysis:');
    console.log(`- Total lines: ${lines.length}`);
    console.log(`- Layers: ${layerLines.length}`);
    console.log(`- Support-related lines: ${supportLines.length}\n`);

    // Save G-code to file.
    const outputDir = path.join(__dirname, '..', 'output');

    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
    }

    const outputPath = path.join(outputDir, 'block-with-supports.gcode');
    fs.writeFileSync(outputPath, gcode);

    console.log(`✅ G-code saved to: ${outputPath}\n`);

    // Display support generation info.
    if (supportLines.length > 0) {
        console.log('Support Generation Details:');
        supportLines.slice(0, 10).forEach(line => {
            console.log(`  ${line.trim()}`);
        });

        if (supportLines.length > 10) {
            console.log(`  ... (${supportLines.length - 10} more support lines)\n`);
        }
    } else {
        console.log('⚠️  No support structures detected in G-code\n');
    }

    // Display some layer information.
    console.log('Layer Information:');
    const sampleLayers = layerLines.slice(0, 5);
    sampleLayers.forEach(line => {
        console.log(`- ${line.trim()}`);
    });

    if (layerLines.length > 5) {
        console.log(`... (${layerLines.length - 5} more layers)\n`);
    }

    console.log('✅ Support generation example completed successfully!');
    console.log('\nNotes:');
    console.log('- If no supports were generated, the model may not have overhangs');
    console.log('- The block.test.stl is a simple rectangular block without overhangs');
    console.log('- Try the strip.test.stl file which may have overhanging features');
    console.log('\nNext steps:');
    console.log('- Load the G-code in a visualizer to inspect the sliced model');
    console.log('- Try different support thresholds (30°, 45°, 60°) to see the effect');
    console.log('- Create or load models with overhangs to test support generation');
    console.log('- Experiment with supportPlacement: "buildPlate" vs "everywhere"');
}

// Run the main function
main().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
