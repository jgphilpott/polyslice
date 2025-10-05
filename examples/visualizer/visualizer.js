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
let layerSlider = null;

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

  // Set up event listeners.
  setupEventListeners();

  // Handle window resize.
  window.addEventListener('resize', onWindowResize, false);

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
                    <div class="legend-color" style="background-color: #ff6600;"></div>
                    <span>Outer Wall</span>
                </div>
                <div class="legend-item">
                    <div class="legend-color" style="background-color: #ff9933;"></div>
                    <span>Inner Wall</span>
                </div>
                <div class="legend-item">
                    <div class="legend-color" style="background-color: #ffcc00;"></div>
                    <span>Skin (Top/Bottom)</span>
                </div>
                <div class="legend-item">
                    <div class="legend-color" style="background-color: #00ccff;"></div>
                    <span>Infill</span>
                </div>
                <div class="legend-item">
                    <div class="legend-color" style="background-color: #ff00ff;"></div>
                    <span>Support</span>
                </div>
                <div class="legend-item">
                    <div class="legend-color" style="background-color: #888888;"></div>
                    <span>Skirt/Brim</span>
                </div>
                <div class="legend-item">
                    <div class="legend-color" style="background-color: #ff0000;"></div>
                    <span>Travel (Non-extruding)</span>
                </div>
                <div class="legend-item">
                    <div class="legend-color" style="background-color: #00ff00;"></div>
                    <span>Other Extrusion</span>
                </div>
            </div>
            <div id="axes-legend">
                <h3>Axes</h3>
                <div class="legend-item">
                    <div class="legend-color" style="background-color: #ff0000;"></div>
                    <span>X Axis</span>
                </div>
                <div class="legend-item">
                    <div class="legend-color" style="background-color: #00ff00;"></div>
                    <span>Y Axis</span>
                </div>
                <div class="legend-item">
                    <div class="legend-color" style="background-color: #0000ff;"></div>
                    <span>Z Axis</span>
                </div>
            </div>
        </div>
    `;

  document.body.insertAdjacentHTML('beforeend', legendHTML);
}

/**
 * Create the layer slider HTML element.
 */
function createLayerSlider() {
  const sliderHTML = `
        <div id="layer-slider-container">
            <input type="range" id="layer-slider" min="0" max="100" value="100" orient="vertical">
            <div id="layer-info">All Layers</div>
        </div>
    `;

  document.body.insertAdjacentHTML('beforeend', sliderHTML);
  layerSlider = document.getElementById('layer-slider');
}

/**
 * Setup layer slider after G-code is loaded.
 */
function setupLayerSlider() {
  if (allLayers.length === 0) {
    document
      .getElementById('layer-slider-container')
      .classList.remove('visible');
    return;
  }

  // Show the slider.
  document.getElementById('layer-slider-container').classList.add('visible');

  // Setup slider range.
  layerSlider.max = allLayers.length;
  layerSlider.value = allLayers.length;

  // Remove existing listener and add new one.
  layerSlider.removeEventListener('input', updateLayerVisibility);
  layerSlider.addEventListener('input', updateLayerVisibility);

  // Update initial display.
  updateLayerVisibility();
}

/**
 * Update layer visibility based on slider value.
 */
function updateLayerVisibility() {
  const visibleCount = parseInt(layerSlider.value);

  for (let i = 0; i < allLayers.length; i++) {
    allLayers[i].visible = i < visibleCount;
  }

  // Update info text.
  const infoText =
    visibleCount === allLayers.length
      ? 'All Layers'
      : `${visibleCount} / ${allLayers.length}`;
  document.getElementById('layer-info').textContent = infoText;
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
  gcodeObject.traverse(child => {
    if (child instanceof THREE.LineSegments) {
      allLayers.push(child);
      child.visible = true; // Show all layers by default.
    }
  });

  // Setup layer slider.
  setupLayerSlider();

  // Update info panel.
  updateInfo(filename, gcodeObject);

  // Center camera on G-code.
  centerCamera(gcodeObject);
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
  if (gcodeObject) {
    centerCamera(gcodeObject);
  } else {
    camera.position.set(100, 100, -100); // Moved Y axis to opposite side
    camera.lookAt(0, 0, 0);
    controls.target.set(0, 0, 0);
    controls.update();
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
