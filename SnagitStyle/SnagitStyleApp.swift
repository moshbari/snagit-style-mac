import AppKit

// Entry point. Pure AppKit menu-bar (accessory) app — no Dock icon.
@main
enum SnagitStyleMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // menu bar only; pairs with LSUIElement
        app.run()
    }
}
