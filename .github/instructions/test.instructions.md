# Testing Guidelines

These notes define conventions and coverage expectations for the test suite.

## Framework

- Use Jest (already configured).
- JavaScript test sources run directly with Jest.

## File / Naming

- Name pattern: `*.test.js`.
- One logical unit per file (e.g. `polyslice.test.js`).
- All helpers from the main class share a single consolidated test file (append new helper tests at bottom, do not create a separate file).

## Structure

- Use a small helper factory for repetitive data construction (e.g. `slicer()`).
- Keep assertion helpers local (no global shared unless reused across 3+ files).
- Avoid hidden magic numbers; define `EPS`, `TOL`, etc. at top of file.
- Place any new shared helper functions (e.g. geometry builders, orientation wrappers) near the TOP of the consolidated test file so subsequent describe blocks can reuse them.
- Formatting / Whitespace: Insert a blank line immediately after each `describe` declaration line and after each `it` line (before the body) to maintain generous vertical whitespace consistent with JavaScript style.

## Assertions

- Prefer strict equality expectations for G-code output validation.
- When testing floating-point calculations (e.g., fan speeds), use appropriate precision handling.
- Test both Node.js and browser environments when applicable.

## Coverage Expectations (G-code Generation)

Polyslice tests must include:

1. **Constructor and Options**
   - Default values initialization
   - Custom options handling
   - Invalid parameter rejection

2. **Parameter Setters/Getters**
   - Valid range checking
   - Type validation
   - Chaining behavior

3. **G-code Command Generation**
   - Basic movement commands (G0, G1)
   - Temperature control (M104, M109, M140, M190)
   - Fan control (M106, M107)
   - Home commands (G28)
   - Workspace plane setting (G17, G18, G19)
   - Unit setting (G20, G21)
   - Arc movements (G2, G3)
   - Bézier curves (G5)
   - Special commands (M117, M112, etc.)

4. **Environment Compatibility**
   - Node.js environment tests
   - Browser environment compatibility (when applicable)
   - Three.js integration tests

5. **Edge Cases**
   - Zero values handling
   - Maximum/minimum parameter values
   - Invalid parameter handling
   - Floating-point precision

Future (add later):

- Random fuzz testing for parameter validation
- Stress test with large coordinate values
- Performance benchmarks for G-code generation
- Integration tests with actual three.js meshes
- Browser environment automated testing

## Floating Point

- Use tolerance constant (default `1e-6`) for floating-point comparisons.
- Do not equality-compare raw floats except against `0` with documented intent.
- For fan speed calculations, test the actual rounded output values.

## Environment Testing

- Test CommonJS imports (`require`)
- Test ES module imports (`import`) when applicable
- Verify browser global availability
- Test three.js integration in both environments

## DRY Principles

- Shared helper naming: `slicer()`, `assertGCode()`.
- Keep helpers minimal; do not abstract prematurely.
- If helper exceeds ~30 LOC or becomes multi-purpose, split.

## Test Output Clarity

- Include descriptive test names that explain what is being tested.
- Use meaningful variable names in test setup.
- Include comments for non-obvious expectations (especially G-code format specifics).

## Adding New G-code Tests

When adding a new G-code command or feature:

1. List expected G-code output format in comment header.
2. Implement parameter validation tests first.
3. Write "happy path" test with expected output.
4. Test edge cases and invalid parameters.
5. Add regression tests for any bugs fixed.

## Performance / Stability

- Long-running test suites should be opt-in via `process.env.LONG_TESTS`.
- Default `npm test` must remain fast (< 5s typical).
- Browser compatibility tests should be separate from core functionality tests.

## Lint / Style

- Follow JavaScript/ESLint formatting guidelines.
- Keep tests readable over condensed.
- Use descriptive assertion messages.

## TODO Tags

- Allowed only with issue reference: `# TODO(#123): add browser integration tests`.
