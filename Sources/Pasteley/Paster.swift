import AppKit
import ApplicationServices

/// Writes an item back to the pasteboard and sends Cmd+V to the previously active app.
@MainActor
final class Paster {
    private let store: ClipStore
    private var previousApp: NSRunningApplication?

    init(store: ClipStore) { self.store = store }

    func rememberFrontApp() {
        previousApp = NSWorkspace.shared.frontmostApplication
    }

    func copy(_ item: ClipItem, asPlainText: Bool = false) {
        let pb = NSPasteboard.general
        pb.clearContents()
        let payload = store.payload(for: item) ?? Data()
        let text = item.text(from: payload) ?? ""
        switch item.kind {
        case .text:
            pb.setString(text, forType: .string)
        case .rtf:
            if asPlainText {
                pb.setString(text, forType: .string)
            } else {
                pb.setData(payload, forType: .rtf)
                pb.setString(text, forType: .string)
            }
        case .image:
            // Plain-text paste of an image means its recognized text, when there is any.
            if asPlainText, let ocr = item.ocrText {
                pb.setString(ocr, forType: .string)
            } else {
                pb.setData(payload, forType: .png)
            }
        case .file:
            let urls = item.preview.split(separator: "\n").map { URL(fileURLWithPath: String($0)) as NSURL }
            pb.writeObjects(urls)
        }
    }

    func paste(_ item: ClipItem, asPlainText: Bool = false) {
        copy(item, asPlainText: asPlainText)
        guard Self.ensureAccessibility() else { return }
        previousApp?.activate()
        // Give the target app one run loop turn to become key before the keystroke lands.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Self.sendCommandV()
        }
    }

    static func isTrusted() -> Bool { AXIsProcessTrusted() }

    /// Prompts once through the system dialog, then opens the Privacy pane.
    static func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func ensureAccessibility() -> Bool {
        if isTrusted() { return true }
        requestAccessibility()
        return false
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
