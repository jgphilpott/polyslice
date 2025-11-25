# Refactoring Guidelines

## Browser/Node.js Compatibility

- Ensure all code works in both Node.js and browser environments.
- Use feature detection rather than environment detection where possible.
- Avoid Node.js-specific APIs in core functionality.
- Test exports work correctly in both CommonJS and browser global contexts.

## G-code Generation

- Maintain backward compatibility for existing G-code methods.
- Keep G-code output format consistent with established standards.
- Validate all numerical parameters before generating commands.
- Include proper error handling for invalid inputs.

## Three.js Integration

- Keep three.js integration optional and modular.
- Ensure mesh processing doesn't break existing functionality.
- Support both geometry and buffer geometry where applicable.
- Handle coordinate system conversions properly.

## Performance Considerations

- Minimize string concatenation in G-code generation loops.
- Use efficient algorithms for mesh processing.
- Consider memory usage when processing large geometries.
- Profile critical paths and optimize as needed.

## DRY & Modularity

- Actively seek duplicate logic; extract helpers or modules when code repeats 3+ times.
- Favor small, focused functions and single-responsibility modules.
- Centralize formatting, math utilities, and G-code command construction to avoid drift.

## Efficiency & Optimization

- Prefer preallocating arrays or using push + join over repeated string concatenation.
- Cache geometry bounds, layer heights, and repeated numeric constants.
- Avoid unnecessary deep clones of geometries or materials.
- Short-circuit early on empty/no-op cases (e.g., zero infill density).

## External Package Suggestions

- When a well-maintained npm package can replace custom utility code (e.g., robust polygon ops, spatial indexing), propose it in PR description before introducing.
- Ensure license compatibility and minimal bundle impact.
- Avoid adding dependencies solely for trivial helpers.

## Large File Extraction

- Files exceeding ~1000 lines (e.g., `polyslice.coffee`) should be candidates for extraction into related modules (`gcode/`, `geometry/`, `pathing/`).
- Preserve public API surface by creating internal modules and re-exporting from the original entry point.
- Incrementally migrate sections (temperature commands, movement planning, infill generation) with tests after each move.

## Comment & Doc Accuracy

- Keep comments concise, factual, and synchronized with code behavior.
- If a discrepancy exists between code and a comment, update the comment to reflect code (never alter working logic just to satisfy outdated commentary).
- Remove obsolete TODOs once addressed; convert persistent concerns into GitHub issues instead of lingering inline notes.

## Package Proposal Workflow

- Document rationale (performance gain, correctness, maintenance reduction) when suggesting a new package.
- Provide a minimal benchmark or qualitative comparison if performance motivated.

## Refactoring Acceptance Addendum

- Confirm that extractions did not alter public method names or signatures.
- Run `npm test`, `npm run compile`, and `npm run build` after structural changes.
- Update any affected docs or examples if internal refactors change recommended usage patterns.
