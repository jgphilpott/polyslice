---
applyTo: '*.coffee'
---

# CoffeeScript Contribution Instructions

These guidelines apply to all CoffeeScript source edits in this repository.

## Code Style: Indentation

- Use 4-space indentation for all code blocks (consistent with `.editorconfig`).
- All indentation must be multiples of 4 spaces (4, 8, 12, 16, etc.).

## Code Style: Whitespace and Vertical Spacing

- Preserve and prefer generous vertical whitespace for readability.
- Insert a blank line after the following situations:
  - function declarations/definitions
  - if/else blocks
  - loops
  - any change in indentation level
  - variable assignments before object creation/manipulation
  - between logical groups within functions
- Do not collapse existing blank lines when editing.
- In helper functions, add blank lines to separate logical groups (geometry creation, mesh setup, return statements).
- Remove trailing whitespace consistently.
- Always insert final newline at the end of files (consistent with `.editorconfig`).

If you are unsure, prefer the more spacious option to maintain consistency with the existing style.

## Variable Naming Conventions

- Follow standard JavaScript camelCase naming conventions for all variables.
- **Do not use leading underscores** (`_variableName`) unless it's a true private convention.
- **Use descriptive, full-form variable names** instead of cryptic abbreviations:
  - ✅ Good: `for previousState in previousStates`
  - ❌ Bad: `for s in previousStates`
  - ✅ Good: `temporaryVertex`, `currentPolygon`
  - ❌ Bad: `tmpV`, `curPoly`
- Prefer clarity over brevity - code is read more often than written.

## G-code Generation Guidelines

- Maintain consistency with existing G-code command naming conventions.
- Use descriptive method names like `codeLinearMovement`, `codeAutohome`.
- Include proper G-code comments and references to Marlin documentation.
- Ensure all temperature, speed, and coordinate parameters are validated.

## Test Code Style Preferences

- Add blank lines after geometry/material creation and before mesh creation.
- Add blank lines after mesh setup and before return statements.
- Align inline comments consistently using single space before # comment.
- For comments explaining parameters, add period after comment for complete sentences.
- Maintain consistent spacing around assignment operators.
- Prefer single-line variable assignments with proper spacing.

## Reserved Word Note (Project Convention)

CoffeeScript reserves certain identifiers (e.g. `by` used in loop syntax). When needing coordinate component variables that might conflict, prefer capitalized suffix forms:

- Use `aX, aY, aZ` / `bX, bY, bZ` instead of `ax, ay, az` / `bx, by, bz` when there is risk of `by` being parsed as the keyword.
- This avoids accidental parse errors in inline multi-assignment statements.

Adopt this naming in new geometry or test code when generating random coordinates.

## Three.js Integration

- When working with three.js objects, maintain clear separation between mesh processing and G-code generation.
- Use proper three.js naming conventions for geometry manipulation.
- Ensure mesh data extraction is compatible with both Node.js and browser environments.