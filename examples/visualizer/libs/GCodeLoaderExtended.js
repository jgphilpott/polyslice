import {
  BufferGeometry,
  FileLoader,
  Float32BufferAttribute,
  Group,
  LineBasicMaterial,
  LineSegments,
  Loader,
} from 'three';

/**
 * Extended GCode Loader - Preserves comments and metadata.
 *
 * GCode files are usually used for 3D printing or CNC applications.
 * This extended version preserves comments and extracts metadata for advanced visualization.
 *
 * ```js
 * const loader = new GCodeLoaderExtended();
 * const object = await loader.loadAsync( 'models/gcode/benchy.gcode' );
 * scene.add( object );
 * ```
 *
 * @augments Loader
 */
class GCodeLoaderExtended extends Loader {
  /**
   * Constructs a new GCode loader.
   *
   * @param {LoadingManager} [manager] - The loading manager.
   */
  constructor(manager) {
    super(manager);

    /**
     * Whether to split layers or not.
     *
     * @type {boolean}
     * @default false
     */
    this.splitLayer = false;
  }

  /**
   * Starts loading from the given URL and passes the loaded GCode asset
   * to the `onLoad()` callback.
   *
   * @param {string} url - The path/URL of the file to be loaded. This can also be a data URI.
   * @param {function(Group)} onLoad - Executed when the loading process has been finished.
   * @param {onProgressCallback} onProgress - Executed while the loading is in progress.
   * @param {onErrorCallback} onError - Executed when errors occur.
   */
  load(url, onLoad, onProgress, onError) {
    const scope = this;

    const loader = new FileLoader(scope.manager);
    loader.setPath(scope.path);
    loader.setRequestHeader(scope.requestHeader);
    loader.setWithCredentials(scope.withCredentials);
    loader.load(
      url,
      function (text) {
        try {
          onLoad(scope.parse(text));
        } catch (e) {
          if (onError) {
            onError(e);
          } else {
            console.error(e);
          }

          scope.manager.itemError(url);
        }
      },
      onProgress,
      onError
    );
  }

