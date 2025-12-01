/**
 * G-code Visualizer
 * A browser-based tool to visualize G-code files and 3D model files using Three.js
 */

import * as THREE from 'three';
import { GCodeLoaderExtended } from './libs/GCodeLoaderExtended.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { STLLoader } from 'three/addons/loaders/STLLoader.js';
import { OBJLoader } from 'three/addons/loaders/OBJLoader.js';
import { ThreeMFLoader } from 'three/addons/loaders/3MFLoader.js';
import { AMFLoader } from 'three/addons/loaders/AMFLoader.js';
import { PLYLoader } from 'three/addons/loaders/PLYLoader.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { ColladaLoader } from 'three/addons/loaders/ColladaLoader.js';

// Make THREE available globally for the Polyslice loader.
window.THREE = Object.assign({}, THREE, {
  STLLoader,
  OBJLoader,
  ThreeMFLoader,
  AMFLoader,
  PLYLoader,
  GLTFLoader,
  ColladaLoader
});

// Global variables.
let scene, camera, renderer, controls;
let gcodeObject = null;
let meshObject = null; // For 3D model meshes
let axesLines;
let gridHelper = null;
let allLayers = [];
let layersByIndex = {}; // Map layer index to LineSegments
let layerCount = 0; // Total number of actual layers from LAYER comments
let layerSliderMin = null;
let layerSliderMax = null;
let moveSlider = null;
let isFirstUpload = true; // Track if this is the first G-code upload

// File extensions for 3D models vs G-code.
const MODEL_EXTENSIONS = ['stl', 'obj', '3mf', 'amf', 'ply', 'gltf', 'glb', 'dae'];
const GCODE_EXTENSIONS = ['gcode', 'gco', 'nc'];

// Initialize the visualizer on page load.
window.addEventListener('DOMContentLoaded', init);

/**
 * Initialize the Three.js scene, camera, renderer, and controls.
 */
function init() {
  // Create scene.
  scene = new THREE.Scene();
  scene.background = new THREE.Color(0x1a1a1a);

  // Create camera.
  camera = new THREE.PerspectiveCamera(
    75,
    window.innerWidth / window.innerHeight,
    0.1,
    1000
  );
  camera.position.set(300, 200, -300); // Moved Y axis to opposite side
  camera.lookAt(0, 0, 0);

  // Create renderer.
  renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.setPixelRatio(window.devicePixelRatio);
  document.getElementById('canvas-container').appendChild(renderer.domElement);

  // Add orbit controls.
  controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.05;
  controls.screenSpacePanning = false;
  controls.minDistance = 10;
  controls.maxDistance = 500;

  // Add lights.
  const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
  scene.add(ambientLight);

  const directionalLight = new THREE.DirectionalLight(0xffffff, 0.4);
  directionalLight.position.set(10, 10, 5);
  scene.add(directionalLight);

  // Add custom axes (longer and thicker).
  createAxes();

  // Add grid helper.
  createGridHelper();

  // Add legend.
  createLegend();

  // Add layer slider.
  createLayerSlider();

  // Add move slider.
  createMoveSlider();

  // Set up event listeners.
  setupEventListeners();

  // Handle window resize.
  window.addEventListener('resize', onWindowResize, false);

  // Add custom keyboard controls for WASD camera tilt and arrow key position movement.
  setupKeyboardControls();

  // Add double-click handler for line focus.
  setupDoubleClickHandler();

  // Start animation loop.
  animate();
}

/**
 * Create custom axes with proper colors and thickness.
 */
const AXIS_LENGTH = 220; // Single source of truth for axis & grid sizing

function createAxes() {
  const axisLength = AXIS_LENGTH;
  const axisThickness = 3;

  // G-code coordinate system: X (red), Y (green), Z (blue, vertical up)
  // GCodeLoader rotates by -90° on X, so: G-code X→X, Y→Z, Z→Y in Three.js

  // Create X axis (red) - G-code X axis.
  const xGeometry = new THREE.BufferGeometry().setFromPoints([
    new THREE.Vector3(0, 0, 0),
    new THREE.Vector3(axisLength, 0, 0),
  ]);
  const xMaterial = new THREE.LineBasicMaterial({
    color: 0xff0000,
    linewidth: axisThickness,
  });
  const xAxis = new THREE.Line(xGeometry, xMaterial);
  scene.add(xAxis);

  // Create Y axis (green) - G-code Y axis (maps to Three.js Z).
  const yGeometry = new THREE.BufferGeometry().setFromPoints([
    new THREE.Vector3(0, 0, 0),
    new THREE.Vector3(0, 0, -axisLength), // Moved to opposite side
  ]);
  const yMaterial = new THREE.LineBasicMaterial({
    color: 0x00ff00,
    linewidth: axisThickness,
  });
  const yAxis = new THREE.Line(yGeometry, yMaterial);
  scene.add(yAxis);

  // Create Z axis (blue) - G-code Z axis (maps to Three.js Y, vertical up).
  const zGeometry = new THREE.BufferGeometry().setFromPoints([
    new THREE.Vector3(0, 0, 0),
    new THREE.Vector3(0, axisLength, 0),
  ]);
  const zMaterial = new THREE.LineBasicMaterial({
    color: 0x0000ff,
    linewidth: axisThickness,
  });
  const zAxis = new THREE.Line(zGeometry, zMaterial);
  scene.add(zAxis);

  axesLines = [xAxis, yAxis, zAxis];
}

/**
 * Create grid helper on the XY plane.
 */
