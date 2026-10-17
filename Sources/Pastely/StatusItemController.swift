import AppKit
import SwiftUI

/// The menu bar icon and its menu, in AppKit so we get hover callbacks for previews.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let store: ClipStore
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let preview = HoverPreview()

    init(store: ClipStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        statusItem.button?.image = MenuBarGlyph.normal
        statusItem.button?.toolTip = AppInfo.isDev ? "Pastely Dev" : "Pastely"
        menu.delegate = self
        statusItem.menu = menu
    }

    func refreshIcon() {
        statusItem.button?.image = store.isPaused ? MenuBarGlyph.paused : MenuBarGlyph.normal
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let items = Array(store.items.prefix(10))
        if items.isEmpty {
            let none = NSMenuItem(title: "No history yet", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        }
        for item in items {
            let row = NSMenuItem(title: item.menuTitle, action: #selector(copyItem(_:)), keyEquivalent: "")
            row.target = self
            row.representedObject = item
            row.image = AssetCache.menuThumbnail(for: item) ?? NSImage(systemSymbolName: item.kind.symbol, accessibilityDescription: item.kind.label)
            menu.addItem(row)
        }
        menu.addItem(.separator())
        let open = NSMenuItem(title: "Open History", action: #selector(openHistory), keyEquivalent: "v")
        open.keyEquivalentModifierMask = [.command, .shift]
        open.target = self
        menu.addItem(open)
        let pause = NSMenuItem(title: store.isPaused ? "Resume Capture" : "Pause Capture", action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)
        menu.addItem(.separator())
        if UpdaterManager.shared.isEnabled {
            let update = NSMenuItem(title: "Check for Updates…", action: #selector(checkUpdates), keyEquivalent: "")
            update.target = self
            menu.addItem(update)
        }
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let quit = NSMenuItem(title: AppInfo.isDev ? "Quit Pastely Dev" : "Quit Pastely", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        guard let clip = item?.representedObject as? ClipItem, let anchor = statusItem.button?.window?.frame else {
            preview.hide()
            return
        }
        preview.show(clip, store: store, besideMenuAt: anchor)
    }

    func menuDidClose(_ menu: NSMenu) {
        preview.hide()
    }

    // MARK: Actions

    @objc private func copyItem(_ sender: NSMenuItem) {
        guard let clip = sender.representedObject as? ClipItem else { return }
        AppDelegate.shared.paster.copy(clip)
    }

    @objc private func openHistory() { AppDelegate.shared.togglePanel() }

    @objc private func togglePause() {
        store.isPaused.toggle()
        refreshIcon()
    }

    @objc private func checkUpdates() { UpdaterManager.shared.checkForUpdates() }
    @objc private func openSettings() { SettingsWindow.shared.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}

// MARK: - Hover preview

/// Small floating card shown next to the menu while a history row is highlighted.
@MainActor
final class HoverPreview {
    private static let size = NSSize(width: 280, height: 220)
    private let panel: NSPanel
    private let model = HoverPreviewModel()
    private var loadTask: Task<Void, Never>?

    init() {
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = NSHostingView(rootView: HoverPreviewView(model: model))
    }

    func show(_ item: ClipItem, store: ClipStore, besideMenuAt anchor: NSRect) {
        loadTask?.cancel()
        model.item = item
        model.image = AssetCache.cachedImage(for: item) ?? AssetCache.thumbnail(for: item)
        model.text = nil
        if item.kind == .image {
            loadTask = Task { [model] in
                guard let payload = store.payload(for: item),
                      let image = await AssetCache.loadImage(for: item, payload: payload),
                      !Task.isCancelled, model.item?.id == item.id else { return }
                model.image = image
            }
        } else {
            model.text = store.text(for: item).map { String($0.prefix(600)) }
        }
        // The menu drops from the status item; put the card just left of it, under the menu bar.
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        var origin = NSPoint(x: anchor.minX - Self.size.width - 8, y: anchor.minY - Self.size.height - 6)
        if origin.x < visible.minX { origin.x = anchor.maxX + 8 }
        origin.y = max(origin.y, visible.minY)
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    func hide() {
        loadTask?.cancel()
        panel.orderOut(nil)
    }
}

@MainActor
@Observable
final class HoverPreviewModel {
    var item: ClipItem?
    var image: NSImage?
    var text: String?
}

struct HoverPreviewView: View {
    let model: HoverPreviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            if let item = model.item {
                if item.kind == .image, let image = model.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                } else if let text = model.text {
                    Text(text)
                        .font(Theme.Text.caption)
                        .lineLimit(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                HStack(spacing: Theme.Space.xs) {
                    KindBadge(kind: item.kind, size: 16)
                    Text(item.kind == .image ? item.preview : item.sizeLabel)
                    if let app = item.sourceAppName { Text("·"); Text(app).lineLimit(1) }
                    Spacer()
                    Text(item.createdAt.shortAgo)
                }
                .font(Theme.Text.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.Space.md)
        .frame(width: 280, height: 220)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.accent.opacity(0.3)))
    }
}
