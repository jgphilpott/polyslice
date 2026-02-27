/**
 * UI Module
 * Handles creation of legends, sliders, GUI, and visibility controls
 */

import { GUI } from 'three/addons/libs/lil-gui.module.min.js';
import { saveSlicingSettings, loadSlicingSettings } from './state.js';

/**
 * Create the legends for movement types and axes.
 */
export function createLegend() {
  const legendHTML = `
        <div class="legend-container">
            <div id="legend">
                <h3>Movement Types</h3>
                <div class="legend-item">
                    <input type="checkbox" class="legend-checkbox" data-type="WALL-OUTER" checked />
                    <div class="legend-color" style="background-color: #ff6600;"></div>
                    <span>Outer Wall</span>
                </div>
                <div class="legend-item">
                    <input type="checkbox" class="legend-checkbox" data-type="WALL-INNER" checked />
                    <div class="legend-color" style="background-color: #ff9933;"></div>
                    <span>Inner Wall</span>
                </div>
                <div class="legend-item">
                    <input type="checkbox" class="legend-checkbox" data-type="SKIN" checked />
                    <div class="legend-color" style="background-color: #ffcc00;"></div>
                    <span>Skin (Top/Bottom)</span>
                </div>
                <div class="legend-item">
                    <input type="checkbox" class="legend-checkbox" data-type="FILL" checked />
                    <div class="legend-color" style="background-color: #00ccff;"></div>
                    <span>Infill</span>
                </div>
                <div class="legend-item">
                    <input type="checkbox" class="legend-checkbox" data-type="SUPPORT" checked />
                    <div class="legend-color" style="background-color: #ff00ff;"></div>
                    <span>Support</span>
                </div>
                <div class="legend-item">
                    <input type="checkbox" class="legend-checkbox" data-type="SKIRT" checked />
                    <div class="legend-color" style="background-color: #888888;"></div>
                    <span>Adhesion (Skirt/Brim/Raft)</span>
                </div>
                <div class="legend-item">
                    <input type="checkbox" class="legend-checkbox" data-type="path" checked />
                    <div class="legend-color" style="background-color: #ff0000;"></div>
                    <span>Travel (Non-extruding)</span>
                </div>
                <div class="legend-item">
                    <input type="checkbox" class="legend-checkbox" data-type="extruded" checked />
                    <div class="legend-color" style="background-color: #00ff00;"></div>
                    <span>Other Extrusion</span>
                </div>
            </div>
            <div>
                <div id="settings">
                    <h3>Settings</h3>
                    <div class="legend-item">
                        <input type="checkbox" class="legend-checkbox settings-checkbox" id="thick-lines-checkbox" />
                        <span>Thick Lines</span>
                    </div>
                    <div class="legend-item">
                        <input type="checkbox" class="legend-checkbox settings-checkbox" id="translucent-lines-checkbox" />
                        <span>Translucent Lines</span>
                    </div>
                </div>
                <div id="axes-legend">
                    <h3>Axes and Grid</h3>
                    <div class="legend-item">
                        <input type="checkbox" class="legend-checkbox axis-checkbox" data-axis="x" checked />
                        <div class="legend-color" style="background-color: #ff0000;"></div>
                        <span>X Axis</span>
                    </div>
                    <div class="legend-item">
                        <input type="checkbox" class="legend-checkbox axis-checkbox" data-axis="y" checked />
                        <div class="legend-color" style="background-color: #00ff00;"></div>
                        <span>Y Axis</span>
                    </div>
                    <div class="legend-item">
                        <input type="checkbox" class="legend-checkbox axis-checkbox" data-axis="z" checked />
                        <div class="legend-color" style="background-color: #0000ff;"></div>
                        <span>Z Axis</span>
                    </div>
                    <div class="legend-item">
                        <input type="checkbox" class="legend-checkbox axis-checkbox" data-axis="grid" checked />
                        <div class="legend-color" style="background-color: #888888;"></div>
                        <span>Grid Lines</span>
                    </div>
                </div>
            </div>
        </div>`;

  document.body.insertAdjacentHTML('beforeend', legendHTML);
}

/**
 * Create the layer slider HTML elements (dual range sliders).
 */
