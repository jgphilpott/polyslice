---
applyTo: '*.coffee'
---

# Comment Guidelines for CoffeeScript Code

These guidelines ensure consistent and helpful commenting throughout the CoffeeScript codebase.

## Documentation Philosophy

**Keep source code comments light and minimal.** Detailed algorithm explanations, architecture documentation, and comprehensive guides belong in:

- **Instruction files** (`/.github/instructions/`) - AI-facing technical documentation organized by module
- **Documentation files** (`/docs/`) - Human-facing guides and reference documentation

Source code comments should provide just enough context to understand the flow of the code, not exhaustive explanations of algorithms or design decisions.

### What Goes Where

| Content Type | Location |
|-------------|----------|
| Algorithm explanations | `/.github/instructions/{module}/overview.instructions.md` |
| API documentation | `/docs/*.md` |
| Usage examples | `/docs/*.md` or README.md |
| Brief function descriptions | Source code comments |
| G-code documentation links | Source code comments |
| Property type annotations | Source code inline comments |

## Source Code Comments

### Keep Comments Brief

```coffeescript
# Good - brief and contextual
# Calculate wall inset for outer boundary.
outerWallOffset = nozzleDiameter / 2

# Bad - too verbose for source code
# Calculate the offset for the outer wall. The outer wall should be inset
# by half the nozzle diameter so that the printed line's outer edge aligns
# with the model's designed dimensions. This is because extrusion produces
# a line with width equal to the nozzle diameter...
```

### Constructor Comments

- Add brief section headers to group related properties
- Use inline type annotations for clarity

```coffeescript
# Printer settings.
@autohome = options.autohome ?= true # Boolean.
@workspacePlane = options.workspacePlane ?= "XY" # String ['XY', 'XZ', 'YZ'].

# Temperature settings.
@nozzleTemperature = options.nozzleTemperature ?= 200 # Number (°C).
```

### Coder Method Comments

For G-code generating methods:
- **Always** include Marlin firmware documentation link
- Add brief one-sentence description

```coffeescript
# https://marlinfw.org/docs/gcode/G028.html
# Generate autohome G-code command.
codeAutohome: (x = null, y = null, z = null) ->
```

### Flow Comments

Use brief comments to explain code flow, not algorithms:

```coffeescript
# Process each layer from bottom to top.
for layerIndex in [0...totalLayers]

    # Generate walls before infill.
    @generateWalls(...)
    @generateInfill(...)
```

## What NOT to Include in Source Comments

Avoid these in source code - put them in instruction files instead:

- Multi-paragraph algorithm explanations
- Mathematical formula derivations
- Design decision rationale
- Performance optimization explanations
- Detailed parameter descriptions
- Usage examples

## General Style

- Use periods at the end of complete sentence comments
- Keep comments concise but informative
- Ensure comments add value, not restate the obvious
- Use proper grammar and punctuation
- Remove outdated comments immediately after refactoring

## Examples

### Good (Brief)

```coffeescript
# Create inset path for infill boundary.
infillBoundary = paths.createInsetPath(boundaryPath, infillGap)

# Skip if boundary too small.
return if infillBoundary.length < 3
```

### Bad (Too Verbose)

```coffeescript
# Create an inset path for the infill boundary. The infill boundary needs to be
# inset from the innermost wall by half the nozzle diameter to maintain proper
# spacing. We use the createInsetPath function which handles the polygon offset
# operation including corner handling for acute angles...
```

The verbose explanation above belongs in `/.github/instructions/slicer/infill/overview.instructions.md`.
