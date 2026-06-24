import AppKit

/// Settings window: choose the save folder and customize the three capture
/// hotkeys. Changes are persisted immediately and broadcast via Settings.didChange.
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private let folderLabel = NSTextField(labelWithString: "")
    private var fields: [HotKeyRecorderField] = []

    init() {
        let win = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 480, height: 280),
                           styleMask: [.titled, .closable],
                           backing: .buffered, defer: false)
        win.title = "HuzaifaShot Settings"
        super.init(window: win)
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func build() {
        guard let content = window?.contentView else { return }
        let settings = Settings.shared

        // Save folder
        let folderTitle = NSTextField(labelWithString: "Save folder")
        folderTitle.font = .boldSystemFont(ofSize: 13)

        folderLabel.stringValue = settings.saveFolder.path
        folderLabel.lineBreakMode = .byTruncatingMiddle
        folderLabel.textColor = .secondaryLabelColor
        folderLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        folderLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let chooseButton = NSButton(title: "Choose…", target: self, action: #selector(chooseFolder))
        let revealButton = NSButton(title: "Reveal", target: self, action: #selector(revealFolder))
        let folderRow = NSStackView(views: [folderLabel, chooseButton, revealButton])
        folderRow.orientation = .horizontal
        folderRow.translatesAutoresizingMaskIntoConstraints = false

        // Hotkeys
        let hotkeyTitle = NSTextField(labelWithString: "Keyboard shortcuts")
        hotkeyTitle.font = .boldSystemFont(ofSize: 13)

        let region = HotKeyRecorderField(spec: settings.regionHotKey)
        region.onChange = { settings.regionHotKey = $0; settings.notifyChanged() }
        let window = HotKeyRecorderField(spec: settings.windowHotKey)
        window.onChange = { settings.windowHotKey = $0; settings.notifyChanged() }
        let full = HotKeyRecorderField(spec: settings.fullscreenHotKey)
        full.onChange = { settings.fullscreenHotKey = $0; settings.notifyChanged() }
        fields = [region, window, full]

        let resetButton = NSButton(title: "Reset shortcuts to defaults",
                                   target: self, action: #selector(resetHotkeys))

        let main = NSStackView(views: [
            folderTitle,
            folderRow,
            spacer(8),
            hotkeyTitle,
            hotkeyRow("Capture Region", region),
            hotkeyRow("Capture Window", window),
            hotkeyRow("Capture Full Screen", full),
            spacer(4),
            resetButton,
        ])
        main.orientation = .vertical
        main.alignment = .leading
        main.spacing = 10
        main.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        main.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(main)

        NSLayoutConstraint.activate([
            main.topAnchor.constraint(equalTo: content.topAnchor),
            main.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            main.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            main.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            folderRow.widthAnchor.constraint(equalTo: main.widthAnchor, constant: -40),
        ])
    }

    private func hotkeyRow(_ title: String, _ field: HotKeyRecorderField) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 150).isActive = true
        let row = NSStackView(views: [label, field])
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    private func spacer(_ height: CGFloat) -> NSView {
        let v = NSView()
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }

    // MARK: Actions

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = Settings.shared.saveFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Settings.shared.saveFolder = url
        Settings.shared.ensureSaveFolderExists()
        folderLabel.stringValue = url.path
        CaptureStore.shared.reload()
    }

    @objc private func revealFolder() {
        Settings.shared.ensureSaveFolderExists()
        NSWorkspace.shared.open(Settings.shared.saveFolder)
    }

    @objc private func resetHotkeys() {
        let settings = Settings.shared
        settings.regionHotKey = .defaultRegion
        settings.windowHotKey = .defaultWindow
        settings.fullscreenHotKey = .defaultFullscreen
        fields[0].spec = .defaultRegion
        fields[1].spec = .defaultWindow
        fields[2].spec = .defaultFullscreen
        settings.notifyChanged()
    }

    func present() {
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
