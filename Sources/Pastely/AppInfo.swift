import Foundation

/// Identity and version strings read from Info.plist, stamped by scripts/bundle.sh.
enum AppInfo {
    static let bundleID = Bundle.main.bundleIdentifier ?? "com.amenophis.pastely"
    static let isDev = bundleID.hasSuffix(".dev")
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    static let commit = Bundle.main.infoDictionary?["PastelyCommit"] as? String ?? "unknown"

    /// "Version 0.1.0 (42) · a1b2c3d"
    static var versionLine: String { "Version \(version) (\(build)) · \(commit)" }
}
