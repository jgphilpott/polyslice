# Refactoring Guidelines

## Browser/Node.js Compatibility

- Ensure all code works in both Node.js and browser environments
- Use feature detection rather than environment detection where possible
- Avoid Node.js-specific APIs in core functionality
- Test exports work correctly in both CommonJS and browser global contexts

## G-code Generation

- Maintain backward compatibility for existing G-code methods
- Keep G-code output format consistent with established standards
- Validate all numerical parameters before generating commands
- Include proper error handling for invalid inputs

## Three.js Integration

- Keep three.js integration optional and modular
- Ensure mesh processing doesn't break existing functionality
- Support both geometry and buffer geometry where applicable
- Handle coordinate system conversions properly

## Performance Considerations

- Minimize string concatenation in G-code generation loops
- Use efficient algorithms for mesh processing
- Consider memory usage when processing large geometries
- Profile critical paths and optimize as needed