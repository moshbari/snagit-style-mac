#!/bin/bash

# ============================================================
#  HuzaifaShot — One-Paste Installer
#  Builds the app with swiftc and installs it to /Applications
#  (falls back to ~/Desktop if /Applications isn't writable).
#  Requires Xcode (for the Swift compiler). No Homebrew/Node needed.
# ============================================================

set -e

echo ""
echo "📸  HuzaifaShot installer"
echo ""

# 1. Check toolchain
echo "🔍 Checking for the Swift compiler..."
if ! xcode-select -p &>/dev/null; then
    echo "⚠️  Xcode Command Line Tools not found. A popup will appear — click 'Install', then re-run."
    xcode-select --install || true
    exit 1
fi
if ! command -v swiftc &>/dev/null; then
    echo "⚠️  swiftc not found. Install Xcode from the App Store, open it once to accept the license, then re-run."
    exit 1
fi
echo "   ✅ Swift compiler found."

# 2. Build folder
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$HOME/.huzaifashot-build"
APP="$BUILD_DIR/HuzaifaShot.app"
rm -rf "$BUILD_DIR"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

SRC="$SCRIPT_DIR/HuzaifaShot"
if [ ! -d "$SRC" ]; then
    echo "⚠️  Cannot find the HuzaifaShot source folder. Run this from the repo root."
    exit 1
fi

# 3. Info.plist + app icon
cp "$SRC/Info.plist" "$APP/Contents/Info.plist"
if [ -f "$SRC/AppIcon.icns" ]; then
    cp "$SRC/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

# 4. Compile
echo "🔨 Compiling (about 15-30 seconds)..."
swiftc \
    -o "$APP/Contents/MacOS/HuzaifaShot" \
    -target "$(uname -m)-apple-macosx13.0" \
    -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -framework Cocoa \
    -framework CoreImage \
    -framework CoreGraphics \
    -framework Carbon \
    -parse-as-library \
    -O \
    "$SRC/Diagnostics.swift" \
    "$SRC/Settings.swift" \
    "$SRC/CaptureStore.swift" \
    "$SRC/Annotation.swift" \
    "$SRC/HotKeyCenter.swift" \
    "$SRC/HotKeyRecorderField.swift" \
    "$SRC/CaptureService.swift" \
    "$SRC/CanvasView.swift" \
    "$SRC/ThumbnailTrayController.swift" \
    "$SRC/SettingsWindowController.swift" \
    "$SRC/EditorWindowController.swift" \
    "$SRC/AppDelegate.swift" \
    "$SRC/HuzaifaShotApp.swift"
echo "   ✅ Compiled."

# 5. Install
if [ -w "/Applications" ]; then
    DEST="/Applications/HuzaifaShot.app"
    LOCATION="/Applications"
else
    DEST="$HOME/Desktop/HuzaifaShot.app"
    LOCATION="Desktop"
    echo "   ℹ️  /Applications not writable — installing to Desktop."
fi

osascript -e 'tell application "HuzaifaShot" to quit' 2>/dev/null || true
sleep 1
rm -rf "$DEST"
cp -R "$APP" "$DEST"
rm -rf "$BUILD_DIR"

# 6. Ad-hoc sign so Gatekeeper lets it launch locally.
codesign --force --deep --sign - "$DEST" 2>/dev/null || true

echo ""
echo "🎉 Installed to $LOCATION/HuzaifaShot.app"
echo ""
echo "Hotkeys:  ⌃⌘1 region   ⌃⌘2 window   ⌃⌘3 full screen"
echo "The camera icon lives in your menu bar."
echo ""
echo "ℹ️  First capture: macOS may ask for Screen Recording permission"
echo "   (System Settings → Privacy & Security → Screen Recording). Allow it,"
echo "   then quit and reopen HuzaifaShot from the menu bar."
echo ""

read -p "🚀 Launch HuzaifaShot now? (y/n): " LAUNCH
if [[ "$LAUNCH" == "y" || "$LAUNCH" == "Y" ]]; then
    open "$DEST"
fi