export function createLayerSlider() {
  const sliderHTML = `
        <div id="layer-slider-container">
            <input type="range" id="layer-slider-max" min="0" max="100" value="100" orient="vertical" tabindex="0">
            <input type="range" id="layer-slider-min" min="0" max="100" value="0" orient="vertical" tabindex="0">
            <div id="layer-info">All Layers</div>
        </div>`;

  document.body.insertAdjacentHTML('beforeend', sliderHTML);
}

/**
 * Create the horizontal move slider at the bottom of the page.
 */
export function createMoveSlider() {
  const sliderHTML = `
        <div id="move-slider-container">
            <div id="move-info">Move Progress: 0%</div>
            <input type="range" id="move-slider" min="0" max="100" value="100" tabindex="0">
        </div>`;

  document.body.insertAdjacentHTML('beforeend', sliderHTML);
}

/**
 * Create the slicing GUI for loaded 3D models.
 */
export function createSlicingGUI(sliceCallback, useDefaults = false, rotateCallback = null) {

  let slicingGUI = window.slicingGUI;

  if (slicingGUI) {
    slicingGUI.destroy();
  }

  // Load saved settings or use defaults
  const savedSettings = useDefaults ? null : loadSlicingSettings();

  const params = {
    rotationX: savedSettings?.rotationX ?? 0,
    rotationY: savedSettings?.rotationY ?? 0,
    rotationZ: savedSettings?.rotationZ ?? 0,
    printer: savedSettings?.printer || 'Ender3',
    filament: savedSettings?.filament || 'GenericPLA',
    nozzleTemperature: savedSettings?.nozzleTemperature ?? 200,
    bedTemperature: savedSettings?.bedTemperature ?? 60,
    fanSpeed: savedSettings?.fanSpeed ?? 100,
    layerHeight: savedSettings?.layerHeight || 0.2,
    shellWallThickness: savedSettings?.shellWallThickness || 0.8,
    shellSkinThickness: savedSettings?.shellSkinThickness || 0.8,
    infillDensity: savedSettings?.infillDensity || 20,
    infillPattern: savedSettings?.infillPattern || 'grid',
    adhesionEnabled: savedSettings?.adhesionEnabled ?? false,
    adhesionType: savedSettings?.adhesionType || 'skirt',
    supportEnabled: savedSettings?.supportEnabled ?? false,
    supportType: savedSettings?.supportType || 'normal',
    supportPlacement: savedSettings?.supportPlacement || 'buildPlate',
    supportThreshold: savedSettings?.supportThreshold ?? 55,
    slice: sliceCallback
  };

  const PRINTER_OPTIONS = ['Ender3', 'UltimakerS5', 'PrusaI3MK3S', 'AnycubicI3Mega', 'BambuLabP1P'];
  const FILAMENT_OPTIONS = ['GenericPLA', 'GenericPETG', 'GenericABS'];
  const INFILL_PATTERN_OPTIONS = ['grid', 'triangles', 'hexagons', 'concentric', 'gyroid', 'spiral', 'lightning'];

  slicingGUI = new GUI({ title: 'Slicer' });

  let h = slicingGUI.addFolder('Model Rotation');
  h.add(params, 'rotationX', -180, 180, 1).name('Rotation X (°)').onChange((value) => {
    saveSlicingSettings(params);
    if (rotateCallback) rotateCallback('x', value);
  });
  h.add(params, 'rotationY', -180, 180, 1).name('Rotation Y (°)').onChange((value) => {
    saveSlicingSettings(params);
    if (rotateCallback) rotateCallback('y', value);
  });
  h.add(params, 'rotationZ', -180, 180, 1).name('Rotation Z (°)').onChange((value) => {
    saveSlicingSettings(params);
    if (rotateCallback) rotateCallback('z', value);
  });

  // Apply initial rotation values to the mesh.
  if (rotateCallback) {
    rotateCallback('x', params.rotationX);
    rotateCallback('y', params.rotationY);
    rotateCallback('z', params.rotationZ);
  }

  h = slicingGUI.addFolder('Printer & Filament');
  h.add(params, 'printer', PRINTER_OPTIONS).name('Printer').onChange(() => saveSlicingSettings(params));
  h.add(params, 'filament', FILAMENT_OPTIONS).name('Filament').onChange(() => saveSlicingSettings(params));
  h.add(params, 'nozzleTemperature', 150, 300, 5).name('Nozzle Temp (°C)').onFinishChange(() => saveSlicingSettings(params));
  h.add(params, 'bedTemperature', 0, 120, 5).name('Bed Temp (°C)').onFinishChange(() => saveSlicingSettings(params));
  h.add(params, 'fanSpeed', 0, 100, 5).name('Fan Speed (%)').onFinishChange(() => saveSlicingSettings(params));

  h = slicingGUI.addFolder('Slicer Settings');
  h.add(params, 'shellWallThickness', 0.4, 2.0, 0.4).name('Shell Wall Thickness (mm)').onFinishChange(() => saveSlicingSettings(params));
  h.add(params, 'shellSkinThickness', 0.4, 2.0, 0.4).name('Shell Skin Thickness (mm)').onFinishChange(() => saveSlicingSettings(params));
  h.add(params, 'layerHeight', 0.1, 0.4, 0.05).name('Layer Height (mm)').onFinishChange(() => saveSlicingSettings(params));
  h.add(params, 'infillDensity', 0, 100, 5).name('Infill Density (%)').onFinishChange(() => saveSlicingSettings(params));
  h.add(params, 'infillPattern', INFILL_PATTERN_OPTIONS).name('Infill Pattern').onChange(() => saveSlicingSettings(params));

  h = slicingGUI.addFolder('Adhesion');
  h.add(params, 'adhesionEnabled').name('Adhesion Enabled').onChange(() => saveSlicingSettings(params));
  h.add(params, 'adhesionType', ['skirt', 'brim', 'raft']).name('Adhesion Type').onChange(() => saveSlicingSettings(params));

  h = slicingGUI.addFolder('Support');
  h.add(params, 'supportEnabled').name('Support Enabled').onChange(() => saveSlicingSettings(params));
  h.add(params, 'supportType', ['normal', 'tree']).name('Support Type').onChange(() => saveSlicingSettings(params));
  h.add(params, 'supportPlacement', ['buildPlate', 'everywhere']).name('Support Placement').onChange(() => saveSlicingSettings(params));
  h.add(params, 'supportThreshold', 0, 90, 1).name('Support Threshold (°)').onFinishChange(() => saveSlicingSettings(params));

  slicingGUI.add(params, 'slice').name('Slice');
  slicingGUI.open();

  // Store params on the GUI instance for access in sliceModel
  slicingGUI.userData = params;

  // Store globally for access
  window.slicingGUI = slicingGUI;

  return slicingGUI;
}

