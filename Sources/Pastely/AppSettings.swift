import Foundation
import Observation
import ServiceManagement

/// User preferences, persisted in UserDefaults. One instance, main-actor only.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    var hotkeyKeyCode: UInt32 { didSet { defaults.set(Int(hotkeyKeyCode), forKey: "hotkeyKeyCode") } }
    var hotkeyModifiers: UInt32 { didSet { defaults.set(Int(hotkeyModifiers), forKey: "hotkeyModifiers") } }
    var maxItems: Int { didSet { defaults.set(maxItems, forKey: "maxItems") } }
    var maxAgeDays: Int { didSet { defaults.set(maxAgeDays, forKey: "maxAgeDays") } }
    var maxImageMB: Int { didSet { defaults.set(maxImageMB, forKey: "maxImageMB") } }
    var ignoredApps: [String] { didSet { defaults.set(ignoredApps, forKey: "ignoredApps") } }
    /// Apps whose program (Claude Code, Codex…) takes images with ⌃V instead of ⌘V.
    var terminalApps: [String] { didSet { defaults.set(terminalApps, forKey: "terminalApps") } }
    var terminalImagePaste: Bool { didSet { defaults.set(terminalImagePaste, forKey: "terminalImagePaste") } }
    var captureImages: Bool { didSet { defaults.set(captureImages, forKey: "captureImages") } }
    var ocrImages: Bool { didSet { defaults.set(ocrImages, forKey: "ocrImages") } }
    var didOnboard: Bool { didSet { defaults.set(didOnboard, forKey: "didOnboard") } }
    /// One-time hint in the panel footer after onboarding, cleared on the first paste or hotkey use.
    var showFirstUseTip: Bool { didSet { defaults.set(showFirstUseTip, forKey: "showFirstUseTip") } }

    static let defaultIgnoredApps = ["com.apple.keychainaccess", "com.apple.Passwords"]
    static let defaultTerminalApps = [
        "com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.Warp-Stable",
        "net.kovidgoyal.kitty", "org.alacritty", "com.github.wez.wezterm",
        "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", "com.exafunction.windsurf",
    ]

    private init() {
        hotkeyKeyCode = UInt32(defaults.object(forKey: "hotkeyKeyCode") as? Int ?? 9) // V
        hotkeyModifiers = UInt32(defaults.object(forKey: "hotkeyModifiers") as? Int
            ?? Int(HotkeyManager.Modifiers([.command, .shift]).rawValue))
        maxItems = defaults.object(forKey: "maxItems") as? Int ?? 500
        maxAgeDays = defaults.object(forKey: "maxAgeDays") as? Int ?? 30
        maxImageMB = defaults.object(forKey: "maxImageMB") as? Int ?? 10
        ignoredApps = defaults.stringArray(forKey: "ignoredApps") ?? Self.defaultIgnoredApps
        terminalApps = defaults.stringArray(forKey: "terminalApps") ?? Self.defaultTerminalApps
        terminalImagePaste = defaults.object(forKey: "terminalImagePaste") as? Bool ?? true
        captureImages = defaults.object(forKey: "captureImages") as? Bool ?? true
        ocrImages = defaults.object(forKey: "ocrImages") as? Bool ?? true
        didOnboard = defaults.bool(forKey: "didOnboard")
        showFirstUseTip = defaults.bool(forKey: "showFirstUseTip")
    }

    // MARK: Launch at login

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Pastely: launch at login failed: \(error)")
            }
        }
    }
}