function createGridHelper() {
  // Only draw grid in X+ / Y- quadrant of G-code space -> Three.js (X >= 0, Z <= 0)
  const sizeX = AXIS_LENGTH;
  const sizeZ = AXIS_LENGTH; // magnitude for negative Z direction
  const divisions = 20; // keep 10mm spacing if AXIS_LENGTH=220 (~11mm) but acceptable
  const colorCenterLine = 0x888888;
  const colorGrid = 0x444444;

  const group = new THREE.Group();

  const materialCenter = new THREE.LineBasicMaterial({ color: colorCenterLine });
  const materialGrid = new THREE.LineBasicMaterial({ color: colorGrid });

  // Step size based on divisions
  const stepX = sizeX / divisions;
  const stepZ = sizeZ / divisions;

  // Vertical lines (parallel to Z axis, extend negative Z)
  for (let x = 0; x <= sizeX + 0.0001; x += stepX) {
    const points = [];
    points.push(new THREE.Vector3(x, 0, 0));
    points.push(new THREE.Vector3(x, 0, -sizeZ));
    const geom = new THREE.BufferGeometry().setFromPoints(points);
    const isCenter = Math.abs(x) < 1e-6; // x==0 edge
    const line = new THREE.Line(geom, isCenter ? materialCenter : materialGrid);
    group.add(line);
  }

  // Horizontal lines (parallel to X axis, at z<=0)
  for (let z = 0; z <= sizeZ + 0.0001; z += stepZ) {
    const points = [];
    const zNeg = -z; // convert to negative Z
    points.push(new THREE.Vector3(0, 0, zNeg));
    points.push(new THREE.Vector3(sizeX, 0, zNeg));
    const geom = new THREE.BufferGeometry().setFromPoints(points);
    const isCenter = Math.abs(z) < 1e-6; // z==0 edge
    const line = new THREE.Line(geom, isCenter ? materialCenter : materialGrid);
    group.add(line);
  }

  // Store group in gridHelper reference for checkbox toggle
  gridHelper = group;
  scene.add(gridHelper);
}

/**
 * Create the legends for movement types and axes.
 */
function createLegend() {
  const legendHTML = `
        <div class="legend-container">
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
                    <span>Skirt/Brim</span>
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
        </div>
    `;

  document.body.insertAdjacentHTML('beforeend', legendHTML);

  // Setup event listeners for movement type checkboxes.
  setupMovementTypeToggles();

  // Setup event listeners for axis checkboxes.
  setupAxisToggles();

  // Setup event listeners for settings checkboxes.
  setupSettingsToggles();
}

/**
 * Setup event listeners for movement type visibility toggles.
 */
function setupMovementTypeToggles() {
  const checkboxes = document.querySelectorAll('.legend-checkbox');

  // Load saved checkbox states from localStorage
  loadCheckboxStates();

  checkboxes.forEach(checkbox => {
    checkbox.addEventListener('change', () => {
      // Save checkbox state to localStorage
      saveCheckboxStates();

      // Update visibility based on both layer slider and movement type checkboxes.
      if (allLayers.length > 0) {
        updateLayerVisibility();
      }
    });
  });
}

/**
 * Setup event listeners for axis visibility toggles.
 */
function setupAxisToggles() {
  const axisCheckboxes = document.querySelectorAll('.axis-checkbox');

  // Load saved axis checkbox states from localStorage
  loadAxisCheckboxStates();

  axisCheckboxes.forEach(checkbox => {
    checkbox.addEventListener('change', (event) => {
      const axis = event.target.dataset.axis;
      const isVisible = event.target.checked;

      // Save axis checkbox state to localStorage
      saveAxisCheckboxStates();

      // Toggle visibility of the corresponding axis line or grid
      if (axis === 'grid') {
        // Toggle grid visibility
        if (gridHelper) {
          gridHelper.visible = isVisible;
        }
      } else if (axesLines) {
        const axisIndex = axis === 'x' ? 0 : axis === 'y' ? 1 : 2;
        axesLines[axisIndex].visible = isVisible;
      }
    });
  });
}

/**
 * Setup event listeners for settings toggles.
 */
function setupSettingsToggles() {
  const thickLinesCheckbox = document.getElementById('thick-lines-checkbox');
  const translucentLinesCheckbox = document.getElementById('translucent-lines-checkbox');

  // Load saved settings from localStorage
  loadSettingsStates();

  if (thickLinesCheckbox) {
    thickLinesCheckbox.addEventListener('change', (event) => {
      const isThick = event.target.checked;

      // Save settings state to localStorage
      saveSettingsStates();

      // Apply thick lines effect to all G-code line segments
      applyThickLinesEffect(isThick);
    });
  }

  if (translucentLinesCheckbox) {
    translucentLinesCheckbox.addEventListener('change', (event) => {
      const isTranslucent = event.target.checked;
      // Save settings state to localStorage
      saveSettingsStates();
      // Apply translucency to all G-code line segments
      applyTranslucentLinesEffect(isTranslucent);
    });
  }
}

/**
 * Save checkbox states to localStorage.
 */
function saveCheckboxStates() {
  const states = {};
  document.querySelectorAll('.legend-checkbox:not(.axis-checkbox)').forEach(checkbox => {
    states[checkbox.dataset.type] = checkbox.checked;
  });
  try {
    localStorage.setItem('visualizer-checkbox-states', JSON.stringify(states));
  } catch (error) {
    console.warn('Failed to save checkbox states to localStorage:', error);
  }
}

/**
 * Save axis checkbox states to localStorage.
 */
function saveAxisCheckboxStates() {
  const states = {};
  document.querySelectorAll('.axis-checkbox').forEach(checkbox => {
    states[checkbox.dataset.axis] = checkbox.checked;
  });
  try {
    localStorage.setItem('visualizer-axis-checkbox-states', JSON.stringify(states));
  } catch (error) {
    console.warn('Failed to save axis checkbox states to localStorage:', error);
  }
}

/**
 * Load checkbox states from localStorage.
 */
