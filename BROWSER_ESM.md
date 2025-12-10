# Browser ESM Build for Import Maps

## Overview

The `dist/index.browser.esm.js` build is designed for use with browser import maps. Unlike the standard ESM build (`dist/index.esm.js`) which requires bundlers, this build can be loaded directly in browsers using import maps.

## Usage

### Required Import Map Setup

All external dependencies must be mapped in your import map:

```html
<script type="importmap">
{
  "imports": {
    "three": "https://unpkg.com/three@0.181.0/build/three.module.js",
    "three-subdivide": "https://unpkg.com/three-subdivide@1.1.5/build/index.module.js",
    "@jgphilpott/polytree": "https://unpkg.com/@jgphilpott/polytree@0.1.4/polytree.bundle.browser.js",
    "@jgphilpott/polyconvert": "https://unpkg.com/@jgphilpott/polyconvert@1.0.4/polyconvert.js",
    "polygon-clipping": "https://unpkg.com/polygon-clipping@0.15.7/dist/polygon-clipping.umd.js",
    "@jgphilpott/polyslice": "https://unpkg.com/@jgphilpott/polyslice/dist/index.browser.esm.js"
  }
}
</script>

<script type="module">
  import Polyslice from '@jgphilpott/polyslice';
  import * as THREE from 'three';
  
  const geometry = new THREE.BoxGeometry(10, 10, 10);
  const mesh = new THREE.Mesh(geometry);
  const slicer = new Polyslice();
  const gcode = slicer.slice(mesh);
  console.log(gcode);
</script>
```

## Dependencies

The browser ESM build externalizes all dependencies:

- `three` - THREE.js library
- `three-subdivide` - Mesh subdivision
- `@jgphilpott/polytree` - Spatial querying
- `@jgphilpott/polyconvert` - Unit conversions
- `polygon-clipping` - Polygon operations
- `serialport` - Optional (for serial communication, not available in browser)

## File Size

- **Size**: ~330KB
- **Lines**: ~9,260
- **Reduction from full bundle**: 88% smaller than IIFE build (2.7MB)

## Comparison with Other Builds

| Build | Use Case | Size | Dependencies |
|-------|----------|------|--------------|
| `index.browser.esm.js` | Import maps in browser | 330KB | All external |
| `index.esm.js` | Bundlers (webpack/vite) | 737KB | three, three-subdivide, polytree external |
| `index.browser.js` | Direct `<script>` tag | 2.7MB | Everything bundled (IIFE) |
| `index.js` | Node.js CommonJS | 737KB | three, three-subdivide, polytree external |

## Limitations

**Note**: This build still uses CommonJS interop internally for managing modules. The `require()` calls for external dependencies will fail unless those dependencies are properly shimmed or the browser environment provides them.

### Known Issue

The current implementation may still have issues with some dependencies in pure browser ESM contexts because:

1. Source code uses `require()` statements
2. esbuild preserves these as runtime `__require()` calls even with `--format=esm`
3. Import maps don't automatically provide a `require()` function

### Recommendation

For the most reliable browser experience with import maps, consider using the **IIFE build** (`dist/index.browser.js`) which bundles all dependencies and works without any import map configuration.

For production applications using bundlers (webpack, vite, rollup), use the standard **ESM build** (`dist/index.esm.js`) which properly externalizes THREE.js to prevent multiple instances.
