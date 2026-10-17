import SwiftUI

/// Pasteley's small design system. Everything visual reads from here so the
/// panel, settings and menu share one voice.
enum Theme {
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
    }

    enum Text {
        static let title = Font.system(.title3, design: .rounded).weight(.semibold)
        static let body = Font.system(.body)
        static let row = Font.system(size: 13)
        static let caption = Font.system(size: 11)
        static let mono = Font.system(size: 12, design: .monospaced)
        static let hint = Font.system(size: 10.5, weight: .medium, design: .rounded)
    }

    /// Brand indigo, the same hue as the app icon. Slightly lighter in dark mode so it reads on material.
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedRed: 0.49, green: 0.55, blue: 1.0, alpha: 1)
            : NSColor(calibratedRed: 0.33, green: 0.39, blue: 0.96, alpha: 1)
    })

    /// Soft wash laid over the material so the panel reads as Pasteley, not as a system sheet.
    static var wash: some View {
        LinearGradient(colors: [accent.opacity(0.14), accent.opacity(0.03), .clear],
                       startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Clip kinds

extension ClipKind {
    var label: String {
        switch self {
        case .text: "Text"
        case .rtf: "Rich text"
        case .image: "Image"
        case .file: "Files"
        }
    }

    var symbol: String {
        switch self {
        case .text: "text.alignleft"
        case .rtf: "textformat"
        case .image: "photo"
        case .file: "doc"
        }
    }

    var tint: Color {
        switch self {
        case .text: .blue
        case .rtf: .purple
        case .image: .orange
        case .file: .green
        }
    }
}

/// Small colored square with the kind's symbol. Used in rows and the preview pane.
struct KindBadge: View {
    let kind: ClipKind
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: kind.symbol)
            .font(.system(size: size * 0.5, weight: .medium))
            .foregroundStyle(kind.tint)
            .frame(width: size, height: size)
            .background(kind.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }
}

// MARK: - Filter chips

struct FilterChip: View {
    let title: String
    let symbol: String?
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.xs) {
                if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .semibold)) }
                Text(title).font(Theme.Text.caption.weight(.medium))
            }
            .padding(.horizontal, Theme.Space.sm + 2)
            .padding(.vertical, Theme.Space.xs + 1)
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .background(isOn ? Theme.accent : Color.primary.opacity(0.07), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Keyboard hints

struct KeyHint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            Text(keys)
                .font(Theme.Text.hint)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
            Text(label).font(Theme.Text.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Empty state

struct EmptyState: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: Theme.Space.sm) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title).font(Theme.Text.body.weight(.medium))
            Text(detail).font(Theme.Text.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Helpers

extension Date {
    /// "now", "5m", "3h", "2d", else a short date.
    var shortAgo: String {
        let secs = Int(-timeIntervalSinceNow)
        switch secs {
        case ..<60: return "now"
        case ..<3600: return "\(secs / 60)m ago"
        case ..<86_400: return "\(secs / 3600)h ago"
        case ..<(86_400 * 7): return "\(secs / 86_400)d ago"
        default: return formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

extension ClipItem {
    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteSize), countStyle: .file)
    }

    @MainActor var sourceAppName: String? {
        sourceApp.map(AssetCache.appName)
    }

    @MainActor var sourceAppIcon: NSImage? {
        sourceApp.flatMap(AssetCache.appIcon)
    }
}
