/**
 * G-code Visualizer
 * Main coordinator that integrates all visualizer modules
 */

import * as THREE from 'three';
import { GCodeLoaderExtended } from './libs/GCodeLoaderExtended.js';
import { STLLoader } from 'three/addons/loaders/STLLoader.js';
import { OBJLoader } from 'three/addons/loaders/OBJLoader.js';
import { ThreeMFLoader } from 'three/addons/loaders/3MFLoader.js';
import { AMFLoader } from 'three/addons/loaders/AMFLoader.js';
import { PLYLoader } from 'three/addons/loaders/PLYLoader.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { ColladaLoader } from 'three/addons/loaders/ColladaLoader.js';
import { TransformControls } from 'three/addons/controls/TransformControls.js';

// Import modules
import { initScene, scene, camera, renderer, controls, axesLines, gridHelper, onWindowResize, animate } from './modules/scene.js';
import {
  createLegend,
  createLayerSlider,
  createMoveSlider,
  createSlicingGUI,
  hideSlicingGUI,
  hideForkMeBanner,
  showForkMeBanner,
  hideGCodeLegends,
  showGCodeLegends,
  updateDownloadButtonVisibility
} from './modules/ui.js';
import { clearSlicingSettings, saveCheckboxStates, saveAxisCheckboxStates, saveSettingsStates, saveSlicingSettings } from './modules/state.js';
import { centerCamera, resetCameraToDefault } from './modules/camera.js';
import {
  setupMovementTypeToggles,
  setupAxisToggles,
  setupSettingsToggles,
  applyThickLinesEffect,
  applyTranslucentLinesEffect
} from './modules/effects.js';
import {
  setupEventListeners,
  setupKeyboardControls,
  setupDoubleClickHandler,
  setupHoverHandler
} from './modules/interactions.js';
import { sliceModel } from './modules/slicer.js';
import {
  MODEL_EXTENSIONS,
  GCODE_EXTENSIONS,
  handleFileUpload as handleFileUploadHelper,
  loadModel,
  displayMesh as displayMeshHelper,
  loadGCode as loadGCodeHelper,
  updateMeshInfo
} from './modules/loaders.js';
import {
  setupLayerSlider as setupLayerSliderHelper,
  setupMoveSlider as setupMoveSliderHelper,
  updateLayerVisibility as updateLayerVisibilityHelper,
  updateMoveVisibility as updateMoveVisibilityHelper,
  updateInfo,
  collectLayers
} from './modules/visualization.js';

// Make THREE available globally for Polyslice loader
window.THREE = Object.assign({}, THREE, {
  STLLoader,
  OBJLoader,
  ThreeMFLoader,
  AMFLoader,
  PLYLoader,
  GLTFLoader,
  ColladaLoader
});

// Application state
let gcodeObject = null;
let meshObject = null;
let isFirstModelUpload = true;
let isFirstGcodeUpload = true;
let currentGcode = null;
let currentFilename = null;
let loadedModelForSlicing = null;
let transformControls = null;
// In three.js ≥ r162, TransformControls no longer extends Object3D.
// transformControlsGizmo holds the Object3D (_gizmo) that is added to the scene.
let transformControlsGizmo = null;

// Layer visualization state
const layerState = {
  allLayers: [],
  layersByIndex: {},
  layerCount: 0,
  layerSliderMin: null,
  layerSliderMax: null,
  moveSlider: null,
  gcodeObject: null,
  updateLayerVisibility: null,
  updateMoveVisibility: null
};

// Initialize on page load
window.addEventListener('DOMContentLoaded', init);

/**
 * Initialize the visualizer.
 */
function init() {

  // Initialize scene
  initScene();

  // Initialize TransformControls gizmo for interactive model rotation
  initTransformControls();

  // Create UI elements
  createLegend();
  createLayerSlider();
  createMoveSlider();

  // Setup layer state callback functions
  layerState.updateLayerVisibility = () => updateLayerVisibilityHelper(layerState);
  layerState.updateMoveVisibility = () => updateMoveVisibilityHelper(layerState);

  // Setup event listeners for toggles
  setupMovementTypeToggles(() => {
    if (layerState.allLayers.length > 0) {
      updateLayerVisibilityHelper(layerState);
    }
  });
  setupAxisToggles(axesLines, gridHelper);
  setupSettingsToggles(
    (isThick) => applyThickLinesEffect(gcodeObject, isThick),
    (isTranslucent) => applyTranslucentLinesEffect(gcodeObject, isTranslucent)
  );

  // Setup main event listeners
  setupEventListeners(handleFileUpload, handleDownload, resetView);

  // Handle window resize
  window.addEventListener('resize', onWindowResize, false);

  // Setup keyboard controls
  setupKeyboardControls(camera, controls);

  // Setup double-click handler
  setupDoubleClickHandler(scene, camera, renderer, controls);

  // Setup hover handler for G-code logging
  setupHoverHandler(scene, camera, renderer);

  // Hide G-code specific legends initially
  hideGCodeLegends();

  // Start animation loop
  animate();

}

