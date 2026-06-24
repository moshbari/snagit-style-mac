import Foundation

/// Lightweight file logger so capture/hotkey behavior can be diagnosed even
/// when the app is launched normally (via Finder), where stderr is invisible.
/// Writes to ~/Library/Logs/SnagitStyle.log and also mirrors to NSLog.
enum Diag {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/SnagitStyle.log")

    static func log(_ message: String) {
        NSLog("[SnagitStyle] \(message)")
        let line = "\(Date()) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}
