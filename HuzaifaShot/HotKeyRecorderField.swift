import AppKit
import Carbon

/// A click-to-record control for a single global hotkey. Click it, then press
/// the desired combination (must include ⌘, ⌃ or ⌥). Reports the new spec via
/// `onChange`.
final class HotKeyRecorderField: NSView {
    var spec: HotKeySpec {
        didSet { button.title = spec.display }
    }
    var onChange: ((HotKeySpec) -> Void)?

    private let button = NSButton()
    private var recording = false

    init(spec: HotKeySpec) {
        self.spec = spec
        super.init(frame: .zero)

        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.title = spec.display
        button.target = self
        button.action = #selector(startRecording)
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 130),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override var acceptsFirstResponder: Bool { true }

    @objc private func startRecording() {
        recording = true
        button.title = "Type shortcut…"
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }

        // Escape cancels.
        if event.keyCode == 53 {
            recording = false
            button.title = spec.display
            window?.makeFirstResponder(nil)
            return
        }

        let modifiers = HotKeyRecorderField.carbonModifiers(from: event.modifierFlags)
        let requiresModifier = modifiers & UInt32(cmdKey | controlKey | optionKey) != 0
        let key = (event.charactersIgnoringModifiers ?? "").uppercased()

        guard requiresModifier, !key.isEmpty else {
            NSSound.beep()   // demand a modifier so we don't hijack a bare key
            return
        }

        let display = HotKeyRecorderField.displayString(modifiers: modifiers, key: key)
        spec = HotKeySpec(keyCode: UInt32(event.keyCode), modifiers: modifiers, display: display)
        recording = false
        onChange?(spec)
        window?.makeFirstResponder(nil)
    }

    // MARK: Modifier helpers

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option)  { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift)   { m |= UInt32(shiftKey) }
        return m
    }

    static func displayString(modifiers: UInt32, key: String) -> String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        return s + key
    }
}
