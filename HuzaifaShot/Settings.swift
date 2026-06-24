import AppKit
import Carbon

/// A configurable hotkey: a virtual key code plus a Carbon modifier mask,
/// with a precomputed display string (e.g. "⌃⌘1").
struct HotKeySpec: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var display: String

    static let defaultRegion     = HotKeySpec(keyCode: 18, modifiers: UInt32(cmdKey | controlKey), display: "⌃⌘1")
    static let defaultWindow     = HotKeySpec(keyCode: 19, modifiers: UInt32(cmdKey | controlKey), display: "⌃⌘2")
    static let defaultFullscreen = HotKeySpec(keyCode: 20, modifiers: UInt32(cmdKey | controlKey), display: "⌃⌘3")
}

/// User-configurable settings, persisted in UserDefaults: the save folder and
/// the three capture hotkeys. Post `didChange` so the app re-registers hotkeys
/// and rebuilds the menu.
final class Settings {
    static let shared = Settings()
    static let didChange = Notification.Name("HuzaifaShotSettingsDidChange")

    private let defaults = UserDefaults.standard
    private enum Key {
        static let saveFolder = "saveFolderPath"
        static let region = "hotkeyRegion"
        static let window = "hotkeyWindow"
        static let fullscreen = "hotkeyFullscreen"
    }

    // MARK: Save folder

    static var defaultSaveFolder: URL {
        let base = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent("HuzaifaShot", isDirectory: true)
    }

    var saveFolder: URL {
        get {
            if let path = defaults.string(forKey: Key.saveFolder) {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
            return Settings.defaultSaveFolder
        }
        set { defaults.set(newValue.path, forKey: Key.saveFolder) }
    }

    func ensureSaveFolderExists() {
        try? FileManager.default.createDirectory(at: saveFolder, withIntermediateDirectories: true)
    }

    // MARK: Hotkeys

    var regionHotKey: HotKeySpec {
        get { spec(Key.region) ?? .defaultRegion }
        set { setSpec(newValue, Key.region) }
    }
    var windowHotKey: HotKeySpec {
        get { spec(Key.window) ?? .defaultWindow }
        set { setSpec(newValue, Key.window) }
    }
    var fullscreenHotKey: HotKeySpec {
        get { spec(Key.fullscreen) ?? .defaultFullscreen }
        set { setSpec(newValue, Key.fullscreen) }
    }

    private func spec(_ key: String) -> HotKeySpec? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(HotKeySpec.self, from: data)
    }

    private func setSpec(_ value: HotKeySpec, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    func notifyChanged() {
        NotificationCenter.default.post(name: Settings.didChange, object: nil)
    }
}
