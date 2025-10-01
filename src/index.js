/**
 * Polyslice - An FDM slicer designed specifically for three.js
 *
 * Main entry point for the polyslice package.
 *
 * @author Jacob Philpott
 * @license MIT
 */

const Polyslice = require('./polyslice');
const Printer = require('./config/printer');
const Filament = require('./config/filament');

// Re-export the main class.
module.exports = Polyslice;

// Named exports for convenience.
module.exports.Polyslice = Polyslice;
module.exports.Printer = Printer;
module.exports.Filament = Filament;

// Export default for ES module compatibility.
module.exports.default = Polyslice;
