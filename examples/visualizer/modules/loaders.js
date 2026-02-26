/**
 * Loaders Module
 * Handles loading of 3D models and G-code files
 */

import * as THREE from 'three';
import { GCodeLoaderExtended } from '../libs/GCodeLoaderExtended.js';

// File extensions
export const MODEL_EXTENSIONS = ['stl', 'obj', '3mf', 'amf', 'ply', 'gltf', 'glb', 'dae'];
export const GCODE_EXTENSIONS = ['gcode', 'gco', 'nc'];

/**
 * Handle file upload event.
 */
export function handleFileUpload(event, loadModelCallback, loadGCodeCallback) {
  const file = event.target.files[0];

  if (!file) {
    return;
  }

  const extension = file.name.split('.').pop().toLowerCase();

  if (MODEL_EXTENSIONS.includes(extension)) {
    loadModelCallback(file);
  } else if (GCODE_EXTENSIONS.includes(extension)) {
    const reader = new FileReader();

    reader.onload = function (e) {
      const content = e.target.result;
      loadGCodeCallback(content, file.name);
    };

    reader.readAsText(file);
  } else {
    console.warn(`Unsupported file format: ${extension}`);
  }

  // Clear the input value to allow re-uploading the same file
  event.target.value = '';
}

/**
 * Load and visualize a 3D model file using the Polyslice loader.
 */
export function loadModel(file, scene, callbacks) {
  const { updateDownloadVisibility, hideSlicingGUI, displayMesh, clearGCodeData, clearMeshData } = callbacks;

  const url = URL.createObjectURL(file);
  const extension = file.name.split('.').pop().toLowerCase();

  // Clear G-code content when loading a model
  clearGCodeData();
  updateDownloadVisibility(false);

  // Hide slicing GUI while loading
  hideSlicingGUI();

  // Remove previous mesh and G-code objects
  clearMeshData(scene);

  // Hide G-code specific sliders
  document.getElementById('layer-slider-container').classList.remove('visible');
  document.getElementById('move-slider-container').classList.remove('visible');

  // Create material for loaded models
  const normalMaterial = new THREE.MeshNormalMaterial();

  // Use format-specific loader method
  let loadPromise;
  switch (extension) {
    case 'stl':
      loadPromise = window.PolysliceLoader.loadSTL(url, normalMaterial);
      break;
    case 'obj':
      loadPromise = window.PolysliceLoader.loadOBJ(url, normalMaterial);
      break;
    case 'ply':
      loadPromise = window.PolysliceLoader.loadPLY(url, normalMaterial);
      break;
    case '3mf':
      loadPromise = window.PolysliceLoader.load3MF(url);
      break;
    case 'amf':
      loadPromise = window.PolysliceLoader.loadAMF(url);
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
      // Handle single mesh or array of meshes
      let object;
      if (Array.isArray(result)) {
        object = new THREE.Group();
        result.forEach((mesh) => {
          if (['3mf', 'amf', 'gltf', 'glb', 'dae'].includes(extension)) {
            mesh.material = normalMaterial;
          }
          object.add(mesh);
        });
      } else {
        object = result;
        if (['3mf', 'amf', 'gltf', 'glb', 'dae'].includes(extension)) {
          object.traverse((child) => {
            if (child.isMesh) {
              child.material = normalMaterial;
            }
          });
        }
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
export function displayMesh(object, filename, scene, callbacks) {
  const { centerCamera, hideForkMeBanner, hideGCodeLegends, createSlicingGUI, updateMeshInfo } = callbacks;

  scene.add(object);

  // Update info panel
  updateMeshInfo(filename, object);

  // Center camera
  centerCamera(object);

  // Hide fork me banner
  hideForkMeBanner();

  // Hide G-code legends
  hideGCodeLegends();

  // Show slicing GUI
  createSlicingGUI();

  return object;
}

/**
 * Load and visualize G-code content.
 */
export function loadGCode(content, filename, scene, callbacks) {
  const {
    updateDownloadVisibility,
    hideSlicingGUI,
    hideForkMeBanner,
    showGCodeLegends,
    centerCamera,
    setupLayerSlider,
    setupMoveSlider,
    updateInfo,
    applyThickLines,
    applyTranslucent,
    clearMeshData,
    clearGCodeData
  } = callbacks;

  // Store the G-code content
  updateDownloadVisibility(true, content, filename);

  // Remove previous objects
  clearGCodeData(scene);
  clearMeshData(scene);

  // Hide slicing GUI
  hideSlicingGUI();

  // Hide fork me banner
  hideForkMeBanner();

  // Show G-code legends
  showGCodeLegends();

  // Parse G-code
  const loader = new GCodeLoaderExtended();
  loader.splitLayer = true;
  const gcodeObject = loader.parse(content);

  // Add to scene
  scene.add(gcodeObject);

  // Setup layers and sliders
  setupLayerSlider(gcodeObject);
  setupMoveSlider(gcodeObject);

  // Update info panel
  updateInfo(filename, gcodeObject);

  // Center camera
  centerCamera(gcodeObject);

  // Apply settings
  const thickLinesCheckbox = document.getElementById('thick-lines-checkbox');
  if (thickLinesCheckbox && thickLinesCheckbox.checked) {
    applyThickLines(gcodeObject, true);
  }

  const translucentLinesCheckbox = document.getElementById('translucent-lines-checkbox');
  if (translucentLinesCheckbox && translucentLinesCheckbox.checked) {
    applyTranslucent(gcodeObject, true);
  }

  return gcodeObject;
}

/**
 * Update mesh info panel.
 */
export function updateMeshInfo(filename, object) {
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

  // Reset info position
  document.getElementById('info').style.bottom = '20px';
  document.getElementById('info').style.left = '20px';
}
