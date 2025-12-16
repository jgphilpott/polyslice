/**
 * Slicer Module
 * Handles 3D model slicing using Polyslice
 */

import { saveSlicingSettings } from './state.js';
import { hideSlicingGUI } from './ui.js';

/**
 * Slice the loaded 3D model using Polyslice.
 */
export function sliceModel(loadedModel, currentFilename, loadGCodeCallback) {

  if (!loadedModel) {
    console.error('No model loaded for slicing');
    alert('No model loaded for slicing');
    return;
  }

  if (!window.Polyslice) {
    console.error('Polyslice library not loaded');
    alert('Polyslice library not loaded. Please refresh the page.');
    return;
  }

  try {
    // Get GUI parameters
    const slicingGUI = window.slicingGUI;
    const params = slicingGUI.userData;

    // Save GUI settings to localStorage
    saveSlicingSettings(params);

    // Create printer and filament configurations
    const printer = new window.Polyslice.Printer(params.printer);
    const filament = new window.Polyslice.Filament(params.filament);

    // Create the slicer instance
    const slicer = new window.Polyslice.Polyslice({
      printer: printer,
      filament: filament,
      layerHeight: params.layerHeight,
      infillPattern: params.infillPattern,
      infillDensity: params.infillDensity,
      verbose: true
    });

    console.log('Slicing model with settings:', params);

    // Slice the loaded mesh
    const gcode = slicer.slice(loadedModel);

    console.log('Slicing complete! G-code generated.');

    // Load the resulting G-code into the visualizer
    const filename = currentFilename ? currentFilename.replace(/\.[^/.]+$/, '.gcode') : 'sliced.gcode';
    loadGCodeCallback(gcode, filename);

    // Hide the slicing GUI after successful slicing
    hideSlicingGUI();

  } catch (error) {
    console.error('Error slicing model:', error);
    alert('Error slicing model: ' + error.message);
  }

}
