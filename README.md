# Notchpad

A command deck for developers that lives in your MacBook's notch. Hover the notch and it expands. Move away and it collapses.

On Macs without a notch, Notchpad draws a small pill at the top center of the screen instead.

> Early development. Only the clipboard module works so far.

## Modules

| Module | Status |
|---|---|
| Clipboard history (text, code, links, auto-expiring secrets) | Working |
| Convert (HEIC to JPG, Markdown to PDF, ...) | Planned |
| Shelf (temporary drop zone for files) | Planned |
| Dev tools (JSON, Base64, UUID, JWT, ...) | Planned |
| Focus (timer and media controls) | Planned |

## Privacy

- No network access, no analytics.
- Clipboard history lives in memory only and is never written to disk.
- Items marked concealed by password managers are ignored.
- Strings that look like API keys or private keys are masked and removed after 60 seconds.

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