  /**
   * Parses the given GCode data and returns a group with lines.
   *
   * @param {string} data - The raw Gcode data as a string.
   * @return {Group} The parsed GCode asset.
   */
  parse(data) {
    let state = {
      x: 0,
      y: 0,
      z: 0,
      e: 0,
      f: 0,
      extruding: false,
      relative: false,
      currentType: null, // Track current movement type from comments
    };
    const layers = [];

    let currentLayer = undefined;

    // Define materials for different movement types
    const materials = {
      path: new LineBasicMaterial({ color: 0xff0000, name: 'path' }),
      extruded: new LineBasicMaterial({ color: 0x00ff00, name: 'extruded' }),
      'WALL-OUTER': new LineBasicMaterial({ color: 0xff6600, name: 'WALL-OUTER' }),
      'WALL-INNER': new LineBasicMaterial({ color: 0xff9933, name: 'WALL-INNER' }),
      SKIN: new LineBasicMaterial({ color: 0xffcc00, name: 'SKIN' }),
      FILL: new LineBasicMaterial({ color: 0x00ccff, name: 'FILL' }),
      SUPPORT: new LineBasicMaterial({ color: 0xff00ff, name: 'SUPPORT' }),
      'SUPPORT-INTERFACE': new LineBasicMaterial({ color: 0xcc00cc, name: 'SUPPORT-INTERFACE' }),
      SKIRT: new LineBasicMaterial({ color: 0x888888, name: 'SKIRT' }),
      PRIME: new LineBasicMaterial({ color: 0x00ff00, name: 'PRIME' }),
    };

    // Legacy references for compatibility
    const pathMaterial = materials.path;
    const extrudingMaterial = materials.extruded;

    function newLayer(line) {
      currentLayer = {
        vertex: [],
        pathVertex: [],
        z: line.z,
        segments: [] // Store segments with their type information
      };
      layers.push(currentLayer);
    }

    //Create line segment between p1 and p2
    function addSegment(p1, p2) {
      if (currentLayer === undefined) {
        newLayer(p1);
      }

      // Determine the type for this segment
      // Non-extruding moves (G0 or G1 without extrusion) are always 'path' (red)
      const segmentType = state.extruding
        ? (state.currentType || 'extruded')
        : 'path';

      // Store segment with type information
      currentLayer.segments.push({
        p1: { x: p1.x, y: p1.y, z: p1.z },
        p2: { x: p2.x, y: p2.y, z: p2.z },
        type: segmentType,
        extruding: state.extruding
      });

      // Also maintain legacy vertex arrays for backward compatibility
      if (state.extruding) {
        currentLayer.vertex.push(p1.x, p1.y, p1.z);
        currentLayer.vertex.push(p2.x, p2.y, p2.z);
      } else {
        currentLayer.pathVertex.push(p1.x, p1.y, p1.z);
        currentLayer.pathVertex.push(p2.x, p2.y, p2.z);
      }
    }

    function delta(v1, v2) {
      return state.relative ? v2 : v2 - v1;
    }

    function absolute(v1, v2) {
      return state.relative ? v1 + v2 : v2;
    }

    // Store metadata from comments
    const metadata = {
      comments: [],
      layerComments: {},
      moveTypes: {},
      layerCount: 0,
    };

    const lines = data.split('\n');

    for (let i = 0; i < lines.length; i++) {
      const rawLine = lines[i];

      // Extract comment if present
      let comment = null;
      let codePart = rawLine;
      const commentIndex = rawLine.indexOf(';');
      if (commentIndex !== -1) {
        comment = rawLine.substring(commentIndex + 1).trim();
        codePart = rawLine.substring(0, commentIndex).trim();
        metadata.comments.push({ line: i, comment });

        // Parse special Cura-style comments
        if (comment.startsWith('TYPE:')) {
          const type = comment.substring(5).trim();
          state.currentType = type;
          metadata.moveTypes[type] = (metadata.moveTypes[type] || 0) + 1;
        } else if (comment.startsWith('LAYER:')) {
          const layerNum = parseInt(comment.substring(6).trim());
          if (!isNaN(layerNum)) {
            metadata.layerCount = Math.max(metadata.layerCount, layerNum + 1);
            metadata.layerComments[layerNum] = i;
          }
        } else if (comment.includes('post-print sequence') || comment.includes('Post-print sequence')) {
          // Clear currentType for post-print sequence - all moves should be travel (red)
          state.currentType = null;
        }
      }

      const tokens = codePart.split(' ');
      const cmd = tokens[0].toUpperCase();

      //Arguments
      const args = {};
      tokens.splice(1).forEach(function (token) {
        if (token[0] !== undefined) {
          const key = token[0].toLowerCase();
          const value = parseFloat(token.substring(1));
          args[key] = value;
        }
      });

      //Process commands
      //M117 – Display Message (check for post-print sequence)
      if (cmd === 'M117') {
        // Check if the M117 message contains post-print sequence text
        const message = rawLine.substring(4).trim(); // Get everything after "M117"
        if (message.includes('post-print sequence') || message.includes('Post-print sequence')) {
          // Clear currentType for post-print sequence - all moves should be travel (red)
          state.currentType = null;
        }
      }
      //G0/G1 – Linear Movement
      else if (cmd === 'G0' || cmd === 'G1') {
        const line = {
          x: args.x !== undefined ? absolute(state.x, args.x) : state.x,
          y: args.y !== undefined ? absolute(state.y, args.y) : state.y,
          z: args.z !== undefined ? absolute(state.z, args.z) : state.z,
          e: args.e !== undefined ? absolute(state.e, args.e) : state.e,
          f: args.f !== undefined ? absolute(state.f, args.f) : state.f,
        };

        // Determine if this move is extruding based on command type and context
        if (cmd === 'G0') {
          state.extruding = false; // G0 is always travel (red)
        } else { // G1
          // G1 with a currentType (like WALL-OUTER) is always extruding
          // G1 without a currentType follows the E parameter logic
          if (state.currentType) {
            state.extruding = true; // Any G1 with active TYPE is extruding
          } else if (args.e !== undefined) {
            state.extruding = delta(state.e, line.e) > 0;
          }
          // If no currentType and no E parameter, keep previous extruding state
        }

        // Layer change detection is made by watching when we extrude at a new Z position
        if (state.extruding) {
          if (currentLayer == undefined || line.z != currentLayer.z) {
            newLayer(line);
          }
        }

        addSegment(state, line);

        // Preserve currentType when updating state
        const preservedType = state.currentType;
        const preservedRelative = state.relative;
        state = line;
        state.currentType = preservedType;
        state.relative = preservedRelative;
      } else if (cmd === 'G2' || cmd === 'G3') {
        //G2/G3 - Arc Movement ( G2 clock wise and G3 counter clock wise )
        //console.warn( 'THREE.GCodeLoader: Arc command not supported' );
      } else if (cmd === 'G90') {
        //G90: Set to Absolute Positioning
        state.relative = false;
      } else if (cmd === 'G91') {
        //G91: Set to state.relative Positioning
        state.relative = true;
      } else if (cmd === 'G92') {
        //G92: Set Position
        const line = state;
        line.x = args.x !== undefined ? args.x : line.x;
        line.y = args.y !== undefined ? args.y : line.y;
        line.z = args.z !== undefined ? args.z : line.z;
        line.e = args.e !== undefined ? args.e : line.e;
      } else {
        //console.warn( 'THREE.GCodeLoader: Command not supported:' + cmd );
      }
    }

    function addObject(vertex, extruding, i) {
      const geometry = new BufferGeometry();
      geometry.setAttribute('position', new Float32BufferAttribute(vertex, 3));
      const segments = new LineSegments(
        geometry,
        extruding ? extrudingMaterial : pathMaterial
      );
      segments.name = 'layer' + i;
      segments.userData.layerIndex = i;
      segments.userData.segmentCount = vertex.length / 6;
      segments.userData.fullVertexCount = vertex.length;
      object.add(segments);
    }

    // Add segments grouped by type
    function addSegmentsByType(layer, layerIndex) {
      // Group segments by type
      const segmentsByType = {};

      layer.segments.forEach(seg => {
        const type = seg.type;
        if (!segmentsByType[type]) {
          segmentsByType[type] = [];
        }
        segmentsByType[type].push(seg.p1.x, seg.p1.y, seg.p1.z);
        segmentsByType[type].push(seg.p2.x, seg.p2.y, seg.p2.z);
      });

      // Create line segments for each type
      Object.keys(segmentsByType).forEach(type => {
        const vertices = segmentsByType[type];
        if (vertices.length > 0) {
          const geometry = new BufferGeometry();
          geometry.setAttribute('position', new Float32BufferAttribute(vertices, 3));

          // Use specific material for the type, or fall back to extruded/path
          const material = materials[type] || materials.extruded;

          const segments = new LineSegments(geometry, material);
          segments.name = 'layer' + layerIndex;
          segments.userData.type = type;
          segments.userData.layerIndex = layerIndex;
          
          // Store segment count for move slider functionality
          // Each line segment uses 2 vertices, so total segments = vertices / 6
          segments.userData.segmentCount = vertices.length / 6;
          segments.userData.fullVertexCount = vertices.length;
          
          object.add(segments);
        }
      });
    }

    // Add segments in chronological order (for move slider chronological playback)
    function addSegmentsChronological(layer, layerIndex) {
      // Build chronological vertex array with type information
      const vertices = [];
      const typeRanges = []; // Track [startIndex, endIndex, type] for each contiguous type section
      
      let currentType = null;
      let currentRangeStart = 0;
      
      layer.segments.forEach((seg, index) => {
        const type = seg.type;
        
        // If type changed, record the previous range
        if (currentType !== null && currentType !== type) {
          typeRanges.push({
            start: currentRangeStart,
            end: vertices.length / 3, // Convert vertex index to actual index
            type: currentType
          });
          currentRangeStart = vertices.length / 3;
        }
        
        currentType = type;
        
        // Add segment vertices
        vertices.push(seg.p1.x, seg.p1.y, seg.p1.z);
        vertices.push(seg.p2.x, seg.p2.y, seg.p2.z);
      });
      
      // Record final range
      if (currentType !== null) {
        typeRanges.push({
          start: currentRangeStart,
          end: vertices.length / 3,
          type: currentType
        });
      }
      
      if (vertices.length > 0) {
        const geometry = new BufferGeometry();
        geometry.setAttribute('position', new Float32BufferAttribute(vertices, 3));
        
        // Use a default material - visibility will be controlled per-type
        const material = materials.extruded;
        
        const segments = new LineSegments(geometry, material);
        segments.name = 'layer' + layerIndex;
        segments.userData.layerIndex = layerIndex;
        segments.userData.chronological = true; // Mark as chronological
        
        // Store segment count for move slider functionality
        segments.userData.segmentCount = vertices.length / 6;
        segments.userData.fullVertexCount = vertices.length;
        
        // Store type ranges for filtering
        segments.userData.typeRanges = typeRanges;
        
        object.add(segments);
      }
    }

    const object = new Group();
    object.name = 'gcode';

    // Use type-based rendering when TYPE comments are detected
    const hasTypeComments = Object.keys(metadata.moveTypes).length > 0;

    if (hasTypeComments && this.splitLayer) {
      // Split by layer with chronological order (for move slider)
      for (let i = 0; i < layers.length; i++) {
        const layer = layers[i];
        addSegmentsChronological(layer, i);
      }
    } else if (hasTypeComments && !this.splitLayer) {
      // All layers combined but colored by type
      const allSegmentsByType = {};

      for (let i = 0; i < layers.length; i++) {
        const layer = layers[i];
        layer.segments.forEach(seg => {
          const type = seg.type;
          if (!allSegmentsByType[type]) {
            allSegmentsByType[type] = [];
          }
          allSegmentsByType[type].push(seg.p1.x, seg.p1.y, seg.p1.z);
          allSegmentsByType[type].push(seg.p2.x, seg.p2.y, seg.p2.z);
        });
      }

      // Create line segments for each type
      Object.keys(allSegmentsByType).forEach(type => {
        const vertices = allSegmentsByType[type];
        if (vertices.length > 0) {
          const geometry = new BufferGeometry();
          geometry.setAttribute('position', new Float32BufferAttribute(vertices, 3));

          const material = materials[type] || materials.extruded;

          const segments = new LineSegments(geometry, material);
          segments.name = 'type_' + type;
          segments.userData.type = type;
          object.add(segments);
        }
      });
    } else if (this.splitLayer) {
      // Legacy: split by layer without type colors
      for (let i = 0; i < layers.length; i++) {
        const layer = layers[i];
        addObject(layer.vertex, true, i);
        addObject(layer.pathVertex, false, i);
      }
    } else {
      // Legacy: all combined without type colors
      const vertex = [],
        pathVertex = [];

      for (let i = 0; i < layers.length; i++) {
        const layer = layers[i];
        const layerVertex = layer.vertex;
        const layerPathVertex = layer.pathVertex;

        for (let j = 0; j < layerVertex.length; j++) {
          vertex.push(layerVertex[j]);
        }

        for (let j = 0; j < layerPathVertex.length; j++) {
          pathVertex.push(layerPathVertex[j]);
        }
      }

      addObject(vertex, true, layers.length);
      addObject(pathVertex, false, layers.length);
    }

    object.rotation.set(-Math.PI / 2, 0, 0);

    // Attach metadata to the object
    object.userData.metadata = metadata;

    return object;
  }
}

export { GCodeLoaderExtended };
