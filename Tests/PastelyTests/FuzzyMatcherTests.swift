import Testing
@testable import Pastely

struct FuzzyMatcherTests {
    @Test func matchesSubsequence() {
        #expect(FuzzyMatcher.score("hw", in: "hello world") != nil)
        #expect(FuzzyMatcher.score("wh", in: "hello world") == nil)
    }

    @Test func scatteredLettersInLongTextDoNotMatch() {
        let code = "func debounce<T>(_ delay: Duration, _ work: @escaping (T) -> Void) -> (T) -> Void { var task: Task<Void, Never>? }"
        #expect(FuzzyMatcher.score("invoice", in: code) == nil)
        #expect(FuzzyMatcher.score("invce", in: "invoice 4521") != nil)
    }

    @Test func consecutiveBeatsScattered() {
        let tight = FuzzyMatcher.score("abc", in: "abc xyz")!
        let loose = FuzzyMatcher.score("abc", in: "a1b2c3")!
        #expect(tight > loose)
    }
}
