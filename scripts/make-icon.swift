// Renders the Pasteley app icon: a rounded gradient tile with a clipboard glyph.
// Usage: swift scripts/make-icon.swift Resources
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources"
let iconset = "\(outDir)/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

func render(_ size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let inset = size * 0.08
    let rect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let tile = NSBezierPath(roundedRect: rect, xRadius: size * 0.2, yRadius: size * 0.2)
    let gradient = NSGradient(starting: NSColor(calibratedRed: 0.36, green: 0.42, blue: 1.0, alpha: 1),
                              ending: NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.62, alpha: 1))!
    gradient.draw(in: tile, angle: -70)

    // Clipboard board
    let board = NSRect(x: size * 0.28, y: size * 0.20, width: size * 0.44, height: size * 0.56)
    NSColor.white.withAlphaComponent(0.95).setFill()
    NSBezierPath(roundedRect: board, xRadius: size * 0.06, yRadius: size * 0.06).fill()
    // Clip
    let clip = NSRect(x: size * 0.41, y: size * 0.70, width: size * 0.18, height: size * 0.11)
    NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.62, alpha: 1).setFill()
    NSBezierPath(roundedRect: clip, xRadius: size * 0.035, yRadius: size * 0.035).fill()
    // Lines
    NSColor(calibratedRed: 0.36, green: 0.42, blue: 1.0, alpha: 0.9).setFill()
    for (i, w) in [0.30, 0.24, 0.18].enumerated() {
        let y = size * (0.58 - CGFloat(i) * 0.11)
        NSBezierPath(roundedRect: NSRect(x: size * 0.35, y: y, width: size * w, height: size * 0.045),
                     xRadius: size * 0.02, yRadius: size * 0.02).fill()
    }
    image.unlockFocus()
    return image
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = CGFloat(base * scale)
        let img = render(px)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px), bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: px, height: px)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        img.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
        NSGraphicsContext.restoreGraphicsState()
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
    }
}
print("wrote \(iconset)")