/**
 * Hide the slicing GUI.
 */
export function hideSlicingGUI() {
  if (window.slicingGUI) {
    window.slicingGUI.destroy();
    window.slicingGUI = null;
  }
}

/**
 * Hide the Fork Me banner.
 */
export function hideForkMeBanner() {
  const forkMe = document.getElementById('forkme');
  if (forkMe) {
    forkMe.style.display = 'none';
  }
}

/**
 * Show the Fork Me banner.
 */
export function showForkMeBanner() {
  const forkMe = document.getElementById('forkme');
  if (forkMe) {
    forkMe.style.display = '';
  }
}

/**
 * Hide Movement Types and Settings legends.
 */
export function hideGCodeLegends() {
  const legend = document.getElementById('legend');
  const settings = document.getElementById('settings');
  if (legend) {
    legend.style.display = 'none';
  }
  if (settings) {
    settings.style.display = 'none';
  }
}

/**
 * Show Movement Types and Settings legends.
 */
export function showGCodeLegends() {
  const legend = document.getElementById('legend');
  const settings = document.getElementById('settings');
  if (legend) {
    legend.style.display = '';
  }
  if (settings) {
    settings.style.display = '';
  }
}

/**
 * Show or hide the download button.
 */
export function updateDownloadButtonVisibility(hasGCode) {
  const downloadButton = document.getElementById('download');
  if (downloadButton) {
    downloadButton.style.display = hasGCode ? '' : 'none';
  }
}
