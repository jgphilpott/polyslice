/**
 * Effects Module
 * Handles visual effects (thick lines, translucent lines) and visibility toggles
 */

import * as THREE from 'three';
import { saveCheckboxStates, saveAxisCheckboxStates, saveSettingsStates, loadCheckboxStates, loadAxisCheckboxStates, loadSettingsStates } from './state.js';

/**
 * Setup event listeners for movement type visibility toggles.
 */
export function setupMovementTypeToggles(updateLayerVisibilityCallback) {
  const checkboxes = document.querySelectorAll('.legend-checkbox:not(.axis-checkbox):not(.settings-checkbox)');

  // Load saved checkbox states from localStorage
  loadCheckboxStates();

  checkboxes.forEach(checkbox => {
    checkbox.addEventListener('change', () => {
      saveCheckboxStates();
      updateLayerVisibilityCallback();
    });
  });
}

/**
 * Setup event listeners for axis visibility toggles.
 */
export function setupAxisToggles(axesLines, gridHelper) {
  const axisCheckboxes = document.querySelectorAll('.axis-checkbox');

  // Load saved axis checkbox states from localStorage
  loadAxisCheckboxStates(axesLines, gridHelper);

  axisCheckboxes.forEach(checkbox => {
    checkbox.addEventListener('change', (event) => {
      const axis = event.target.dataset.axis;
      const isVisible = event.target.checked;

      saveAxisCheckboxStates();

      if (axis === 'grid') {
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
export function setupSettingsToggles(applyThickLinesCallback, applyTranslucentLinesCallback) {
  const thickLinesCheckbox = document.getElementById('thick-lines-checkbox');
  const translucentLinesCheckbox = document.getElementById('translucent-lines-checkbox');

  // Load saved settings from localStorage
  loadSettingsStates();

  if (thickLinesCheckbox) {
    thickLinesCheckbox.addEventListener('change', (event) => {
      const isThick = event.target.checked;
      saveSettingsStates();
      applyThickLinesCallback(isThick);
    });
  }

  if (translucentLinesCheckbox) {
    translucentLinesCheckbox.addEventListener('change', (event) => {
      const isTranslucent = event.target.checked;
      saveSettingsStates();
      applyTranslucentLinesCallback(isTranslucent);
    });
  }
}

/**
 * Apply or remove thick lines effect to all G-code line segments.
 */
export function applyThickLinesEffect(gcodeObject, isThick) {

  if (!gcodeObject) return;

  // Check current translucent state
  const translucentCheckbox = document.getElementById('translucent-lines-checkbox');
  const isTranslucent = translucentCheckbox ? translucentCheckbox.checked : false;

  gcodeObject.traverse(child => {
    if (!(child instanceof THREE.LineSegments || child instanceof THREE.Line)) return;
    if (!child.material) return;

    const isTravelLine = child.material.name === 'path';

    if (isThick && !isTravelLine) {
      if (!child.userData.originalMaterial) {
        child.userData.originalMaterial = child.material;
      }
      if (!child.userData.thickMaterial) {
        const thickMat = child.userData.originalMaterial.clone();
        thickMat.linewidth = 5;
        child.userData.thickMaterial = thickMat;
      }
      if (child.material !== child.userData.thickMaterial) {
        child.material = child.userData.thickMaterial;
        // Apply translucent state to thick material
        if (isTranslucent) {
          child.material.transparent = true;
          child.material.opacity = 0.5;
        } else {
          child.material.transparent = false;
          child.material.opacity = 1;
        }
        child.material.needsUpdate = true;
      }
    } else {
      if (child.userData.originalMaterial && child.material !== child.userData.originalMaterial) {
        child.material = child.userData.originalMaterial;
        // Apply translucent state to original material
        if (isTranslucent) {
          child.material.transparent = true;
          child.material.opacity = 0.5;
        } else {
          child.material.transparent = child.userData.originalTransparent ?? false;
          child.material.opacity = child.userData.originalOpacity ?? 1;
        }
        child.material.needsUpdate = true;
      }
    }
  });

}

/**
 * Apply or remove translucency to all G-code line segments.
 */
export function applyTranslucentLinesEffect(gcodeObject, isTranslucent) {

  if (!gcodeObject) return;

  // Check current thick state
  const thickCheckbox = document.getElementById('thick-lines-checkbox');
  const isThick = thickCheckbox ? thickCheckbox.checked : false;

  gcodeObject.traverse(child => {
    if (!(child instanceof THREE.LineSegments || child instanceof THREE.Line)) return;
    if (!child.material) return;

    // Preserve original transparency settings
    if (child.userData.originalTransparent === undefined) {
      child.userData.originalTransparent = !!child.material.transparent;
    }
    if (child.userData.originalOpacity === undefined) {
      child.userData.originalOpacity = (child.material.opacity !== undefined) ? child.material.opacity : 1;
    }

    // Apply translucent effect to whichever material is currently active
    if (isTranslucent) {
      child.material.transparent = true;
      child.material.opacity = 0.5;
      child.material.needsUpdate = true;
    } else {
      // When disabling translucent, respect the original values
      child.material.transparent = child.userData.originalTransparent ?? false;
      child.material.opacity = child.userData.originalOpacity ?? 1;
      child.material.needsUpdate = true;
    }
  });

}
