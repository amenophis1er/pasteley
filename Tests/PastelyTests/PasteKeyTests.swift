import Testing
@testable import Pastely

struct PasteKeyTests {
    let terminals = ["com.apple.Terminal", "com.googlecode.iterm2"]

    @Test func imagesIntoTerminalsUseControlV() {
        #expect(Paster.pasteKey(kind: .image, target: "com.apple.Terminal", terminals: terminals, forceControl: false) == .controlV)
    }

    @Test func textKeepsCommandVEverywhere() {
        #expect(Paster.pasteKey(kind: .text, target: "com.apple.Terminal", terminals: terminals, forceControl: false) == .commandV)
        #expect(Paster.pasteKey(kind: .rtf, target: "com.googlecode.iterm2", terminals: terminals, forceControl: false) == .commandV)
    }

    @Test func imagesIntoOtherAppsUseCommandV() {
        #expect(Paster.pasteKey(kind: .image, target: "com.apple.Safari", terminals: terminals, forceControl: false) == .commandV)
        #expect(Paster.pasteKey(kind: .image, target: nil, terminals: terminals, forceControl: false) == .commandV)
        #expect(Paster.pasteKey(kind: .image, target: "com.apple.Terminal", terminals: [], forceControl: false) == .commandV)
    }

    @Test func holdingControlForcesControlV() {
        #expect(Paster.pasteKey(kind: .text, target: "com.apple.Safari", terminals: [], forceControl: true) == .controlV)
    }
}
