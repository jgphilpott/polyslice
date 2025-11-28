// Require THREE, Polyslice, Printer and Filament (omit for browser)
const THREE = require("three");
const { Polyslice, Printer, Filament } = require('../../src/index');

// Create the printer and filament objects
const printer = new Printer("Ender3");
const filament = new Filament("GenericPLA");

// Create the slicer instance with the printer, filament and other configs
const slicer = new Polyslice({
  printer: printer,
  filament: filament,
  infillPattern: "triangles",
  infillDensity: 30,
  testStrip: true,
  verbose: true
});

// Create a 1cm cube (10mm x 10mm x 10mm)
const geometry = new THREE.BoxGeometry(10, 10, 10);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const cube = new THREE.Mesh(geometry, material);

// Slice the cube and generate the G-code
const gcode = slicer.slice(cube);

console.log("Successfully Generated G-code!");
