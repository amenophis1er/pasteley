import AppKit
import SwiftUI

/// Settings in a plain AppKit window, so it can be opened from anywhere without a SwiftUI scene.
@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = AppInfo.isDev ? "Pastely Dev Settings" : "Pastely Settings"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView())
            w.center()
            window = w
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
