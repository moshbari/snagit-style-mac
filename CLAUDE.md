# HuzaifaShot — Standing Instructions for Claude

Native macOS menu-bar screenshot + annotation app. Pure AppKit, no SwiftUI, no third-party deps. Read this before editing.

## Build / install

Two things must stay in sync:

1. **`install.sh`** is the canonical build. It compiles with `swiftc` directly and lists every source file explicitly. **If you add or rename a `.swift` file, update the `swiftc` file list in `install.sh`** or the build silently misses it.
2. There is no `.xcodeproj`. Quick compile check:
   ```bash
   swiftc -o /tmp/x -target "$(uname -m)-apple-macosx13.0" \
     -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
     -framework Cocoa -framework CoreImage -framework Carbon \
     -parse-as-library -O HuzaifaShot/*.swift
   ```

Frameworks: **Cocoa, CoreImage** (blur via `CIPixellate`), **Carbon** (global hotkeys). The entry point is a `@main enum` in `HuzaifaShotApp.swift` — required because `-parse-as-library` forbids top-level code.

### App icon

`HuzaifaShot/AppIcon.icns` is generated, not hand-drawn. To regenerate:
```bash
swift tools/make_icon.swift /tmp/huzaifashot.iconset
iconutil -c icns /tmp/huzaifashot.iconset -o HuzaifaShot/AppIcon.icns
```
`Info.plist` sets `CFBundleIconFile = AppIcon`; `install.sh` copies the `.icns` into `Contents/Resources/`. The committed `.icns` is the source of truth for installs — regenerate and recommit if you change the artwork. macOS caches icons aggressively; a reinstall + relaunch (or `killall Dock`) may be needed to see changes.

## Permissions

- **Screen Recording** is required (macOS gates `screencapture` behind it). It prompts on first capture; the app must be **quit and relaunched** after granting before capture works. Call this out in any post-install report.
- **Accessibility is NOT needed.** Hotkeys use Carbon `RegisterEventHotKey`, which only listens — it never synthesizes events. Don't add an Accessibility flow.

## Architecture notes

- **Capture** shells out to `/usr/sbin/screencapture` (`CaptureService.swift`) rather than reimplementing CGDisplay capture + selection overlay. This gives native selection UI for free. If the user hits Esc, no file is written and capture is a no-op.
- **CanvasView is flipped** (`isFlipped = true`) so it shares the image's top-left origin. `NSImage.draw(in:)` handles the flip automatically — don't manually flip the image.
- **Blur** pre-renders one pixelated copy of the whole image (`makePixelated`), then draws it clipped to each blur rect. Because it shares the image's logical size, it aligns 1:1 in `bounds` — keep that invariant if you touch blur.
- **Export** uses `bitmapImageRepForCachingDisplay` + `cacheDisplay`, which captures at backing (Retina) scale. The selection outline is cleared before export so it isn't baked in.
- **Undo** is a manual snapshot stack of deep-copied annotations (`Annotation.copy()`), capped at 50. Reference-type annotations are mutated in place during drag, so snapshots must deep-copy.
- **Tool ↔ segment mapping:** `NSSegmentedControl` segment index equals `Tool.rawValue` (select=0, arrow, rect, oval, highlight, blur, text, step, eraseObject, erasePixels=9). If you reorder `Tool` or the segment labels, keep them aligned.
- **Erasers:** `eraseObject` removes whole annotations under the cursor (snapshot once at mouseDown, then delete on down+drag — don't snapshot per-removal). `erasePixels` is a freehand white brush stored as `Annotation.points`; it paints white (not transparent) for predictable export. Both share the undo stack.
- **Thumbnail right-click:** `ThumbnailItemView.menu(for:)` builds the context menu. "Reveal in Finder" uses `activateFileViewerSelecting` (Snagit's "open folder" behavior); "Move to Trash" trashes then `CaptureStore.reload()` to refresh the tray.
- **Tray drag-out:** `ThumbnailItemView` drags the capture's **file URL** (`url as NSURL`), so it drops as a real `.png` in other apps. This depends on captures being saved to disk — `CaptureStore` auto-saves every capture to the save folder, and the editor's "Save" overwrites that same file. Don't switch the editor to clipboard-only or the tray loses its source files.
- **Settings → re-register:** changing a hotkey or the save folder posts `Settings.didChange`; `AppDelegate` calls `HotKeyCenter.reset()` then re-registers and rebuilds the menu. `HotKeyCenter.reset()` must `UnregisterEventHotKey` every ref or old hotkeys leak and double-fire.
- **Hotkey recording:** `HotKeyRecorderField` stores `NSEvent.keyCode` directly — it's the same virtual keycode `RegisterEventHotKey` wants. It requires at least one of ⌘/⌃/⌥ so we never hijack a bare key. Esc cancels recording.

## Things NOT to do

- Don't commit `.env` — it holds the GitHub token and is git-ignored. Never paste tokens into chat or commits.
- Don't add an Accessibility permission flow (see above).
- Don't `git push --force` without asking.
- Don't add features the user didn't ask for. Current scope: capture + annotate, a draggable recent-captures tray, a configurable save folder, and customizable hotkeys. Screen recording (video/GIF) and scrolling capture remain explicitly deferred.

## Commit conventions

- Imperative subject, ~60 chars, no trailing period.
- Body explains *why*, not *what*.
- Co-author footer with the model identifier, matching `git log` style.
