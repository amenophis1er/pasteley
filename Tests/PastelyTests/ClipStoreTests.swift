import Foundation
import Testing
@testable import Pastely

@MainActor
struct ClipStoreTests {
    private func item(_ text: String, at date: Date = Date()) -> ClipItem {
        ClipItem(id: 0, createdAt: date, kind: .text, uti: "public.utf8-plain-text", preview: text,
                 thumb: nil, ocrText: nil, byteSize: text.utf8.count, contentHash: text, sourceApp: nil, pinned: false)
    }

    private func insert(_ store: ClipStore, _ text: String, at date: Date = Date()) {
        store.insert(item(text, at: date), payload: Data(text.utf8))
    }

    @Test func insertAndRead() throws {
        let store = try ClipStore(path: ":memory:")
        insert(store, "hello")
        #expect(store.items.count == 1)
        #expect(store.items[0].preview == "hello")
        #expect(store.text(for: store.items[0]) == "hello")
    }

    @Test func repeatCopyBumpsInsteadOfDuplicating() throws {
        let store = try ClipStore(path: ":memory:")
        insert(store, "a", at: Date(timeIntervalSinceNow: -40))
        insert(store, "b", at: Date(timeIntervalSinceNow: -30))
        insert(store, "a", at: Date(timeIntervalSinceNow: -20))
        #expect(store.items.map(\.preview) == ["a", "b"])
    }

    @Test func countCapKeepsPinned() throws {
        let store = try ClipStore(path: ":memory:")
        store.maxItems = 2
        insert(store, "old", at: Date(timeIntervalSinceNow: -40))
        store.togglePin(store.items[0])
        insert(store, "x", at: Date(timeIntervalSinceNow: -30))
        insert(store, "y", at: Date(timeIntervalSinceNow: -20))
        insert(store, "z", at: Date(timeIntervalSinceNow: -10))
        #expect(Set(store.items.map(\.preview)) == ["old", "y", "z"])
    }

    @Test func searchIsCaseInsensitive() throws {
        let store = try ClipStore(path: ":memory:")
        insert(store, "Hello World")
        insert(store, "other")
        #expect(store.search("world").count == 1)
    }

    @Test func ocrTextIsSearchable() throws {
        let store = try ClipStore(path: ":memory:")
        var img = item("Image 10×10")
        img.kind = .image
        let (id, _) = store.insert(img, payload: Data([1, 2, 3]))
        store.setOCRText("Invoice 4521 due Friday", for: id)
        #expect(store.search("invoice").first?.id == id)
    }

    @Test func cryptoRoundTrip() {
        let data = Data("secret".utf8)
        let sealed = Crypto.seal(data)
        #expect(sealed != data)
        #expect(Crypto.open(sealed) == data)
    }
}
