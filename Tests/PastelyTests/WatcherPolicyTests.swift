import Testing
@testable import Pastely

struct WatcherPolicyTests {
    let ignored = ["com.apple.Passwords", "com.agilebits.onepassword7"]

    @Test func ignoresWhenFrontAppIsIgnored() {
        #expect(PasteboardWatcher.shouldIgnore(front: "com.apple.Passwords", previous: "com.apple.Safari", ignored: ignored))
    }

    @Test func ignoresWhenCopyHappenedBeforeSwitchingAway() {
        // Copied in Passwords, switched to Safari before the next 500 ms tick.
        #expect(PasteboardWatcher.shouldIgnore(front: "com.apple.Safari", previous: "com.apple.Passwords", ignored: ignored))
    }

    @Test func allowsOrdinaryApps() {
        #expect(!PasteboardWatcher.shouldIgnore(front: "com.apple.Safari", previous: "com.apple.Safari", ignored: ignored))
        #expect(!PasteboardWatcher.shouldIgnore(front: nil, previous: nil, ignored: ignored))
    }
}
