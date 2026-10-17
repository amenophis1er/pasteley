import Foundation

/// Subsequence matcher: every query character must appear in order. Consecutive
/// matches and matches at word starts score higher. Returns nil when not matched.
enum FuzzyMatcher {
    static func score(_ query: String, in text: String) -> Int? {
        let q = Array(query), t = Array(text)
        guard !q.isEmpty, q.count <= t.count else { return nil }
        var qi = 0, score = 0, lastMatch = -2
        for (ti, ch) in t.enumerated() where qi < q.count {
            if ch == q[qi] {
                score += 10
                if ti == lastMatch + 1 { score += 15 }
                if ti == 0 || t[ti - 1] == " " || t[ti - 1] == "_" || t[ti - 1] == "/" || t[ti - 1] == "." { score += 10 }
                lastMatch = ti
                qi += 1
            }
        }
        guard qi == q.count else { return nil }
        return score - min(t.count / 20, 30)
    }
}
