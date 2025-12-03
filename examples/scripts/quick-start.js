/// SETUP ///

// Require all the necessary modules
const path = require("path");
const THREE = require("three");
const { Polyslice, Printer, Filament, Loader, Exporter } = require("../../src/index");

/// CONFIGURATION ///

// Create the printer and filament objects
const printer = new Printer("Ender3");
const filament = new Filament("GenericPLA");

// Both classes have a full set of getters and setters
// These can be used to customize the objects after initialization
printer.getSize();
filament.setBedTemperature(0);

// Create the slicer instance with the printer, filament and other config options
// Config options passed here will override printer and filament configs, if they conflict
const slicer = new Polyslice({
    printer: printer,
    filament: filament,
    infillPattern: "triangles",
    infillDensity: 30,
    testStrip: true,
    metadata: true,
    verbose: true
});

// The slicer can also be configured further after initialization
slicer.getLayerHeight();
slicer.setWipeNozzle(true);
slicer.setInfillPattern("hexagons");

/// SLICE FROM THREE.JS ///

// Create a 1cm cube (10mm x 10mm x 10mm)
const geometry = new THREE.BoxGeometry(10, 10, 10);
const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
const cube = new THREE.Mesh(geometry, material);

// Slice the cube and generate the G-code
const gcode = slicer.slice(cube);

/// SLICE FROM EXTERNAL FILE ///

// Alternatively you can also load your design from an external file
Loader.loadSTL(path.join(__dirname, "../../resources/stl/cube/cube-1cm.stl"))
      .then((meshFromSTL) => {
          const gcodeFromSTL = slicer.slice(meshFromSTL);
      }).catch((error) => {
          console.error("Failed to load or slice STL:", error.message);
      });

/// SAVE G-CODE TO FILE ///

// You can then use the Exporter class to save the G-code to a file
Exporter.saveToFile(gcode, path.join(__dirname, "../output/quick-start.gcode"))
        .then((savedPath) => {
            console.log("Saved G-code to:", savedPath);
        }).catch((error) => {
            console.error("Failed to save G-code:", error.message);
        });

/// STREAM G-CODE TO PRINTER ///

// You can also stream the G-code directly to a printer via a serial port connection
// Note: This requires serialport installed and a connected printer
const serialPath = "/dev/ttyUSB0"; // Update this to your printers serial path
const baudRate = 115200; // Standard baud rate, update if necessary
const streamingOptions = {}; // Additional streaming options

Exporter.connectSerial({ path: serialPath, baudRate })
        .then(async () => {
            console.log(`Connected to: ${serialPath} @ ${baudRate}`);
            await Exporter.streamGCodeWithAck(gcode, streamingOptions);
            console.log("Streaming complete. Disconnecting...");
            await Exporter.disconnectSerial();
            console.log("Disconnected.");
        }).catch((error) => {
            console.error("Serial streaming skipped/failed:", error.message);
        });
