# Snagit Style — Standing Instructions for Claude

Native macOS menu-bar screenshot + annotation app. Pure AppKit, no SwiftUI, no third-party deps. Read this before editing.

## Build / install

Two things must stay in sync:

1. **`install.sh`** is the canonical build. It compiles with `swiftc` directly and lists every source file explicitly. **If you add or rename a `.swift` file, update the `swiftc` file list in `install.sh`** or the build silently misses it.
2. There is no `.xcodeproj`. Quick compile check:
   ```bash
   swiftc -o /tmp/x -target "$(uname -m)-apple-macosx13.0" \
     -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
     -framework Cocoa -framework CoreImage -framework Carbon \
     -parse-as-library -O SnagitStyle/*.swift
   ```

Frameworks: **Cocoa, CoreImage** (blur via `CIPixellate`), **Carbon** (global hotkeys). The entry point is a `@main enum` in `SnagitStyleApp.swift` — required because `-parse-as-library` forbids top-level code.

## Permissions

- **Screen Recording** is required (macOS gates `screencapture` behind it). It prompts on first capture; the app must be **quit and relaunched** after granting before capture works. Call this out in any post-install report.
- **Accessibility is NOT needed.** Hotkeys use Carbon `RegisterEventHotKey`, which only listens — it never synthesizes events. Don't add an Accessibility flow.

## Architecture notes

- **Capture** shells out to `/usr/sbin/screencapture` (`CaptureService.swift`) rather than reimplementing CGDisplay capture + selection overlay. This gives native selection UI for free. If the user hits Esc, no file is written and capture is a no-op.
- **CanvasView is flipped** (`isFlipped = true`) so it shares the image's top-left origin. `NSImage.draw(in:)` handles the flip automatically — don't manually flip the image.
- **Blur** pre-renders one pixelated copy of the whole image (`makePixelated`), then draws it clipped to each blur rect. Because it shares the image's logical size, it aligns 1:1 in `bounds` — keep that invariant if you touch blur.
- **Export** uses `bitmapImageRepForCachingDisplay` + `cacheDisplay`, which captures at backing (Retina) scale. The selection outline is cleared before export so it isn't baked in.
- **Undo** is a manual snapshot stack of deep-copied annotations (`Annotation.copy()`), capped at 50. Reference-type annotations are mutated in place during drag, so snapshots must deep-copy.
- **Tool ↔ segment mapping:** `NSSegmentedControl` segment index equals `Tool.rawValue` (select=0 … step=7). If you reorder `Tool` or the segment labels, keep them aligned.

## Things NOT to do

- Don't commit `.env` — it holds the GitHub token and is git-ignored. Never paste tokens into chat or commits.
- Don't add an Accessibility permission flow (see above).
- Don't `git push --force` without asking.
- Don't add features the user didn't ask for. v1 scope is capture + annotate. Screen recording (video/GIF) and scrolling capture were explicitly deferred.

## Commit conventions

- Imperative subject, ~60 chars, no trailing period.
- Body explains *why*, not *what*.
- Co-author footer with the model identifier, matching `git log` style.
