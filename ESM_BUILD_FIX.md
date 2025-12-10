# ESM Build Fix - Three.js Externalization

## Problem
The ESM build (`dist/index.esm.js`) was bundling THREE.js and all node_modules dependencies, resulting in a 2.7MB file. This caused the warning "THREE.WARNING: Multiple instances of Three.js being imported" when Polyslice was used alongside other three.js imports in a project.

## Solution
Updated the build configuration to externalize all node_modules packages using esbuild's `--packages=external` flag. This ensures that THREE.js and other dependencies are imported as peer dependencies rather than being bundled.

### Changes Made
1. Updated `build:cjs` script to use `--packages=external`
2. Updated `build:esm` script to use `--packages=external`
3. Added `createRequire` banner to ESM build to support CommonJS-style requires in ESM context
4. Added `peerDependencies` section documenting THREE.js and three-subdivide requirements

### Results
- **Before**: `dist/index.esm.js` = 2.7MB (70,983 lines) - THREE.js bundled
- **After**: `dist/index.esm.js` = 330KB (9,260 lines) - THREE.js external
- **Reduction**: 87.8% smaller file size

## Testing
```javascript
// ESM Import (works in Node.js and bundlers)
import * as THREE from 'three';
import Polyslice from '@jgphilpott/polyslice';

const geometry = new THREE.BoxGeometry(10, 10, 10);
const mesh = new THREE.Mesh(geometry);
const slicer = new Polyslice();
const gcode = slicer.slice(mesh);
```

## Impact on Users
- **Bundler users** (webpack, vite, rollup): Will now properly share a single THREE.js instance across all modules
- **Node.js ESM users**: Can now import Polyslice as an ES module
- **Node.js CommonJS users**: No change, still works the same way
- **Browser IIFE users**: No change, browser build still bundles everything

## Dependencies
All node_modules dependencies are now treated as external:
- `three` (peer dependency)
- `three-subdivide` (peer dependency)
- `@jgphilpott/polyconvert`
- `@jgphilpott/polytree`
- `polygon-clipping`
- `serialport` (optional)

These will be resolved from the user's node_modules directory at runtime.
