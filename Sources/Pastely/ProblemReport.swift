import AppKit
import SwiftUI

/// "Report a Problem": a sheet that posts a description plus visible diagnostics to the
/// site's report endpoint, which files a GitHub issue. Nothing from the clipboard is ever included.
enum Diagnostics {
    @MainActor static func collect() -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let s = AppSettings.shared
        let store = AppDelegate.shared.store
        var lines: [String] = []
        lines.append("Pastely \(AppInfo.version) (\(AppInfo.build)) \(AppInfo.commit)\(AppInfo.isDev ? " [dev]" : "")")
        lines.append("macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion), \(machine())")
        lines.append("Accessibility: \(Paster.isTrusted() ? "granted" : "not granted")")
        lines.append("Hotkey: \(HotkeyManager.label(keyCode: s.hotkeyKeyCode, modifiers: s.hotkeyModifiers))")
        lines.append("Launch at login: \(s.launchAtLogin), auto-update: \(UpdaterManager.shared.automaticallyChecks)")
        lines.append("Capture images: \(s.captureImages) (max \(s.maxImageMB) MB), OCR: \(s.ocrImages)")
        lines.append("Retention: \(s.maxItems) items / \(s.maxAgeDays) days, ignored apps: \(s.ignoredApps.count)")
        lines.append("History: \(store.items.count) items, \(ByteCountFormatter.string(fromByteCount: Int64(store.totalBytes), countStyle: .file)), paused: \(store.isPaused)")
        return lines.joined(separator: "\n")
    }

    private static func machine() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &buf, &size, nil, 0)
        return String(cString: buf)
    }
}

enum ReportSender {
    static let endpoint = URL(string: "https://pastely.amenophis.dev/api/report")!

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Returns the URL of the filed issue.
    static func send(description: String, email: String, diagnostics: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "description": description, "email": email, "diagnostics": diagnostics,
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw Failure(message: json["error"] as? String ?? "The server could not take the report right now.")
        }
        return json["url"] as? String ?? ""
    }
}

@MainActor
final class ReportWindow {
    static let shared = ReportWindow()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Report a Problem"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: ReportView { [weak self] in self?.window?.close() })
            w.center()
            window = w
        }
        // An accessory app opening a window from a menu or URL must insist on coming forward.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}

struct ReportView: View {
    let onClose: () -> Void
    @State private var description = ""
    @State private var email = ""
    @State private var diagnostics = Diagnostics.collect()
    @State private var sending = false
    @State private var error: String?
    @State private var filedURL: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            if let filedURL {
                sent(filedURL)
            } else {
                form
            }
        }
        .padding(Theme.Space.xl)
        .frame(width: 520, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(Theme.accent)
    }

    private var form: some View {
        Group {
            Text("What went wrong?").font(Theme.Text.title)
            Text("A sentence or two is enough. What you did, what you expected, what happened instead.")
                .font(Theme.Text.caption).foregroundStyle(.secondary)
            TextEditor(text: $description)
                .font(Theme.Text.body)
                .frame(height: 150)
                .padding(6)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).strokeBorder(Color.primary.opacity(0.1)))

            TextField("Email, if you'd like a reply (optional, kept private)", text: $email)
                .textFieldStyle(.roundedBorder)

            Text("Sent with the report").font(Theme.Text.caption.weight(.semibold)).padding(.top, Theme.Space.xs)
            ScrollView {
                Text(diagnostics)
                    .font(Theme.Text.mono)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Space.sm)
            }
            .frame(height: 120)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
            Text("Nothing from your clipboard history is included. Your description and the block above become a public issue on GitHub; your email does not.")
                .font(Theme.Text.caption).foregroundStyle(.secondary)

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.Text.caption).foregroundStyle(.orange)
            }
            HStack {
                Button("Copy Report") { copyReport() }
                Spacer()
                Button("Cancel") { onClose() }.keyboardShortcut(.cancelAction)
                Button(sending ? "Sending…" : "Send") { Task { await send() } }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(sending || description.trimmingCharacters(in: .whitespacesAndNewlines).count < 10)
            }
        }
    }

    private func sent(_ url: String) -> some View {
        VStack(spacing: Theme.Space.md) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(.green)
            Text("Thanks, it's filed.").font(Theme.Text.title)
            if let link = URL(string: url) {
                Link("Follow it on GitHub", destination: link).font(Theme.Text.body)
            }
            Spacer()
            Button("Done") { onClose() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func send() async {
        sending = true
        error = nil
        defer { sending = false }
        do {
            filedURL = try await ReportSender.send(description: description, email: email, diagnostics: diagnostics)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func copyReport() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("\(description)\n\n\(diagnostics)", forType: .string)
    }
}
