import AppKit
import ApplicationServices

/// Which keystroke delivers the paste. Terminals hand ⌃V to the program inside them,
/// which is how Claude Code, Codex and friends accept images.
enum PasteKey: Equatable {
    case commandV, controlV
}

/// Writes an item back to the pasteboard and sends Cmd+V to the previously active app.
@MainActor
final class Paster {
    private let store: ClipStore
    private var previousApp: NSRunningApplication?

    init(store: ClipStore) { self.store = store }

    func rememberFrontApp() {
        // Never target ourselves (the welcome window or settings may be in front).
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        previousApp = app
    }

    /// Writes the item to the pasteboard. Returns false, leaving the pasteboard untouched,
    /// when the payload cannot be read or decrypted.
    @discardableResult
    func copy(_ item: ClipItem, asPlainText: Bool = false) -> Bool {
        guard let payload = store.payload(for: item) else {
            NSSound.beep()
            return false
        }
        let text = item.text(from: payload) ?? ""
        let pb = NSPasteboard.general
        pb.clearContents()
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
            if asPlainText {
                pb.setString(item.preview, forType: .string)
            } else {
                let urls = item.preview.split(separator: "\n").map { URL(fileURLWithPath: String($0)) as NSURL }
                pb.writeObjects(urls)
            }
        }
        return true
    }

    /// `forceControl` is ⌃ held on Return, or the row's "Paste with ⌃V" menu item.
    func paste(_ item: ClipItem, asPlainText: Bool = false, forceControl: Bool = false) {
        guard copy(item, asPlainText: asPlainText) else { return }
        // Without the permission the item is on the pasteboard; the panel footer explains
        // what is missing, so no system prompt is forced here.
        guard Self.isTrusted() else { return }
        let settings = AppSettings.shared
        let key = Self.pasteKey(kind: Self.pastedKind(of: item.kind, hasText: item.ocrText != nil, asPlainText: asPlainText),
                                target: previousApp?.bundleIdentifier,
                                terminals: settings.terminalImagePaste ? settings.terminalApps : [],
                                forceControl: forceControl)
        previousApp?.activate()
        // Give the target app one run loop turn to become key before the keystroke lands.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Self.sendV(key)
        }
    }

    /// What `copy` actually put on the pasteboard: a plain-text paste of an image with no
    /// recognized text falls back to the PNG, so it must still be routed as an image.
    nonisolated static func pastedKind(of kind: ClipKind, hasText: Bool, asPlainText: Bool) -> ClipKind {
        guard asPlainText else { return kind }
        return kind == .image && !hasText ? .image : .text
    }

    /// Images going into a known terminal are pasted with ⌃V; everything else keeps ⌘V,
    /// since text pastes fine with ⌘V everywhere and ⌃V in a bare shell does nothing useful.
    nonisolated static func pasteKey(kind: ClipKind, target: String?, terminals: [String], forceControl: Bool) -> PasteKey {
        if forceControl { return .controlV }
        guard kind == .image, let target else { return .commandV }
        return terminals.contains(target) ? .controlV : .commandV
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

    private static func sendV(_ key: PasteKey) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else { return }
        let flags: CGEventFlags = key == .controlV ? .maskControl : .maskCommand
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
