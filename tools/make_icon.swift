import AppKit

// Renders the Snagit Style app icon: a blue→purple rounded tile with white
// viewfinder corner brackets and an amber annotation arrow. Run with:
//   swift tools/make_icon.swift <output.iconset-dir>
// then: iconutil -c icns <dir> -o SnagitStyle/AppIcon.icns

func drawIcon(size s: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: Int(s), pixelsHigh: Int(s),
                               bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false,
                               colorSpaceName: .calibratedRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Rounded tile with diagonal gradient
    let margin = s * 0.085
    let tile = NSRect(x: margin, y: margin, width: s - 2 * margin, height: s - 2 * margin)
    let radius = tile.width * 0.2237
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()
    let blue = NSColor(srgbRed: 0.31, green: 0.49, blue: 1.0, alpha: 1)
    let purple = NSColor(srgbRed: 0.61, green: 0.24, blue: 0.94, alpha: 1)
    NSGradient(starting: blue, ending: purple)!.draw(in: tile, angle: -45)
    NSGraphicsContext.restoreGraphicsState()

    // Viewfinder corner brackets
    let inset = s * 0.30
    let frame = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let arm = s * 0.10
    let brackets = NSBezierPath()
    brackets.lineWidth = s * 0.035
    brackets.lineCapStyle = .round
    brackets.lineJoinStyle = .round
    // bottom-left
    brackets.move(to: NSPoint(x: frame.minX, y: frame.minY + arm))
    brackets.line(to: NSPoint(x: frame.minX, y: frame.minY))
    brackets.line(to: NSPoint(x: frame.minX + arm, y: frame.minY))
    // bottom-right
    brackets.move(to: NSPoint(x: frame.maxX - arm, y: frame.minY))
    brackets.line(to: NSPoint(x: frame.maxX, y: frame.minY))
    brackets.line(to: NSPoint(x: frame.maxX, y: frame.minY + arm))
    // top-right
    brackets.move(to: NSPoint(x: frame.maxX, y: frame.maxY - arm))
    brackets.line(to: NSPoint(x: frame.maxX, y: frame.maxY))
    brackets.line(to: NSPoint(x: frame.maxX - arm, y: frame.maxY))
    // top-left
    brackets.move(to: NSPoint(x: frame.minX + arm, y: frame.maxY))
    brackets.line(to: NSPoint(x: frame.minX, y: frame.maxY))
    brackets.line(to: NSPoint(x: frame.minX, y: frame.maxY - arm))
    NSColor.white.setStroke()
    brackets.stroke()

    // Amber annotation arrow across the middle
    let amber = NSColor(srgbRed: 1.0, green: 0.78, blue: 0.24, alpha: 1)
    let start = NSPoint(x: s * 0.40, y: s * 0.40)
    let end = NSPoint(x: s * 0.61, y: s * 0.61)
    let shaft = NSBezierPath()
    shaft.lineWidth = s * 0.05
    shaft.lineCapStyle = .round
    shaft.move(to: start)
    shaft.line(to: end)
    amber.setStroke()
    shaft.stroke()

    let angle = atan2(end.y - start.y, end.x - start.x)
    let len = s * 0.12
    let spread = CGFloat.pi / 6
    let head = NSBezierPath()
    head.move(to: end)
    head.line(to: NSPoint(x: end.x - cos(angle - spread) * len, y: end.y - sin(angle - spread) * len))
    head.line(to: NSPoint(x: end.x - cos(angle + spread) * len, y: end.y - sin(angle + spread) * len))
    head.close()
    amber.setFill()
    head.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./icon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let variants: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for (name, size) in variants {
    let rep = drawIcon(size: size)
    if let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
    }
}
print("Wrote iconset to \(outDir)")
