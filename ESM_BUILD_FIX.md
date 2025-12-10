# ESM Build Fix - Three.js Externalization

## Problem
The ESM build (`dist/index.esm.js`) was bundling THREE.js and all node_modules dependencies, resulting in a 2.7MB file. This caused the warning "THREE.WARNING: Multiple instances of Three.js being imported" when Polyslice was used alongside other three.js imports in a project.

## Solution
Updated the build configuration to externalize THREE.js, three-subdivide, and @jgphilpott/polytree using esbuild's `--external` flags. This ensures that THREE.js and packages that depend on it are not bundled, preventing multiple THREE.js instances.

### Changes Made
1. Updated `build:cjs` script to use `--external:three --external:three-subdivide --external:@jgphilpott/polytree`
2. Updated `build:esm` script to use `--external:three --external:three-subdivide --external:@jgphilpott/polytree`
3. Added `peerDependencies` section documenting THREE.js, three-subdivide, and polytree requirements

### Results
- **Before**: `dist/index.esm.js` = 2.7MB (70,983 lines) - THREE.js bundled
- **After**: `dist/index.esm.js` = 737.5KB (22,430 lines) - THREE.js and polytree external
- **Reduction**: 72.7% smaller file size

## ⚠️ Important: How to Use Each Build

### ESM Build (`dist/index.esm.js`) - For Bundlers ONLY

**The ESM build is designed exclusively for module bundlers (webpack, vite, rollup, etc.).**

It will NOT work if you:
- Import it directly in Node.js with `import` statements
- Include it directly in a browser with `<script type="module">`
- Try to use it without a build tool

**Correct Usage with Bundlers:**
```javascript
// In your webpack/vite/rollup project
import * as THREE from 'three';
import Polyslice from '@jgphilpott/polyslice';

const mesh = new THREE.Mesh(geometry);
const slicer = new Polyslice();
const gcode = slicer.slice(mesh);
```

Your bundler will process the code and properly handle the external dependencies (THREE.js, three-subdivide, and @jgphilpott/polytree).

### CJS Build (`dist/index.js`) - For Node.js

**For Node.js applications, use the CommonJS build:**

```javascript
const THREE = require('three');
const Polyslice = require('@jgphilpott/polyslice');

const mesh = new THREE.Mesh(geometry);
const slicer = new Polyslice();
const gcode = slicer.slice(mesh);
```

### Browser IIFE Build (`dist/index.browser.js`) - For Direct Browser Use

**For browsers without a bundler, use the IIFE build:**

```html
<script src="https://unpkg.com/three@0.181.0/build/three.min.js"></script>
<script src="https://unpkg.com/@jgphilpott/polyslice/dist/index.browser.min.js"></script>
<script>
  const geometry = new THREE.BoxGeometry(10, 10, 10);
  const mesh = new THREE.Mesh(geometry);
  const slicer = new Polyslice();
  const gcode = slicer.slice(mesh);
</script>
```

## Why Can't I Use the ESM Build Directly?

The ESM build uses esbuild's CommonJS interop layer internally. While it outputs ESM format, it contains CommonJS-style `require()` calls for external dependencies. Modern bundlers understand this hybrid format and process it correctly, but:

- **Node.js ESM**: Cannot execute the CommonJS `require()` calls
- **Browsers**: Cannot resolve or execute `require()` statements  
- **Bundlers**: Can process and transform the code properly ✅

This is a standard pattern for npm packages that need to support multiple environments while keeping specific dependencies external.

## Impact on Users
- **Bundler users** (webpack, vite, rollup): ✅ Single THREE.js instance, no "multiple instances" warning
- **Node.js users**: ✅ Use CommonJS build (`require()`)
- **Browser users** (no bundler): ✅ Use IIFE build

## Dependencies

**Externalized** (must be installed by user):
- `three` (peer dependency ^0.180.0)
- `three-subdivide` (peer dependency ^1.1.5)
- `@jgphilpott/polytree` (peer dependency ^0.1.4) - Externalized because it has THREE.js dependency

**Bundled** (included in the build):
- `@jgphilpott/polyconvert`
- `polygon-clipping`
- `serialport` (optional, externalized in browser build)

### Why is polytree External?

The `@jgphilpott/polytree` package internally uses THREE.js. By externalizing it along with THREE.js, we ensure that all packages use the same THREE.js instance, preventing the "multiple instances" warning. Users who install polyslice will automatically get polytree as a dependency.


