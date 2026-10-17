import AppKit
import ApplicationServices


/// Finds where the next paste will land, using the Accessibility API.
/// Returns AppKit screen coordinates (origin bottom-left of the primary screen).
@MainActor
enum FocusLocator {
    /// The caret rectangle if the focused element is a text field, else the focused element's frame.
    static func targetRect() -> CGRect? {
        guard AXIsProcessTrusted() else { return nil }
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
        let pid = front.processIdentifier
        let app = AXUIElementCreateApplication(pid)

        if let focused = child(of: app, kAXFocusedUIElementAttribute) {
            if let caret = caretRect(of: focused) { return flip(caret) }
            if let frame = frame(of: focused) { return flip(frame) }
        }
        if let window = child(of: app, kAXFocusedWindowAttribute), let frame = frame(of: window) {
            return flip(frame)
        }
        return nil
    }

    private static func child(of element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success, let any = ref else { return nil }
        return (any as! AXUIElement)
    }

    private static func caretRect(of element: AXUIElement) -> CGRect? {
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeAny = rangeRef else { return nil }
        let rangeValue = rangeAny as! AXValue
        var range = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &range) else { return nil }
        // A zero-length range at the caret; ask for its bounds.
        var caretRange = CFRange(location: range.location + range.length, length: 0)
        guard let param = AXValueCreate(.cfRange, &caretRange) else { return nil }
        var boundsRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, param, &boundsRef) == .success,
              let boundsAny = boundsRef else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(boundsAny as! AXValue, .cgRect, &rect), rect.width >= 0, rect.height > 0 else { return nil }
        // Some apps report a zero rect for an empty field; treat it as unknown.
        return rect == .zero ? nil : rect
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?, sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posAny = posRef, let sizeAny = sizeRef else { return nil }
        var pos = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(posAny as! AXValue, .cgPoint, &pos), AXValueGetValue(sizeAny as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: pos, size: size)
    }

    /// AX uses a top-left origin on the primary display; AppKit uses bottom-left.
    private static func flip(_ rect: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