function loadCheckboxStates() {
  try {
    const saved = localStorage.getItem('visualizer-checkbox-states');
    if (saved) {
      const states = JSON.parse(saved);
      document.querySelectorAll('.legend-checkbox:not(.axis-checkbox)').forEach(checkbox => {
        if (checkbox.dataset.type in states) {
          checkbox.checked = states[checkbox.dataset.type];
        }
      });
    }
  } catch (error) {
    console.warn('Failed to load checkbox states from localStorage:', error);
  }
}

/**
 * Load axis checkbox states from localStorage.
 */
function loadAxisCheckboxStates() {
  try {
    const saved = localStorage.getItem('visualizer-axis-checkbox-states');
    if (saved) {
      const states = JSON.parse(saved);
      document.querySelectorAll('.axis-checkbox').forEach(checkbox => {
        const axis = checkbox.dataset.axis;
        if (axis in states) {
          checkbox.checked = states[axis];
          // Apply the visibility state to the axis line or grid
          if (axis === 'grid') {
            if (gridHelper) {
              gridHelper.visible = checkbox.checked;
            }
          } else if (axesLines) {
            const axisIndex = axis === 'x' ? 0 : axis === 'y' ? 1 : 2;
            axesLines[axisIndex].visible = checkbox.checked;
          }
        }
      });
    }
  } catch (error) {
    console.warn('Failed to load axis checkbox states from localStorage:', error);
  }
}

/**
 * Save settings states to localStorage.
 */
function saveSettingsStates() {
  const states = {};
  const thickLinesCheckbox = document.getElementById('thick-lines-checkbox');
  const translucentLinesCheckbox = document.getElementById('translucent-lines-checkbox');
  if (thickLinesCheckbox) {
    states.thickLines = thickLinesCheckbox.checked;
  }
  if (translucentLinesCheckbox) {
    states.translucentLines = translucentLinesCheckbox.checked;
  }
  try {
    localStorage.setItem('visualizer-settings-states', JSON.stringify(states));
  } catch (error) {
    console.warn('Failed to save settings states to localStorage:', error);
  }
}

/**
 * Load settings states from localStorage.
 */
function loadSettingsStates() {
  try {
    const saved = localStorage.getItem('visualizer-settings-states');
    if (saved) {
      const states = JSON.parse(saved);
      const thickLinesCheckbox = document.getElementById('thick-lines-checkbox');
      const translucentLinesCheckbox = document.getElementById('translucent-lines-checkbox');
      if (thickLinesCheckbox && 'thickLines' in states) {
        thickLinesCheckbox.checked = states.thickLines;
        // Don't apply effect here - it will be applied when G-code loads
      }
      if (translucentLinesCheckbox && 'translucentLines' in states) {
        translucentLinesCheckbox.checked = states.translucentLines;
        // Don't apply effect here - it will be applied when G-code loads
      }
    }
  } catch (error) {
    console.warn('Failed to load settings states from localStorage:', error);
  }
}

/**
 * Apply or remove thick lines effect to all G-code line segments.
 */
function applyThickLinesEffect(isThick) {
  if (!gcodeObject) return;

  gcodeObject.traverse(child => {
    if (!(child instanceof THREE.LineSegments || child instanceof THREE.Line)) return;
    if (!child.material) return;

    const isTravelLine = child.material.name === 'path';

    // When enabling thick lines, swap to a cloned "thick" material so we can revert cleanly.
    if (isThick && !isTravelLine) {
      if (!child.userData.originalMaterial) {
        // Preserve original material reference once.
        child.userData.originalMaterial = child.material;
      }
      if (!child.userData.thickMaterial) {
        const thickMat = child.userData.originalMaterial.clone();
        thickMat.linewidth = 5; // Note: LineBasicMaterial linewidth may be GPU-limited; kept for platforms that support it.
        thickMat.transparent = false;
        thickMat.opacity = 1;
        child.userData.thickMaterial = thickMat;
      }
      // Swap to thick material if not already active.
      if (child.material !== child.userData.thickMaterial) {
        child.material = child.userData.thickMaterial;
        child.material.needsUpdate = true;
      }
    } else {
      // Disable thick mode: restore original material if we have it.
      if (child.userData.originalMaterial && child.material !== child.userData.originalMaterial) {
        child.material = child.userData.originalMaterial;
        child.material.needsUpdate = true;
      }
      // Ensure transparency/opacity restored if we previously mutated original directly (legacy first toggle scenario).
      if (child.userData.originalOpacity !== undefined) {
        child.material.opacity = child.userData.originalOpacity;
      }
      if (child.userData.originalTransparent !== undefined) {
        child.material.transparent = child.userData.originalTransparent;
      }
    }
  });
}

/**
 * Apply or remove translucency to all G-code line segments.
 * When enabled, sets opacity to 0.5 and transparent=true; when disabled, restores to 1.0.
 */
function applyTranslucentLinesEffect(isTranslucent) {
  if (!gcodeObject) return;

  gcodeObject.traverse(child => {
    if (!(child instanceof THREE.LineSegments || child instanceof THREE.Line)) return;
    if (!child.material) return;

    // Preserve original transparency settings at first encounter
    if (child.userData.originalTransparent === undefined) {
      child.userData.originalTransparent = !!child.material.transparent;
    }
    if (child.userData.originalOpacity === undefined) {
      child.userData.originalOpacity = (child.material.opacity !== undefined) ? child.material.opacity : 1;
    }

    if (isTranslucent) {
      child.material.transparent = true;
      child.material.opacity = 0.5;
      child.material.needsUpdate = true;
    } else {
      child.material.transparent = child.userData.originalTransparent ?? false;
      child.material.opacity = 1.0;
      child.material.needsUpdate = true;
    }
  });
}

/**
 * Create the layer slider HTML elements (dual range sliders).
 */
