const { Polyslice, Printer, Filament, Loader } = require('./src/index');

async function testSlicing() {
  const mesh = await Loader.loadSTL('resources/testing/obj_2_Assembly_B.stl');
  
  console.log('Testing slicing performance...\n');
  
  const configs = [
    { name: 'No infill, no exposure', infillDensity: 0, exposureDetection: false },
    { name: 'With infill, no exposure', infillDensity: 20, exposureDetection: false },
    { name: 'No infill, with exposure', infillDensity: 0, exposureDetection: true }
  ];
  
  for (const config of configs) {
    console.log(`\nTest: ${config.name}`);
    console.log('='.repeat(50));
    
    const slicer = new Polyslice({
      printer: new Printer('Ender3'),
      filament: new Filament('PrusamentPLA'),
      verbose: false,
      infillDensity: config.infillDensity,
      exposureDetection: config.exposureDetection
    });
    
    const startTime = Date.now();
    const gcode = slicer.slice(mesh);
    const elapsed = Date.now() - startTime;
    
    console.log(`Time: ${(elapsed / 1000).toFixed(1)}s`);
    console.log(`G-code size: ${(gcode.length / 1024).toFixed(0)}KB`);
    
    // Check for invalid coordinates
    const lines = gcode.split('\n');
    const invalidLines = lines.filter(l => {
      const match = l.match(/X(-?\d+\.?\d*) Y(-?\d+\.?\d*)/);
      if (match) {
        const x = parseFloat(match[1]);
        const y = parseFloat(match[2]);
        return Math.abs(x) > 300 || Math.abs(y) > 300;
      }
      return false;
    });
    
    console.log(`Invalid coordinates (|x| or |y| > 300): ${invalidLines.length}`);
    if (invalidLines.length > 0) {
      console.log(`  First invalid: ${invalidLines[0].trim()}`);
    }
  }
}

testSlicing().catch(console.error);
