/**
 * Camera Utilities Module
 * Handles camera focusing, centering, and animations
 */

import * as THREE from 'three';

/**
 * Center camera on an object.
 */
export function centerCamera(object, camera, controls) {
  const box = new THREE.Box3().setFromObject(object);
  const center = box.getCenter(new THREE.Vector3());
  const size = box.getSize(new THREE.Vector3());

  // Calculate optimal camera distance.
  const maxDim = Math.max(size.x, size.y, size.z);
  const fov = camera.fov * (Math.PI / 180);
  let cameraZ = Math.abs(maxDim / 2 / Math.tan(fov / 2));
  cameraZ *= 1.5;

  // Position camera.
  camera.position.set(
    center.x + cameraZ,
    center.y + cameraZ,
    center.z + cameraZ
  );

  camera.lookAt(center);

  // Update controls target.
  controls.target.copy(center);
  controls.update();
}

/**
 * Focus camera on a specific point with smooth animation.
 */
export function focusCameraOnPoint(point, camera, controls) {
  // Calculate current camera direction
  const direction = new THREE.Vector3()
    .subVectors(camera.position, controls.target)
    .normalize();

  // Set a closer distance for more precise focusing
  const focusDistance = 20;

  // Calculate new camera position closer to the point
  const newCameraPosition = new THREE.Vector3()
    .addVectors(point, direction.multiplyScalar(focusDistance));

  // Smoothly transition to new position
  const startPosition = camera.position.clone();
  const startTarget = controls.target.clone();
  const duration = 500;
  const startTime = Date.now();

  function animateCamera() {
    const elapsed = Date.now() - startTime;
    const progress = Math.min(elapsed / duration, 1);

    // Use easing function for smooth animation (ease-out cubic)
    const easeProgress = 1 - Math.pow(1 - progress, 3);

    // Interpolate camera position
    camera.position.lerpVectors(startPosition, newCameraPosition, easeProgress);

    // Interpolate controls target to the exact clicked point
    controls.target.lerpVectors(startTarget, point, easeProgress);

    controls.update();

    if (progress < 1) {
      requestAnimationFrame(animateCamera);
    }
  }

  animateCamera();
}

/**
 * Reset camera to default position.
 */
export function resetCameraToDefault(camera, controls) {
  camera.position.set(300, 300, 150);
  camera.lookAt(0, 0, 0);
  controls.target.set(0, 0, 0);
  controls.update();
}
