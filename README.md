# Notchpad

A command deck for developers that lives in your MacBook's notch. Hover the notch and it expands. Move away and it collapses.

On Macs without a notch, Notchpad draws a small pill at the top center of the screen instead.

> Early development. The clipboard and convert modules work so far.

## Modules

| Module | Status |
|---|---|
| Clipboard history (text, code, links, auto-expiring secrets) | Working |
| Convert (drop a file or use the Finder selection) | Working |
| Shelf (temporary drop zone for files) | Planned |
| Dev tools (JSON, Base64, UUID, JWT, ...) | Planned |
| Focus (timer and media controls) | Planned |

## Convert

Drag a file onto the notch, or click "Use Finder selection" in the Convert tab. It uses only tools built into macOS, so nothing extra to install. Results are saved next to the original.

| From | To |
|---|---|
| Images (PNG, JPG, HEIC, TIFF, GIF, BMP) | JPG, PNG, PDF |
| Word, RTF, HTML, text, Markdown, ODT | Word, text, HTML, RTF, PDF |
| PDF | Text, Word (text only), PNG (page 1) |
| MOV, MP4, M4V | MP4, M4A audio |

PDF to Word keeps the text but not the layout. "Use Finder selection" asks for Automation permission the first time.

## Privacy

- No network access, no analytics.
- Clipboard history lives in memory only and is never written to disk.
- Items marked concealed by password managers are ignored.
- Strings that look like API keys, private keys, or passwords are masked, and click-to-reveal shows them for 5 seconds.
- After 60 seconds a secret is removed from history, and the system clipboard is wiped too if nothing else was copied since.
- Copying a secret back out of Notchpad marks it as concealed so other clipboard managers skip it.
- Password detection is a heuristic (8 to 64 characters, no spaces, mixed character types), so it can occasionally mask an ordinary identifier.

## Build and run

You only need the Command Line Tools (`xcode-select --install`). Xcode is not required.

```bash
swift run
```

To build a `.app` bundle:

```bash
./scripts/bundle.sh
open build/Notchpad.app
```

Set `UNIVERSAL=1` to build for Apple silicon and Intel.

## Opening an unsigned build

Releases are not notarized yet. On first launch, right-click the app, choose Open, then confirm.

## Adding a module

Conform to `NotchModule` in `Sources/Notchpad/Modules/` and add it to `ModuleRegistry`.

## License

MIT
