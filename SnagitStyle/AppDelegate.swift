import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.shared.ensureSaveFolderExists()
        CaptureStore.shared.reload()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder",
                                   accessibilityDescription: "Snagit Style")
        }

        rebuildMenu()
        registerHotKeys()

        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: Settings.didChange, object: nil)
    }

    @objc private func settingsChanged() {
        registerHotKeys()
        rebuildMenu()
    }

    private func registerHotKeys() {
        HotKeyCenter.shared.reset()
        let settings = Settings.shared
        let region = settings.regionHotKey
        let window = settings.windowHotKey
        let full = settings.fullscreenHotKey
        HotKeyCenter.shared.register(keyCode: region.keyCode, modifiers: region.modifiers) { [weak self] in self?.captureRegion() }
        HotKeyCenter.shared.register(keyCode: window.keyCode, modifiers: window.modifiers) { [weak self] in self?.captureWindow() }
        HotKeyCenter.shared.register(keyCode: full.keyCode, modifiers: full.modifiers) { [weak self] in self?.captureFull() }
    }

    private func rebuildMenu() {
        let settings = Settings.shared
        let menu = NSMenu()
        menu.addItem(withTitle: "Capture Region  (\(settings.regionHotKey.display))",
                     action: #selector(captureRegion), keyEquivalent: "")
        menu.addItem(withTitle: "Capture Window  (\(settings.windowHotKey.display))",
                     action: #selector(captureWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Capture Full Screen  (\(settings.fullscreenHotKey.display))",
                     action: #selector(captureFull), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Show Recent Captures", action: #selector(showTray), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Snagit Style", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    private func begin(_ mode: CaptureMode) {
        CaptureService.capture(mode) { image in
            guard let image = image else { return } // user cancelled
            let url = CaptureStore.shared.save(image)
            NSApp.activate(ignoringOtherApps: true)
            let controller = EditorWindowController(image: image, fileURL: url)
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func captureRegion() { begin(.region) }
    @objc private func captureWindow() { begin(.window) }
    @objc private func captureFull() { begin(.fullscreen) }

    @objc private func showTray() {
        ThumbnailTrayController.shared.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.present()
    }
}
