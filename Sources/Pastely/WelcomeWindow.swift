import AppKit
import SwiftUI

/// First-launch welcome: one screen, the three things that matter, then out of the way.
@MainActor
final class WelcomeWindow {
    static let shared = WelcomeWindow()
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.standardWindowButton(.miniaturizeButton)?.isHidden = true
        w.standardWindowButton(.zoomButton)?.isHidden = true
        w.isReleasedWhenClosed = false
        // Follow the user: granting Accessibility sends them to System Settings on another Space.
        w.collectionBehavior = [.moveToActiveSpace]
        w.contentView = NSHostingView(rootView: WelcomeView { [weak self] in self?.close() })
        w.center()
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func close() {
        AppSettings.shared.didOnboard = true
        window?.close()
        window = nil
    }
}

struct WelcomeView: View {
    let onDone: () -> Void
    @Bindable private var settings = AppSettings.shared
    @State private var accessibility = Paster.isTrusted()
    @State private var launchAtLogin = AppSettings.shared.launchAtLogin
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: Theme.Space.md) {
                hotkeyCard
                accessibilityCard
                loginCard
            }
            .padding(.horizontal, Theme.Space.xl)
            Spacer(minLength: Theme.Space.lg)
            footer
        }
        .frame(width: 520, height: 600)
        .background {
            ZStack(alignment: .top) {
                Color(nsColor: .windowBackgroundColor)
                Theme.wash.frame(height: 260)
            }
        }
        .tint(Theme.accent)
        .onReceive(poll) { _ in
            let trusted = Paster.isTrusted()
            if trusted && !accessibility {
                // Permission just landed: come back in front of System Settings with the green state.
                WelcomeWindow.shared.show()
            }
            accessibility = trusted
        }
        .onChange(of: settings.hotkeyKeyCode) { _, _ in AppDelegate.shared.registerHotkey() }
        .onChange(of: settings.hotkeyModifiers) { _, _ in AppDelegate.shared.registerHotkey() }
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: Theme.Space.sm) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
                .shadow(color: Theme.accent.opacity(0.35), radius: 18, y: 8)
            Text("Welcome to Pastely")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text("Everything you copy, one keystroke away.\nIt all stays on this Mac.")
                .font(Theme.Text.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 44)
        .padding(.bottom, Theme.Space.xl)
    }

    private var hotkeyCard: some View {
        WelcomeCard(symbol: "keyboard", title: "Open your history") {
            Text("Press the shortcut in any app. Type to search, Return to paste.")
        } control: {
            HotkeyRecorder(keyCode: $settings.hotkeyKeyCode, modifiers: $settings.hotkeyModifiers)
        }
    }

    private var accessibilityCard: some View {
        WelcomeCard(symbol: "hand.raised", title: "Paste into other apps",
                    status: accessibility ? nil : .pending("Needed")) {
            Text("macOS calls this Accessibility. Pastely uses it for one thing: sending ⌘V to the app you're in.")
        } control: {
            if accessibility {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(Theme.Text.body.weight(.medium))
            } else {
                Button("Grant Access…") { Paster.requestAccessibility() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var loginCard: some View {
        WelcomeCard(symbol: "power", title: "Start with your Mac") {
            Text("Pastely lives in the menu bar and uses almost nothing while idle.")
        } control: {
            Toggle("", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .labelsHidden()
                .onChange(of: launchAtLogin) { _, on in AppSettings.shared.launchAtLogin = on }
        }
    }

    private var footer: some View {
        VStack(spacing: Theme.Space.md) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xs) {
                Image(systemName: "lock.fill")
                Text("History is encrypted on disk. Password managers are never recorded. No network, ever.")
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
            .font(Theme.Text.caption)
            .foregroundStyle(.secondary)
            Button(action: onDone) {
                Text("Get Started")
                    .font(Theme.Text.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.bottom, Theme.Space.xl)
    }
}

// MARK: - Card

struct WelcomeCard<Detail: View, Control: View>: View {
    enum Status { case good(String), pending(String) }

    let symbol: String
    let title: String
    var status: Status? = nil
    @ViewBuilder let detail: () -> Detail
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.md) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Theme.Space.sm) {
                    Text(title).font(Theme.Text.body.weight(.semibold)).fixedSize()
                    if let status { statusPill(status) }
                }
                detail()
                    .font(Theme.Text.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Theme.Space.md)
            control()
        }
        .padding(Theme.Space.lg)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Color.primary.opacity(0.07)))
    }

    private func statusPill(_ status: Status) -> some View {
        let (text, color): (String, Color) = switch status {
        case .good(let t): (t, .green)
        case .pending(let t): (t, .orange)
        }
        return Text(text)
            .font(Theme.Text.hint)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: Capsule())
    }
}
