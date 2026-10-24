import Foundation

/// Tag normalization and textual suggestions (spec 8.3, FR-101).
public enum TagNormalizer {
    /// Lowercase, no diacritics, collapsed and trimmed spaces.
    public static func normalize(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it"))
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Levenshtein distance, used to catch typos ("kickof" → "kickoff").
    public static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }

    /// Existing tags matching `input`: prefix matches first (alphabetical), then near matches by edit
    /// distance (at most 1 for short inputs, 2 otherwise).
    public static func suggestions(for input: String, among tags: [Tag], limit: Int = 8) -> [Tag] {
        let query = normalize(input)
        guard !query.isEmpty else { return Array(tags.sorted { $0.normalized < $1.normalized }.prefix(limit)) }
        let prefix = tags.filter { $0.normalized.hasPrefix(query) }.sorted { $0.normalized < $1.normalized }
        let maxDistance = query.count <= 4 ? 1 : 2
        let near = tags.filter { !$0.normalized.hasPrefix(query) }
            .map { ($0, editDistance($0.normalized, query)) }
            .filter { $0.1 <= maxDistance }
            .sorted { ($0.1, $0.0.normalized) < ($1.1, $1.0.normalized) }
            .map(\.0)
        return Array((prefix + near).prefix(limit))
    }
}
