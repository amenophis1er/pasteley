import AppKit

// Pure AppKit shell: the status item, panel and windows are managed by AppDelegate,
// and every screen is SwiftUI hosted in an NSWindow or NSPanel.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
