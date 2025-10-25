/**
 * G-code Visualizer
 * A browser-based tool to visualize G-code files using Three.js
 */

import * as THREE from 'three';
import { GCodeLoaderExtended } from './libs/GCodeLoaderExtended.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

// Global variables.
let scene, camera, renderer, controls;
let gcodeObject = null;
let axesLines;
let allLayers = [];
let layersByIndex = {}; // Map layer index to LineSegments
let layerCount = 0; // Total number of actual layers from LAYER comments
let layerSliderMin = null;
let layerSliderMax = null;
let moveSlider = null;
let isFirstUpload = true; // Track if this is the first G-code upload

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
  camera.position.set(100, 100, -100); // Moved Y axis to opposite side
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
function createAxes() {
  const axisLength = 150;
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
 * Create the legends for movement types and axes.
 */
function createLegend() {
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
            <div id="axes-legend">
                <h3>Axes</h3>
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
            </div>
        </div>
    `;

  document.body.insertAdjacentHTML('beforeend', legendHTML);

  // Setup event listeners for movement type checkboxes.
  setupMovementTypeToggles();

  // Setup event listeners for axis checkboxes.
  setupAxisToggles();
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

      // Toggle visibility of the corresponding axis line
      if (axesLines) {
        const axisIndex = axis === 'x' ? 0 : axis === 'y' ? 1 : 2;
        axesLines[axisIndex].visible = isVisible;
      }
    });
  });
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
          // Apply the visibility state to the axis line
          if (axesLines) {
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

  // Show the slider.
  document.getElementById('layer-slider-container').classList.add('visible');
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

    // For the top layer, apply move slider
    if (segmentLayerIndex === topLayerIndex && segment.userData.segmentCount) {
      const totalSegments = segment.userData.segmentCount;
      const visibleSegments = Math.ceil((totalSegments * movePercentage) / 100);
      
      // Use drawRange to control how many segments are drawn
      // Each segment uses 2 vertices
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
  });
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
 * Handle file upload and load G-code.
 */
function handleFileUpload(event) {
  const file = event.target.files[0];

  if (!file) {
    return;
  }

  const reader = new FileReader();

  reader.onload = function (e) {
    const content = e.target.result;
    loadGCode(content, file.name);
  };

  reader.readAsText(file);
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
  } else {
    camera.position.set(100, 100, -100); // Moved Y axis to opposite side
    camera.lookAt(0, 0, 0);
    controls.target.set(0, 0, 0);
    controls.update();
  }

  // Reset all movement type checkboxes to checked
  document.querySelectorAll('.legend-checkbox:not(.axis-checkbox)').forEach(checkbox => {
    checkbox.checked = true;
  });

  // Reset all axis checkboxes to checked and update axis visibility
  document.querySelectorAll('.axis-checkbox').forEach(checkbox => {
    checkbox.checked = true;
    const axis = checkbox.dataset.axis;
    if (axesLines) {
      const axisIndex = axis === 'x' ? 0 : axis === 'y' ? 1 : 2;
      axesLines[axisIndex].visible = true;
    }
  });

  // Save the reset states to localStorage
  saveCheckboxStates();
  saveAxisCheckboxStates();

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
