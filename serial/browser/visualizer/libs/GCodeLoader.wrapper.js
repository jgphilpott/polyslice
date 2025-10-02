// Wrapper to make GCodeLoader work with global THREE object
(function() {
    const module = {};
    
    // GCodeLoader implementation
    class GCodeLoader extends THREE.Loader {
        constructor(manager) {
            super(manager);
            this.splitLayer = false;
        }

        load(url, onLoad, onProgress, onError) {
            const scope = this;
            const loader = new THREE.FileLoader(scope.manager);
            loader.setPath(scope.path);
            loader.setRequestHeader(scope.requestHeader);
            loader.setWithCredentials(scope.withCredentials);
            loader.load(url, function(text) {
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
            }, onProgress, onError);
        }

        parse(data) {
            let state = { x: 0, y: 0, z: 0, e: 0, f: 0, extruding: false, relative: false };
            const layers = [];
            let currentLayer = undefined;
            const pathMaterial = new THREE.LineBasicMaterial({ color: 0xFF0000 });
            const travelMaterial = new THREE.LineBasicMaterial({ color: 0x00FF00 });
            
            const object = new THREE.Group();
            
            function newLayer(line) {
                currentLayer = { vertex: [], pathVertex: [], z: line.z };
                layers.push(currentLayer);
            }

            function addSegment(p1, p2, extruding) {
                const geometry = new THREE.BufferGeometry();
                geometry.setAttribute('position', new THREE.Float32BufferAttribute([p1.x, p1.y, p1.z, p2.x, p2.y, p2.z], 3));
                const segments = new THREE.LineSegments(geometry, extruding ? pathMaterial : travelMaterial);
                segments.userData.type = extruding ? 'G1' : 'G0';
                return segments;
            }

            const lines = data.replace(/;.+/g, '').split('\n');

            for (let i = 0; i < lines.length; i++) {
                const tokens = lines[i].split(' ');
                const cmd = tokens[0].toUpperCase();

                const args = {};
                tokens.splice(1).forEach(function(token) {
                    if (token[0] !== undefined) {
                        const key = token[0].toLowerCase();
                        const value = parseFloat(token.substring(1));
                        args[key] = value;
                    }
                });

                if (cmd === 'G0' || cmd === 'G1') {
                    const line = {
                        x: args.x !== undefined ? args.x : state.x,
                        y: args.y !== undefined ? args.y : state.y,
                        z: args.z !== undefined ? args.z : state.z,
                        e: args.e !== undefined ? args.e : state.e,
                        f: args.f !== undefined ? args.f : state.f,
                    };

                    if (line.z !== state.z) {
                        newLayer(line);
                    }

                    const extruding = (line.e > state.e);
                    
                    if (currentLayer === undefined) {
                        newLayer(line);
                    }

                    if (extruding) {
                        currentLayer.pathVertex.push(state.x, state.y, state.z);
                        currentLayer.pathVertex.push(line.x, line.y, line.z);
                    } else {
                        currentLayer.vertex.push(state.x, state.y, state.z);
                        currentLayer.vertex.push(line.x, line.y, line.z);
                    }

                    state = line;
                } else if (cmd === 'G28') {
                    state.x = 0;
                    state.y = 0;
                    state.z = 0;
                }
            }

            function addObject(vertex, extruding, layerCount) {
                if (vertex.length === 0) return;
                
                const geometry = new THREE.BufferGeometry();
                geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertex, 3));
                const segments = new THREE.LineSegments(geometry, extruding ? pathMaterial : travelMaterial);
                segments.userData.type = extruding ? 'G1' : 'G0';
                object.add(segments);
            }

            for (let i = 0; i < layers.length; i++) {
                const layer = layers[i];
                addObject(layer.vertex, false, layers.length);
                addObject(layer.pathVertex, true, layers.length);
            }

            object.rotation.set(-Math.PI / 2, 0, 0);
            
            return object;
        }
    }

    // Attach to THREE global
    THREE.GCodeLoader = GCodeLoader;
})();
