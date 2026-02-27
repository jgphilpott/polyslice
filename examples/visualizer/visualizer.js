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
// True while a gizmo drag is in progress; prevents the pointerup click handler
// from treating the drag-release as a "click elsewhere" and hiding the gizmo.
let wasDraggingGizmo = false;

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
 * In three.js ≥ r162, TransformControls extends Controls (not Object3D).
 * getHelper() returns the TransformControlsRoot (an Object3D) that contains both
 * the renderable gizmo and the interaction plane, and must be added to the scene.
 * attach() / detach() manage root.visible automatically.
 */
function initTransformControls() {
  transformControls = new TransformControls(camera, renderer.domElement);
  transformControls.setMode('rotate');

  // Add the helper root (gizmo + interaction plane) to the scene.
  scene.add(transformControls.getHelper());

  // Disable orbit controls while the user is dragging the rotation gizmo.
  // Track that a drag occurred so the pointerup handler can ignore it.
  transformControls.addEventListener('dragging-changed', (event) => {
    controls.enabled = !event.value;
    if (event.value) wasDraggingGizmo = true;
  });

  // Sync drag interactions back to the GUI sliders.
  transformControls.addEventListener('objectChange', syncTransformToSliders);

  // Show the gizmo when the user clicks on the mesh; hide it on click-elsewhere.
  // The listener is registered once at startup so no cleanup reference is needed.
  const raycaster = new THREE.Raycaster();
  const pointer = new THREE.Vector2();

  renderer.domElement.addEventListener('pointerup', (event) => {
    // A drag-release must not be treated as a "click elsewhere".
    if (wasDraggingGizmo) {
      wasDraggingGizmo = false;
      return;
    }

    if (!meshObject) return;

    const rect = renderer.domElement.getBoundingClientRect();
    pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
    raycaster.setFromCamera(pointer, camera);

    const hits = raycaster.intersectObject(meshObject, true);
    if (hits.length > 0) {
      // Click on mesh: attach and reveal the gizmo.
      transformControls.attach(meshObject);
    } else {
      // Click elsewhere: hide the gizmo.
      transformControls.detach();
    }
  });

  // Gizmo is hidden until the user clicks the mesh.
  transformControls.detach();
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

      // TransformControls are available; gizmo appears when the user clicks the mesh.
      if (transformControls) {
        transformControls.detach();
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

  // Ensure TransformControls remain detached after reset; gizmo appears only when the user clicks the mesh.
  if (meshObject && transformControls) {
    transformControls.detach();
  }

  // Update visibility
  if (layerState.allLayers.length > 0) {
    updateLayerVisibilityHelper(layerState);
  }
}
