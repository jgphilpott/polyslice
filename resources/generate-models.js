/**
 * Generate example 3D models in various formats for testing
 *
 * This script creates basic geometric shapes (Cube, Cylinder, Sphere, Cone, Torus)
 * in multiple sizes (1cm, 3cm, 5cm) and exports them to different file formats
 * that are commonly used in 3D printing.
 *
 * Available exporters from three.js:
 *
 * - STLExporter (Binary and ASCII)
 * - OBJExporter
 * - PLYExporter (Binary and ASCII)
 */

const fs = require('fs');
const path = require('path');
const THREE = require('three');

// Polyfills for browser APIs in Node.js
if (typeof global.requestAnimationFrame === 'undefined') {
    global.requestAnimationFrame = (callback) => {
        return setTimeout(callback, 0);
    };
}

// Simple FileReader polyfill for Node.js (limited functionality)
if (typeof global.FileReader === 'undefined') {
    global.FileReader = class FileReader {
        readAsArrayBuffer(blob) {
            if (this.onload) {
                setTimeout(() => {
                    this.onload({ target: { result: Buffer.alloc(0) } });
                }, 0);
            }
        }
        readAsDataURL(blob) {
            if (this.onload) {
                setTimeout(() => {
                    this.onload({ target: { result: 'data:application/octet-stream;base64,' } });
                }, 0);
            }
        }
    };
}

// Import exporters
let STLExporter, OBJExporter, PLYExporter, GLTFExporter;

async function loadExporters() {
    const stlModule = await import('three/examples/jsm/exporters/STLExporter.js');
    STLExporter = stlModule.STLExporter;

    const objModule = await import('three/examples/jsm/exporters/OBJExporter.js');
    OBJExporter = objModule.OBJExporter;

    const plyModule = await import('three/examples/jsm/exporters/PLYExporter.js');
    PLYExporter = plyModule.PLYExporter;
}

// Define shapes and sizes
const shapes = [
    { name: 'cube', generator: (size) => new THREE.BoxGeometry(size, size, size) },
    { name: 'cylinder', generator: (size) => new THREE.CylinderGeometry(size/2, size/2, size, 32) },
    { name: 'sphere', generator: (size) => new THREE.SphereGeometry(size/2, 32, 32) },
    { name: 'cone', generator: (size) => new THREE.ConeGeometry(size/2, size, 32) },
    { name: 'torus', generator: (size) => new THREE.TorusGeometry(size/3, size/6, 16, 32) }
];

const sizes = [
    { name: '1cm', value: 10 },  // 10mm = 1cm
    { name: '3cm', value: 30 },  // 30mm = 3cm
    { name: '5cm', value: 50 }   // 50mm = 5cm
];

// Ensure directories exist
function ensureDirectories() {
    const formats = ['stl', 'obj', 'ply'];
    const shapeNames = ['cube', 'cylinder', 'sphere', 'cone', 'torus'];

    formats.forEach(format => {
        shapeNames.forEach(shapeName => {
            const dirPath = path.join(__dirname, format, shapeName);
            if (!fs.existsSync(dirPath)) {
                fs.mkdirSync(dirPath, { recursive: true });
            }
        });
    });
}

// Export to STL (binary)
function exportSTL(mesh, shapeName, filename) {
    const exporter = new STLExporter();
    const result = exporter.parse(mesh, { binary: true });
    const outputPath = path.join(__dirname, 'stl', shapeName, filename);
    // Result is a DataView, get the underlying ArrayBuffer
    const buffer = result.buffer;
    fs.writeFileSync(outputPath, Buffer.from(buffer));
    console.log(`✓ Generated ${outputPath}`);
}

// Export to OBJ
function exportOBJ(mesh, shapeName, filename) {
    const exporter = new OBJExporter();
    const result = exporter.parse(mesh);
    const outputPath = path.join(__dirname, 'obj', shapeName, filename);
    fs.writeFileSync(outputPath, result);
    console.log(`✓ Generated ${outputPath}`);
}

// Export to PLY (binary)
function exportPLY(mesh, shapeName, filename) {
    return new Promise((resolve, reject) => {
        const exporter = new PLYExporter();
        exporter.parse(mesh, (result) => {
            try {
                const outputPath = path.join(__dirname, 'ply', shapeName, filename);
                fs.writeFileSync(outputPath, Buffer.from(result));
                console.log(`✓ Generated ${outputPath}`);
                resolve();
            } catch (error) {
                reject(error);
            }
        }, { binary: true });
    });
}

// Generate all models
async function generateModels() {
    console.log('Generating 3D model files...\n');

    // Load exporters
    await loadExporters();

    // Ensure output directories exist
    ensureDirectories();

    let totalFiles = 0;

    // Generate each combination of shape and size
    for (const shape of shapes) {
        for (const size of sizes) {
            // Create geometry
            const geometry = shape.generator(size.value);

            // Create material (simple for export)
            const material = new THREE.MeshPhongMaterial({
                color: 0x808080,
                flatShading: false
            });

            // Create mesh
            const mesh = new THREE.Mesh(geometry, material);

            // Generate filename
            const baseName = `${shape.name}-${size.name}`;

            try {

                // Export to STL
                exportSTL(mesh, shape.name, `${baseName}.stl`);
                totalFiles++;

                // Export to OBJ
                exportOBJ(mesh, shape.name, `${baseName}.obj`);
                totalFiles++;

                // Export to PLY (async)
                await exportPLY(mesh, shape.name, `${baseName}.ply`);
                totalFiles++;

            } catch (error) {
                console.error(`✗ Error generating ${baseName}:`, error.message);
            }

            // Clean up
            geometry.dispose();
            material.dispose();
        }
    }

    console.log(`\n✓ Successfully generated ${totalFiles} files!`);
    console.log('\nFile structure:');
    console.log('  resources/');
    console.log('    ├── stl/');
    console.log('    │   ├── cube/     (3 files)');
    console.log('    │   ├── cylinder/ (3 files)');
    console.log('    │   ├── sphere/   (3 files)');
    console.log('    │   ├── cone/     (3 files)');
    console.log('    │   └── torus/    (3 files)');
    console.log('    ├── obj/');
    console.log('    │   ├── cube/     (3 files)');
    console.log('    │   ├── cylinder/ (3 files)');
    console.log('    │   ├── sphere/   (3 files)');
    console.log('    │   ├── cone/     (3 files)');
    console.log('    │   └── torus/    (3 files)');
    console.log('    └── ply/');
    console.log('        ├── cube/     (3 files)');
    console.log('        ├── cylinder/ (3 files)');
    console.log('        ├── sphere/   (3 files)');
    console.log('        ├── cone/     (3 files)');
    console.log('        └── torus/    (3 files)');
    console.log('\nShapes: cube, cylinder, sphere, cone, torus');
    console.log('Sizes:  1cm, 3cm, 5cm');
    console.log('\nFormats not generated:');
    console.log('  - 3MF, AMF, Collada: No exporters available in three.js');
    console.log('  - GLTF: Requires browser APIs not available in Node.js');
}

// Run the generator
generateModels().catch(error => {
    console.error('Error generating models:', error);
    process.exit(1);
});
