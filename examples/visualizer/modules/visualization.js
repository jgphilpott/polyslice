/**
 * Visualization Module
 * Handles layer/move visibility updates and G-code info display
 */

import * as THREE from 'three';

/**
 * Setup layer slider after G-code is loaded.
 */
export function setupLayerSlider(gcodeObject, layerState) {
  if (layerState.layerCount === 0) {
    document.getElementById('layer-slider-container').classList.remove('visible');
    return;
  }

  // Show the sliders
  document.getElementById('layer-slider-container').classList.add('visible');
  document.getElementById('info').style.bottom = '110px';
  document.getElementById('info').style.left = '120px';

  // Get slider elements
  const layerSliderMin = document.getElementById('layer-slider-min');
  const layerSliderMax = document.getElementById('layer-slider-max');

  // Setup slider ranges
  layerSliderMin.min = 0;
  layerSliderMin.max = layerState.layerCount;
  layerSliderMin.value = 0;

  layerSliderMax.min = 0;
  layerSliderMax.max = layerState.layerCount;
  layerSliderMax.value = layerState.layerCount;

  // Store slider elements in state
  layerState.layerSliderMin = layerSliderMin;
  layerState.layerSliderMax = layerSliderMax;

  // Remove existing listeners and add new ones
  layerSliderMin.removeEventListener('input', layerState.updateLayerVisibility);
  layerSliderMax.removeEventListener('input', layerState.updateLayerVisibility);
  layerSliderMin.addEventListener('input', layerState.updateLayerVisibility);
  layerSliderMax.addEventListener('input', layerState.updateLayerVisibility);

  // Update initial display
  layerState.updateLayerVisibility();
}

/**
 * Setup move slider after G-code is loaded.
 */
export function setupMoveSlider(gcodeObject, layerState) {
  if (layerState.layerCount === 0) {
    document.getElementById('move-slider-container').classList.remove('visible');
    return;
  }

  // Show the slider
  document.getElementById('move-slider-container').classList.add('visible');

  // Get slider element
  const moveSlider = document.getElementById('move-slider');

  // Reset slider to full (100%)
  moveSlider.value = 100;

  // Store slider element in state
  layerState.moveSlider = moveSlider;

  // Remove existing listener and add new one
  moveSlider.removeEventListener('input', layerState.updateMoveVisibility);
  moveSlider.addEventListener('input', layerState.updateMoveVisibility);

  // Update initial display
  layerState.updateMoveVisibility();
}

/**
 * Update layer visibility based on slider values.
 */
export function updateLayerVisibility(layerState) {
  // Early return if sliders aren't set up yet
  if (!layerState.layerSliderMin || !layerState.layerSliderMax) {
    return;
  }

  let minLayer = parseInt(layerState.layerSliderMin.value);
  let maxLayer = parseInt(layerState.layerSliderMax.value);

  // Ensure min is not greater than max
  if (minLayer > maxLayer) {
    const temp = minLayer;
    minLayer = maxLayer;
    maxLayer = temp;
    layerState.layerSliderMin.value = minLayer;
    layerState.layerSliderMax.value = maxLayer;
  }

  // Get currently enabled movement types
  const enabledTypes = new Set();
  document.querySelectorAll('.legend-checkbox:checked').forEach(checkbox => {
    enabledTypes.add(checkbox.dataset.type);
  });

  // Update visibility for all line segments
  for (let i = 0; i < layerState.allLayers.length; i++) {
    const segment = layerState.allLayers[i];
    const segmentLayerIndex = segment.userData.layerIndex;

    const layerVisible = segmentLayerIndex === undefined
      ? true
      : (segmentLayerIndex >= minLayer && segmentLayerIndex < maxLayer);

    const typeEnabled = enabledTypes.has(segment.userData.type) || enabledTypes.has(segment.material.name);

    segment.visible = layerVisible && typeEnabled;
  }

  // Update info text
  const infoText =
    minLayer === 0 && maxLayer === layerState.layerCount
      ? 'All Layers'
      : `<p>Layers ${minLayer} - ${maxLayer - 1}</p><p>(${maxLayer - minLayer} / ${layerState.layerCount})</p>`;
  document.getElementById('layer-info').innerHTML = infoText;

  // Update move slider
  layerState.updateMoveVisibility();
}

/**
 * Update move visibility based on horizontal slider value.
 */
