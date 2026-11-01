<p align="center">
  <img src="assets/banner.png" alt="RIM: everything lives in the notch" width="100%">
</p>

# RIM

A command deck for developers that lives in your MacBook's notch. Hover the notch and it opens. Move away and it tucks back in.

On Macs without a notch, RIM draws a small pill at the top center of the screen instead.

> Early development. All five tabs work: clipboard, convert, shelf, dev tools and focus.

## Modules

| Module | Status |
|---|---|
| Clipboard history (text, code, links, files, auto-expiring secrets) | Working |
| Convert (drop a file or use the Finder selection) | Working |
| Shelf (temporary drop zone for files) | Working |
| Dev tools (JSON, Base64, JWT, hashes, timestamps, colors, ...) | Working |
| Focus (timer, now playing and media controls) | Working |

## Focus

A countdown timer (15, 25 or 50 minutes, or adjust in 5-minute steps) with a label for what you're working on. While it runs and the notch is closed, a progress ring appears on the left of the notch and the time left on the right. When it ends, the notch opens, plays a sound, and tucks itself away after a few seconds. The tab also counts your finished sessions for the day.

The right half shows what Spotify or Music is playing, with previous, play/pause and next. macOS asks for permission to control the player the first time.

## Dev tools

Open the tab and your clipboard text is already in the input box (unless it looks like a secret). Click a tool to run it, edit the input to re-run live, and copy the result.

JSON format and minify, Base64, URL encoding, JWT decode (with expiry), SHA-256, SHA-1, MD5, new UUID, timestamp conversion (seconds, milliseconds or a date), color conversion (hex, rgb, hsl), and snake_case, kebab-case and camelCase.

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

If [LibreOffice](https://www.libreoffice.org) is installed, RIM uses it for Word to PDF and adds a "to Word (LibreOffice)" option for PDFs, which gives the best layout in both directions.

"Use Finder selection" asks for Automation permission the first time.

## Privacy

- No network access, no analytics.
- Clipboard history lives in memory only and is never written to disk.
- Items marked concealed by password managers are ignored.
- Strings that look like API keys, private keys, or passwords are masked, and click-to-reveal shows them for 5 seconds.
- After 60 seconds a secret is removed from history, and the system clipboard is wiped too if nothing else was copied since.
- Copying a secret back out of RIM marks it as concealed so other clipboard managers skip it.
- Password detection is a heuristic (8 to 64 characters, no spaces, mixed character types), so it can occasionally mask an ordinary identifier.

## Design

Near-black, one warm accent, no chrome. The tabs are icons and the selected one shows its name. A thin edge of light runs along the bottom of the open notch, which is where the name comes from. The icon and banner are drawn by `scripts/make-assets.swift`, so they stay in the same style as the app. Run `./scripts/make-icon.sh` to regenerate them.

## Build and run

You only need the Command Line Tools (`xcode-select --install`). Xcode is not required.

```bash
swift run
```

To build a `.app` bundle:

```bash
./scripts/bundle.sh
open build/RIM.app
```

Set `UNIVERSAL=1` to build for Apple silicon and Intel.

## Opening an unsigned build

Releases are not notarized yet. On first launch, right-click the app, choose Open, then confirm.

## Adding a module

Conform to `NotchModule` in `Sources/RIM/Modules/` and add it to `ModuleRegistry`.

## License

MIT