/**
 * Handle file upload.
 */
function handleFileUpload(event) {
  handleFileUploadHelper(event, loadModelWrapper, loadGCodeWrapper);
}

// Rotation controller property names used for bidirectional slider sync.
const ROTATION_PROPERTIES = ['rotationX', 'rotationY', 'rotationZ'];

/**
 * Convert radians to degrees normalized to the range [-180, 180].
 * The double-modulo handles negative inputs: e.g. -190° → 170°.
 */
function radiansToDegrees(radians) {
  const degrees = radians * 180 / Math.PI;
  return ((degrees + 180) % 360 + 360) % 360 - 180;
}

/**
 * Sync the TransformControls current rotation back to the slicing GUI sliders.
 */
function syncTransformToSliders() {
  const mesh = transformControls?.object;
  if (!mesh || !window.slicingGUI) return;
  const params = window.slicingGUI.userData;
  if (!params) return;

  params.rotationX = radiansToDegrees(mesh.rotation.x);
  params.rotationY = radiansToDegrees(mesh.rotation.y);
  params.rotationZ = radiansToDegrees(mesh.rotation.z);

  window.slicingGUI.controllersRecursive().forEach(c => {
    if (ROTATION_PROPERTIES.includes(c.property)) {
      c.updateDisplay();
    }
  });

  saveSlicingSettings(params);
}

/**
 * Initialize TransformControls for interactive model rotation in the viewport.
 * In three.js ≥ r162, TransformControls extends Controls (not Object3D), so the
 * renderable gizmo lives in `_gizmo` and must be added to the scene separately.
 */
function initTransformControls() {
  transformControls = new TransformControls(camera, renderer.domElement);
  transformControls.setMode('rotate');

  // Use the internal gizmo Object3D for scene membership and visibility toggling.
  // In three.js ≥ r162, TransformControls extends Controls (not Object3D); the
  // renderable gizmo is in `_gizmo`. The fallback to `transformControls` itself
  // keeps compatibility with any build that still extends Object3D directly.
  transformControlsGizmo = transformControls._gizmo || transformControls;
  scene.add(transformControlsGizmo);

  // Disable orbit controls while the user is dragging the rotation gizmo.
  transformControls.addEventListener('dragging-changed', (event) => {
    controls.enabled = !event.value;
  });

  // Sync drag interactions back to the GUI sliders.
  transformControls.addEventListener('objectChange', syncTransformToSliders);

  // Hidden until a mesh is attached.
  transformControlsGizmo.visible = false;
}

/**
 * Apply a rotation in degrees to one axis of a mesh.
 */
function applyMeshRotation(mesh, axis, degrees) {
  if (!mesh) return;
  mesh.rotation[axis] = degrees * Math.PI / 180;
  mesh.updateMatrixWorld(true);
}

/**
 * Load 3D model wrapper.
 */
function loadModelWrapper(file) {
  const callbacks = {
    updateDownloadVisibility: (hasDownload) => {
      currentGcode = null;
      currentFilename = file.name;
      updateDownloadButtonVisibility(false);
    },
    hideSlicingGUI,
    displayMesh: (loadedMesh, filename) => {
      meshObject = displayMeshHelper(loadedMesh, filename, scene, {
        centerCamera: (obj) => {
          if (isFirstModelUpload) {
            centerCamera(obj, camera, controls);
            isFirstModelUpload = false;
          }
        },
        hideForkMeBanner,
        hideGCodeLegends,
        createSlicingGUI: () => {
          createSlicingGUI(
            () => {
              isFirstGcodeUpload = true;
              sliceModel(loadedModelForSlicing, currentFilename, loadGCodeWrapper);
            },
            false,
            (axis, degrees) => applyMeshRotation(loadedMesh, axis, degrees)
          );
        },
        updateMeshInfo
      });
      loadedModelForSlicing = loadedMesh;

      // Attach TransformControls gizmo to the loaded mesh.
      if (transformControls) {
        transformControls.attach(loadedMesh);
        transformControlsGizmo.visible = true;
      }

      return meshObject;
    },
    clearGCodeData: () => {
      if (gcodeObject) {
        scene.remove(gcodeObject);
        gcodeObject = null;
        layerState.allLayers = [];
        layerState.layersByIndex = {};
        layerState.layerCount = 0;
        layerState.gcodeObject = null;
      }
    },
    clearMeshData: (sceneObj) => {
      if (transformControls) {
        transformControls.detach();
        transformControlsGizmo.visible = false;
      }
      if (meshObject) {
        sceneObj.remove(meshObject);
        meshObject = null;
      }
    }
  };

  loadModel(file, scene, callbacks);
}

/**
 * Load G-code wrapper.
 */
