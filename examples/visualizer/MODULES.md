# Visualizer Module Structure

The G-code Visualizer has been refactored from a single 1863-line file into a modular architecture with focused, maintainable modules.

## Architecture

```
examples/visualizer/
├── visualizer.js (321 lines)      # Main coordinator
├── visualizer.html                # HTML entry point
├── visualizer.css                 # Styles
├── modules/
│   ├── scene.js (195 lines)       # Three.js scene setup
│   ├── state.js (173 lines)       # localStorage persistence
│   ├── camera.js (94 lines)       # Camera utilities
│   ├── ui.js (229 lines)          # UI elements
│   ├── effects.js (166 lines)     # Visual effects
│   ├── interactions.js (159 lines) # Event handlers
│   ├── slicer.js (66 lines)       # Model slicing
│   ├── loaders.js (257 lines)     # File loading
│   └── visualization.js (387 lines) # Layer/move updates
└── libs/
    ├── GCodeLoaderExtended.js     # G-code parser
    ├── OrbitControls.js           # Camera controls
    └── faviconScheme.js           # Favicon handling
```

## Module Responsibilities

### visualizer.js (Main Coordinator)
- Initializes all modules
- Manages application state (gcodeObject, meshObject, etc.)
- Coordinates communication between modules
- Handles top-level events

### scene.js
- Three.js scene initialization
- Camera and renderer setup
- Axes and grid creation
- Animation loop
- Window resize handling

### state.js
- localStorage persistence for:
  - Movement type checkbox states
  - Axis visibility checkbox states
  - Settings (thick lines, translucent lines)
  - Slicing parameters (printer, filament, layer height, etc.)

### camera.js
- Camera focusing animations
- Camera centering on objects
- Camera reset to default position

### ui.js
- Legend creation (movement types, axes, settings)
- Layer slider (dual vertical sliders)
- Move slider (horizontal progress slider)
- Slicing GUI (lil-gui interface)
- Fork Me banner visibility
- Download button visibility

### effects.js
- Movement type visibility toggles
- Axis visibility toggles
- Settings toggles
- Thick lines effect
- Translucent lines effect

### interactions.js
- File upload handling
- Keyboard controls (WASD for tilt, arrows for pan)
- Double-click to focus on line
- Button event listeners

### slicer.js
- Model slicing using Polyslice library
- Printer and filament configuration
- G-code generation from 3D models

### loaders.js
- 3D model file loading (STL, OBJ, 3MF, AMF, PLY, GLTF, GLB, DAE)
- G-code file loading and parsing
- Mesh display and info updates
- File extension detection

### visualization.js
- Layer collection and organization
- Layer slider setup and updates
- Move slider setup and updates
- Layer visibility calculations
- Move visibility calculations (chronological and grouped)
- G-code info panel updates

## Data Flow

### Loading a 3D Model
```
visualizer.js (handleFileUpload)
  → loaders.js (loadModel)
    → scene (add mesh)
    → ui.js (createSlicingGUI)
    → camera.js (centerCamera)
```

### Slicing a Model
```
ui.js (Slice button)
  → slicer.js (sliceModel)
    → Polyslice library
    → loaders.js (loadGCode)
      → visualization.js (setupLayerSlider, setupMoveSlider)
```

### Loading G-code
```
visualizer.js (handleFileUpload)
  → loaders.js (loadGCode)
    → GCodeLoaderExtended (parse)
    → visualization.js (collectLayers, setupSliders)
    → effects.js (applyEffects)
```

### Adjusting Layer Visibility
```
UI (layer slider input)
  → visualization.js (updateLayerVisibility)
    → effects.js (check enabled types)
    → Three.js (segment.visible = true/false)
```

## State Management

### Application State (visualizer.js)
- `gcodeObject`: Current loaded G-code Three.js object
- `meshObject`: Current loaded 3D mesh object
- `isFirstUpload`: Flag for initial camera positioning
- `currentGcode`: G-code content for download
- `currentFilename`: Current file name
- `loadedModelForSlicing`: Mesh reference for slicing

### Layer State (layerState object)
- `allLayers`: Array of all layer segments
- `layersByIndex`: Map of layer index to segments
- `layerCount`: Total number of layers
- `layerSliderMin/Max`: Slider element references
- `moveSlider`: Move slider element reference
- `gcodeObject`: Reference to G-code object
- `updateLayerVisibility`: Callback function
- `updateMoveVisibility`: Callback function

### Persisted State (localStorage via state.js)
- Movement type checkbox states
- Axis checkbox states
- Settings (thick lines, translucent lines)
- Slicing settings (printer, filament, parameters)

## Benefits of Refactoring

1. **Maintainability**: Each module has a single, clear responsibility
2. **Testability**: Modules can be tested independently
3. **Reusability**: Functions can be imported where needed
4. **Readability**: Easier to navigate and understand code structure
5. **Collaboration**: Multiple developers can work on different modules
6. **Performance**: Modular imports enable better tree-shaking
7. **Debugging**: Easier to isolate and fix issues

## Migration Notes

The refactored visualizer maintains 100% backward compatibility:
- All features work exactly as before
- No changes to HTML or CSS required
- localStorage keys remain unchanged
- External libraries (Polyslice, PolysliceLoader, PolysliceExporter) work as before

## Future Improvements

Potential enhancements enabled by modular structure:
- Unit tests for individual modules
- Separate worker threads for heavy computations
- Plugin system for custom visualizations
- Alternative renderers (WebGPU)
- Export functionality for screenshots/videos
