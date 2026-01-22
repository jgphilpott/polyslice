/**
 * Interactions Module
 * Handles keyboard controls, mouse interactions, and event listeners
 */

import * as THREE from 'three';
import { focusCameraOnPoint } from './camera.js';

/**
 * Setup main event listeners for upload, download, and reset buttons.
 */
export function setupEventListeners(handleFileUploadCallback, handleDownloadCallback, resetViewCallback) {
  // Upload button
  document.getElementById('upload').addEventListener('click', () => {
    document.getElementById('uploader').click();
  });

  // File input change
  document
    .getElementById('uploader')
    .addEventListener('change', handleFileUploadCallback);

  // Download button
  document.getElementById('download').addEventListener('click', handleDownloadCallback);

  // Reset button
  document.getElementById('reset').addEventListener('click', resetViewCallback);
}

/**
 * Setup custom keyboard controls for WASD (camera tilt) and arrow keys (camera position).
 */
export function setupKeyboardControls(camera, controls) {
  // Movement speed for keyboard controls
  const rotateSpeed = 0.05;
  const panSpeed = 5;

  // Track which slider is currently focused
  let focusedSlider = null;

  // Add focus/blur listeners to all sliders
  const layerSliderMin = document.getElementById('layer-slider-min');
  const layerSliderMax = document.getElementById('layer-slider-max');
  const moveSlider = document.getElementById('move-slider');

  const sliders = [layerSliderMin, layerSliderMax, moveSlider];

  sliders.forEach(slider => {
    if (slider) {
      slider.addEventListener('focus', () => {
        focusedSlider = slider;
      });

      slider.addEventListener('blur', () => {
        if (focusedSlider === slider) {
          focusedSlider = null;
        }
      });
    }
  });

  window.addEventListener('keydown', (event) => {
    let needsUpdate = false;
    let sliderHandled = false;

    // Check if a slider is focused and handle arrow keys for slider control
    if (focusedSlider) {
      const isVerticalSlider = (focusedSlider === layerSliderMin || focusedSlider === layerSliderMax);
      const isHorizontalSlider = (focusedSlider === moveSlider);

      const currentValue = parseInt(focusedSlider.value);
      const minValue = parseInt(focusedSlider.min);
      const maxValue = parseInt(focusedSlider.max);

      switch (event.key.toLowerCase()) {
        case 'arrowup':
          if (isVerticalSlider) {
            // For vertical sliders, up arrow increases value
            if (currentValue < maxValue) {
              focusedSlider.value = currentValue + 1;
              focusedSlider.dispatchEvent(new Event('input', { bubbles: true }));
            }
            sliderHandled = true;
            event.preventDefault();
          }
          break;

        case 'arrowdown':
          if (isVerticalSlider) {
            // For vertical sliders, down arrow decreases value
            if (currentValue > minValue) {
              focusedSlider.value = currentValue - 1;
              focusedSlider.dispatchEvent(new Event('input', { bubbles: true }));
            }
            sliderHandled = true;
            event.preventDefault();
          }
          break;

        case 'arrowleft':
          if (isHorizontalSlider) {
            // For horizontal slider, left arrow decreases value
            if (currentValue > minValue) {
              focusedSlider.value = currentValue - 1;
              focusedSlider.dispatchEvent(new Event('input', { bubbles: true }));
            }
            sliderHandled = true;
            event.preventDefault();
          }
          break;

        case 'arrowright':
          if (isHorizontalSlider) {
            // For horizontal slider, right arrow increases value
            if (currentValue < maxValue) {
              focusedSlider.value = currentValue + 1;
              focusedSlider.dispatchEvent(new Event('input', { bubbles: true }));
            }
            sliderHandled = true;
            event.preventDefault();
          }
          break;
      }
    }

    // If slider didn't handle the key, use it for camera control
    if (!sliderHandled) {
      // Get camera's current orientation vectors
      const forward = new THREE.Vector3();
      const right = new THREE.Vector3();
      const up = new THREE.Vector3(0, 1, 0);

      camera.getWorldDirection(forward);
      right.crossVectors(forward, up).normalize();

      switch (event.key.toLowerCase()) {
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
    }
  });
}

/**
 * Setup double-click handler to focus camera on clicked line.
 */
export function setupDoubleClickHandler(scene, camera, renderer, controls) {
  const raycaster = new THREE.Raycaster();
  const mouse = new THREE.Vector2();

  raycaster.params.Line.threshold = 2;

  renderer.domElement.addEventListener('dblclick', (event) => {
    // Calculate mouse position in normalized device coordinates
    const rect = renderer.domElement.getBoundingClientRect();
    mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    mouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;

    // Update the raycaster
    raycaster.setFromCamera(mouse, camera);

    // Calculate intersections
    const intersects = raycaster.intersectObjects(scene.children, true);

    // Find the first intersected line segment
    for (let i = 0; i < intersects.length; i++) {
      const intersect = intersects[i];

      if (intersect.object instanceof THREE.LineSegments ||
          intersect.object instanceof THREE.Line) {

        const point = intersect.point.clone();
        focusCameraOnPoint(point, camera, controls);
        break;
      }
    }
  });
}