function createLayerSlider() {
  const sliderHTML = `
        <div id="layer-slider-container">
            <input type="range" id="layer-slider-max" min="0" max="100" value="100" orient="vertical">
            <input type="range" id="layer-slider-min" min="0" max="100" value="0" orient="vertical">
            <div id="layer-info">All Layers</div>
        </div>
    `;

  document.body.insertAdjacentHTML('beforeend', sliderHTML);
  layerSliderMin = document.getElementById('layer-slider-min');
  layerSliderMax = document.getElementById('layer-slider-max');
}

/**
 * Create the horizontal move slider at the bottom of the page.
 */
function createMoveSlider() {
  const sliderHTML = `
        <div id="move-slider-container">
            <div id="move-info">Move Progress: 0%</div>
            <input type="range" id="move-slider" min="0" max="100" value="100">
        </div>
    `;

  document.body.insertAdjacentHTML('beforeend', sliderHTML);
  moveSlider = document.getElementById('move-slider');
}

/**
 * Setup layer slider after G-code is loaded.
 */
function setupLayerSlider() {
  if (layerCount === 0) {
    document
      .getElementById('layer-slider-container')
      .classList.remove('visible');
    return;
  }

  // Show the sliders.
  document.getElementById('layer-slider-container').classList.add('visible');
  document.getElementById('info').style.bottom = '110px';
  document.getElementById('info').style.left = '120px';

  // Setup slider ranges.
  layerSliderMin.min = 0;
  layerSliderMin.max = layerCount;
  layerSliderMin.value = 0;

  layerSliderMax.min = 0;
  layerSliderMax.max = layerCount;
  layerSliderMax.value = layerCount;

  // Remove existing listeners and add new ones.
  layerSliderMin.removeEventListener('input', updateLayerVisibility);
  layerSliderMax.removeEventListener('input', updateLayerVisibility);
  layerSliderMin.addEventListener('input', updateLayerVisibility);
  layerSliderMax.addEventListener('input', updateLayerVisibility);

  // Update initial display.
  updateLayerVisibility();
}

/**
 * Setup move slider after G-code is loaded.
 */
function setupMoveSlider() {
  if (layerCount === 0) {
    document.getElementById('move-slider-container').classList.remove('visible');
    return;
  }

  // Show the slider.
  document.getElementById('move-slider-container').classList.add('visible');

  // Reset slider to full (100%).
  moveSlider.value = 100;

  // Remove existing listener and add new one.
  moveSlider.removeEventListener('input', updateMoveVisibility);
  moveSlider.addEventListener('input', updateMoveVisibility);

  // Update initial display.
  updateMoveVisibility();
}

/**
 * Update layer visibility based on slider values.
 */
function updateLayerVisibility() {
  let minLayer = parseInt(layerSliderMin.value);
  let maxLayer = parseInt(layerSliderMax.value);

  // Ensure min is not greater than max
  if (minLayer > maxLayer) {
    const temp = minLayer;
    minLayer = maxLayer;
    maxLayer = temp;
    // Update slider values to reflect the swap
    layerSliderMin.value = minLayer;
    layerSliderMax.value = maxLayer;
  }

  // Get currently enabled movement types from checkboxes.
  const enabledTypes = new Set();
  document.querySelectorAll('.legend-checkbox:checked').forEach(checkbox => {
    enabledTypes.add(checkbox.dataset.type);
  });

  // Update visibility for all line segments
  for (let i = 0; i < allLayers.length; i++) {
    const segment = allLayers[i];

    // Get the layer index for this segment
    const segmentLayerIndex = segment.userData.layerIndex;

    // Check if this layer index is within the visible range
    // If layerIndex is undefined, treat it as always visible (for backwards compatibility)
    const layerVisible = segmentLayerIndex === undefined
      ? true
      : (segmentLayerIndex >= minLayer && segmentLayerIndex < maxLayer);

    // Check if this segment's type is enabled.
    const typeEnabled = enabledTypes.has(segment.userData.type) || enabledTypes.has(segment.material.name);

    // Segment is visible only if both conditions are met.
    segment.visible = layerVisible && typeEnabled;
  }

  // Update info text.
  const infoText =
    minLayer === 0 && maxLayer === layerCount
      ? 'All Layers'
      : `<p>Layers ${minLayer} - ${maxLayer - 1}</p><p>(${maxLayer - minLayer} / ${layerCount})</p>`;
  document.getElementById('layer-info').innerHTML = infoText;

  // Update move slider when layer visibility changes.
  updateMoveVisibility();
}

/**
 * Update move visibility based on horizontal slider value.
 * Only affects the topmost visible layer.
 */
