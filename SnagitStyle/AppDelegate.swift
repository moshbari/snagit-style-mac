import AppKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder",
                                   accessibilityDescription: "Snagit Style")
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Capture Region  (⌃⌘1)", action: #selector(captureRegion), keyEquivalent: "")
        menu.addItem(withTitle: "Capture Window  (⌃⌘2)", action: #selector(captureWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Capture Full Screen  (⌃⌘3)", action: #selector(captureFull), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Snagit Style", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        let mods = UInt32(cmdKey) | UInt32(controlKey)
        HotKeyCenter.shared.register(keyCode: 18, modifiers: mods) { [weak self] in self?.captureRegion() } // 1
        HotKeyCenter.shared.register(keyCode: 19, modifiers: mods) { [weak self] in self?.captureWindow() } // 2
        HotKeyCenter.shared.register(keyCode: 20, modifiers: mods) { [weak self] in self?.captureFull() }   // 3
    }

    private func begin(_ mode: CaptureMode) {
        CaptureService.capture(mode) { image in
            guard let image = image else { return } // user cancelled
            NSApp.activate(ignoringOtherApps: true)
            let controller = EditorWindowController(image: image)
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func captureRegion() { begin(.region) }
    @objc private func captureWindow() { begin(.window) }
    @objc private func captureFull() { begin(.fullscreen) }
}
