import CryptoKit
import Foundation
import Testing
@testable import Pastely

/// Serialized: the tests swap the process-wide key provider.
@Suite(.serialized)
@MainActor
struct ClipStoreTests {
    init() {
        Crypto.keyProvider = { SymmetricKey(size: .bits256) }
        Crypto.resetCache()
    }

    private func item(_ text: String, kind: ClipKind = .text, at date: Date = Date()) -> ClipItem {
        ClipItem(id: 0, createdAt: date, kind: kind, uti: "public.utf8-plain-text", preview: text,
                 thumb: nil, ocrText: nil, byteSize: text.utf8.count,
                 contentHash: PasteboardWatcher.contentHash(kind: kind, payload: Data(text.utf8)),
                 sourceApp: nil, pinned: false)
    }

    @discardableResult
    private func insert(_ store: ClipStore, _ text: String, kind: ClipKind = .text, at date: Date = Date()) throws -> Int64 {
        try store.insert(item(text, kind: kind, at: date), payload: Data(text.utf8)).id
    }

    @Test func insertAndRead() throws {
        let store = try ClipStore(path: ":memory:")
        try insert(store, "hello")
        #expect(store.items.count == 1)
        #expect(store.items[0].preview == "hello")
        #expect(store.text(for: store.items[0]) == "hello")
    }

    @Test func repeatCopyBumpsInsteadOfDuplicating() throws {
        let store = try ClipStore(path: ":memory:")
        try insert(store, "a", at: Date(timeIntervalSinceNow: -40))
        try insert(store, "b", at: Date(timeIntervalSinceNow: -30))
        let (id, isNew) = try store.insert(item("a", at: Date(timeIntervalSinceNow: -20)), payload: Data("a".utf8))
        #expect(!isNew)
        #expect(id == store.items[0].id)
        #expect(store.items.map(\.preview) == ["a", "b"])
    }

    @Test func sameBytesDifferentKindAreDifferentClips() throws {
        let store = try ClipStore(path: ":memory:")
        try insert(store, "/tmp/example", kind: .text)
        try insert(store, "/tmp/example", kind: .file)
        #expect(store.items.count == 2)
        #expect(Set(store.items.map(\.kind)) == [.text, .file])
    }

    @Test func countCapKeepsPinned() throws {
        let store = try ClipStore(path: ":memory:")
        store.maxItems = 2
        try insert(store, "old", at: Date(timeIntervalSinceNow: -40))
        store.togglePin(store.items[0])
        try insert(store, "x", at: Date(timeIntervalSinceNow: -30))
        try insert(store, "y", at: Date(timeIntervalSinceNow: -20))
        try insert(store, "z", at: Date(timeIntervalSinceNow: -10))
        #expect(Set(store.items.map(\.preview)) == ["old", "y", "z"])
    }

    @Test func retentionAppliesWithoutANewCopy() throws {
        let store = try ClipStore(path: ":memory:")
        for n in 1...5 { try insert(store, "item \(n)", at: Date(timeIntervalSinceNow: Double(-60 + n))) }
        #expect(store.items.count == 5)
        store.applyRetention(maxItems: 2, maxAgeDays: 30)
        #expect(store.items.map(\.preview) == ["item 5", "item 4"])
    }

    @Test func ageCapAppliesAtStartup() throws {
        let store = try ClipStore(path: ":memory:")
        store.maxAgeDays = 365
        try insert(store, "stale", at: Date(timeIntervalSinceNow: -40 * 86_400))
        try insert(store, "fresh")
        #expect(store.items.count == 2)
        store.applyRetention(maxItems: 500, maxAgeDays: 30) // what launch does with the real settings
        #expect(store.items.map(\.preview) == ["fresh"])
    }

    @Test func unpinningSubjectsItemToCaps() throws {
        let store = try ClipStore(path: ":memory:")
        store.maxItems = 1
        try insert(store, "keep", at: Date(timeIntervalSinceNow: -20))
        store.togglePin(store.items[0])
        try insert(store, "newer", at: Date(timeIntervalSinceNow: -10))
        #expect(store.items.count == 2)
        store.togglePin(store.items.first { $0.preview == "keep" }!)
        #expect(store.items.map(\.preview) == ["newer"])
    }

    @Test func searchIsCaseInsensitive() throws {
        let store = try ClipStore(path: ":memory:")
        try insert(store, "Hello World")
        try insert(store, "other")
        #expect(store.search("world").count == 1)
    }

    @Test func ocrTextIsSearchable() throws {
        let store = try ClipStore(path: ":memory:")
        let id = try insert(store, "Image 10×10", kind: .image)
        try store.setOCRText("Invoice 4521 due Friday", for: id)
        #expect(store.search("invoice").first?.id == id)
    }

    // MARK: Crypto

    @Test func cryptoRoundTrip() throws {
        let data = Data("secret".utf8)
        let sealed = try Crypto.seal(data)
        #expect(sealed != data)
        #expect(Crypto.open(sealed) == data)
    }

    @Test func openRejectsGarbageAndWrongKey() throws {
        let sealed = try Crypto.seal(Data("secret".utf8))
        #expect(Crypto.open(Data([1, 2, 3])) == nil)
        Crypto.keyProvider = { SymmetricKey(size: .bits256) }
        Crypto.resetCache()
        #expect(Crypto.open(sealed) == nil)
    }

    @Test func sealFailsClosedWhenKeyUnavailable() throws {
        Crypto.keyProvider = { throw CryptoError.keychain(errSecAuthFailed) }
        Crypto.resetCache()
        #expect(throws: CryptoError.keychain(errSecAuthFailed)) { try Crypto.seal(Data("x".utf8)) }
    }

    @Test func insertWritesNothingWhenEncryptionFails() throws {
        let store = try ClipStore(path: ":memory:")
        Crypto.keyProvider = { throw CryptoError.keychain(errSecInteractionNotAllowed) }
        Crypto.resetCache()
        #expect(throws: CryptoError.self) { try insert(store, "must not land") }
        #expect(store.items.isEmpty)
    }

    @Test func shortKeyIsRejected() {
        Crypto.keyProvider = { SymmetricKey(size: .bits128) }
        Crypto.resetCache()
        #expect(throws: CryptoError.invalidKey) { try Crypto.seal(Data("x".utf8)) }
    }
}