function updateMoveVisibility() {
  const movePercentage = parseInt(moveSlider.value);

  // Update info text.
  document.getElementById('move-info').textContent = `Move Progress: ${movePercentage}%`;

  // Find the topmost visible layer.
  let minLayer = parseInt(layerSliderMin.value);
  let maxLayer = parseInt(layerSliderMax.value);

  // Ensure min is not greater than max
  if (minLayer > maxLayer) {
    const temp = minLayer;
    minLayer = maxLayer;
    maxLayer = temp;
  }

  const topLayerIndex = maxLayer - 1; // The topmost visible layer (0-indexed)

  // Get currently enabled movement types from checkboxes.
  const enabledTypes = new Set();
  document.querySelectorAll('.legend-checkbox:checked').forEach(checkbox => {
    enabledTypes.add(checkbox.dataset.type);
  });

  // For chronological segments, we need to calculate the total segment count
  // across all type sections in the top layer
  let totalChronologicalSegments = 0;
  const topLayerChronologicalSegments = [];

  allLayers.forEach(segment => {
    if (segment.userData.chronological && segment.userData.layerIndex === topLayerIndex) {
      topLayerChronologicalSegments.push(segment);
      if (segment.userData.chronologicalEnd !== undefined) {
        totalChronologicalSegments = Math.max(totalChronologicalSegments, segment.userData.chronologicalEnd);
      }
    }
  });

  // Calculate the chronological cutoff point based on slider percentage
  const visibleChronologicalCount = Math.ceil((totalChronologicalSegments * movePercentage) / 100);

  // Track current segment mapping for logging
  let lastVisibleLine = null;
  let lastVisibleCmd = null;

  // Process all segments
  allLayers.forEach(segment => {
    const segmentLayerIndex = segment.userData.layerIndex;

    // Check layer visibility
    const layerVisible = segmentLayerIndex === undefined
      ? true
      : (segmentLayerIndex >= minLayer && segmentLayerIndex < maxLayer);

    // Check type visibility
    const typeEnabled = enabledTypes.has(segment.userData.type) ||
                       enabledTypes.has(segment.material.name);

    // For chronological segments on the top layer
    if (segment.userData.chronological && segmentLayerIndex === topLayerIndex) {
      const start = segment.userData.chronologicalStart || 0;
      const end = segment.userData.chronologicalEnd || 0;

      // Determine how much of this segment should be visible based on chronological position
      if (visibleChronologicalCount <= start) {
        // This entire segment is beyond the visible range
        segment.visible = false;
      } else if (visibleChronologicalCount >= end) {
        // This entire segment is within the visible range
        segment.visible = layerVisible && typeEnabled;
        // Reset draw range to show full segment
        if (segment.geometry.drawRange && segment.userData.fullVertexCount) {
          segment.geometry.setDrawRange(0, segment.userData.fullVertexCount);
        }
        // Update last visible mapping to final command of this section
        if (segment.userData.sourceLines && segment.userData.sourceCmds) {
          const idx = segment.userData.sourceLines.length - 1;
          if (idx >= 0) {
            lastVisibleLine = segment.userData.sourceLines[idx];
            lastVisibleCmd = segment.userData.sourceCmds[idx];
          }
        }
      } else {
        // Partial visibility - calculate how many segments to show
        const visibleInThisSegment = visibleChronologicalCount - start;
        const drawCount = visibleInThisSegment * 2; // 2 vertices per segment

        if (segment.geometry.drawRange) {
          segment.geometry.setDrawRange(0, drawCount);
        }

        segment.visible = layerVisible && typeEnabled && (visibleInThisSegment > 0);

        // Update last visible mapping to the partial index within this section
        if (segment.userData.sourceLines && segment.userData.sourceCmds) {
          const idx = Math.max(0, Math.min(segment.userData.sourceLines.length - 1, visibleInThisSegment - 1));
          lastVisibleLine = segment.userData.sourceLines[idx];
          lastVisibleCmd = segment.userData.sourceCmds[idx];
        }
      }
    }
    // For non-chronological segments or non-top layers
    else if (!segment.userData.chronological) {
      // Old grouped-by-type approach for backward compatibility
      if (segmentLayerIndex === topLayerIndex && segment.userData.segmentCount) {
        const totalSegments = segment.userData.segmentCount;
        const visibleSegments = Math.ceil((totalSegments * movePercentage) / 100);

        // Use drawRange to control how many segments are drawn
        const drawCount = visibleSegments * 2;

        if (segment.geometry.drawRange) {
          segment.geometry.setDrawRange(0, drawCount);
        }

        segment.visible = layerVisible && typeEnabled && (visibleSegments > 0);
      } else {
        // Reset draw range for non-top layers
        if (segment.geometry.drawRange && segment.userData.fullVertexCount) {
          segment.geometry.setDrawRange(0, segment.userData.fullVertexCount);
        }
        segment.visible = layerVisible && typeEnabled;
      }
    } else {
      // Chronological segments on non-top layers - show/hide based on type only
      if (segment.geometry.drawRange && segment.userData.fullVertexCount) {
        segment.geometry.setDrawRange(0, segment.userData.fullVertexCount);
      }
      segment.visible = layerVisible && typeEnabled;
    }
  });

  // Log current G-code position if available
  if (topLayerIndex >= 0) {
    if (lastVisibleLine != null && lastVisibleCmd != null) {
      console.log(`G-code line ${lastVisibleLine + 1}: ${lastVisibleCmd}`);
    } else {
      // As a fallback, try to log layer start line from metadata
      if (gcodeObject && gcodeObject.userData && gcodeObject.userData.metadata) {
        const meta = gcodeObject.userData.metadata;
        const layerStart = meta.layerComments ? meta.layerComments[topLayerIndex] : undefined;
        if (typeof layerStart === 'number') {
          console.log(`Layer ${topLayerIndex} (starts at G-code line ${layerStart + 1})`);
        }
      }
    }
  }
}

/**
 * Set up event listeners for UI interactions.
 */
function setupEventListeners() {
  // Upload button.
  document.getElementById('upload').addEventListener('click', () => {
    document.getElementById('uploader').click();
  });

  // File input change.
  document
    .getElementById('uploader')
    .addEventListener('change', handleFileUpload);

  // Reset button.
  document.getElementById('reset').addEventListener('click', resetView);
}

/**
 * Setup custom keyboard controls for WASD (camera tilt) and arrow keys (camera position).
 */
