/**
 * Polyslice - An AI powered slicer designed specifically for three.js
 *
 * Main entry point for the polyslice package.
 *
 * @author Jacob Philpott
 * @license MIT
 */

const Polyslice = require('./polyslice');
const Printer = require('./config/printer');
const Filament = require('./config/filament');
const Loader = require('./loaders/loader');
const Exporter = require('./exporters/exporter');

// Re-export the main class.
module.exports = Polyslice;

// Named exports for convenience.
module.exports.Polyslice = Polyslice;
module.exports.Printer = Printer;
module.exports.Filament = Filament;
module.exports.Loader = Loader;
module.exports.Exporter = Exporter;

// Export default for ES module compatibility.
module.exports.default = Polyslice;