export function updateMoveVisibility(layerState) {
  // Early return if sliders aren't set up yet
  if (!layerState.moveSlider || !layerState.layerSliderMin || !layerState.layerSliderMax) {
    return;
  }

  const movePercentage = parseInt(layerState.moveSlider.value);

  // Update info text
  document.getElementById('move-info').textContent = `Move Progress: ${movePercentage}%`;

  // Find the topmost visible layer
  let minLayer = parseInt(layerState.layerSliderMin.value);
  let maxLayer = parseInt(layerState.layerSliderMax.value);

  if (minLayer > maxLayer) {
    const temp = minLayer;
    minLayer = maxLayer;
    maxLayer = temp;
  }

  const topLayerIndex = maxLayer - 1;

  // Get enabled movement types
  const enabledTypes = new Set();
  document.querySelectorAll('.legend-checkbox:checked').forEach(checkbox => {
    enabledTypes.add(checkbox.dataset.type);
  });

  // Calculate chronological segments
  let totalChronologicalSegments = 0;
  const topLayerChronologicalSegments = [];

  layerState.allLayers.forEach(segment => {
    if (segment.userData.chronological && segment.userData.layerIndex === topLayerIndex) {
      topLayerChronologicalSegments.push(segment);
      if (segment.userData.chronologicalEnd !== undefined) {
        totalChronologicalSegments = Math.max(totalChronologicalSegments, segment.userData.chronologicalEnd);
      }
    }
  });

  const visibleChronologicalCount = Math.ceil((totalChronologicalSegments * movePercentage) / 100);

  let lastVisibleLine = null;
  let lastVisibleCmd = null;

  // Process all segments
  layerState.allLayers.forEach(segment => {
    const segmentLayerIndex = segment.userData.layerIndex;

    const layerVisible = segmentLayerIndex === undefined
      ? true
      : (segmentLayerIndex >= minLayer && segmentLayerIndex < maxLayer);

    const typeEnabled = enabledTypes.has(segment.userData.type) ||
                       enabledTypes.has(segment.material.name);

    // For chronological segments on the top layer
    if (segment.userData.chronological && segmentLayerIndex === topLayerIndex) {
      const start = segment.userData.chronologicalStart || 0;
      const end = segment.userData.chronologicalEnd || 0;

      if (visibleChronologicalCount <= start) {
        segment.visible = false;
      } else if (visibleChronologicalCount >= end) {
        segment.visible = layerVisible && typeEnabled;
        if (segment.geometry.drawRange && segment.userData.fullVertexCount) {
          segment.geometry.setDrawRange(0, segment.userData.fullVertexCount);
        }
        if (segment.userData.sourceLines && segment.userData.sourceCmds) {
          const idx = segment.userData.sourceLines.length - 1;
          if (idx >= 0) {
            lastVisibleLine = segment.userData.sourceLines[idx];
            lastVisibleCmd = segment.userData.sourceCmds[idx];
          }
        }
      } else {
        const visibleInThisSegment = visibleChronologicalCount - start;
        const drawCount = visibleInThisSegment * 2;

        if (segment.geometry.drawRange) {
          segment.geometry.setDrawRange(0, drawCount);
        }

        segment.visible = layerVisible && typeEnabled && (visibleInThisSegment > 0);

        if (segment.userData.sourceLines && segment.userData.sourceCmds) {
          const idx = Math.max(0, Math.min(segment.userData.sourceLines.length - 1, visibleInThisSegment - 1));
          lastVisibleLine = segment.userData.sourceLines[idx];
          lastVisibleCmd = segment.userData.sourceCmds[idx];
        }
      }
    }
    // For non-chronological segments
    else if (!segment.userData.chronological) {
      if (segmentLayerIndex === topLayerIndex && segment.userData.segmentCount) {
        const totalSegments = segment.userData.segmentCount;
        const visibleSegments = Math.ceil((totalSegments * movePercentage) / 100);
        const drawCount = visibleSegments * 2;

        if (segment.geometry.drawRange) {
          segment.geometry.setDrawRange(0, drawCount);
        }

        segment.visible = layerVisible && typeEnabled && (visibleSegments > 0);
      } else {
        if (segment.geometry.drawRange && segment.userData.fullVertexCount) {
          segment.geometry.setDrawRange(0, segment.userData.fullVertexCount);
        }
        segment.visible = layerVisible && typeEnabled;
      }
    } else {
      if (segment.geometry.drawRange && segment.userData.fullVertexCount) {
        segment.geometry.setDrawRange(0, segment.userData.fullVertexCount);
      }
      segment.visible = layerVisible && typeEnabled;
    }
  });

  // Log current G-code position
  if (topLayerIndex >= 0) {
    if (lastVisibleLine != null && lastVisibleCmd != null) {
      console.log(`G-code line ${lastVisibleLine + 1}: ${lastVisibleCmd}`);
    } else if (layerState.gcodeObject && layerState.gcodeObject.userData && layerState.gcodeObject.userData.metadata) {
      const meta = layerState.gcodeObject.userData.metadata;
      const layerStart = meta.layerComments ? meta.layerComments[topLayerIndex] : undefined;
      if (typeof layerStart === 'number') {
        console.log(`Layer ${topLayerIndex} (starts at G-code line ${layerStart + 1})`);
      }
    }
  }
}

/**
 * Update G-code info panel.
 */
export function updateInfo(filename, object) {
  document.getElementById('filename').textContent = filename;

  let totalLines = 0;
  const typeCount = {};

  object.traverse(child => {
    if (child instanceof THREE.LineSegments) {
      totalLines++;

      if (child.material && child.material.name) {
        const typeName = child.material.name;
        typeCount[typeName] = (typeCount[typeName] || 0) + 1;
      }
    }
  });

  // Build stats text
  let statsLines = [`Total segments: ${totalLines}`];

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
 * Collect all layers from G-code object.
 */
export function collectLayers(gcodeObject) {
  const allLayers = [];
  const layersByIndex = {};
  let layerCount = 0;

  // Get layer count from metadata
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

  // Collect all layer segments
  gcodeObject.traverse(child => {
    if (child instanceof THREE.LineSegments) {
      allLayers.push(child);
      child.visible = true;

      // Extract layer index
      if (child.name.startsWith('layer')) {
        const layerIndex = parseInt(child.name.replace('layer', ''));
        if (!isNaN(layerIndex)) {
          child.userData.layerIndex = layerIndex;

          if (!layersByIndex[layerIndex]) {
            layersByIndex[layerIndex] = [];
          }
          layersByIndex[layerIndex].push(child);
        }
      }
    }
  });

  return { allLayers, layersByIndex, layerCount };
}
