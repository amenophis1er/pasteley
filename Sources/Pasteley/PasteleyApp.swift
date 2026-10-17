import SwiftUI

@main
struct PasteleyApp: App {
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
    static let pasteleyOpenSettings = Notification.Name("PasteleyOpenSettings")
}

struct MenuBarIcon: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let paused = AppDelegate.shared?.store.isPaused ?? false
        Image(nsImage: paused ? MenuBarGlyph.paused : MenuBarGlyph.normal)
            .onReceive(NotificationCenter.default.publisher(for: .pasteleyOpenSettings)) { _ in
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

    override init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pasteley", isDirectory: true)
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
        watcher.start()
        registerHotkey()
    }

    /// `pasteley://history` toggles the panel, `pasteley://settings` opens settings.
    /// Handy for Raycast, Alfred or a shell alias.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            switch url.host {
            case "history": togglePanel()
            case "settings":
                NotificationCenter.default.post(name: .pasteleyOpenSettings, object: nil)
            case "pause": store.isPaused = true
            case "resume": store.isPaused = false
            default: break
            }
        }
    }

    func registerHotkey() {
        let s = AppSettings.shared
        hotkey = nil
        hotkey = HotkeyManager(keyCode: s.hotkeyKeyCode, modifiers: .init(rawValue: s.hotkeyModifiers)) { [weak self] in
            self?.togglePanel()
        }
    }

    func togglePanel() {
        if panel.isVisible {
            panel.hide()
        } else {
            paster.rememberFrontApp()
            panel.show { [weak self] item, plain in
                guard let self else { return }
                self.panel.hide()
                self.paster.paste(item, asPlainText: plain)
            }
        }
    }
}

struct MenuBarContent: View {
    private var store: ClipStore { AppDelegate.shared.store }

    var body: some View {
        let items = Array(store.items.prefix(10))
        let hotkey = HotkeyManager.Modifiers(rawValue: AppSettings.shared.hotkeyModifiers).symbols
            + HotkeyManager.keyName(AppSettings.shared.hotkeyKeyCode)

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
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
        Button("Quit Pasteley") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
