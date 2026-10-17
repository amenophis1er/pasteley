import Testing
@testable import Pastely

struct FuzzyMatcherTests {
    @Test func matchesSubsequence() {
        #expect(FuzzyMatcher.score("hw", in: "hello world") != nil)
        #expect(FuzzyMatcher.score("wh", in: "hello world") == nil)
    }

    @Test func consecutiveBeatsScattered() {
        let tight = FuzzyMatcher.score("abc", in: "abc xyz")!
        let loose = FuzzyMatcher.score("abc", in: "a1b2c3")!
        #expect(tight > loose)
    }
}
