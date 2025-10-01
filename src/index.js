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

// Re-export the main class.
module.exports = Polyslice;

// Named exports for convenience.
module.exports.Polyslice = Polyslice;
module.exports.Printer = Printer;

// Export default for ES module compatibility.
module.exports.default = Polyslice;
