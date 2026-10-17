import AppKit

enum ClipKind: String, Codable, Sendable {
    case text, rtf, image, file
}

/// One history row as the UI sees it: metadata, a short preview and, for images,
/// a small thumbnail. The full payload stays in the database and is loaded on demand
/// through `ClipStore.payload(for:)`.
struct ClipItem: Identifiable, Hashable, Sendable {
    var id: Int64
    var createdAt: Date
    var kind: ClipKind
    var uti: String
    var preview: String
    var thumb: Data?
    /// Text recognized inside an image, used for search and shown under the preview.
    var ocrText: String?
    var byteSize: Int
    var contentHash: String
    var sourceApp: String?
    var pinned: Bool

    var menuTitle: String {
        switch kind {
        case .image: return "Image (\(ByteCountFormatter.string(fromByteCount: Int64(byteSize), countStyle: .file)))"
        case .file: return preview.split(separator: "\n").first.map(String.init) ?? preview
        default:
            let line = preview.split(whereSeparator: \.isNewline).first.map(String.init) ?? preview
            let short = line.count > 60 ? String(line.prefix(60)) + "…" : line
            // AppKit turns a title of "-" into a separator; keep dashes visible as text.
            return short.hasPrefix("-") || short.isEmpty ? "\u{2009}" + short : short
        }
    }

    /// What search matches against.
    var searchText: String {
        if let ocrText { return preview + "\n" + ocrText }
        return preview
    }

    /// Plain text for a payload of this item's kind.
    func text(from payload: Data) -> String? {
        switch kind {
        case .text: return String(data: payload, encoding: .utf8)
        case .rtf: return NSAttributedString(rtf: payload, documentAttributes: nil)?.string
        case .file: return preview
        case .image: return nil
        }
    }
}