function setupKeyboardControls() {
  // Movement speed for keyboard controls
  const rotateSpeed = 0.05; // Rotation speed for WASD
  const panSpeed = 5; // Pan speed for arrow keys

  window.addEventListener('keydown', (event) => {
    let needsUpdate = false;

    // Get camera's current orientation vectors
    const forward = new THREE.Vector3();
    const right = new THREE.Vector3();
    const up = new THREE.Vector3(0, 1, 0);

    camera.getWorldDirection(forward);
    right.crossVectors(forward, up).normalize();

    switch (event.key.toLowerCase()) {
      // WASD for camera rotation (tilt)
      case 'w':
        // Rotate camera up (around the right axis)
        camera.position.sub(controls.target);
        camera.position.applyAxisAngle(right, -rotateSpeed);
        camera.position.add(controls.target);
        needsUpdate = true;
        break;

      case 's':
        // Rotate camera down (around the right axis)
        camera.position.sub(controls.target);
        camera.position.applyAxisAngle(right, rotateSpeed);
        camera.position.add(controls.target);
        needsUpdate = true;
        break;

      case 'a':
        // Rotate camera left (around the up axis)
        camera.position.sub(controls.target);
        camera.position.applyAxisAngle(up, rotateSpeed);
        camera.position.add(controls.target);
        needsUpdate = true;
        break;

      case 'd':
        // Rotate camera right (around the up axis)
        camera.position.sub(controls.target);
        camera.position.applyAxisAngle(up, -rotateSpeed);
        camera.position.add(controls.target);
        needsUpdate = true;
        break;

      // Arrow keys for camera position movement (pan)
      case 'arrowup':
        // Move camera and target forward
        camera.position.addScaledVector(forward, panSpeed);
        controls.target.addScaledVector(forward, panSpeed);
        needsUpdate = true;
        event.preventDefault();
        break;

      case 'arrowdown':
        // Move camera and target backward
        camera.position.addScaledVector(forward, -panSpeed);
        controls.target.addScaledVector(forward, -panSpeed);
        needsUpdate = true;
        event.preventDefault();
        break;

      case 'arrowleft':
        // Move camera and target left
        camera.position.addScaledVector(right, -panSpeed);
        controls.target.addScaledVector(right, -panSpeed);
        needsUpdate = true;
        event.preventDefault();
        break;

      case 'arrowright':
        // Move camera and target right
        camera.position.addScaledVector(right, panSpeed);
        controls.target.addScaledVector(right, panSpeed);
        needsUpdate = true;
        event.preventDefault();
        break;
    }

    if (needsUpdate) {
      controls.update();
    }
  });
}

/**
 * Setup double-click handler to focus camera on clicked line.
 */
function setupDoubleClickHandler() {
  const raycaster = new THREE.Raycaster();
  const mouse = new THREE.Vector2();

  // Set raycaster threshold for better line detection
  raycaster.params.Line.threshold = 2;

  renderer.domElement.addEventListener('dblclick', (event) => {
    // Calculate mouse position in normalized device coordinates (-1 to +1)
    const rect = renderer.domElement.getBoundingClientRect();
    mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    mouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;

    // Update the raycaster with the camera and mouse position
    raycaster.setFromCamera(mouse, camera);

    // Calculate objects intersecting the picking ray
    const intersects = raycaster.intersectObjects(scene.children, true);

    // Find the first intersected line segment
    for (let i = 0; i < intersects.length; i++) {
      const intersect = intersects[i];

      // Check if the intersected object is a line segment (part of G-code)
      if (intersect.object instanceof THREE.LineSegments ||
          intersect.object instanceof THREE.Line) {

        // Use the exact intersection point from the raycaster
        const point = intersect.point.clone();

        // Focus camera on the exact intersection point
        focusCameraOnPoint(point);
        break;
      }
    }
  });
}

/**
 * Focus camera on a specific point with smooth animation.
 */
function focusCameraOnPoint(point) {
  // Calculate current camera direction
  const direction = new THREE.Vector3()
    .subVectors(camera.position, controls.target)
    .normalize();

  // Set a closer distance for more precise focusing (20 units from the point)
  const focusDistance = 20;

  // Calculate new camera position closer to the point
  const newCameraPosition = new THREE.Vector3()
    .addVectors(point, direction.multiplyScalar(focusDistance));

  // Smoothly transition to new position
  const startPosition = camera.position.clone();
  const startTarget = controls.target.clone();
  const duration = 500; // milliseconds
  const startTime = Date.now();

  function animateCamera() {
    const elapsed = Date.now() - startTime;
    const progress = Math.min(elapsed / duration, 1);

    // Use easing function for smooth animation
    const easeProgress = 1 - Math.pow(1 - progress, 3); // ease-out cubic

    // Interpolate camera position
    camera.position.lerpVectors(startPosition, newCameraPosition, easeProgress);

    // Interpolate controls target to the exact clicked point
    controls.target.lerpVectors(startTarget, point, easeProgress);

    controls.update();

    if (progress < 1) {
      requestAnimationFrame(animateCamera);
    }
  }

  animateCamera();
}

/**
 * Handle file upload and load G-code or 3D model.
 */
function handleFileUpload(event) {
  const file = event.target.files[0];

  if (!file) {
    return;
  }

  const extension = file.name.split('.').pop().toLowerCase();

  if (MODEL_EXTENSIONS.includes(extension)) {
    // Load as 3D model using Polyslice loader.
    loadModel(file);
  } else if (GCODE_EXTENSIONS.includes(extension)) {
    // Load as G-code.
    const reader = new FileReader();

    reader.onload = function (e) {
      const content = e.target.result;
      loadGCode(content, file.name);
    };

    reader.readAsText(file);
  } else {
    console.warn(`Unsupported file format: ${extension}`);
  }
}

/**
 * Load and visualize a 3D model file using the Polyslice loader.
 */
