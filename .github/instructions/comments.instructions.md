---
applyTo: '*.coffee'
---

# Comment Guidelines for CoffeeScript Code

These guidelines ensure consistent and helpful commenting throughout the CoffeeScript codebase.

## Constructor Comments

- Add descriptive comments for all constructor property sections to help explain organization.
- Use periods at the end of long/complete sentence comments.
- Group related properties together with section comments.

## Coder Method Comments

- For coder methods that generate G-code, **always** add a commented link to the Marlin firmware documentation for that specific G-code.
- Add brief one-sentence comments explaining what each coder method does.
- Use the format: `# https://marlinfw.org/docs/gcode/GXXX.html` above method definitions.
- Include brief functional descriptions like `# Generate autohome G-code command.`

## General Comment Style

- Use periods at the end of complete sentence comments.
- Keep comments concise but informative.
- Ensure comments add value and context, not just restate the obvious.
- Use proper grammar and punctuation for professional readability.

## Examples

```coffeescript
# Basic printer settings and configuration.
@autohome = options.autohome ?= true # Boolean.
@workspacePlane = options.workspacePlane ?= "XY" # String ['XY', 'XZ', 'YZ'].

# https://marlinfw.org/docs/gcode/G028.html
# Generate autohome G-code command.
codeAutohome: (x = null, y = null, z = null) ->
```