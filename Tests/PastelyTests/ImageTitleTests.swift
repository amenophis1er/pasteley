import Testing
@testable import Pastely

struct ImageTitleTests {
    @Test func skipsFragmentsAndJoinsShortLines() {
        let ocr = "+\n• • nophis'\nPNC Bank Alert\nToday\nZelle payment of $500.00"
        #expect(ClipItem.imageTitle(from: ocr) == "PNC Bank Alert · Today")
    }

    @Test func keepsOneLongLineAlone() {
        #expect(ClipItem.imageTitle(from: "Invoice 4521 due Friday, please pay\nAcme") == "Invoice 4521 due Friday, please pay")
    }

    @Test func nothingMeaningfulGivesNil() {
        #expect(ClipItem.imageTitle(from: "+\n--\n12") == nil)
        #expect(ClipItem.imageTitle(from: nil) == nil)
    }

    @Test func truncatesLongTitles() {
        let long = String(repeating: "word ", count: 20)
        #expect(ClipItem.imageTitle(from: long)!.hasSuffix("…"))
    }
}
