const { Polyslice, Printer, Filament, Loader } = require('./src/index');

async function testSlicing() {
  const mesh = await Loader.loadSTL('resources/testing/obj_2_Assembly_B.stl');
  
  const geo = mesh.geometry;
  geo.computeBoundingBox();
  const bbox = geo.boundingBox;
  
  console.log('Mesh bounding box:');
  console.log(`  Min: (${bbox.min.x.toFixed(2)}, ${bbox.min.y.toFixed(2)}, ${bbox.min.z.toFixed(2)})`);
  console.log(`  Max: (${bbox.max.x.toFixed(2)}, ${bbox.max.y.toFixed(2)}, ${bbox.max.z.toFixed(2)})`);
  console.log(`  Height: ${(bbox.max.z - bbox.min.z).toFixed(2)}mm`);
  
  const slicer = new Polyslice({
    printer: new Printer('Ender3'),
    filament: new Filament('PrusamentPLA'),
    verbose: true
  });
  
  console.log('\nSlicing...');
  const gcode = slicer.slice(mesh);
  
  // Count different comment types
  const lines = gcode.split('\n');
  const layerLines = lines.filter(l => l.includes('; LAYER:'));
  const wallLines = lines.filter(l => l.includes(';TYPE: WALL'));
  const fillLines = lines.filter(l => l.includes(';TYPE: FILL'));
  const skinLines = lines.filter(l => l.includes(';TYPE: SKIN'));
  
  console.log(`\nG-code analysis:`);
  console.log(`  Total lines: ${lines.length}`);
  console.log(`  Layer markers: ${layerLines.length}`);
  console.log(`  Wall commands: ${wallLines.length}`);
  console.log(`  Fill commands: ${fillLines.length}`);
  console.log(`  Skin commands: ${skinLines.length}`);
  
  // Show first 100 lines
  console.log('\nFirst 100 lines of G-code:');
  console.log(lines.slice(0, 100).join('\n'));
}

testSlicing().catch(console.error);
