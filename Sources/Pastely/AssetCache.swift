import AppKit

/// Memoizes the expensive bits of rendering a row: decoded images, downsampled
/// thumbnails and app names/icons. Keyed by item id or bundle id.
@MainActor
enum AssetCache {
    private static let images = NSCache<NSNumber, NSImage>()
    private static let thumbs = NSCache<NSNumber, NSImage>()
    private static var appNames: [String: String] = [:]
    private static var appIcons: [String: NSImage] = [:]

    static func cachedImage(for item: ClipItem) -> NSImage? {
        images.object(forKey: NSNumber(value: item.id))
    }

    /// Decodes the full image off the main thread, then caches it by item id.
    static func loadImage(for item: ClipItem, payload: Data) async -> NSImage? {
        if let cached = cachedImage(for: item) { return cached }
        let decoded = await Task.detached(priority: .userInitiated) { () -> NSImage? in
            guard let source = CGImageSourceCreateWithData(payload as CFData, nil),
                  let cg = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: true] as CFDictionary)
            else { return nil }
            return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }.value
        if let decoded { images.setObject(decoded, forKey: NSNumber(value: item.id), cost: payload.count) }
        return decoded
    }

    static func thumbnail(for item: ClipItem) -> NSImage? {
        guard let data = item.thumb else { return nil }
        let key = NSNumber(value: item.id)
        if let cached = thumbs.object(forKey: key) { return cached }
        guard let thumb = NSImage(data: data) else { return nil }
        thumbs.setObject(thumb, forKey: key)
        return thumb
    }

    static func appName(for bundleID: String) -> String {
        if let cached = appNames[bundleID] { return cached }
        let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") } ?? bundleID
        appNames[bundleID] = name
        return name
    }

    static func appIcon(for bundleID: String) -> NSImage? {
        if let cached = appIcons[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 16, height: 16)
        appIcons[bundleID] = icon
        return icon
    }
}
