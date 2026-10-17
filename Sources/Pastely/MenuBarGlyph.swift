import AppKit

/// Menu bar icon drawn in code so it matches the app icon. Template so macOS
/// recolors it for light and dark menu bars.
enum MenuBarGlyph {
    static let normal = make(paused: false)
    static let paused = make(paused: true)

    private static func make(paused: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let ink = NSColor.black
            // Board
            let board = NSRect(x: 3.5, y: 1, width: 11, height: 14)
            let boardPath = NSBezierPath(roundedRect: board, xRadius: 2.2, yRadius: 2.2)
            ink.setFill()
            boardPath.fill()
            // Clip, sitting over the top edge
            let clip = NSRect(x: 6.5, y: 13, width: 5, height: 3.2)
            NSBezierPath(roundedRect: clip, xRadius: 1.2, yRadius: 1.2).fill()
            // Lines knocked out of the board
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            for (i, w) in [6.0, 5.0, 3.5].enumerated() {
                let y = 9.5 - CGFloat(i) * 2.6
                NSBezierPath(roundedRect: NSRect(x: 6, y: y, width: w, height: 1.4), xRadius: 0.7, yRadius: 0.7).fill()
            }
            // Gap under the clip so it reads as a separate piece
            NSBezierPath(rect: NSRect(x: 5.5, y: 12.3, width: 7, height: 0.8)).fill()
            if paused {
                // Pause bars in the lower right corner
                NSBezierPath(roundedRect: NSRect(x: 10, y: 0, width: 7, height: 7), xRadius: 3.5, yRadius: 3.5).fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
                ink.setFill()
                NSBezierPath(roundedRect: NSRect(x: 11, y: 1, width: 5, height: 5), xRadius: 2.5, yRadius: 2.5).fill()
                NSGraphicsContext.current?.compositingOperation = .destinationOut
                NSBezierPath(rect: NSRect(x: 12.4, y: 2.2, width: 0.9, height: 2.6)).fill()
                NSBezierPath(rect: NSRect(x: 13.7, y: 2.2, width: 0.9, height: 2.6)).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
