import AppKit
import CoreImage

/// The editor canvas: draws the captured image plus all annotations, and
/// handles mouse interaction for creating, selecting, moving and deleting them.
final class CanvasView: NSView {
    let image: NSImage
    private let pixelated: NSImage   // precomputed once, sampled by the blur tool

    var annotations: [Annotation] = []
    var strokeColor: NSColor = .systemRed
    var lineWidth: CGFloat = 4
    var currentTool: Tool = .arrow {
        didSet {
            if currentTool != .select { selected = nil }
            needsDisplay = true
        }
    }

    /// Called when the text tool is used, so the editor can show an input field.
    var onRequestText: ((CGPoint) -> Void)?

    private var draft: Annotation?
    private var selected: Annotation?
    private var moving = false
    private var lastPoint: CGPoint = .zero
    private var stepCounter = 1
    private var undoStack: [[Annotation]] = []

    override var isFlipped: Bool { true }            // top-left origin, matches image
    override var acceptsFirstResponder: Bool { true }

    init(image: NSImage) {
        self.image = image
        self.pixelated = CanvasView.makePixelated(image)
        super.init(frame: CGRect(origin: .zero, size: image.size))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Undo

    private func snapshot() {
        undoStack.append(annotations.map { $0.copy() })
        if undoStack.count > 50 { undoStack.removeFirst() }
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        annotations = last
        selected = nil
        needsDisplay = true
    }

    func addText(_ text: String, at point: CGPoint) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        snapshot()
        annotations.append(Annotation(type: .text, start: point, end: point,
                                      color: strokeColor, lineWidth: lineWidth, text: trimmed))
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds)
        for a in annotations { render(a) }
        if let d = draft { render(d) }
        if let s = selected { drawSelection(s) }
    }

    private func render(_ a: Annotation) {
        switch a.type {
        case .arrow:     drawArrow(a)
        case .rectangle: stroke(NSBezierPath(rect: a.rect), a)
        case .ellipse:   stroke(NSBezierPath(ovalIn: a.rect), a)
        case .highlight:
            a.color.withAlphaComponent(0.35).setFill()
            NSBezierPath(rect: a.rect).fill()
        case .blur:      drawBlur(a)
        case .text:      drawText(a)
        case .step:      drawStep(a)
        case .select:    break
        }
    }

    private func stroke(_ path: NSBezierPath, _ a: Annotation) {
        path.lineWidth = a.lineWidth
        path.lineJoinStyle = .round
        a.color.setStroke()
        path.stroke()
    }

    private func drawArrow(_ a: Annotation) {
        let shaft = NSBezierPath()
        shaft.lineWidth = a.lineWidth
        shaft.lineCapStyle = .round
        shaft.move(to: a.start)
        shaft.line(to: a.end)
        a.color.setStroke()
        shaft.stroke()

        let angle = atan2(a.end.y - a.start.y, a.end.x - a.start.x)
        let len = max(14, a.lineWidth * 4)
        let spread = CGFloat.pi / 7
        let head = NSBezierPath()
        head.move(to: a.end)
        head.line(to: CGPoint(x: a.end.x - cos(angle - spread) * len,
                              y: a.end.y - sin(angle - spread) * len))
        head.line(to: CGPoint(x: a.end.x - cos(angle + spread) * len,
                              y: a.end.y - sin(angle + spread) * len))
        head.close()
        a.color.setFill()
        head.fill()
    }

    private func drawBlur(_ a: Annotation) {
        guard a.rect.width > 1, a.rect.height > 1 else { return }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: a.rect).setClip()
        // pixelated has the same logical size as image, so it aligns 1:1 in bounds.
        pixelated.draw(in: bounds)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawText(_ a: Annotation) {
        let font = NSFont.boldSystemFont(ofSize: max(12, a.lineWidth * 6))
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: a.color]
        (a.text as NSString).draw(at: a.start, withAttributes: attrs)
    }

    private func drawStep(_ a: Annotation) {
        let d = a.stepDiameter
        let circle = CGRect(x: a.start.x - d / 2, y: a.start.y - d / 2, width: d, height: d)
        a.color.setFill()
        NSBezierPath(ovalIn: circle).fill()

        let label = "\(a.stepNumber)"
        let font = NSFont.boldSystemFont(ofSize: d * 0.5)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let size = (label as NSString).size(withAttributes: attrs)
        (label as NSString).draw(at: CGPoint(x: a.start.x - size.width / 2,
                                             y: a.start.y - size.height / 2),
                                 withAttributes: attrs)
    }

    private func drawSelection(_ a: Annotation) {
        let path = NSBezierPath(rect: a.boundingRect)
        path.lineWidth = 1.5
        path.setLineDash([5, 3], count: 2, phase: 0)
        NSColor.controlAccentColor.setStroke()
        path.stroke()
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let p = convert(event.locationInWindow, from: nil)
        lastPoint = p

        switch currentTool {
        case .select:
            selected = annotations.last { $0.boundingRect.contains(p) }
            moving = (selected != nil)
            if moving { snapshot() }
            needsDisplay = true
        case .text:
            onRequestText?(p)
        case .step:
            snapshot()
            annotations.append(Annotation(type: .step, start: p, end: p,
                                          color: strokeColor, lineWidth: lineWidth,
                                          stepNumber: stepCounter))
            stepCounter += 1
            needsDisplay = true
        default:
            draft = Annotation(type: currentTool, start: p, end: p,
                               color: strokeColor, lineWidth: lineWidth)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if moving, let s = selected {
            s.translate(dx: p.x - lastPoint.x, dy: p.y - lastPoint.y)
            lastPoint = p
            needsDisplay = true
        } else if let d = draft {
            d.end = p
            needsDisplay = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        if let d = draft {
            // Discard zero-size shapes (an accidental click); arrows always count.
            if d.type == .arrow || d.rect.width > 3 || d.rect.height > 3 {
                snapshot()
                annotations.append(d)
            }
            draft = nil
            needsDisplay = true
        }
        moving = false
    }

    override func keyDown(with event: NSEvent) {
        // 51 = delete, 117 = forward delete
        if event.keyCode == 51 || event.keyCode == 117,
           let s = selected, let idx = annotations.firstIndex(where: { $0 === s }) {
            snapshot()
            annotations.remove(at: idx)
            selected = nil
            needsDisplay = true
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Export

    /// Flatten the image + annotations into a single NSImage at backing resolution.
    func flattened() -> NSImage {
        let previous = selected
        selected = nil // don't bake the selection outline into the export
        defer { selected = previous }

        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return image }
        cacheDisplay(in: bounds, to: rep)
        let out = NSImage(size: bounds.size)
        out.addRepresentation(rep)
        return out
    }

    // MARK: - Helpers

    /// Pre-render a pixelated copy of the whole image for the blur/redact tool.
    private static func makePixelated(_ source: NSImage) -> NSImage {
        guard let tiff = source.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return source }
        let ciImage = CIImage(bitmapImageRep: bitmap)
        guard let ci = ciImage,
              let filter = CIFilter(name: "CIPixellate") else { return source }
        let scale = max(8.0, min(ci.extent.width, ci.extent.height) / 40.0)
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        guard let output = filter.outputImage,
              let cg = CIContext().createCGImage(output, from: ci.extent) else { return source }
        return NSImage(cgImage: cg, size: source.size)
    }
}
