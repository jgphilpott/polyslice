/**
 * State Management Module
 * Handles localStorage persistence for checkbox states and settings
 */

/**
 * Save movement type checkbox states to localStorage.
 */
export function saveCheckboxStates() {
  const states = {};
  document.querySelectorAll('.legend-checkbox:not(.axis-checkbox):not(.settings-checkbox)').forEach(checkbox => {
    states[checkbox.dataset.type] = checkbox.checked;
  });
  try {
    localStorage.setItem('visualizer-checkbox-states', JSON.stringify(states));
  } catch (error) {
    console.warn('Failed to save checkbox states to localStorage:', error);
  }
}

/**
 * Load movement type checkbox states from localStorage.
 */
export function loadCheckboxStates() {
  try {
    const saved = localStorage.getItem('visualizer-checkbox-states');
    if (saved) {
      const states = JSON.parse(saved);
      document.querySelectorAll('.legend-checkbox:not(.axis-checkbox):not(.settings-checkbox)').forEach(checkbox => {
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
 * Save axis checkbox states to localStorage.
 */
export function saveAxisCheckboxStates() {
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
 * Load axis checkbox states from localStorage.
 */
export function loadAxisCheckboxStates(axesLines, gridHelper) {
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
export function saveSettingsStates() {
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
export function loadSettingsStates() {
  try {
    const saved = localStorage.getItem('visualizer-settings-states');
    if (saved) {
      const states = JSON.parse(saved);
      const thickLinesCheckbox = document.getElementById('thick-lines-checkbox');
      const translucentLinesCheckbox = document.getElementById('translucent-lines-checkbox');
      if (thickLinesCheckbox && 'thickLines' in states) {
        thickLinesCheckbox.checked = states.thickLines;
      }
      if (translucentLinesCheckbox && 'translucentLines' in states) {
        translucentLinesCheckbox.checked = states.translucentLines;
      }
    }
  } catch (error) {
    console.warn('Failed to load settings states from localStorage:', error);
  }
}

/**
 * Save slicing settings to localStorage.
 */
export function saveSlicingSettings(params) {
  const settings = {
    rotationX: params.rotationX,
    rotationY: params.rotationY,
    rotationZ: params.rotationZ,
    printer: params.printer,
    filament: params.filament,
    nozzleTemperature: params.nozzleTemperature,
    bedTemperature: params.bedTemperature,
    fanSpeed: params.fanSpeed,
    layerHeight: params.layerHeight,
    shellWallThickness: params.shellWallThickness,
    shellSkinThickness: params.shellSkinThickness,
    infillDensity: params.infillDensity,
    infillPattern: params.infillPattern,
    adhesionEnabled: params.adhesionEnabled,
    adhesionType: params.adhesionType,
    supportEnabled: params.supportEnabled,
    supportType: params.supportType,
    supportPlacement: params.supportPlacement,
    supportThreshold: params.supportThreshold
  };
  try {
    localStorage.setItem('visualizer-slicing-settings', JSON.stringify(settings));
  } catch (error) {
    console.warn('Failed to save slicing settings to localStorage:', error);
  }
}

/**
 * Load slicing settings from localStorage.
 */
export function loadSlicingSettings() {
  try {
    const saved = localStorage.getItem('visualizer-slicing-settings');
    if (saved) {
      return JSON.parse(saved);
    }
  } catch (error) {
    console.warn('Failed to load slicing settings from localStorage:', error);
  }
  return null;
}

/**
 * Clear slicing settings from localStorage.
 */
export function clearSlicingSettings() {
  try {
    localStorage.removeItem('visualizer-slicing-settings');
  } catch (error) {
    console.warn('Failed to clear slicing settings from localStorage:', error);
  }
}
