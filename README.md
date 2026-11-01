# Notchpad

A command deck for developers that lives in your MacBook's notch. Hover the notch and it expands. Move away and it collapses.

On Macs without a notch, Notchpad draws a small pill at the top center of the screen instead.

> Early development. Clipboard, Convert and Shelf work so far.

## Modules

| Module | Status |
|---|---|
| Clipboard history (text, code, links, files, auto-expiring secrets) | Working |
| Convert (drop a file or use the Finder selection) | Working |
| Shelf (temporary drop zone for files) | Working |
| Dev tools (JSON, Base64, UUID, JWT, ...) | Planned |
| Focus (timer and media controls) | Planned |

## Shelf

Drag files onto the notch and two drop zones appear: Convert and Shelf. Drop on Shelf to park the files, then drag them out into any app later. Right-click a file for Open, Show in Finder, Convert and Remove. The shelf holds references to the original files, not copies, and is emptied when you quit.

## Convert

Drop a file on the Convert zone, or click "Use Finder selection" in the Convert tab. It uses only tools built into macOS, so nothing extra to install. Results are saved next to the original.

| From | To |
|---|---|
| Images (PNG, JPG, HEIC, TIFF, GIF, BMP) | JPG, PNG, PDF |
| Word, RTF, HTML, text, Markdown, ODT | Word, text, HTML, RTF, PDF |
| PDF | Text, Word (editable text or exact look), PNG (page 1) |
| MOV, MP4, M4V | MP4, M4A audio |

Word to PDF reads `.docx` files directly, so tables, images, lists, links and basic styling carry over. Headers, footers and complex layouts aren't covered.

PDF to Word has two modes. "Editable text" keeps bold, italic and sizes and re-joins wrapped lines into paragraphs, but drops images and table structure. "Exact look" puts each page in the Word file as a picture, so it looks identical but isn't editable.

If [LibreOffice](https://www.libreoffice.org) is installed, Notchpad uses it for Word to PDF and adds a "to Word (LibreOffice)" option for PDFs, which gives the best layout in both directions.

"Use Finder selection" asks for Automation permission the first time.

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
