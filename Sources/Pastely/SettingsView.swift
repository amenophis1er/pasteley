import AppKit
import SwiftUI

struct SettingsView: View {
    enum Tab: String, CaseIterable, Hashable {
        case general, history, privacy, about

        var title: String { rawValue.capitalized }
        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .history: "clock.arrow.circlepath"
            case .privacy: "hand.raised"
            case .about: "info.circle"
            }
        }
    }

    static let size = CGSize(width: 560, height: 600)
    @State private var tab: Tab

    init(initialTab: Tab = .general) { _tab = State(initialValue: initialTab) }

    var body: some View {
        VStack(spacing: 0) {
            // Chip tab bar, the same component language as the panel's filters.
            HStack(spacing: Theme.Space.sm) {
                ForEach(Tab.allCases, id: \.self) { t in
                    FilterChip(title: t.title, symbol: t.symbol, isOn: tab == t) { tab = t }
                }
            }
            .padding(.top, 38) // clear the (transparent) title bar and traffic lights
            .padding(.bottom, Theme.Space.md)
            Divider()
            Group {
                switch tab {
                case .general: GeneralSettings()
                case .history: HistorySettings()
                case .privacy: PrivacySettings()
                case .about: AboutSettings()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background {
            ZStack(alignment: .top) {
                Color(nsColor: .windowBackgroundColor)
                Theme.wash.frame(height: 120)
            }
        }
        .tint(Theme.accent)
    }
}

// MARK: - General

struct GeneralSettings: View {
    @Bindable private var settings = AppSettings.shared
    @State private var accessibility = Screenshots.isRendering || Paster.isTrusted()
    @State private var launchAtLogin = Screenshots.isRendering || AppSettings.shared.launchAtLogin
    @State private var autoUpdate = Screenshots.isRendering || UpdaterManager.shared.automaticallyChecks
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                LabeledContent("Open history") {
                    HotkeyRecorder(keyCode: $settings.hotkeyKeyCode, modifiers: $settings.hotkeyModifiers)
                }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in AppSettings.shared.launchAtLogin = on }
            }
            Section {
                LabeledContent("Accessibility") {
                    HStack(spacing: Theme.Space.sm) {
                        Circle().fill(accessibility ? Color.green : Color.orange).frame(width: 8, height: 8)
                        Text(accessibility ? "Granted" : "Not granted")
                        if !accessibility {
                            Button("Grant…") { Paster.requestAccessibility() }.controlSize(.small)
                        }
                    }
                }
            } footer: {
                Text("Needed to paste into the front app after you pick an item. Without it, Pastely copies the item and you paste with ⌘V.")
                    .font(Theme.Text.caption).foregroundStyle(.secondary)
            }
            Section("Updates") {
                if UpdaterManager.shared.isEnabled || Screenshots.isRendering {
                    Toggle("Check for updates automatically", isOn: $autoUpdate)
                        .onChange(of: autoUpdate) { _, on in UpdaterManager.shared.automaticallyChecks = on }
                    LabeledContent(AppInfo.versionLine) {
                        Button("Check Now") { UpdaterManager.shared.checkForUpdates() }
                            .disabled(!UpdaterManager.shared.canCheck && !Screenshots.isRendering)
                    }
                } else {
                    LabeledContent(AppInfo.versionLine) {
                        Text(AppInfo.isDev ? "Dev build, updates off" : "Updates unavailable").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onChange(of: settings.hotkeyKeyCode) { _, _ in AppDelegate.shared.registerHotkey() }
        .onChange(of: settings.hotkeyModifiers) { _, _ in AppDelegate.shared.registerHotkey() }
        .onReceive(timer) { _ in if !Screenshots.isRendering { accessibility = Paster.isTrusted() } }
    }
}

// MARK: - History

struct HistorySettings: View {
    @Bindable private var settings = AppSettings.shared
    @State private var confirmClear = false

    private var clearTitle: String {
        let n = AppDelegate.shared.store.items.filter { !$0.pinned }.count
        return n == 1 ? "Delete 1 unpinned item?" : "Delete \(n) unpinned items?"
    }

    var body: some View {
        Form {
            Section("Retention") {
                Picker("Keep up to", selection: $settings.maxItems) {
                    ForEach([100, 250, 500, 1000, 2500], id: \.self) { Text("\($0) items").tag($0) }
                }
                Picker("Expire after", selection: $settings.maxAgeDays) {
                    ForEach([1, 7, 30, 90, 365], id: \.self) { Text($0 == 1 ? "1 day" : "\($0) days").tag($0) }
                }
            }
            Section {
                Toggle("Capture images", isOn: $settings.captureImages)
                Picker("Skip images larger than", selection: $settings.maxImageMB) {
                    ForEach([2, 5, 10, 25, 50], id: \.self) { Text("\($0) MB").tag($0) }
                }
                .disabled(!settings.captureImages)
                Toggle("Recognize text in images", isOn: $settings.ocrImages)
                    .disabled(!settings.captureImages)
            } header: {
                Text("Images")
            } footer: {
                Text("Text found in screenshots becomes searchable. Recognition runs on this Mac through Vision and is stored encrypted with the image.")
                    .font(Theme.Text.caption).foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Stored") {
                    let store = AppDelegate.shared.store
                    Text("\(store.items.count) items · \(ByteCountFormatter.string(fromByteCount: Int64(store.totalBytes), countStyle: .file))")
                        .foregroundStyle(.secondary)
                }
                Button("Clear unpinned history…", role: .destructive) { confirmClear = true }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onChange(of: settings.maxItems) { _, _ in AppDelegate.shared.applyRetention() }
        .onChange(of: settings.maxAgeDays) { _, _ in AppDelegate.shared.applyRetention() }
        .confirmationDialog(clearTitle, isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { AppDelegate.shared.store.clear() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pinned items are kept. This cannot be undone.")
        }
    }
}

// MARK: - Privacy

struct PrivacySettings: View {
    @Bindable private var settings = AppSettings.shared
    @State private var selected: String?

    var body: some View {
        Form {
            Section {
                List(selection: $selected) {
                    ForEach(settings.ignoredApps, id: \.self) { bundleID in
                        HStack(spacing: Theme.Space.sm) {
                            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable().frame(width: 18, height: 18)
                                Text(FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""))
                            } else {
                                Image(systemName: "app.dashed").frame(width: 18)
                                Text(bundleID)
                            }
                            Spacer()
                            Text(bundleID).font(Theme.Text.caption).foregroundStyle(.tertiary)
                        }
                        .tag(bundleID)
                    }
                }
                .frame(height: 220)
                HStack {
                    Menu("Add running app") {
                        ForEach(runningApps, id: \.bundleIdentifier) { app in
                            Button(app.localizedName ?? app.bundleIdentifier ?? "?") {
                                if let id = app.bundleIdentifier, !settings.ignoredApps.contains(id) {
                                    settings.ignoredApps.append(id)
                                }
                            }
                        }
                    }
                    .fixedSize()
                    Button("Choose…") { chooseApp() }
                    Spacer()
                    Button("Remove") {
                        if let selected { settings.ignoredApps.removeAll { $0 == selected } }
                        selected = nil
                    }
                    .disabled(selected == nil)
                }
            } header: {
                Text("Ignored apps")
            } footer: {
                Text("Copies made while one of these apps is in front are never recorded. Password managers that mark their pasteboard as concealed are skipped automatically.")
                    .font(Theme.Text.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url,
              let id = Bundle(url: url)?.bundleIdentifier, !settings.ignoredApps.contains(id) else { return }
        settings.ignoredApps.append(id)
    }
}

// MARK: - About

struct AboutSettings: View {
    var body: some View {
        VStack(spacing: Theme.Space.md) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 72, height: 72)
            Text("Pastely").font(Theme.Text.title)
            Text(AppInfo.versionLine)
                .font(Theme.Text.caption).foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("A small, local-only clipboard manager.\nYour history never leaves this Mac.")
                .font(Theme.Text.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
            HStack(spacing: Theme.Space.md) {
                Button("Show Welcome Screen") { WelcomeWindow.shared.show() }
                Link("pastely.amenophis.dev", destination: URL(string: "https://pastely.amenophis.dev")!)
                Link("GitHub", destination: URL(string: "https://github.com/amenophis1er/pastely")!)
            }
            .controlSize(.small)
        }
        .padding(Theme.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
