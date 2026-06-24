import AppKit
import CoreGraphics

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var idleIcon: NSImage?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.shared.ensureSaveFolderExists()
        CaptureStore.shared.reload()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        idleIcon = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "HuzaifaShot")
        statusItem.button?.image = idleIcon

        rebuildMenu()
        registerHotKeys()
        Diag.log("launched; hotkeys registered")

        // Show the tray on launch if there are existing captures (like Snagit).
        if !CaptureStore.shared.items.isEmpty {
            ThumbnailTrayController.shared.show()
        }

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
        menu.addItem(withTitle: "Quit HuzaifaShot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    private func begin(_ mode: CaptureMode) {
        Diag.log("begin capture mode=\(mode)")
        flashStatusIcon()   // immediate visual proof the trigger fired

        if !CGPreflightScreenCaptureAccess() {
            Diag.log("Screen Recording permission NOT granted — requesting")
            CGRequestScreenCaptureAccess()
            promptForScreenRecording()
            return
        }

        CaptureService.capture(mode) { image in
            Diag.log("capture done: image=\(image != nil)")
            guard let image = image else { return } // user cancelled
            let url = CaptureStore.shared.save(image)
            Diag.log("saved: \(url?.lastPathComponent ?? "nil")")
            NSApp.activate(ignoringOtherApps: true)
            ThumbnailTrayController.shared.show()   // pop the tray with the new thumbnail
            let controller = EditorWindowController(image: image, fileURL: url)
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
        }
    }

    /// Briefly swap the menu-bar icon so a fired hotkey is visible even if the
    /// capture step is blocked (e.g. by a missing permission).
    private func flashStatusIcon() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "camera.metering.center.weighted",
                               accessibilityDescription: nil)
        button.contentTintColor = .systemRed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            button.image = self?.idleIcon
            button.contentTintColor = nil
        }
    }

    private func promptForScreenRecording() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording permission needed"
        alert.informativeText = """
        HuzaifaShot needs Screen Recording permission to capture your screen.

        1. In the window that opens, enable HuzaifaShot under Screen Recording.
        2. Remove any older "HuzaifaShot" entry first (it points to a previous build).
        3. Quit and reopen HuzaifaShot from the menu bar.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
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
