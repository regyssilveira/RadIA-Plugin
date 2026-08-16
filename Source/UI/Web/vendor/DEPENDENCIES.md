# Bundled web dependencies

The RadIA WebView surfaces bundle these dependencies locally and do not load code from a CDN:

- Marked 15.0.12 (MIT)
- PrismJS 1.30.0 with the Pascal component (MIT)
- Diff2Html 3.x (MIT)
- jsdiff, bundled with Diff2Html (BSD-3-Clause)

Security updates must preserve the local-only loading policy and the WebView security regression tests.
