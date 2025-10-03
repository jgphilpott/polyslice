/**
 * Generate example 3D models in various formats for testing
 * 
 * This script creates basic geometric shapes (Cube, Cylinder, Sphere, Cone, Torus)
 * in multiple sizes (1cm, 3cm, 5cm) and exports them to different file formats
 * that are commonly used in 3D printing.
 * 
 * Available exporters from three.js:
 * - STLExporter (Binary and ASCII)
 * - OBJExporter
 * - PLYExporter (Binary and ASCII)
 * - GLTFExporter (GLTF and GLB)
 * 
 * Note: 3MF, AMF, and Collada exporters are not available in three.js,
 * so these formats are skipped.
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
    
    // GLTF exporter requires too many browser APIs (FileReader, Blob, etc.)
    // Skipping GLTF export for Node.js environment
    // const gltfModule = await import('three/examples/jsm/exporters/GLTFExporter.js');
    // GLTFExporter = gltfModule.GLTFExporter;
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
    const dirs = ['stl', 'obj', 'ply'];
    dirs.forEach(dir => {
        const dirPath = path.join(__dirname, dir);
        if (!fs.existsSync(dirPath)) {
            fs.mkdirSync(dirPath, { recursive: true });
        }
    });
}

// Export to STL (binary)
function exportSTL(mesh, filename) {
    const exporter = new STLExporter();
    const result = exporter.parse(mesh, { binary: true });
    const outputPath = path.join(__dirname, 'stl', filename);
    // Result is a DataView, get the underlying ArrayBuffer
    const buffer = result.buffer;
    fs.writeFileSync(outputPath, Buffer.from(buffer));
    console.log(`✓ Generated ${outputPath}`);
}

// Export to OBJ
function exportOBJ(mesh, filename) {
    const exporter = new OBJExporter();
    const result = exporter.parse(mesh);
    const outputPath = path.join(__dirname, 'obj', filename);
    fs.writeFileSync(outputPath, result);
    console.log(`✓ Generated ${outputPath}`);
}

// Export to PLY (binary)
function exportPLY(mesh, filename) {
    return new Promise((resolve, reject) => {
        const exporter = new PLYExporter();
        exporter.parse(mesh, (result) => {
            try {
                const outputPath = path.join(__dirname, 'ply', filename);
                fs.writeFileSync(outputPath, Buffer.from(result));
                console.log(`✓ Generated ${outputPath}`);
                resolve();
            } catch (error) {
                reject(error);
            }
        }, { binary: true });
    });
}

// Export to GLTF
function exportGLTF(mesh, filename) {
    return new Promise((resolve, reject) => {
        const exporter = new GLTFExporter();
        exporter.parse(mesh, (result) => {
            try {
                const outputPath = path.join(__dirname, 'gltf', filename);
                const output = JSON.stringify(result, null, 2);
                fs.writeFileSync(outputPath, output);
                console.log(`✓ Generated ${outputPath}`);
                resolve();
            } catch (error) {
                reject(error);
            }
        }, { binary: false });
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
                exportSTL(mesh, `${baseName}.stl`);
                totalFiles++;
                
                // Export to OBJ
                exportOBJ(mesh, `${baseName}.obj`);
                totalFiles++;
                
                // Export to PLY (async)
                await exportPLY(mesh, `${baseName}.ply`);
                totalFiles++;
                
                // GLTF export skipped - requires browser APIs not available in Node.js
                
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
    console.log('    ├── stl/     (15 files)');
    console.log('    ├── obj/     (15 files)');
    console.log('    └── ply/     (15 files)');
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

