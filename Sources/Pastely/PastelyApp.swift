import SwiftUI

@main
struct PastelyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
        } label: {
            MenuBarIcon()
        }
        Settings {
            SettingsView()
        }
    }
}

extension Notification.Name {
    static let pastelyOpenSettings = Notification.Name("PastelyOpenSettings")
}

struct MenuBarIcon: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let paused = AppDelegate.shared?.store.isPaused ?? false
        Image(nsImage: paused ? MenuBarGlyph.paused : MenuBarGlyph.normal)
            .onReceive(NotificationCenter.default.publisher(for: .pastelyOpenSettings)) { _ in
                NSApp.activate()
                openSettings()
            }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    nonisolated(unsafe) static var shared: AppDelegate!

    let store: ClipStore
    let watcher: PasteboardWatcher
    let panel: HistoryPanel
    let paster: Paster
    private var hotkey: HotkeyManager?
    private var hotkeyCombo: (keyCode: UInt32, modifiers: UInt32)?
    private var retentionTimer: Timer?

    override init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppInfo.isDev ? "Pastely Dev" : "Pastely", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        store = try! ClipStore(path: support.appendingPathComponent("history.sqlite").path)
        watcher = PasteboardWatcher(store: store)
        panel = HistoryPanel(store: store)
        paster = Paster(store: store)
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        applyRetention()
        retentionTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { @MainActor in AppDelegate.shared.applyRetention() }
        }
        watcher.start()
        registerHotkey()
        _ = UpdaterManager.shared // starts Sparkle's scheduled checks for release builds
        if !AppSettings.shared.didOnboard { WelcomeWindow.shared.show() }
    }

    /// Prunes with the current settings. Runs at launch, hourly, and when retention settings change.
    func applyRetention() {
        let s = AppSettings.shared
        store.applyRetention(maxItems: s.maxItems, maxAgeDays: s.maxAgeDays)
    }

    /// `pastely://history` toggles the panel, `pastely://settings` opens settings.
    /// Handy for Raycast, Alfred or a shell alias.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            switch url.host {
            case "history": togglePanel()
            case "settings":
                NotificationCenter.default.post(name: .pastelyOpenSettings, object: nil)
            case "welcome": WelcomeWindow.shared.show()
            case "pause": store.isPaused = true
            case "resume": store.isPaused = false
            default: break
            }
        }
    }

    /// Registers the shortcut from settings. If the system refuses it (another app owns it),
    /// the previous working shortcut is kept and the settings are reverted to match.
    func registerHotkey() {
        let s = AppSettings.shared
        let combo = (keyCode: s.hotkeyKeyCode, modifiers: s.hotkeyModifiers)
        if let current = hotkeyCombo, current == combo, hotkey != nil { return }

        let candidate = HotkeyManager(keyCode: combo.keyCode, modifiers: .init(rawValue: combo.modifiers)) { [weak self] in
            if AppSettings.shared.showFirstUseTip { AppSettings.shared.showFirstUseTip = false } // they found it
            self?.togglePanel()
        }
        guard let candidate else {
            NSSound.beep()
            if let previous = hotkeyCombo {
                // Revert the stored values; this re-enters registerHotkey and no-ops on the match.
                s.hotkeyKeyCode = previous.keyCode
                s.hotkeyModifiers = previous.modifiers
                let alert = NSAlert()
                alert.messageText = "That shortcut is taken"
                alert.informativeText = "\(HotkeyManager.label(keyCode: combo.keyCode, modifiers: combo.modifiers)) is already used by another app. Pastely kept \(HotkeyManager.label(keyCode: previous.keyCode, modifiers: previous.modifiers))."
                alert.runModal()
            } else {
                NSLog("Pastely: could not register the global shortcut")
            }
            return
        }
        hotkey = candidate // releasing the old registration, if any
        hotkeyCombo = combo
    }

    func togglePanel() {
        if panel.isVisible { panel.hide() } else { openPanel() }
    }

    func showPanel() {
        if !panel.isVisible { openPanel() }
    }

    private func openPanel() {
        paster.rememberFrontApp()
        panel.show { [weak self] item, plain in
            guard let self else { return }
            self.panel.hide()
            self.paster.paste(item, asPlainText: plain)
        }
    }
}

struct MenuBarContent: View {
    private var store: ClipStore { AppDelegate.shared.store }

    var body: some View {
        let items = Array(store.items.prefix(10))
        let hotkey = HotkeyManager.label(keyCode: AppSettings.shared.hotkeyKeyCode, modifiers: AppSettings.shared.hotkeyModifiers)

        if items.isEmpty {
            Text("No history yet")
        }
        ForEach(items) { item in
            Button {
                AppDelegate.shared.paster.copy(item)
            } label: {
                Label(item.menuTitle, systemImage: item.kind.symbol)
            }
        }
        Divider()
        Button("Open History    \(hotkey)") { AppDelegate.shared.togglePanel() }
        Button(store.isPaused ? "Resume Capture" : "Pause Capture") { store.isPaused.toggle() }
        Divider()
        if UpdaterManager.shared.isEnabled {
            Button("Check for Updates…") { UpdaterManager.shared.checkForUpdates() }
        }
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
        Button("Quit Pastely") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
