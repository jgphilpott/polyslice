# Development Guide

This guide covers setting up your development environment and working with the Polyslice codebase.

## Prerequisites

### Git LFS

This repository uses [Git LFS](https://git-lfs.github.com/) to store G-code sample files. Make sure you have Git LFS installed:

```bash
# Install Git LFS
git lfs install

# If you cloned before installing LFS, pull the actual files:
git lfs pull
```

### Node.js

Polyslice requires Node.js 16 or higher. Install dependencies:

```bash
npm install
```

## Development Commands

### Running Tests

```bash
npm test              # Run all tests
npm run test:watch    # Run tests in watch mode
npm run test:coverage # Run tests with coverage report
```

### Compiling CoffeeScript

```bash
npm run compile       # Compile CoffeeScript to JavaScript
```

### Building for Production

```bash
npm run build:node    # Node.js builds (CommonJS + ESM)
npm run build:browser # Browser build (IIFE)
npm run build:cjs     # CommonJS build only
npm run build:esm     # ES modules build only
npm run build:minify  # Minified builds
npm run build         # All builds
```

### Running Examples

```bash
node examples/basic.js
node examples/threejs-integration.js
```

## Project Structure

```
polyslice/
├── src/                    # Source code (CoffeeScript)
│   ├── polyslice.coffee    # Main slicer class
│   ├── config/             # Printer and filament configurations
│   │   ├── printer/        # Printer profiles
│   │   └── filament/       # Filament profiles
│   ├── loaders/            # 3D file loaders
│   ├── exporters/          # G-code exporters
│   ├── slicer/             # Slicing engine
│   │   ├── gcode/          # G-code generation
│   │   ├── geometry/       # Geometry utilities
│   │   ├── infill/         # Infill patterns
│   │   ├── preprocessing/  # Mesh preprocessing
│   │   ├── skin/           # Skin generation
│   │   ├── support/        # Support structures
│   │   ├── utils/          # Utility functions
│   │   └── walls/          # Wall generation
│   └── utils/              # General utilities
├── docs/                   # Documentation
├── examples/               # Example scripts
├── dist/                   # Built files (generated)
└── tests/                  # Test files
```

## Code Style

- Source code is written in CoffeeScript
- Use 4-space indentation
- Follow existing naming conventions
- Add tests for new features
- Update documentation for API changes

## Testing

Tests are written using Jest and located alongside source files with `.test.coffee` extension.

```bash
# Run all tests
npm test

# Run specific test file
npm test -- --testPathPattern="polyslice.test"

# Run with verbose output
npm test -- --verbose
```

## Building

The build process creates multiple output formats:

| Format | Output | Usage |
|--------|--------|-------|
| CommonJS | `dist/index.cjs.js` | Node.js (require) |
| ES Modules | `dist/index.esm.js` | Modern bundlers |
| Browser | `dist/index.browser.js` | Browser (script tag) |
| Browser (min) | `dist/index.browser.min.js` | Production |

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

See [CONTRIBUTING](../CONTRIBUTING.md) for detailed guidelines.

## Debugging

### Verbose G-code Output

Enable verbose mode to add comments in generated G-code:

```javascript
const slicer = new Polyslice({
  verbose: true
});
```

### Using the G-code Visualizer

Use the [G-code Visualizer](../tools/TOOLS.md#g-code-visualizer) to inspect generated G-code in 3D.

## Related Documentation

- [API Reference](../api/API.md) - Complete API reference
- [Examples](../examples/EXAMPLES.md) - Usage examples
- [Tools](../tools/TOOLS.md) - Development and debugging tools
