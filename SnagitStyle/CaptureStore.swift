import AppKit

/// Tracks captured PNGs in the configured save folder and notifies the tray
/// when the list changes. Captures are saved here on capture and overwritten
/// when the editor saves an annotated version.
final class CaptureStore {
    static let shared = CaptureStore()
    static let didChange = Notification.Name("SnagitCaptureStoreDidChange")

    private(set) var items: [URL] = []   // newest first

    func reload() {
        let folder = Settings.shared.saveFolder
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles])) ?? []

        items = urls
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { lhs, rhs in modified(lhs) > modified(rhs) }
        notify()
    }

    @discardableResult
    func save(_ image: NSImage) -> URL? {
        Settings.shared.ensureSaveFolderExists()
        let url = Settings.shared.saveFolder.appendingPathComponent(Self.newFileName())
        guard writePNG(image, to: url) else { return nil }
        items.insert(url, at: 0)
        notify()
        return url
    }

    func update(_ url: URL, with image: NSImage) {
        _ = writePNG(image, to: url)
        notify()
    }

    // MARK: Helpers

    private func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func writePNG(_ image: NSImage, to url: URL) -> Bool {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return false }
        do { try png.write(to: url); return true } catch { return false }
    }

    private static func newFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Snagit \(formatter.string(from: Date())).png"
    }

    private func notify() {
        NotificationCenter.default.post(name: CaptureStore.didChange, object: nil)
    }
}
