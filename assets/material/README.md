# Putkin icon assets

Google **Material Symbols Outlined**, FILL 0, weight 400, GRAD 0, opsz 24.
Downloaded SVG files are preserved locally, with URLs and SHA-256 checksums
in `manifest.json`. Google assets use the Apache 2.0 license in `LICENSE`.
Source: <https://fonts.google.com/icons>.

`putkin_tether.svg` (linked devices) is an original Putkin symbol on the same
24-unit grid, not an official app logo. Google does not include third-party
logos. Signal uses Google's `chat_bubble`, changing to `chat` for unread
messages in the tray. Both share the same outline and canvas.

Charging uses Google's original `battery_charging_*_2.svg`, with the bolt
on the right. Their paths are unchanged. The catalog adds a 960 × 800
layout viewport centered on the 960 × 960 source: the 400-unit battery
height then matches Android's 480-unit battery height at the same section
size. Uniform scaling preserves the symbol's proportions. The icon field
expands horizontally for the bolt, keeping the section's usual padding.
No derived battery SVG or overlaid bolt is used.

`python3 scripts/update-icons` compiles paths without network access.
`--fetch` explicitly refreshes Google's assets and their provenance.
`Paths.js` is generated and checked in; no downloading occurs at runtime.
`components/Glyph.qml` renders the SVG paths with a single themed fill.
