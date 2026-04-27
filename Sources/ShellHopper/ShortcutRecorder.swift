import SwiftUI
import AppKit

/// SwiftUI wrapper around an NSView that captures a keyboard shortcut.
struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: Shortcut?

    func makeNSView(context: Context) -> ShortcutRecorderView {
        let view = ShortcutRecorderView()
        view.onChange = { newValue in
            DispatchQueue.main.async { self.shortcut = newValue }
        }
        view.shortcut = shortcut
        return view
    }

    func updateNSView(_ view: ShortcutRecorderView, context: Context) {
        if view.shortcut != shortcut {
            view.shortcut = shortcut
            view.needsDisplay = true
        }
    }
}

final class ShortcutRecorderView: NSView {
    var shortcut: Shortcut? { didSet { needsDisplay = true } }
    var onChange: ((Shortcut?) -> Void)?

    private var isRecording = false { didSet { needsDisplay = true } }
    private var localMonitor: Any?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 6
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { stopMonitor() }

    override func mouseDown(with event: NSEvent) {
        let clearWidth: CGFloat = 22
        if event.locationInWindow.x - frame.origin.x > bounds.width - clearWidth, shortcut != nil {
            shortcut = nil
            onChange?(nil)
            return
        }
        window?.makeFirstResponder(self)
        startRecording()
    }

    override func resignFirstResponder() -> Bool {
        stopRecording()
        return super.resignFirstResponder()
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                self.handleKeyDown(event)
                return nil // swallow
            }
            return event
        }
    }

    private func stopRecording() {
        isRecording = false
        stopMonitor()
    }

    private func stopMonitor() {
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }

    private func handleKeyDown(_ event: NSEvent) {
        // Escape clears recording without committing.
        if event.keyCode == 53 {
            stopRecording()
            window?.makeFirstResponder(nil)
            return
        }
        let relevantMods: NSEvent.ModifierFlags = event.modifierFlags
            .intersection([.command, .option, .control, .shift])
        // Require at least one modifier (otherwise normal typing would bind).
        guard !relevantMods.isEmpty else { NSSound.beep(); return }

        let new = Shortcut(keyCode: UInt32(event.keyCode),
                           modifiers: UInt32(relevantMods.rawValue))
        shortcut = new
        onChange?(new)
        stopRecording()
        window?.makeFirstResponder(nil)
    }

    override func draw(_ dirtyRect: NSRect) {
        let bg = NSColor.controlBackgroundColor
        let border = isRecording ? NSColor.controlAccentColor : NSColor.separatorColor
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                                xRadius: 6, yRadius: 6)
        bg.setFill(); path.fill()
        border.setStroke(); path.lineWidth = isRecording ? 2 : 1; path.stroke()

        let text: String
        if isRecording {
            text = "Press shortcut…"
        } else if let s = shortcut {
            text = s.displayString
        } else {
            text = "Click to record"
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13,
                weight: shortcut != nil && !isRecording ? .medium : .regular),
            .foregroundColor: shortcut == nil && !isRecording
                ? NSColor.secondaryLabelColor : NSColor.labelColor
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let size = str.size()
        let textRect = NSRect(x: 8,
                              y: (bounds.height - size.height) / 2,
                              width: bounds.width - 30,
                              height: size.height)
        str.draw(in: textRect)

        // Clear button (✕)
        if shortcut != nil && !isRecording {
            let xStr = NSAttributedString(string: "✕", attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.tertiaryLabelColor
            ])
            let xSize = xStr.size()
            xStr.draw(at: NSPoint(x: bounds.width - xSize.width - 8,
                                  y: (bounds.height - xSize.height) / 2))
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 24)
    }
}
