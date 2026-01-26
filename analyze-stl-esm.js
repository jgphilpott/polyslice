const fs = require('fs');
const THREE = await import('three');

async function analyzeSTL(filePath) {
  const { STLLoader } = await import('three/examples/jsm/loaders/STLLoader.js');
  const buffer = fs.readFileSync(filePath);
  const loader = new STLLoader();
  const geometry = loader.parse(buffer.buffer);
  
  geometry.computeBoundingBox();
  const bbox = geometry.boundingBox;
  
  const triangles = geometry.index ? geometry.index.count / 3 : geometry.attributes.position.count / 3;
  const size = new THREE.Vector3();
  bbox.getSize(size);
  
  console.log(`File: ${filePath.split('/').pop()}`);
  console.log(`Triangles: ${Math.floor(triangles)}`);
  console.log(`Bounding Box:`);
  console.log(`  Min: (${bbox.min.x.toFixed(2)}, ${bbox.min.y.toFixed(2)}, ${bbox.min.z.toFixed(2)})`);
  console.log(`  Max: (${bbox.max.x.toFixed(2)}, ${bbox.max.y.toFixed(2)}, ${bbox.max.z.toFixed(2)})`);
  console.log(`  Size: ${size.x.toFixed(2)} x ${size.y.toFixed(2)} x ${size.z.toFixed(2)} mm`);
  console.log(`  Aspect Ratio: X:Y:Z = ${(size.x/size.z).toFixed(2)}:${(size.y/size.z).toFixed(2)}:1`);
  
  // Calculate complexity for different orientations
  const layerHeight = 0.2;
  
  // Original orientation (slicing along Z)
  const layersZ = Math.ceil(size.z / layerHeight);
  const complexityZ = triangles * layersZ;
  
  // Rotated 90° on X (slicing along what was Y)
  const layersRotatedX = Math.ceil(size.y / layerHeight);
  const complexityRotatedX = triangles * layersRotatedX;
  
  console.log(`\nComplexity Analysis (layer height ${layerHeight}mm):`);
  console.log(`  Original (Z-up): ${layersZ} layers, score ${Math.floor(complexityZ / 1000)}k`);
  console.log(`  Rotated 90° X: ${layersRotatedX} layers, score ${Math.floor(complexityRotatedX / 1000)}k`);
  console.log(`  Speedup: ${(complexityZ / complexityRotatedX).toFixed(1)}x faster when rotated`);
}

async function main() {
  const files = [
    'resources/testing/obj_1_Key+hanger+with+shelf+home.stl',
    'resources/testing/obj_2_Assembly_B.stl'
  ];
  
  for (const file of files) {
    console.log('\n' + '='.repeat(70));
    await analyzeSTL(file);
  }
  console.log('\n' + '='.repeat(70));
}

main().catch(console.error);
