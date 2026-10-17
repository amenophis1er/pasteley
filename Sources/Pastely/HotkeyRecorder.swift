import AppKit
import Carbon
import SwiftUI

/// A click-to-record field for the global hotkey.
struct HotkeyRecorder: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    @State private var recording = false

    private var label: String {
        HotkeyManager.Modifiers(rawValue: modifiers).symbols + HotkeyManager.keyName(keyCode)
    }

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            RecorderField(recording: $recording) { code, flags in
                guard let carbon = Self.carbonModifiers(flags), !carbon.isEmpty else { return false }
                keyCode = code
                modifiers = carbon.rawValue
                return true
            }
            .frame(width: 150, height: 26)
            .overlay {
                Text(recording ? "Press shortcut…" : label)
                    .font(recording ? Theme.Text.caption : Theme.Text.body)
                    .foregroundStyle(recording ? .secondary : .primary)
                    .allowsHitTesting(false)
            }
            if recording {
                Button("Cancel") { recording = false }.controlSize(.small)
            }
        }
    }

    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> HotkeyManager.Modifiers? {
        var m = HotkeyManager.Modifiers()
        if flags.contains(.command) { m.insert(.command) }
        if flags.contains(.shift) { m.insert(.shift) }
        if flags.contains(.option) { m.insert(.option) }
        if flags.contains(.control) { m.insert(.control) }
        return m
    }
}

private struct RecorderField: NSViewRepresentable {
    @Binding var recording: Bool
    let onRecord: (UInt32, NSEvent.ModifierFlags) -> Bool

    func makeNSView(context: Context) -> RecorderNSView {
        let v = RecorderNSView()
        v.onRecord = { code, flags in
            if onRecord(code, flags) { recording = false }
        }
        v.onToggle = { recording = $0 }
        return v
    }

    func updateNSView(_ view: RecorderNSView, context: Context) {
        view.isRecording = recording
        if recording { view.window?.makeFirstResponder(view) }
    }
}

final class RecorderNSView: NSView {
    var onRecord: ((UInt32, NSEvent.ModifierFlags) -> Void)?
    var onToggle: ((Bool) -> Void)?
    var isRecording = false { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.12) : NSColor.controlBackgroundColor).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = isRecording ? 1.5 : 1
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        onToggle?(true)
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { onToggle?(false); return } // escape cancels
        onRecord?(UInt32(event.keyCode), event.modifierFlags.intersection(.deviceIndependentFlagsMask))
    }

    override func resignFirstResponder() -> Bool {
        onToggle?(false)
        return true
    }
}
