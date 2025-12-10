# ESM Build Fix - Three.js Externalization

## Problem
The ESM build (`dist/index.esm.js`) was bundling THREE.js and all node_modules dependencies, resulting in a 2.7MB file. This caused the warning "THREE.WARNING: Multiple instances of Three.js being imported" when Polyslice was used alongside other three.js imports in a project.

## Solution
Updated the build configuration to externalize all node_modules packages using esbuild's `--packages=external` flag. This ensures that THREE.js and other dependencies are imported as peer dependencies rather than being bundled.

### Changes Made
1. Updated `build:cjs` script to use `--packages=external`
2. Updated `build:esm` script to use `--packages=external`
3. Added `peerDependencies` section documenting THREE.js and three-subdivide requirements

### Results
- **Before**: `dist/index.esm.js` = 2.7MB (70,983 lines) - THREE.js bundled
- **After**: `dist/index.esm.js` = 330KB (9,260 lines) - THREE.js external
- **Reduction**: 87.8% smaller file size

## Usage

### For Bundlers (webpack, vite, rollup) - RECOMMENDED
The ESM build is designed specifically for bundlers. Use the following import:

```javascript
// In your bundled application
import * as THREE from 'three';
import Polyslice from '@jgphilpott/polyslice';

const geometry = new THREE.BoxGeometry(10, 10, 10);
const mesh = new THREE.Mesh(geometry);
const slicer = new Polyslice();
const gcode = slicer.slice(mesh);
```

The bundler will handle the external dependencies and ensure a single THREE.js instance is shared.

### For Node.js - Use CommonJS
For Node.js applications, use the CommonJS build:

```javascript
// In Node.js
const THREE = require('three');
const Polyslice = require('@jgphilpott/polyslice');

const geometry = new THREE.BoxGeometry(10, 10, 10);
const mesh = new THREE.Mesh(geometry);
const slicer = new Polyslice();
const gcode = slicer.slice(mesh);
```

### For Browsers - Use IIFE
For direct browser usage without a bundler, use the browser build:

```html
<script src="https://unpkg.com/three@0.181.0/build/three.min.js"></script>
<script src="dist/index.browser.js"></script>
<script>
  const geometry = new THREE.BoxGeometry(10, 10, 10);
  const mesh = new THREE.Mesh(geometry);
  const slicer = new Polyslice();
  const gcode = slicer.slice(mesh);
</script>
```

## Impact on Users
- **Bundler users** (webpack, vite, rollup): ✅ Will now properly share a single THREE.js instance across all modules
- **Node.js users**: ✅ Use CommonJS build (`require()`) for best compatibility
- **Browser IIFE users**: ✅ No change, browser build still bundles everything

## Dependencies
All node_modules dependencies are now treated as external:
- `three` (peer dependency)
- `three-subdivide` (peer dependency)
- `@jgphilpott/polyconvert`
- `@jgphilpott/polytree`
- `polygon-clipping`
- `serialport` (optional)

These will be resolved from the user's node_modules directory at build time (bundlers) or runtime (Node.js).

