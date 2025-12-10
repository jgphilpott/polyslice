# Browser IIFE Build Without THREE.js

## Overview

The `dist/index.browser.iife.js` build is an IIFE (Immediately Invoked Function Expression) format that **externalizes THREE.js** and related dependencies. This is perfect for use with `<script>` tags where THREE.js is loaded separately, such as with import maps or CDN usage in the three.js examples.

## Key Differences from Standard IIFE Build

| Build | File | Size | THREE.js | Use Case |
|-------|------|------|----------|----------|
| Standard IIFE | `index.browser.js` | 2.7MB | Bundled | Direct `<script>` tag, everything included |
| **Lightweight IIFE** | `index.browser.iife.js` | 628KB | External | Use with separate THREE.js `<script>` tag |

## Usage

### With Script Tags (Recommended)

```html
<!-- Load THREE.js first -->
<script src="https://unpkg.com/three@0.181.0/build/three.min.js"></script>

<!-- Load Polyslice IIFE build (expects THREE globally) -->
<script src="https://unpkg.com/@jgphilpott/polyslice/dist/index.browser.iife.js"></script>

<script>
  // THREE and Polyslice are now globally available
  const geometry = new THREE.BoxGeometry(10, 10, 10);
  const mesh = new THREE.Mesh(geometry);
  const slicer = new Polyslice();
  const gcode = slicer.slice(mesh);
  console.log(gcode);
</script>
```

### With Import Maps

This build also works well with import maps by providing THREE.js as a global:

```html
<script src="https://unpkg.com/three@0.181.0/build/three.min.js"></script>

<script type="importmap">
{
  "imports": {
    "@jgphilpott/polyslice": "https://unpkg.com/@jgphilpott/polyslice/dist/index.browser.iife.js"
  }
}
</script>

<script type="module">
  // Use as module, but Polyslice is still available as global
  const slicer = new Polyslice();
</script>
```

## Externalized Dependencies

The following dependencies are **externalized** and must be loaded separately:

- `three` - THREE.js library (must be available globally as `window.THREE`)
- `three-subdivide` - For mesh subdivision
- `@jgphilpott/polytree` - For spatial querying
- `serialport` - Not available in browser

The following are **bundled**:

- `@jgphilpott/polyconvert` - Unit conversions
- `polygon-clipping` - Polygon operations

## File Size Comparison

- **Standard IIFE** (`index.browser.js`): 2.7MB - Everything bundled
- **Lightweight IIFE** (`index.browser.iife.js`): 628KB - THREE.js external (76.9% smaller!)
- **THREE.js** (separate): ~600KB when loaded via CDN

**Total when using lightweight IIFE**: ~1.2MB (still 55% smaller than bundled version)

## When to Use Each Build

### Use Lightweight IIFE (`index.browser.iife.js`) when:

✅ THREE.js is already loaded on the page  
✅ Using in three.js examples or similar projects  
✅ Want smaller bundle size  
✅ Loading THREE.js from CDN separately  

### Use Standard IIFE (`index.browser.js`) when:

✅ Want a single self-contained file  
✅ THREE.js is not already available  
✅ Simplicity over file size  

### Use Browser ESM (`index.browser.esm.js`) when:

✅ Using import maps with ALL dependencies mapped  
✅ Need ES module format  
✅ All dependencies available as ESM modules  

## Browser Compatibility

Same as standard IIFE build:
- Chrome 60+
- Firefox 54+
- Safari 10.1+
- Edge 15+

## Example: three.js Examples Repository

This build is perfect for the three.js examples repository:

```html
<!DOCTYPE html>
<html>
<head>
  <script src="../build/three.module.js"></script>
  <script src="https://unpkg.com/@jgphilpott/polyslice/dist/index.browser.iife.js"></script>
</head>
<body>
  <script>
    // THREE is already loaded globally from three.module.js
    // Polyslice is now available globally
    
    const geometry = new THREE.TorusKnotGeometry(10, 3, 100, 16);
    const mesh = new THREE.Mesh(geometry);
    
    const slicer = new Polyslice({
      nozzleTemperature: 200,
      bedTemperature: 60,
      layerHeight: 0.2
    });
    
    const gcode = slicer.slice(mesh);
    console.log('Generated G-code:', gcode);
  </script>
</body>
</html>
```

## Minified Version

For production use, a minified version will be available as `index.browser.iife.min.js` (when minification is added to the build process).

## Technical Details

- **Format**: IIFE (Immediately Invoked Function Expression)
- **Platform**: browser
- **Global Name**: `Polyslice`
- **External Dependencies**: three, three-subdivide, @jgphilpott/polytree, serialport
- **Bundled Dependencies**: @jgphilpott/polyconvert, polygon-clipping
- **Output Size**: ~628KB unminified

## Comparison with Other Builds

| Build | Use Case | Size | THREE.js Handling |
|-------|----------|------|-------------------|
| `index.esm.js` | Bundlers (webpack/vite) | 737KB | External (peer dep) |
| `index.browser.esm.js` | Import maps | 330KB | All deps external |
| `index.browser.iife.js` | Script tags w/ THREE | 628KB | External (global) |
| `index.browser.js` | Script tags standalone | 2.7MB | Bundled |
| `index.js` | Node.js CommonJS | 737KB | External (peer dep) |
