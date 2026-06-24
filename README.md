# 📸 Snagit Style

A lightweight native macOS menu-bar screenshot tool with a built-in annotation editor — a small, open-source take on [Snagit](https://www.techsmith.com/screen-capture.html).

![macOS](https://img.shields.io/badge/macOS-13.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9+-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Three capture modes** with global hotkeys:
  - `⌃⌘1` → **Region** (drag to select; press Space mid-drag to grab a window)
  - `⌃⌘2` → **Window** (click any window)
  - `⌃⌘3` → **Full screen**
- **Annotation editor** opens automatically after each capture:
  - **Arrow**, **Rectangle**, **Oval**
  - **Highlight** (semi-transparent marker)
  - **Blur / redact** (pixelates a region — great for hiding sensitive info)
  - **Text** callouts
  - **Step numbers** (auto-incrementing badges, just like Snagit)
- **Select tool** to move annotations; **Delete** key removes the selected one
- **Color picker** and **line-width** slider
- **Undo** (`⌘Z`), **Copy** to clipboard (`⌘C`), **Save as PNG** (`⌘S`)
- **Menu-bar only** — no Dock icon, minimal footprint

## Quick Install (Terminal)

```bash
git clone https://github.com/moshbari/snagit-style-mac.git
cd snagit-style-mac
bash install.sh
```

This compiles the app with `swiftc` and installs it to `/Applications` (or your Desktop if `/Applications` isn't writable). Requires Xcode (for the Swift compiler) — no Homebrew or Node needed.

## Usage

1. Click the **camera icon** in your menu bar (or use a hotkey).
2. Pick a capture mode — the editor opens with your screenshot.
3. Choose a tool, set color/width, and annotate.
4. **Copy** (`⌘C`) to paste anywhere, or **Save…** (`⌘S`) to a PNG.

| Action | How |
|--------|-----|
| Capture region | `⌃⌘1` |
| Capture window | `⌃⌘2` |
| Capture full screen | `⌃⌘3` |
| Move an annotation | Pick **Select**, then drag it |
| Delete an annotation | Select it, press **Delete** |
| Undo | `⌘Z` |
| Copy to clipboard | `⌘C` |
| Save PNG | `⌘S` |

## Permissions

| Permission | Why | Required? |
|-----------|-----|-----------|
| Screen Recording | macOS gates all screen capture behind it | Yes (macOS prompts on first capture) |

Grant it under **System Settings → Privacy & Security → Screen Recording**, then quit and reopen Snagit Style from the menu bar. Global hotkeys use the Carbon API and do **not** require Accessibility permission.

## Architecture

```
SnagitStyle/
├── SnagitStyleApp.swift        → @main entry (accessory / menu-bar app)
├── AppDelegate.swift           → menu bar item, hotkeys, capture → editor flow
├── HotKeyCenter.swift          → global hotkeys via Carbon RegisterEventHotKey
├── CaptureService.swift        → wraps /usr/sbin/screencapture
├── Annotation.swift            → annotation model (type, geometry, style)
├── CanvasView.swift            → draws image + annotations, mouse handling, export
├── EditorWindowController.swift→ editor window, tool strip, save/copy/undo
└── Info.plist                  → bundle config (LSUIElement = menu-bar only)
```

## How It Works

1. A hotkey (or menu item) shells out to macOS's `screencapture` for native-quality selection.
2. The resulting PNG loads into an editor window.
3. Annotations are drawn live on a flipped `NSView`; **blur** samples a pre-pixelated copy of the image clipped to the selected region.
4. Export flattens the view at backing (Retina) resolution to PNG or the clipboard.

## License

MIT — do whatever you want with it.

## Author

Built by **Mosh Bari** with the help of Claude.