function loadGCodeWrapper(content, filename) {
  const callbacks = {
    updateDownloadVisibility: (hasDownload, gcode, fname) => {
      currentGcode = gcode || content;
      currentFilename = fname || filename;
      updateDownloadButtonVisibility(true);
    },
    hideSlicingGUI,
    hideForkMeBanner,
    showGCodeLegends,
    centerCamera: (obj) => {
      if (isFirstGcodeUpload) {
        centerCamera(obj, camera, controls);
        isFirstGcodeUpload = false;
      }
    },
    setupLayerSlider: (gcodeObj) => {
      const layerData = collectLayers(gcodeObj);
      layerState.allLayers = layerData.allLayers;
      layerState.layersByIndex = layerData.layersByIndex;
      layerState.layerCount = layerData.layerCount;
      layerState.gcodeObject = gcodeObj;
      setupLayerSliderHelper(gcodeObj, layerState);
    },
    setupMoveSlider: (gcodeObj) => {
      setupMoveSliderHelper(gcodeObj, layerState);
    },
    updateInfo,
    applyThickLines: applyThickLinesEffect,
    applyTranslucent: applyTranslucentLinesEffect,
    clearMeshData: (sceneObj) => {
      if (transformControls) {
        transformControls.detach();
        transformControlsGizmo.visible = false;
      }
      if (meshObject) {
        sceneObj.remove(meshObject);
        meshObject = null;
      }
      loadedModelForSlicing = null;
    },
    clearGCodeData: (sceneObj) => {
      if (gcodeObject) {
        sceneObj.remove(gcodeObject);
        gcodeObject = null;
        layerState.allLayers = [];
        layerState.layersByIndex = {};
        layerState.layerCount = 0;
        layerState.gcodeObject = null;
      }
    }
  };

  gcodeObject = loadGCodeHelper(content, filename, scene, callbacks);
}

/**
 * Handle download button click.
 */
function handleDownload() {
  if (!currentGcode) {
    console.warn('No G-code available to download');
    return;
  }

  if (window.PolysliceExporter?.saveToFile) {
    window.PolysliceExporter.saveToFile(currentGcode, currentFilename ?? 'output.gcode')
      .then((filename) => {
        console.log(`G-code downloaded as: ${filename}`);
      })
      .catch((error) => {
        console.error('Error downloading G-code:', error);
      });
  } else {
    console.error('PolysliceExporter not available');
  }
}

/**
 * Reset view to initial state.
 */
function resetView() {
  // Reset camera position
  if (gcodeObject) {
    centerCamera(gcodeObject, camera, controls);
  } else if (meshObject) {
    centerCamera(meshObject, camera, controls);
  } else {
    resetCameraToDefault(camera, controls);
    showForkMeBanner();
  }

  // Reset first upload state so camera refocuses on the next upload
  isFirstModelUpload = true;
  isFirstGcodeUpload = true;

  // Reset all movement type checkboxes
  document.querySelectorAll('.legend-checkbox:not(.axis-checkbox):not(.settings-checkbox)').forEach(checkbox => {
    checkbox.checked = true;
  });
  saveCheckboxStates();

  // Reset all axis checkboxes
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
  saveAxisCheckboxStates();

  // Reset settings checkboxes
  const thickLinesCheckbox = document.getElementById('thick-lines-checkbox');
  if (thickLinesCheckbox) {
    thickLinesCheckbox.checked = false;
    applyThickLinesEffect(gcodeObject, false);
  }
  const translucentLinesCheckbox = document.getElementById('translucent-lines-checkbox');
  if (translucentLinesCheckbox) {
    translucentLinesCheckbox.checked = false;
    applyTranslucentLinesEffect(gcodeObject, false);
  }
  saveSettingsStates();

  // Reset layer sliders
  if (layerState.layerSliderMin && layerState.layerSliderMax && layerState.layerCount > 0) {
    layerState.layerSliderMin.value = 0;
    layerState.layerSliderMax.value = layerState.layerCount;
  }

  // Reset move slider
  if (layerState.moveSlider) {
    layerState.moveSlider.value = 100;
  }

  // Reset slicing settings
  clearSlicingSettings();

  // Detach TransformControls before resetting rotation.
  if (transformControls) {
    transformControls.detach();
    transformControlsGizmo.visible = false;
  }

  // Reset mesh rotation if a model is loaded
  if (meshObject) {
    meshObject.rotation.set(0, 0, 0);
    meshObject.updateMatrixWorld(true);
  }

  // Recreate slicing GUI with default settings if mesh is loaded
  if (meshObject && loadedModelForSlicing) {
    createSlicingGUI(
      () => sliceModel(loadedModelForSlicing, currentFilename, loadGCodeWrapper),
      true,
      (axis, degrees) => applyMeshRotation(meshObject, axis, degrees)
    );
  }

  // Re-attach TransformControls to the mesh after reset.
  if (meshObject && transformControls) {
    transformControls.attach(meshObject);
    transformControlsGizmo.visible = true;
  }

  // Update visibility
  if (layerState.allLayers.length > 0) {
    updateLayerVisibilityHelper(layerState);
  }
}
