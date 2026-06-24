import AppKit

/// A single draggable thumbnail. Dragging it out provides the underlying PNG
/// file URL, so it drops as a real .png into Finder, Slack, Mail, etc. —
/// exactly like Snagit's tray.
final class ThumbnailItemView: NSView, NSDraggingSource {
    let url: URL
    private let imageView = NSImageView()
    private var mouseDownPoint: NSPoint = .zero

    init(url: URL, image: NSImage) {
        self.url = url
        super.init(frame: CGRect(x: 0, y: 0, width: 120, height: 84))
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])
        toolTip = url.lastPathComponent
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        let dx = event.locationInWindow.x - mouseDownPoint.x
        let dy = event.locationInWindow.y - mouseDownPoint.y
        guard hypot(dx, dy) > 6 else { return }

        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        item.setDraggingFrame(bounds, contents: imageView.image)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    var onDoubleClick: (() -> Void)?

    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 2 { onDoubleClick?() }
    }

    // Right-click menu — Snagit-style "open the folder" plus quick actions.
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open in Editor", action: #selector(openInEditor), keyEquivalent: "")
        menu.addItem(withTitle: "Reveal in Finder", action: #selector(revealInFinder), keyEquivalent: "")
        menu.addItem(withTitle: "Open Save Folder", action: #selector(openFolder), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Copy Image", action: #selector(copyImage), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Move to Trash", action: #selector(moveToTrash), keyEquivalent: "")
        menu.items.forEach { $0.target = self }
        return menu
    }

    @objc private func openInEditor() { onDoubleClick?() }

    @objc private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func openFolder() {
        NSWorkspace.shared.open(url.deletingLastPathComponent())
    }

    @objc private func copyImage() {
        guard let image = NSImage(contentsOf: url) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    @objc private func moveToTrash() {
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        CaptureStore.shared.reload()
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }
}

/// A floating panel showing recent captures as draggable thumbnails.
final class ThumbnailTrayController: NSWindowController {
    static let shared = ThumbnailTrayController()

    private let stack = NSStackView()
    private let scroll = NSScrollView()

    init() {
        let panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 540, height: 112),
                            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
                            backing: .buffered, defer: false)
        panel.title = "Recent Captures — drag to any app"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        super.init(window: panel)
        buildUI()
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: CaptureStore.didChange, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        stack.orientation = .horizontal
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let doc = NSView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)

        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasHorizontalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = doc
        content.addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            stack.topAnchor.constraint(equalTo: doc.topAnchor),
            stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            doc.heightAnchor.constraint(equalTo: scroll.contentView.heightAnchor),
        ])
        refresh()
    }

    @objc private func refresh() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let urls = Array(CaptureStore.shared.items.prefix(40))
        guard !urls.isEmpty else {
            let label = NSTextField(labelWithString: "No captures yet — use a capture hotkey.")
            label.textColor = .secondaryLabelColor
            stack.addArrangedSubview(label)
            return
        }

        for url in urls {
            let image = NSImage(contentsOf: url) ?? NSImage()
            let view = ThumbnailItemView(url: url, image: image)
            view.onDoubleClick = { [weak self] in self?.openInEditor(url) }
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalToConstant: 120).isActive = true
            view.heightAnchor.constraint(equalToConstant: 84).isActive = true
            stack.addArrangedSubview(view)
        }
    }

    private func openInEditor(_ url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        NSApp.activate(ignoringOtherApps: true)
        let controller = EditorWindowController(image: image, fileURL: url)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    func show() {
        CaptureStore.shared.reload()
        if let window = window, !window.isVisible { positionAtBottom(window) }
        window?.orderFront(nil)
    }

    /// Park the tray centered along the bottom of the main screen, Snagit-style.
    private func positionAtBottom(_ window: NSWindow) {
        guard let screen = NSScreen.main else { window.center(); return }
        let visible = screen.visibleFrame
        let origin = NSPoint(x: visible.midX - window.frame.width / 2,
                             y: visible.minY + 24)
        window.setFrameOrigin(origin)
    }
}