function loadModel(file) {
  const url = URL.createObjectURL(file);
  const extension = file.name.split('.').pop().toLowerCase();

  // Remove previous mesh object if exists.
  if (meshObject) {
    scene.remove(meshObject);
    meshObject = null;
  }

  // Remove previous G-code object if exists.
  if (gcodeObject) {
    scene.remove(gcodeObject);
    gcodeObject = null;
    allLayers = [];
    layersByIndex = {};
    layerCount = 0;
  }

  // Hide G-code specific sliders when viewing a model.
  document.getElementById('layer-slider-container').classList.remove('visible');
  document.getElementById('move-slider-container').classList.remove('visible');

  // Use the Polyslice loader with the format-specific method.
  // We use format-specific methods because the generic load() extracts extension from URL,
  // but blob URLs don't contain the file extension.
  let loadPromise;
  switch (extension) {
    case 'stl':
      loadPromise = window.PolysliceLoader.loadSTL(url);
      break;
    case 'obj':
      loadPromise = window.PolysliceLoader.loadOBJ(url);
      break;
    case '3mf':
      loadPromise = window.PolysliceLoader.load3MF(url);
      break;
    case 'amf':
      loadPromise = window.PolysliceLoader.loadAMF(url);
      break;
    case 'ply':
      loadPromise = window.PolysliceLoader.loadPLY(url);
      break;
    case 'gltf':
    case 'glb':
      loadPromise = window.PolysliceLoader.loadGLTF(url);
      break;
    case 'dae':
      loadPromise = window.PolysliceLoader.loadCollada(url);
      break;
    default:
      console.error(`Unsupported file format: ${extension}`);
      URL.revokeObjectURL(url);
      return;
  }

  loadPromise
    .then((result) => {
      // Handle single mesh or array of meshes.
      let object;
      if (Array.isArray(result)) {
        // Create a group to hold multiple meshes.
        object = new THREE.Group();
        result.forEach((mesh) => object.add(mesh));
      } else {
        object = result;
      }

      displayMesh(object, file.name);
      URL.revokeObjectURL(url);
    })
    .catch((error) => {
      console.error('Error loading model:', error);
      URL.revokeObjectURL(url);
    });
}

/**
 * Display a loaded mesh in the scene.
 */
function displayMesh(object, filename) {
  meshObject = object;

  // Rotate mesh to align with G-code coordinate system (Z up).
  meshObject.rotation.x = -Math.PI / 2;

  scene.add(meshObject);

  // Update info panel.
  updateMeshInfo(filename, meshObject);

  // Center camera on mesh.
  if (isFirstUpload) {
    centerCamera(meshObject);
    isFirstUpload = false;
  }
}

/**
 * Update info panel with mesh statistics.
 */
function updateMeshInfo(filename, object) {
  document.getElementById('filename').textContent = filename;

  let totalTriangles = 0;
  let totalVertices = 0;
  let meshCount = 0;

  object.traverse((child) => {
    if (child.isMesh) {
      meshCount++;
      if (child.geometry) {
        const geometry = child.geometry;
        if (geometry.index) {
          totalTriangles += geometry.index.count / 3;
        } else if (geometry.attributes.position) {
          totalTriangles += geometry.attributes.position.count / 3;
        }
        if (geometry.attributes.position) {
          totalVertices += geometry.attributes.position.count;
        }
      }
    }
  });

  const statsLines = [
    `Meshes: ${meshCount}`,
    `Triangles: ${Math.floor(totalTriangles).toLocaleString()}`,
    `Vertices: ${totalVertices.toLocaleString()}`
  ];

  document.getElementById('stats').textContent = statsLines.join('\n');

  // Reset info position when showing mesh (no sliders).
  document.getElementById('info').style.bottom = '20px';
  document.getElementById('info').style.left = '20px';
}

/**
 * Load and visualize G-code content.
 */
function loadGCode(content, filename) {
  // Remove previous G-code object if exists.
  if (gcodeObject) {
    scene.remove(gcodeObject);
    gcodeObject = null;
  }

  // Remove previous mesh object if exists.
  if (meshObject) {
    scene.remove(meshObject);
    meshObject = null;
  }

  // Parse G-code with extended loader that preserves comments.
  const loader = new GCodeLoaderExtended();
  loader.splitLayer = true; // Enable layer splitting for proper layer slider functionality
  gcodeObject = loader.parse(content);

  // Log metadata if available for debugging.
  if (gcodeObject.userData.metadata) {
    console.log('G-code metadata:', gcodeObject.userData.metadata);

    // Check if TYPE comments were found
    const moveTypes = gcodeObject.userData.metadata.moveTypes || {};
    if (Object.keys(moveTypes).length === 0) {
      console.warn('No TYPE comments detected in G-code. Using legacy red/green colors.');
      console.warn('For color-coded visualization, ensure your G-code includes Cura-style TYPE comments.');
    } else {
      console.log('TYPE comments detected! Color-coded visualization active.');
      console.log('Movement types found:', Object.keys(moveTypes));
    }
  }

  // Add to scene.
  scene.add(gcodeObject);

  // Collect all layers for slider control.
  allLayers = [];
  layersByIndex = {};

  // Get layer count from metadata if available
  if (gcodeObject.userData.metadata && gcodeObject.userData.metadata.layerCount > 0) {
    layerCount = gcodeObject.userData.metadata.layerCount;
  } else {
    // Fallback: count unique layer names
    const uniqueLayers = new Set();
    gcodeObject.traverse(child => {
      if (child instanceof THREE.LineSegments && child.name.startsWith('layer')) {
        const layerNum = parseInt(child.name.replace('layer', ''));
        if (!isNaN(layerNum)) {
          uniqueLayers.add(layerNum);
        }
      }
    });
    layerCount = uniqueLayers.size;
  }

  gcodeObject.traverse(child => {
    if (child instanceof THREE.LineSegments) {
      allLayers.push(child);
      child.visible = true; // Show all layers by default.

      // Extract layer index from name (e.g., "layer0", "layer1")
      if (child.name.startsWith('layer')) {
        const layerIndex = parseInt(child.name.replace('layer', ''));
        if (!isNaN(layerIndex)) {
          child.userData.layerIndex = layerIndex;

          // Group segments by layer index
          if (!layersByIndex[layerIndex]) {
            layersByIndex[layerIndex] = [];
          }
          layersByIndex[layerIndex].push(child);
        }
      }
    }
  });

  // Setup layer slider.
  setupLayerSlider();

  // Setup move slider.
  setupMoveSlider();

  // Update info panel.
  updateInfo(filename, gcodeObject);

  // Center camera on G-code only for the first upload.
  if (isFirstUpload) {
    centerCamera(gcodeObject);
    isFirstUpload = false;
  }

  // Apply thick lines setting if it's enabled
  const thickLinesCheckbox = document.getElementById('thick-lines-checkbox');
  if (thickLinesCheckbox && thickLinesCheckbox.checked) {
    applyThickLinesEffect(true);
  }

  // Apply translucent lines setting if it's enabled
  const translucentLinesCheckbox = document.getElementById('translucent-lines-checkbox');
  if (translucentLinesCheckbox && translucentLinesCheckbox.checked) {
    applyTranslucentLinesEffect(true);
  }
}

