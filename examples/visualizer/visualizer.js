/**
 * G-code Visualizer
 * A browser-based tool to visualize G-code files using Three.js
 */

import * as THREE from 'three';
import { GCodeLoader } from 'three/addons/loaders/GCodeLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

// Global variables.
let scene, camera, renderer, controls;
let gcodeObject = null;
let axesLines;

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
  camera.position.set(100, 100, 100);
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

  // Create X axis (red).
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

  // Create Y axis (green).
  const yGeometry = new THREE.BufferGeometry().setFromPoints([
    new THREE.Vector3(0, 0, 0),
    new THREE.Vector3(0, axisLength, 0),
  ]);
  const yMaterial = new THREE.LineBasicMaterial({
    color: 0x00ff00,
    linewidth: axisThickness,
  });
  const yAxis = new THREE.Line(yGeometry, yMaterial);
  scene.add(yAxis);

  // Create Z axis (blue) - positioned on opposite side.
  const zGeometry = new THREE.BufferGeometry().setFromPoints([
    new THREE.Vector3(0, 0, 0),
    new THREE.Vector3(0, 0, -axisLength),
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
        <div id="legend">
            <h3>Movement Types</h3>
            <div class="legend-item">
                <div class="legend-color" style="background-color: #ff0000;"></div>
                <span>Travel (G0 - Non-extruding)</span>
            </div>
            <div class="legend-item">
                <div class="legend-color" style="background-color: #00ff00;"></div>
                <span>Extrusion (G1 - Extruding)</span>
            </div>
            <div class="legend-item">
                <div class="legend-color" style="background-color: #ffff00;"></div>
                <span>Arc Movement (G2/G3)</span>
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
    `;

  document.body.insertAdjacentHTML('beforeend', legendHTML);
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

  // Parse G-code.
  const loader = new GCodeLoader();
  gcodeObject = loader.parse(content);

  // Add to scene.
  scene.add(gcodeObject);

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
  let travelMoves = 0;
  let extrusionMoves = 0;

  object.traverse(child => {
    if (child instanceof THREE.LineSegments) {
      totalLines++;

      // Check material name to determine move type.
      if (child.material && child.material.name === 'path') {
        travelMoves++;
      } else if (child.material && child.material.name === 'extruded') {
        extrusionMoves++;
      }
    }
  });

  const statsText = `
        Total line segments: ${totalLines}
        Travel moves: ${travelMoves}
        Extrusion moves: ${extrusionMoves}
    `
    .trim()
    .replace(/\n\s+/g, '\n');

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

  // Position camera.
  camera.position.set(
    center.x + cameraZ / 2,
    center.y + cameraZ / 2,
    center.z + cameraZ
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
    camera.position.set(100, 100, 100);
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
