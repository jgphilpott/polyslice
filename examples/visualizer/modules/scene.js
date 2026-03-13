/**
 * Scene Setup Module
 * Handles Three.js scene, camera, renderer, axes, and grid initialization
 */

import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

// Default build volume dimensions (mm) – matches the Ender3 preset.
export const AXIS_LENGTH = 220;

// Scene state
export let scene, camera, renderer, controls;
export let axesLines;
export let gridHelper = null;

/**
 * Initialize the Three.js scene, camera, renderer, and controls.
 */
export function initScene() {

  // Create scene.
  scene = new THREE.Scene();
  scene.background = new THREE.Color(0x1a1a1a);

  // Use Z-up coordinate system to match G-code expectations and model slicing
  THREE.Object3D.DEFAULT_UP.set(0, 0, 1);

  // Create camera.
  camera = new THREE.PerspectiveCamera(
    75,
    window.innerWidth / window.innerHeight,
    0.1,
    1000
  );
  camera.up.set(0, 0, 1);
  camera.position.set(300, 300, 150);
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

  // Add custom axes.
  createAxes();

  // Add grid helper.
  createGridHelper();

}

/**
 * Create custom axes with proper colors and thickness.
 * @param {number} sizeX - Length of the X axis in mm.
 * @param {number} sizeY - Length of the Y axis in mm.
 * @param {number} sizeZ - Length of the Z axis in mm.
 */
function createAxes(sizeX = AXIS_LENGTH, sizeY = AXIS_LENGTH, sizeZ = AXIS_LENGTH) {

  const axisThickness = 3;

  // Create X axis (red)
  const xGeometry = new THREE.BufferGeometry().setFromPoints([
    new THREE.Vector3(0, 0, 0),
    new THREE.Vector3(sizeX, 0, 0),
  ]);
  const xMaterial = new THREE.LineBasicMaterial({
    color: 0xff0000,
    linewidth: axisThickness,
  });
  const xAxis = new THREE.Line(xGeometry, xMaterial);
  scene.add(xAxis);

  // Create Y axis (green)
  const yGeometry = new THREE.BufferGeometry().setFromPoints([
    new THREE.Vector3(0, 0, 0),
    new THREE.Vector3(0, sizeY, 0),
  ]);
  const yMaterial = new THREE.LineBasicMaterial({
    color: 0x00ff00,
    linewidth: axisThickness,
  });
  const yAxis = new THREE.Line(yGeometry, yMaterial);
  scene.add(yAxis);

  // Create Z axis (blue)
  const zGeometry = new THREE.BufferGeometry().setFromPoints([
    new THREE.Vector3(0, 0, 0),
    new THREE.Vector3(0, 0, sizeZ),
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
 * Create grid helper on the XY plane.
 * @param {number} sizeX - Width of the grid in mm (X direction).
 * @param {number} sizeY - Length of the grid in mm (Y direction).
 */
function createGridHelper(sizeX = AXIS_LENGTH, sizeY = AXIS_LENGTH) {

  const divisions = 20;
  const colorCenterLine = 0x888888;
  const colorGrid = 0x444444;

  const group = new THREE.Group();

  const materialCenter = new THREE.LineBasicMaterial({ color: colorCenterLine });
  const materialGrid = new THREE.LineBasicMaterial({ color: colorGrid });

  // Step size based on divisions
  const stepX = sizeX / divisions;
  const stepY = sizeY / divisions;

  // Vertical lines (parallel to Y axis)
  for (let x = 0; x <= sizeX + 1e-4; x += stepX) {
    const points = [];
    points.push(new THREE.Vector3(x, 0, 0));
    points.push(new THREE.Vector3(x, sizeY, 0));
    const geom = new THREE.BufferGeometry().setFromPoints(points);
    const isCenter = Math.abs(x) < 1e-6;
    const line = new THREE.Line(geom, isCenter ? materialCenter : materialGrid);
    group.add(line);
  }

  // Horizontal lines (parallel to X axis)
  for (let y = 0; y <= sizeY + 1e-4; y += stepY) {
    const points = [];
    points.push(new THREE.Vector3(0, y, 0));
    points.push(new THREE.Vector3(sizeX, y, 0));
    const geom = new THREE.BufferGeometry().setFromPoints(points);
    const isCenter = Math.abs(y) < 1e-6;
    const line = new THREE.Line(geom, isCenter ? materialCenter : materialGrid);
    group.add(line);
  }

  gridHelper = group;
  scene.add(gridHelper);

}

/**
 * Update the scene axes and grid to match new printer build volume dimensions.
 * Updates the existing Three.js objects in-place so that all references held by
 * event listeners (axis visibility toggles) continue to work correctly.
 *
 * @param {number} width  - Build plate width  in mm (X axis).
 * @param {number} length - Build plate length in mm (Y axis).
 * @param {number} height - Build volume height in mm (Z axis).
 */
export function updateBuildVolume(width, length, height) {

  if (axesLines) {
    // Update each axis line's endpoint position in-place.
    const xPos = axesLines[0].geometry.attributes.position;
    xPos.setXYZ(1, width, 0, 0);
    xPos.needsUpdate = true;

    const yPos = axesLines[1].geometry.attributes.position;
    yPos.setXYZ(1, 0, length, 0);
    yPos.needsUpdate = true;

    const zPos = axesLines[2].geometry.attributes.position;
    zPos.setXYZ(1, 0, 0, height);
    zPos.needsUpdate = true;
  }

  if (gridHelper) {
    // Dispose existing child geometries and remove them from the group.
    while (gridHelper.children.length > 0) {
      const child = gridHelper.children[0];
      child.geometry.dispose();
      gridHelper.remove(child);
    }

    // Rebuild the grid for the new build plate dimensions.
    const divisions = 20;
    const colorCenterLine = 0x888888;
    const colorGrid = 0x444444;

    const materialCenter = new THREE.LineBasicMaterial({ color: colorCenterLine });
    const materialGrid = new THREE.LineBasicMaterial({ color: colorGrid });

    const stepX = width / divisions;
    const stepY = length / divisions;

    for (let x = 0; x <= width + 0.001; x += stepX) {
      const geom = new THREE.BufferGeometry().setFromPoints([
        new THREE.Vector3(x, 0, 0),
        new THREE.Vector3(x, length, 0),
      ]);
      const isCenter = Math.abs(x) < 1e-6;
      gridHelper.add(new THREE.Line(geom, isCenter ? materialCenter : materialGrid));
    }

    for (let y = 0; y <= length + 0.001; y += stepY) {
      const geom = new THREE.BufferGeometry().setFromPoints([
        new THREE.Vector3(0, y, 0),
        new THREE.Vector3(width, y, 0),
      ]);
      const isCenter = Math.abs(y) < 1e-6;
      gridHelper.add(new THREE.Line(geom, isCenter ? materialCenter : materialGrid));
    }
  }

}

/**
 * Handle window resize.
 */
export function onWindowResize() {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
}

/**
 * Animation loop.
 */
export function animate() {

  requestAnimationFrame(animate);

  controls.update();

  renderer.render(scene, camera);

}