/**
 * Update info panel with G-code statistics.
 */
function updateInfo(filename, object) {
  document.getElementById('filename').textContent = filename;

  let totalLines = 0;
  const typeCount = {};

  object.traverse(child => {
    if (child instanceof THREE.LineSegments) {
      totalLines++;

      // Count by material/type name.
      if (child.material && child.material.name) {
        const typeName = child.material.name;
        typeCount[typeName] = (typeCount[typeName] || 0) + 1;
      }
    }
  });

  // Build stats text with type breakdown
  let statsLines = [`Total segments: ${totalLines}`];

  // Add metadata info if available
  if (object.userData.metadata) {
    const metadata = object.userData.metadata;
    if (metadata.layerCount > 0) {
      statsLines.push(`Layers: ${metadata.layerCount}`);
    }
    if (Object.keys(metadata.moveTypes).length > 0) {
      statsLines.push('Movement types detected:');
      Object.entries(metadata.moveTypes).forEach(([type, count]) => {
        statsLines.push(`  ${type}: ${count} sections`);
      });
    }
  }

  // Add segment counts by type
  if (Object.keys(typeCount).length > 0) {
    statsLines.push('Segments by type:');
    Object.entries(typeCount).forEach(([type, count]) => {
      const displayName =
        type === 'path'
          ? 'Travel'
          : type === 'extruded'
            ? 'Generic extrusion'
            : type;
      statsLines.push(`  ${displayName}: ${count}`);
    });
  }

  const statsText = statsLines.join('\n');
  document.getElementById('stats').textContent = statsText;
}

/**
 * Center camera on the G-code object.
 */
function centerCamera(object) {
  const box = new THREE.Box3().setFromObject(object);
  const center = box.getCenter(new THREE.Vector3());
  const size = box.getSize(new THREE.Vector3());

  // Calculate optimal camera distance.
  const maxDim = Math.max(size.x, size.y, size.z);
  const fov = camera.fov * (Math.PI / 180);
  let cameraZ = Math.abs(maxDim / 2 / Math.tan(fov / 2));
  cameraZ *= 1.5; // Add some padding.

  // Position camera with Y axis on opposite side (X+, Y+, Z-) relative to center.
  camera.position.set(
    center.x + cameraZ,
    center.y + cameraZ,
    center.z - cameraZ
  );

  camera.lookAt(center);

  // Update controls target.
  controls.target.copy(center);
  controls.update();
}

/**
 * Reset view to initial state.
 */
function resetView() {
  // Reset camera position
  if (gcodeObject) {
    centerCamera(gcodeObject);
  } else if (meshObject) {
    centerCamera(meshObject);
  } else {
    camera.position.set(300, 200, -300); // Moved Y axis to opposite side
    camera.lookAt(0, 0, 0);
    controls.target.set(0, 0, 0);
    controls.update();
  }

  // Reset all movement type checkboxes to checked
  document.querySelectorAll('.legend-checkbox:not(.axis-checkbox):not(.settings-checkbox)').forEach(checkbox => {
    checkbox.checked = true;
  });

  // Reset all axis checkboxes to checked and update axis visibility
  document.querySelectorAll('.axis-checkbox').forEach(checkbox => {
    checkbox.checked = true;
    const axis = checkbox.dataset.axis;
    if (axis === 'grid') {
      if (gridHelper) {
        gridHelper.visible = true;
      }
    } else if (axesLines) {
      const axisIndex = axis === 'x' ? 0 : axis === 'y' ? 1 : 2;
      axesLines[axisIndex].visible = true;
    }
  });

  // Reset settings checkboxes to unchecked (default state)
  const thickLinesCheckbox = document.getElementById('thick-lines-checkbox');
  if (thickLinesCheckbox) {
    thickLinesCheckbox.checked = false;
    applyThickLinesEffect(false);
  }
  const translucentLinesCheckbox = document.getElementById('translucent-lines-checkbox');
  if (translucentLinesCheckbox) {
    translucentLinesCheckbox.checked = false; // default OFF
    applyTranslucentLinesEffect(false);
  }

  // Reset layer sliders to show all layers
  if (layerSliderMin && layerSliderMax && layerCount > 0) {
    layerSliderMin.value = 0;
    layerSliderMax.value = layerCount;
  }

  // Reset move slider to 100%
  if (moveSlider) {
    moveSlider.value = 100;
  }

  // Save the reset states to localStorage
  saveCheckboxStates();
  saveAxisCheckboxStates();
  saveSettingsStates();

  // Update layer visibility with all checkboxes checked
  if (allLayers.length > 0) {
    updateLayerVisibility();
  }
}

/**
 * Handle window resize.
 */
function onWindowResize() {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
}

/**
 * Animation loop.
 */
function animate() {
  requestAnimationFrame(animate);

  // Update controls.
  controls.update();

  // Render scene.
  renderer.render(scene, camera);
}
