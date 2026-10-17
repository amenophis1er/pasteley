import AppKit
import Sparkle

/// Sparkle wrapper. Disabled for dev builds and for any bundle without a feed URL,
/// so running from source never talks to GitHub.
@MainActor
final class UpdaterManager {
    static let shared = UpdaterManager()

    private let controller: SPUStandardUpdaterController?

    var isEnabled: Bool { controller != nil }
    var canCheck: Bool { controller?.updater.canCheckForUpdates ?? false }

    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    var lastCheck: Date? { controller?.updater.lastUpdateCheckDate }

    private init() {
        guard !AppInfo.isDev, Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil else {
            controller = nil
            return
        }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    func checkForUpdates() {
        NSApp.activate()
        controller?.checkForUpdates(nil)
    }
}
