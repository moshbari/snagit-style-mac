import AppKit

enum Tool: Int, CaseIterable {
    case select, arrow, rectangle, ellipse, highlight, blur, text, step
}

/// One annotation drawn on top of the captured image.
/// Reference type so it can be mutated in place while dragging and moving.
final class Annotation {
    var type: Tool
    var start: CGPoint
    var end: CGPoint
    var color: NSColor
    var lineWidth: CGFloat
    var text: String
    var stepNumber: Int

    init(type: Tool,
         start: CGPoint,
         end: CGPoint,
         color: NSColor,
         lineWidth: CGFloat,
         text: String = "",
         stepNumber: Int = 0) {
        self.type = type
        self.start = start
        self.end = end
        self.color = color
        self.lineWidth = lineWidth
        self.text = text
        self.stepNumber = stepNumber
    }

    func copy() -> Annotation {
        Annotation(type: type, start: start, end: end, color: color,
                   lineWidth: lineWidth, text: text, stepNumber: stepNumber)
    }

    func translate(dx: CGFloat, dy: CGFloat) {
        start.x += dx; start.y += dy
        end.x += dx; end.y += dy
    }

    /// Normalized rect from the two drag points (for rect/ellipse/highlight/blur).
    var rect: CGRect {
        CGRect(x: min(start.x, end.x),
               y: min(start.y, end.y),
               width: abs(end.x - start.x),
               height: abs(end.y - start.y))
    }

    var stepDiameter: CGFloat { max(28, lineWidth * 7) }

    /// Used for hit-testing (select tool) and drawing the selection outline.
    var boundingRect: CGRect {
        switch type {
        case .text:
            let h = lineWidth * 7
            let w = max(80, CGFloat(text.count) * lineWidth * 3.6)
            return CGRect(x: start.x - 4, y: start.y - 4, width: w + 8, height: h + 8)
        case .step:
            let d = stepDiameter
            return CGRect(x: start.x - d / 2 - 2, y: start.y - d / 2 - 2, width: d + 4, height: d + 4)
        default:
            return rect.insetBy(dx: -lineWidth - 4, dy: -lineWidth - 4)
        }
    }
}
