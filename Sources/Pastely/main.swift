import AppKit

// Pure AppKit shell: the status item, panel and windows are managed by AppDelegate,
// and every screen is SwiftUI hosted in an NSWindow or NSPanel.
// A second copy of the same build (a dev binary launched by hand, a stale process after an
// update) would double-poll the pasteboard and fight over the hotkey, so it yields at once.
if let bundleID = Bundle.main.bundleIdentifier,
   NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
       .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
    NSLog("Pastely: another instance of \(bundleID) is running, quitting")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
