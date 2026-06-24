import AppKit
import UniformTypeIdentifiers

/// Hosts the annotation editor: a tool strip on top, the scrollable canvas below.
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    let canvas: CanvasView

    // Keep controllers alive while their windows are open.
    private static var openControllers: [EditorWindowController] = []

    /// The PNG this capture was auto-saved to, so "Save" can update it in place.
    private let fileURL: URL?

    private var textField: NSTextField?
    private var textPoint: CGPoint = .zero

    private let toolLabels = ["Select", "Arrow", "Rect", "Oval", "Mark", "Blur", "Text", "Step", "Erase Obj", "Erase Px"]

    init(image: NSImage, fileURL: URL? = nil) {
        self.fileURL = fileURL
        canvas = CanvasView(image: image)

        let fit = EditorWindowController.fitSize(image.size)
        let toolbarHeight: CGFloat = 44
        let win = NSWindow(contentRect: CGRect(x: 0, y: 0, width: fit.width,
                                               height: fit.height + toolbarHeight),
                           styleMask: [.titled, .closable, .resizable, .miniaturizable],
                           backing: .buffered, defer: false)
        win.title = "HuzaifaShot — Editor"
        win.minSize = CGSize(width: 480, height: 320)

        super.init(window: win)
        win.delegate = self
        buildUI(toolbarHeight: toolbarHeight)
        win.center()
        EditorWindowController.openControllers.append(self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - UI

    private func buildUI(toolbarHeight: CGFloat) {
        guard let content = window?.contentView else { return }

        let tools = NSSegmentedControl(labels: toolLabels,
                                       trackingMode: .selectOne,
                                       target: self,
                                       action: #selector(toolChanged(_:)))
        tools.selectedSegment = Tool.arrow.rawValue

        let colorWell = NSColorWell()
        colorWell.color = canvas.strokeColor
        colorWell.target = self
        colorWell.action = #selector(colorChanged(_:))
        colorWell.widthAnchor.constraint(equalToConstant: 42).isActive = true

        let widthSlider = NSSlider(value: Double(canvas.lineWidth), minValue: 1, maxValue: 24,
                                   target: self, action: #selector(widthChanged(_:)))
        widthSlider.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let undoButton = NSButton(title: "Undo", target: self, action: #selector(undo(_:)))
        let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyImage(_:)))
        let saveButton = NSButton(title: "Save", target: self, action: #selector(save(_:)))
        let exportButton = NSButton(title: "Export…", target: self, action: #selector(export(_:)))
        copyButton.keyEquivalent = "c"
        copyButton.keyEquivalentModifierMask = [.command]
        saveButton.keyEquivalent = "s"
        saveButton.keyEquivalentModifierMask = [.command]
        exportButton.keyEquivalent = "s"
        exportButton.keyEquivalentModifierMask = [.command, .shift]
        undoButton.keyEquivalent = "z"
        undoButton.keyEquivalentModifierMask = [.command]

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let bar = NSStackView(views: [tools, colorWell, widthSlider, spacer,
                                      undoButton, copyButton, saveButton, exportButton])
        bar.orientation = .horizontal
        bar.alignment = .centerY
        bar.spacing = 8
        bar.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        bar.translatesAutoresizingMaskIntoConstraints = false

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.borderType = .noBorder
        scroll.documentView = canvas
        canvas.onRequestText = { [weak self] point in self?.beginTextEntry(at: point) }

        content.addSubview(bar)
        content.addSubview(scroll)

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: content.topAnchor),
            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: toolbarHeight),

            scroll.topAnchor.constraint(equalTo: bar.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
    }

    // MARK: - Text entry

    private func beginTextEntry(at point: CGPoint) {
        textField?.removeFromSuperview()
        let field = NSTextField(frame: CGRect(x: point.x, y: point.y, width: 220, height: 26))
        field.placeholderString = "Type text, press Enter"
        field.font = NSFont.boldSystemFont(ofSize: max(12, canvas.lineWidth * 6))
        field.textColor = canvas.strokeColor
        field.target = self
        field.action = #selector(commitText(_:))
        canvas.addSubview(field)
        window?.makeFirstResponder(field)
        textField = field
        textPoint = point
    }

    @objc private func commitText(_ sender: NSTextField) {
        canvas.addText(sender.stringValue, at: textPoint)
        sender.removeFromSuperview()
        textField = nil
        window?.makeFirstResponder(canvas)
    }

    // MARK: - Toolbar actions

    @objc private func toolChanged(_ sender: NSSegmentedControl) {
        canvas.currentTool = Tool(rawValue: sender.selectedSegment) ?? .arrow
    }

    @objc private func colorChanged(_ sender: NSColorWell) {
        canvas.strokeColor = sender.color
    }

    @objc private func widthChanged(_ sender: NSSlider) {
        canvas.lineWidth = CGFloat(sender.doubleValue)
    }

    @objc private func undo(_ sender: Any?) { canvas.undo() }

    @objc private func copyImage(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([canvas.flattened()])
    }

    /// Save updates the capture's file in the save folder (and refreshes the
    /// tray). If there's no tracked file, it falls back to Export.
    @objc private func save(_ sender: Any?) {
        if let fileURL = fileURL {
            CaptureStore.shared.update(fileURL, with: canvas.flattened())
        } else {
            export(sender)
        }
    }

    /// Export… lets the user pick a destination via a save panel.
    @objc private func export(_ sender: Any?) {
        let image = canvas.flattened()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.png]
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "Capture.png"
        panel.directoryURL = Settings.shared.saveFolder
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? png.write(to: url)
            CaptureStore.shared.reload()
        }
    }

    // MARK: - Window

    func windowWillClose(_ notification: Notification) {
        EditorWindowController.openControllers.removeAll { $0 === self }
    }

    private static func fitSize(_ size: CGSize) -> CGSize {
        let maxW: CGFloat = 1400, maxH: CGFloat = 900
        let scale = min(1, min(maxW / size.width, maxH / size.height))
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}
