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
import { clearSlicingSettings, saveCheckboxStates, saveAxisCheckboxStates, saveSettingsStates } from './modules/state.js';
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
  setupDoubleClickHandler
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
let isFirstUpload = true;
let currentGcode = null;
let currentFilename = null;
let loadedModelForSlicing = null;

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
    displayMesh: (object, filename) => {
      meshObject = displayMeshHelper(object, filename, scene, {
        centerCamera: (obj) => {
          if (isFirstUpload) {
            centerCamera(obj, camera, controls);
            isFirstUpload = false;
          }
        },
        hideForkMeBanner,
        hideGCodeLegends,
        createSlicingGUI: () => {
          createSlicingGUI(() => sliceModel(loadedModelForSlicing, currentFilename, loadGCodeWrapper));
        },
        updateMeshInfo,
        isFirstUpload: () => isFirstUpload
      });
      loadedModelForSlicing = object;
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
      if (isFirstUpload) {
        centerCamera(obj, camera, controls);
        isFirstUpload = false;
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
    isFirstUpload: () => isFirstUpload,
    clearMeshData: (sceneObj) => {
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

  // Update visibility
  if (layerState.allLayers.length > 0) {
    updateLayerVisibilityHelper(layerState);
  }
}
