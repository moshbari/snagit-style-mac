import AppKit

enum CaptureMode {
    case region      // interactive drag-to-select (space toggles window mode)
    case window      // click a window
    case fullscreen  // whole main display
}

/// Wraps macOS's built-in /usr/sbin/screencapture. Using the system tool gives
/// us native-quality region selection and avoids re-implementing the overlay UI.
/// Note: screen capture may require Screen Recording permission on first use;
/// macOS prompts automatically.
enum CaptureService {
    static func capture(_ mode: CaptureMode, completion: @escaping (NSImage?) -> Void) {
        let path = NSTemporaryDirectory() + "huzaifashot-\(UUID().uuidString).png"
        let args: [String]
        switch mode {
        case .region:     args = ["-i", "-o", path]
        case .window:     args = ["-i", "-o", "-w", path]
        case .fullscreen: args = ["-o", path]
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            proc.arguments = args
            try? proc.run()
            proc.waitUntilExit()

            // If the user pressed Esc, no file is written.
            let image = NSImage(contentsOfFile: path)
            try? FileManager.default.removeItem(atPath: path)
            DispatchQueue.main.async { completion(image) }
        }
    }
}
